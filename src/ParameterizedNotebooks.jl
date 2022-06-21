module ParameterizedNotebooks

using MacroTools, JSON

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
end


function parse_heading(str)
    m = match(r"(#*)\s+(.+)\s*",str)
    m == nothing ? nothing : (level=length(m.captures[1]), name=m.captures[2])
end

section_matches(current_section::String, pattern::Nothing; recursive=true) = true
function section_matches(current_section::String, patterns::Tuple; recursive=true)
    any(section_matches(current_section, pattern; recursive=recursive) for pattern in patterns)
end
function section_matches(current_section::String, pattern::String; recursive=true)
    recursive ? occursin(pattern, current_section) : endswith(pattern, current_section)
end
function section_matches(current_section::String, pattern::Regex; recursive=true)
    recursive ? match(pattern, current_section) : match(pattern * r"$", current_section)
end
section_matches(current_section::Tuple, section; recursive) = section_matches(join(current_section, "/"), section; recursive)


function ParameterizedNotebook(filename::String; sections=nothing, recursive=true)

    cells = JSON.parsefile(filename)["cells"]
    exprs = []
    
    current_section = ("",)
    current_section_active = section_matches(current_section, sections; recursive)
    
    while !isempty(cells)
        cell = first(cells)
        if cell["cell_type"] == "code"
            popfirst!(cells)
            if current_section_active
                append!(exprs, parsecode(join(cell["source"],"\n")))
            end
        elseif cell["cell_type"] == "markdown"
            if isempty(cell["source"])
                popfirst!(cells)
            else
                heading = parse_heading(popfirst!(cell["source"]))
                if heading != nothing
                    current_section = (current_section[1:min(end,heading.level)]..., heading.name)
                    current_section_active = section_matches(current_section, sections; recursive)
                    if current_section_active
                        @show current_section
                    end
                end
            end
        else
            popfirst!(cells)
        end
    end

    parameters = Symbol[]
    for ex in exprs
        if @capture(ex, @nbparam name_ = val_)
            push!(parameters, name)
        end
    end

    ParameterizedNotebook(filename, parameters, exprs)
end

function Base.show(io::IO, nb::ParameterizedNotebook)
    print(io, "ParameterizedNotebook(\"", nb.filename, "\") with parameters: ")
    print(io, join(string.(nb.parameters), ", "))
end

function (nb::ParameterizedNotebook)(; kwargs...)
    kwargs = Dict(kwargs)
    for name in nb.parameters
        haskey(kwargs, name) || error("Must provide keyword argument for $name.")
    end
    for ex in nb.exprs
        if @capture(ex, @nbparam name_ = val_)
            @eval Main $name = $(kwargs[name])
        elseif @capture(ex, @nbonly _)
            continue
        else
            ans = Main.eval(ex)
            if ans isa ReturnValue
                return ans.val
            end
        end
    end
end


function parsecode(code::String)
    # https://discourse.julialang.org/t/parsing-a-julia-file/32622
    filter(
        x -> !(x isa LineNumberNode),
        Meta.parse(join(["quote", code, "end"], ";")).args[1].args
    )
end


end
