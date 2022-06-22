module ParameterizedNotebooks

using MacroTools, JSON, Term

export @nbparam, @nbonly, @nbreturn, ParameterizedNotebook

macro nbparam(ex)
    @capture(ex, arg_ = val_) || error("usage: @nbparam name = val")
    esc(ex)
end

macro nbonly(ex)
    esc(ex)
end

macro nbreturn(ex=nothing)
    :(ReturnValue($(esc(ex))))
end

struct ReturnValue
    val
end

struct ParameterizedNotebook
    filename :: String
    parameters :: Vector{Symbol}
    exprs :: Vector
    toc :: Union{String,Nothing}
end


function ParameterizedNotebook(filename::String; sections=nothing, recursive=true)

    cells = JSON.parsefile(filename)["cells"]

    exprs = []
    parameters = Symbol[]
    toc = []

    function heading_string(active, level, name)
        if active
            " "^(2*level) * @bold(@green("☒ ") * name) * "\n" * " "^(2*(level+1)) * @bold(@green("☒ ")) * @bold("…")
        else
            " "^(2*level) * @dim("□ " * name)
        end
    end

    current_section = ("~",)
    current_section_active = section_matches(current_section, sections; recursive=recursive)
    push!(toc, heading_string(current_section_active, 0, "~"))

    while !isempty(cells)
        cell = first(cells)
        if cell["cell_type"] == "code"
            popfirst!(cells)
            if current_section_active
                source = join(cell["source"],"\n")
                cell_id = cell["execution_count"] == nothing ? "In" : "In[$(cell["execution_count"])]"
                append!(exprs, parsecode(source, cell_id) do ex
                    if @capture(ex, @nbparam name_ = val_)
                        push!(parameters, name)
                    end
                    ex
                end)
            end
        elseif cell["cell_type"] == "markdown"
            if isempty(cell["source"])
                popfirst!(cells)
            else
                heading = parse_heading(popfirst!(cell["source"]))
                if heading != nothing
                    current_section = (current_section[1:min(end,heading.level)]..., heading.name)
                    current_section_active = section_matches(current_section, sections; recursive=recursive)
                    push!(toc, heading_string(current_section_active, heading.level, heading.name))
                end
            end
        else
            popfirst!(cells)
        end
    end

    ParameterizedNotebook(filename, parameters, exprs, isnothing(sections) ? nothing : join(toc, "\n"))
end

function Base.show(io::IO, nb::ParameterizedNotebook)
    print(io, "ParameterizedNotebook(\"", nb.filename, "\")")
    if !isempty(nb.parameters)
        print(" with parameters: (", join(string.(nb.parameters), ", "), ")")
    end
    if nb.toc != nothing
        print(io, "\n", nb.toc)
    end
end

function (nb::ParameterizedNotebook)(; kwargs...)
    kwargs = Dict(kwargs)
    for name in nb.parameters
        haskey(kwargs, name) || error("Must provide keyword argument for $name.")
    end
    for ex in nb.exprs
        if @capture(last(ex.args), @nbparam name_ = val_)
            @eval Main $name = $(kwargs[name])
        elseif @capture(last(ex.args), @nbonly _)
            continue
        else
            ans = Core.eval(Main, ex)
            if ans isa ReturnValue
                return ans.val
            end
        end
    end
end


# more-or-less a copy of Base.include_string
# but instead of eval'ing the expression, just return it
function parsecode(mapexpr::Function, code::String, filename)
    loc = LineNumberNode(1, Symbol(filename))
    try
        ast = Meta.parseall(code, filename=filename)
        @assert Meta.isexpr(ast, :toplevel)
        result = nothing
        exs = []
        for ex in ast.args
            line_and_ex = Expr(:toplevel, loc, nothing)
            if ex isa LineNumberNode
                loc = ex
                line_and_ex.args[1] = ex
                continue
            end
            ex = mapexpr(ex)
            # Wrap things to be eval'd in a :toplevel expr to carry line
            # information as part of the expr.
            line_and_ex.args[2] = ex
            push!(exs, line_and_ex)
        end
        exs
    catch exc
        # TODO: Now that stacktraces are more reliable we should remove
        # LoadError and expose the real error type directly.
        rethrow(LoadError(filename, loc.line, exc))
    end
end


# section matching logic
section_matches(current_section::AbstractString, pattern::Nothing) = true
section_matches(current_section::AbstractString, patterns::Tuple) =
    any(section_matches(current_section, pattern) for pattern in patterns)
section_matches(current_section::AbstractString, pattern::String) = current_section == pattern
section_matches(current_section::AbstractString, pattern::Regex) = occursin(pattern, current_section)
section_matches(current_section::Tuple, pattern; recursive) = 
    recursive ? any(section_matches(s, pattern) for s in current_section) : section_matches(last(current_section), pattern)


function parse_heading(str)
    m = match(r"(#*)\s+(.+)\s*",str)
    m == nothing ? nothing : (level=length(m.captures[1]), name=m.captures[2])
end

end
