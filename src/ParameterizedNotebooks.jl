module ParameterizedNotebooks

using MacroTools

export @nbarg, @nbonly, @nbreturn, ParameterizedNotebook

macro nbarg(ex)
    @capture(ex, arg_ = val_) || error("usage: @nbarg name = val")
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

function ParameterizedNotebook(filename::String)
    script = read(`jupyter nbconvert --to script $filename --stdout`, String)
    exprs = parsecode(script)
    parameters = Symbol[]
    for ex in exprs
        if @capture(ex, @nbarg name_ = val_)
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
        if @capture(ex, @nbarg name_ = val_)
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
