const VALID_FOR_IN_OPERATORS = ("in", "=", "∈")

struct _Unset end

"""
    Options{T<:_Unset}

Struct containing all the options for formatting.

The type parameter `T` is used to indicate whether the option is allowed to be unset.
By default, `T` is `Union{}`.

- `Options{Union{}}` indicates that all options MUST be set to some value. For example,

      Options(; always_use_return=true)

   creates a set of default options but with `always_use_return` set to `true`.

- `Options{_Unset}` indicates that all options are allowed to be unset. For example.

      Options{_Unset}(; always_use_return=true)

  creates a set of empty options but with `always_use_return` set to `true`.

This allows us to perform a merge on two `Options` objects which can be partially populated.
"""
Base.@kwdef struct Options{T<:_Unset}
    align_assignment::Union{T,Bool} = false
    align_conditional::Union{T,Bool} = false
    align_matrix::Union{T,Bool} = false
    align_pair_arrow::Union{T,Bool} = false
    align_struct_field::Union{T,Bool} = false
    always_for_in::Union{T,Union{Bool,Nothing}} = false
    always_use_return::Union{T,Bool} = false
    annotate_untyped_fields_with_any::Union{T,Bool} = true
    conditional_to_if::Union{T,Bool} = false
    disallow_single_arg_nesting::Union{T,Bool} = false
    for_in_replacement::Union{T,String} = "in"
    force_long_function_def::Union{T,Bool} = false
    format_docstrings::Union{T,Bool} = false
    import_to_using::Union{T,Bool} = false
    indent::Union{T,Int} = 4
    indent_submodule::Union{T,Bool} = false
    join_lines_based_on_source::Union{T,Bool} = false
    long_to_short_function_def::Union{T,Bool} = false
    margin::Union{T,Int} = 92
    normalize_line_endings::Union{T,String} = "auto"
    pipe_to_function_call::Union{T,Bool} = false
    remove_extra_newlines::Union{T,Bool} = false
    sciml_margin_overrun::Union{T,Int} = 20
    separate_kwargs_with_semicolon::Union{T,Bool} = false
    short_circuit_to_if::Union{T,Bool} = false
    short_to_long_function_def::Union{T,Bool} = false
    surround_whereop_typeparameters::Union{T,Bool} = true
    trailing_comma::Union{T,Bool,Nothing} = true
    trailing_zero::Union{T,Bool} = true
    v2_stable_multiline_strings::Union{T,Bool} = false
    variable_call_indent::Union{T,Vector{String}} = []
    whitespace_in_kwargs::Union{T,Bool} = true
    whitespace_ops_in_indices::Union{T,Bool} = false
    whitespace_typedefs::Union{T,Bool} = false
    yas_style_nesting::Union{T,Bool} = false

    Options(args...) = verify_options(new{Union{}}(args...))
    Options{_Unset}(args...) = new{_Unset}(args...)
end
function Options{_Unset}(; kwargs...)
    # Has to be an outer constructor because @kwdef messes things up
    kw = Dict{Symbol,Any}(kwargs)
    return Options{_Unset}((get(kw, f, _Unset()) for f in fieldnames(Options))...)
end

function verify_options(opts::Options{Union{}})::Options{Union{}}
    if (opts.force_long_function_def === true) &&
       (opts.short_to_long_function_def === false)
        msg = """
        The combination `force_long_function_def = true` and `short_to_long_function_def = false` is invalid.
        """
        throw(ArgumentError(msg))
    end
    if opts.sciml_margin_overrun < 0
        throw(ArgumentError("`sciml_margin_overrun` must be greater than or equal to 0."))
    end
    if opts.always_for_in == true && !(opts.for_in_replacement in VALID_FOR_IN_OPERATORS)
        throw(
            ArgumentError(
                "`for_in_replacement` is set to an invalid operator \"$(opts.for_in_replacement)\", valid operators are $(VALID_FOR_IN_OPERATORS). Change it to one of the valid operators and then reformat.",
            ),
        )
    end
    return opts
end

function Base.show(io::IO, opt::Options{T}) where {T}
    fields = fieldnames(Options)
    max_len = maximum(length ∘ string, fields)
    print(io, T === Union{} ? "Options(" : "Options{_Unset}(")
    for (i, f) in enumerate(fields)
        v = getfield(opt, f)
        println(io)
        printstyled(io, "  ", rpad(f, max_len))
        print(io, " = ")
        if v isa _Unset
            printstyled(io, "_Unset()"; color = :white)
        else
            print(io, repr(v))
        end
        i < length(fields) && print(io, ",")
    end
    print(io, "\n)")
end

function needs_alignment(opts::Options{Union{}})::Bool
    if !(
        opts.align_struct_field ||
        opts.align_conditional ||
        opts.align_assignment ||
        opts.align_pair_arrow
    )
        opts.align_matrix
    else
        true
    end
end

function merge_options(opts1::Options{T1}, opts2::Options{T2}) where {T1<:_Unset,T2<:_Unset}
    # Merge two Options objects, with any set values in opts2 taking precedence over opts1.
    Tout = T1 === _Unset && T2 === _Unset ? _Unset : Union{}
    kwargs = Dict{Symbol,Any}()
    for f in fieldnames(Options)
        v1 = getfield(opts1, f)
        v2 = getfield(opts2, f)
        kwargs[f] = v2 isa _Unset ? v1 : v2
    end
    return Tout === Union{} ? Options(; kwargs...) : Options{Tout}(; kwargs...)
end
