struct FormatSkip
    startline::Int
    endline::Int
    startoffset::Int
    endoffset::Int
end

struct Document
    srcfile::JuliaSyntax.SourceFile
    format_skips::Vector{FormatSkip}
    # Line where there's a noindent comment. "#! format: noindent". This is checked during
    # the print stage to know if the contents of the block (recursive) should not be indented.
    noindent_blocks::Vector{Int}

    comments::Dict{Int,Tuple{Int,String}}

    ends_on_nl::Bool
end

function Document(text::AbstractString)
    format_skips = FormatSkip[]
    noindent_blocks = Int[]
    stack = Tuple{Int,Int}[]
    comments = Dict{Int,Tuple{Int,String}}()

    srcfile = JuliaSyntax.SourceFile(text)
    tokens = JuliaSyntax.tokenize(text)

    ends_on_nl = kind(tokens[end]) === K"NewlineWs"

    for (i, t) in enumerate(tokens)
        if kind(t) === K"Comment"
            ws = 0
            if i > 1 &&
               (kind(tokens[i-1]) === K"Whitespace" || kind(tokens[i-1]) === K"NewlineWs")
                pt = tokens[i-1]
                prevval = try
                    srcfile.code[first(pt.range):last(pt.range)]
                catch e
                    if isa(e, StringIndexError)
                        srcfile.code[first(pt.range):prevind(text, last(pt.range))]
                    else
                        rethrow(e)
                    end
                end

                idx = findlast(c -> c == '\n', prevval)
                if idx === nothing
                    idx = 1
                end
                ws = count(c -> c == ' ', prevval[idx:end])
            end

            startline = JuliaSyntax.source_line(srcfile, first(t.range))
            endline = JuliaSyntax.source_line(srcfile, last(t.range))
            val = slice_source(srcfile.code, t.range)

            if startswith(val, "#=") && endswith(val, "=#")
                # Block comments (#= ... =#) are handled as HASHEQCOMMENT FST
                # nodes in p_comment(), so we don't store them in the dict.
            elseif startline == endline
                comments[startline] = (ws, val)
            else
                # multiline comment
                idx = findfirst(x -> x == '\n', val)::Int + 1
                fc2 = findfirst(c -> !isspace(c), val[idx:end])

                lr = JuliaSyntax.source_line_range(srcfile, first(t.range))
                lineoffset = (first(t.range) - lr[1]) + 1
                ws2 = fc2 === nothing || lineoffset < fc2 ? ws : max(ws, fc2 - 1)

                line = startline
                cs = ""
                for (i, c) in enumerate(val)
                    cs *= c
                    if c == '\n'
                        fc = findfirst(c -> !isspace(c), cs)
                        if fc === nothing
                            # comment is all whitespace
                            comments[line] = (ws, cs[end:end])
                        else
                            idx = min(fc, ws + 1)
                            comments[line] = (ws, cs[idx:end])
                        end
                        line += 1
                        ws = ws2
                        cs = ""
                    end
                end
                # last comment
                idx = min(findfirst(c -> !isspace(c), cs)::Int, ws + 1)
                comments[line] = (ws, cs[idx:end])
            end

            if length(stack) == 0 && occursin(r"^#!\s*format\s*:\s*off\s*$", val)
                # There should not be more than 1
                # "off" tag on the stack at a time.
                offset = first(t.range)
                r = JuliaSyntax.source_line_range(srcfile, offset)
                line = JuliaSyntax.source_line(srcfile, offset)
                push!(stack, (line, first(r)))
            elseif length(stack) > 0 && occursin(r"^#!\s*format\s*:\s*on\s*$", val)
                # If "#! format: off" has not been seen
                # "#! format: on" is treated as a normal comment.
                offset = last(t.range)
                r = JuliaSyntax.source_line_range(srcfile, offset)
                line = JuliaSyntax.source_line(srcfile, offset)
                v = pop!(stack)
                push!(format_skips, FormatSkip(v[1], line, v[2], last(r)))
            end
            if occursin(r"^#!\s*format\s*:\s*noindent\s*$", val)
                line = JuliaSyntax.source_line(srcfile, first(t.range))
                push!(noindent_blocks, line)
            end
        elseif kind(t) === K"ErrorEofMultiComment"
            l = JuliaSyntax.source_line(srcfile, first(t.range))
            throw(
                ErrorException(
                    """Unable to format. Multi-line comment on line $l is not closed.""",
                ),
            )
        end
    end

    # If there is a SINGLE "#! format: off" tag
    # do not format from the "off" tag onwards.
    if length(stack) == 1 && length(format_skips) == 0
        # -1 signifies everything afterwards "#! format: off"
        # will not formatted.
        v = pop!(stack)
        line = numlines(srcfile)
        r = JuliaSyntax.source_line_range(srcfile, srcfile.line_starts[line])
        push!(format_skips, FormatSkip(v[1], line, v[2], last(r)))
    end

    return Document(srcfile, format_skips, noindent_blocks, comments, ends_on_nl)
end

function has_noindent_block(d::Document, r::Tuple{Int,Int})
    for b in d.noindent_blocks
        if b in r
            return true
        end
    end
    return false
end

numlines(sf::JuliaSyntax.SourceFile) = length(sf.line_starts) - 1
numlines(d::Document) = numlines(d.srcfile)

function getsrcval(d::Document, r::UnitRange{T}) where {T<:Union{Int,UInt}}
    return slice_source(JuliaSyntax.sourcetext(d.srcfile), r)
end

"""
    slice_source(code::AbstractString, r::UnitRange)

Return the text of `code` in the byte range `r`.

JuliaSyntax gives byte ranges, so `last(r)` is the last *byte* of the final character. If
that character takes up more than one byte (e.g. `α` or `∈`), `last(r)` is not a valid
string index and `code[r]` throws. For example, in `code = "x = α"`, the `α` token has byte
range `5:6`, and `code[5:6]` throws a `StringIndexError` because `6` is in the middle of `α`.
`code[5:5]` gives `"α"`.

Throwing and catching errors is very slow, and this happens for every such token, so we
first move `last(r)` back to the start of its character, which avoids the error in the
common case.
"""
function slice_source(code::AbstractString, r::UnitRange{<:Integer})
    j = Int(last(r))
    if 1 <= j <= ncodeunits(code)
        j = thisind(code, j)
    end
    try
        code[first(r):j]
    catch
        code[first(r):prevind(code, j)]
    end
end
