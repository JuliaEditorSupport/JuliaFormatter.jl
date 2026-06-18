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

"""
    InvalidFormattedTextError(msg)

Error thrown when the formatted text is invalid.
"""
struct InvalidFormattedTextError <: Exception end

"""
    InvalidFileError(filename)

Error thrown when the file to be formatted is not a valid Julia or Markdown file.
"""
struct InvalidFileError <: Exception
    filename::AbstractString
end

const UNIX_TO_WINDOWS = r"\r?\n" => "\r\n"
const WINDOWS_TO_UNIX = "\r\n" => "\n"
function choose_line_ending_replacer(text)
    rn = count("\r\n", text)
    n = count(r"(?<!\r)\n", text)
    n >= rn ? WINDOWS_TO_UNIX : UNIX_TO_WINDOWS
end
normalize_line_ending(s::AbstractString, replacer = WINDOWS_TO_UNIX) = replace(s, replacer)

# TODO(penelopeysm): Get rid of idempotence issues with SciMLStyle and remove this hack.
_maxiters(::AbstractStyle) = 1
_maxiters(::SciMLStyle) = 4

"""
    _format_text(
        text::AbstractString, style::AbstractStyle, opts::Options{Union{}};
        check_output::Bool=true, maxiters::Int=1)

The lower-level entry point for text formatting.

`check_output` is a boolean flag that indicates whether the output should be checked for
validity. If set to `true`, the function will attempt to parse the formatted text and throw
an `InvalidFormattedTextError` if it is not valid Julia code. If `false` it will just return
the formatted text, which may be invalid!

The `maxiters` keyword argument is specified in order to allow the formatting algorithm to
iterate to a fixed point. This is a hack and should really not be used, but currently
SciMLStyle is not idempotent and requires multiple iterations to reach a fixed point. By
default `maxiters` is set to 1, i.e., only one pass.
"""
function _format_text(
    text::AbstractString,
    style::AbstractStyle,
    opts::Options{Union{}};
    check_output::Bool = true,
    maxiters::Int = _maxiters(style),
)
    maxiters <= 0 && return text
    isempty(text) && return text

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
        align_fst!(fst, s.doc, s.opts)
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
                throw(InvalidFormattedTextError())
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
        _format_md(str, config.style, merged_options)
    elseif ext == ".jl" || match(shebang_pattern, readline(filename)) !== nothing
        config.verbose && println("Formatting $filename")
        str = String(read(filename))
        _format_text(str, config.style, merged_options)
    else
        throw(InvalidFileError(filename))
    end
    formatted_str = replace(formatted_str, r"\n*$" => "\n")

    already_formatted = (formatted_str == str)
    if config.overwrite && !already_formatted
        write(filename, formatted_str)
    end
    return already_formatted
end
