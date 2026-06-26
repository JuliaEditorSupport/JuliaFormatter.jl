"""
    FormattingError(line, column, original_error)

Error thrown when formatting fails. The `line` and `column` fields indicate the location of
the error in the source code.
"""
struct FormattingError <: Exception
    line::Int
    column::Int
    original_error::Exception
end
function Base.showerror(io::IO, fe::FormattingError)
    print(io, "\nformatting error at line $(fe.line), column $(fe.column)\n")
end

"""
    InvalidFormattedTextError(msg)

Error thrown when the formatted text is invalid.
"""
struct InvalidFormattedTextError <: Exception
    juliasyntax_error::JuliaSyntax.ParseError
end
function Base.showerror(io::IO, ie::InvalidFormattedTextError)
    print(io, "\nformatted text could not be parsed as valid Julia\n")
    showerror(io, ie.juliasyntax_error)
end

"""
    InvalidFileError(filename)

Error thrown when the file to be formatted is not a valid Julia or Markdown file.
"""
struct InvalidFileError <: Exception
    filename::AbstractString
end
function Base.showerror(io::IO, e::InvalidFileError)
    print(io, "\nthe file to be formatted ($(e.filename)) was not a Julia or Markdown file\n")
end

const UNIX_TO_WINDOWS = r"\r?\n" => "\r\n"
const WINDOWS_TO_UNIX = "\r\n" => "\n"
function choose_line_ending_replacer(text)
    rn = count("\r\n", text)
    n = count(r"(?<!\r)\n", text)
    n >= rn ? WINDOWS_TO_UNIX : UNIX_TO_WINDOWS
end
normalize_line_ending(s::AbstractString, replacer = WINDOWS_TO_UNIX) = replace(s, replacer)

"""
    _format_text(
        text::AbstractString, style::AbstractStyle, opts::Options{Union{}};
        check_output::Bool=true,
        maxiters::Int=1,
        ensure_trailing_newline::Bool=false
    )

The lower-level entry point for text formatting.

`check_output` is a boolean flag that indicates whether the output should be checked for
validity. If set to `true`, the function will attempt to parse the formatted text and throw
an `InvalidFormattedTextError` if it is not valid Julia code. If `false` it will just return
the formatted text, which may be invalid!

The `maxiters` keyword argument is specified in order to allow the formatting algorithm to
iterate to a fixed point. This is a hack and should really not be used, but currently
SciMLStyle is not idempotent and requires multiple iterations to reach a fixed point. By
default `maxiters` is set to 1, i.e., only one pass.

If `ensure_trailing_newline` is set to `true`, the function will ensure that the formatted
text ends with a single newline character. This might be either CRLF or LF depending on the
line ending normalization settings. If set to `false`, the function will not modify the
trailing newline character(s) in the formatted text. This option is useful when formatting
files.
"""
function _format_text(
    text::AbstractString,
    style::AbstractStyle,
    opts::Options{Union{}};
    check_output::Bool = true,
    maxiters::Int = opts.max_iterations,
    ensure_trailing_newline::Bool = false,
)
    maxiters <= 0 && return text
    if isempty(text)
        if ensure_trailing_newline
            return opts.normalize_line_endings == "windows" ? "\r\n" : "\n"
        end
        return text
    end

    node = JuliaSyntax.parseall(
        JuliaSyntax.GreenNode,
        text;
        ignore_warnings = true,
        version = SUPPORTED_SYNTAX_VERSION,
    )

    s = State(Document(text), opts)
    fst::FST = try
        pretty(style, node, s)
    catch e
        loc = cursor_loc(s, s.offset)
        throw(FormattingError(loc[1], loc[2], e))
    end
    if hascomment(s.doc, fst.endline)
        add_node!(fst, InlineComment(fst.endline), s)
    end

    flatten_fst!(fst)

    if s.opts.short_circuit_to_if
        short_circuit_to_if_pass!(fst, s)
    end

    if needs_alignment(s.opts)
        align_fst!(fst, s.opts)
    end

    nest!(style, fst, s)

    # ignore maximum width can be extra whitespace at the end of lines
    # remove it all before we print.
    if s.opts.join_lines_based_on_source
        remove_superfluous_whitespace!(fst)
    end

    s.line_offset = 0
    io = IOBuffer()

    # Print comments and whitespace before code.
    if fst.startline > 1
        format_check(io, Notcode(1, fst.startline - 1), s)
        print_leaf(io, Newline(), s)
    end
    print_tree(io, fst, s)
    nlines = numlines(s.doc)
    if fst.endline < nlines
        if s.on
            print_leaf(io, Newline(), s)
        end
        format_check(io, Notcode(fst.endline + 1, nlines), s)
    end
    if s.doc.ends_on_nl
        print_leaf(io, Newline(), s)
    end
    output = String(take!(io))

    replacer = if s.opts.normalize_line_endings == "unix"
        WINDOWS_TO_UNIX
    elseif s.opts.normalize_line_endings == "windows"
        UNIX_TO_WINDOWS
    else
        choose_line_ending_replacer(s.doc.srcfile.code)
    end
    output = normalize_line_ending(output, replacer)

    output = if ensure_trailing_newline
        if replacer == WINDOWS_TO_UNIX
            replace(output, r"\n*$" => "\n")
        else
            replace(output, r"(\r\n)*$" => "\r\n")
        end
    else
        output
    end

    if check_output
        try
            JuliaSyntax.parseall(
                JuliaSyntax.GreenNode,
                output;
                ignore_warnings = true,
                version = SUPPORTED_SYNTAX_VERSION,
            )
        catch err
            if err isa JuliaSyntax.ParseError
                # rethrow() is a bit of bad practice, but
                # otherwise you'll see the failed parse twice.
                rethrow(InvalidFormattedTextError(err))
            else
                rethrow(err)
            end
        end
    end
    return if output == text
        output
    else
        _format_text(
            output,
            style,
            opts;
            check_output = check_output,
            maxiters = maxiters - 1,
        )
    end
end

function _format_file(filename::AbstractString, config::Configuration)::Bool
    _, ext = splitext(filename)
    shebang_pattern = r"^#!\s*/.*\bjulia[0-9.-]*\b"
    merged_options = get_formatting_options(config)

    formatted_str = if ext in (".md", ".jmd", ".qmd")
        config.format_markdown || return true
        config.verbose && println("Formatting $filename")
        str = String(read(filename))
        # Already guarantees trailing newline, although newlines in Markdown are not
        # normalised (that's a CommonMark thing, not JuliaFormatter).
        _format_md(str, config.style, merged_options)
    elseif ext == ".jl" || match(shebang_pattern, readline(filename)) !== nothing
        config.verbose && println("Formatting $filename")
        str = String(read(filename))
        _format_text(str, config.style, merged_options; ensure_trailing_newline = true)
    else
        throw(InvalidFileError(filename))
    end

    already_formatted = (formatted_str == str)
    if config.overwrite && !already_formatted
        write(filename, formatted_str)
    end
    return already_formatted
end
