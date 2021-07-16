to_func_name(x::Symbol) = Symbol(lowercase(string(x)))
# Fallback for Combined ...
# Will get overloaded by recipe Macro
plotsym(x) = :plot

function func2string(func::F) where F <: Function
    string(F.name.mt.name)
end

plotfunc(::Combined{F}) where F = F
plotfunc(::Type{<: AbstractPlot{Func}}) where Func = Func
plotfunc(::T) where T <: AbstractPlot = plotfunc(T)
plotfunc(f::Function) = f

func2type(x::T) where T = func2type(T)
func2type(x::Type{<: AbstractPlot}) = x
func2type(f::Function) = Combined{f}

plotkey(::Type{<: AbstractPlot{Typ}}) where Typ = Symbol(lowercase(func2string(Typ)))
plotkey(::T) where T <: AbstractPlot = plotkey(T)

"""
     default_plot_signatures(funcname, funcname!, PlotType)
Creates all the different overloads for `funcname` that need to be supported for the plotting frontend!
Since we add all these signatures to different functions, we make it reusable with this function.
The `Core.@__doc__` macro transfers the docstring given to the Recipe into the functions.
"""
function default_plot_signatures(funcname, funcname!, PlotType)
    quote
        Core.@__doc__ function ($funcname)(args...; attributes...)
            plot($PlotType, args...; attributes...)
        end

        Core.@__doc__ function ($funcname!)(args...; attributes...)
            plot!($PlotType, args...; attributes...)
        end
    end
end

"""
Each argument can be named for a certain plot type `P`. Falls back to `arg1`, `arg2`, etc.
"""
function argument_names(plot::P) where {P<:AbstractPlot}
    argument_names(P, length(plot.converted))
end

function argument_names(::Type{<:AbstractPlot}, num_args::Integer)
    # this is called in the indexing function, so let's be a bit efficient
    ntuple(i -> Symbol("arg$i"), num_args)
end

# Since we can use Combined like a scene in some circumstances, we define this alias
theme(x::SceneLike, args...) = theme(x.parent, args...)
theme(x::AbstractScene) = x.theme
theme(x::AbstractScene, key) = deepcopy(x.theme[key])
theme(x::AbstractPlot, key) = deepcopy(x.attributes[key])

Attributes(x::AbstractPlot) = x.attributes

default_theme(scene, T) = Attributes()

"""
# Plot Recipes in `Makie`

There's two types of recipes. *Type recipes* define a simple mapping from a
user defined type to an existing plot type. *Full recipes* can customize the
theme and define a custom plotting function.

## Type recipes

Type recipe are really simple and just overload the argument conversion
pipeline. This can be done for all plot types or for a subset of plot types:

    # All plot types
    convert_arguments(P::Type{<:AbstractPlot}, x::MyType) = convert_arguments(P, rand(10, 10))
    # Only for scatter plots
    convert_arguments(P::Type{<:Scatter}, x::MyType) = convert_arguments(P, rand(10, 10))

Optionally you may define the default plot type so that `plot(x::MyType)` will
use this:

    plottype(::MyType) = Surface

## Full recipes with the `@recipe` macro

A full recipe for `MyPlot` comes in two parts. First is the plot type name,
arguments and theme definition which are defined using the `@recipe` macro.
Second is a custom `plot!` for `MyPlot`, implemented in terms of the atomic
plotting functions.

We use an example to show how this works:

    # arguments (x, y, z) && theme are optional
    @recipe(MyPlot, x, y, z) do scene
        Attributes(
            plot_color => :red
        )
    end

This macro expands to several things. Firstly a type definition:

    const MyPlot{ArgTypes} = Combined{myplot, ArgTypes}

The type parameter of `Combined` contains the function instead of e.g. a
symbol. This way the mapping from `MyPlot` to `myplot` is safer and simpler.
(The downside is we always need a function `myplot` - TODO: is this a problem?)

The following signatures are defined to make `MyPlot` nice to use:

    myplot(args...; kw_args...) = ...
    myplot!(scene, args...; kw_args...) = ...
    myplot(kw_args::Dict, args...) = ...
    myplot!(scene, kw_args::Dict, args...) = ...
    #etc (not 100% settled what signatures there will be)

A specialization of `argument_names` is emitted if you have an argument list
`(x,y,z)` provided to the recipe macro:

    argument_names(::Type{<: MyPlot}) = (:x, :y, :z)

This is optional but it will allow the use of `plot_object[:x]` to
fetch the first argument from the call
`plot_object = myplot(rand(10), rand(10), rand(10))`, for example.
Alternatively you can always fetch the `i`th argument using `plot_object[i]`,
and if you leave out the `(x,y,z)`, the default version of `argument_names`
will provide `plot_object[:arg1]` etc.

The theme given in the body of the `@recipe` invocation is inserted into a
specialization of `default_theme` which inserts the theme into any scene that
plots `MyPlot`:

    function default_theme(scene, ::MyPlot)
        Attributes(
            plot_color => :red
        )
    end

As the second part of defining `MyPlot`, you should implement the actual
plotting of the `MyPlot` object by specializing `plot!`:

    function plot!(plot::MyPlot)
        # normal plotting code, building on any previously defined recipes
        # or atomic plotting operations, and adding to the combined `plot`:
        lines!(plot, rand(10), color = plot[:plot_color])
        plot!(plot, plot[:x], plot[:y])
        plot
    end

It's possible to add specializations here, depending on the argument *types*
supplied to `myplot`. For example, to specialize the behavior of `myplot(a)`
when `a` is a 3D array of floating point numbers:

    const MyVolume = MyPlot{Tuple{<:AbstractArray{<: AbstractFloat, 3}}}
    argument_names(::Type{<: MyVolume}) = (:volume,) # again, optional
    function plot!(plot::MyVolume)
        # plot a volume with a colormap going from fully transparent to plot_color
        volume!(plot, plot[:volume], colormap = :transparent => plot[:plot_color])
        plot
    end

The docstring given to the recipe will be transferred to the functions it generates.

"""
macro recipe(theme_func, Tsym::Symbol, args::Symbol...)
    funcname_sym = to_func_name(Tsym)
    funcname! = esc(Symbol("$(funcname_sym)!"))
    PlotType = esc(Tsym)
    funcname = esc(funcname_sym)
    expr = quote
        $(funcname)() = not_implemented_for($funcname)
        const $(PlotType){$(esc(:ArgType))} = Combined{$funcname,$(esc(:ArgType))}
        $(MakieCore).plotsym(::Type{<:$(PlotType)}) = $(QuoteNode(Tsym))
        $(default_plot_signatures(funcname, funcname!, PlotType))
        $(MakieCore).default_theme(scene, ::Type{<:$PlotType}) = $(esc(theme_func))(scene)
        export $PlotType, $funcname, $funcname!
    end
    if !isempty(args)
        push!(
            expr.args,
            :(
                $(esc(:($(MakieCore).argument_names)))(::Type{<:$PlotType}, len::Integer) =
                    $args
            ),
        )
    end
    expr
end

# Register plot / plot! using the Any type as PlotType.
# This is done so that plot(args...) / plot!(args...) can by default go
# through a pipeline where the appropriate PlotType is determined
# from the input arguments themselves.
eval(default_plot_signatures(:plot, :plot!, :Any))

"""
Returns the Combined type that represents the signature of `args`.
"""
function Plot(args::Vararg{Any,N}) where {N}
    Combined{Any,<:Tuple{args...}}
end

Base.@pure function Plot(::Type{T}) where {T}
    Combined{Any,<:Tuple{T}}
end

Base.@pure function Plot(::Type{T1}, ::Type{T2}) where {T1,T2}
    Combined{Any,<:Tuple{T1,T2}}
end

"""
    `plottype(plot_args...)`

Any custom argument combination that has a preferred way to be plotted should overload this.
e.g.:
```julia
    # make plot(rand(5, 5, 5)) plot as a volume
    plottype(x::Array{<: AbstractFloat, 3}) = Volume
```
"""
plottype(plot_args...) = Combined{Any, Tuple{typeof.(to_value.(plot_args))...}} # default to dispatch to type recipes!

function extract_type(type_expr)
    if Meta.isexpr(type_expr, :(<:))
        type_name, inheritance = type_expr.args
        if Meta.isexpr(type_name, :curly)
            name, type_vars... = type_name.args
            return name, type_vars
        else
            return type_name, ()
        end
    end
    error("Type needs to inherit from e.g AbstractPlot")
end

"""
    mutable struct Name{...} <: AbstractPlot
        fields

"""
macro plottype(arg)
    fields = arg.args[3].args
    TypeName, typevars = extract_type(arg.args[2])
    TypeName = esc(TypeName)
    typevar_names = map(typevars) do var
        var isa Symbol && return var
        return var.args[1]
    end

    function to_field(expr)
        expr isa Symbol && error("Field $(expr) needs a type! If no type applies use $(expr)::Any!")
        expr.head == :(::) && return expr
        expr.head == :(=) && return to_field(expr.args[1])
        error("Not a field expr: $(expr), $(expr.head)")
    end
    keywords = []
    arguments = []
    struct_field_expr = map(fields) do expr
        expr isa LineNumberNode && return expr
        not_typed() = error("Field $(expr) needs a type! If no type applies use $(expr)::Any!")
        expr isa Symbol && not_typed()
        if expr.head == :(::)
            push!(arguments, expr)
            return expr
        elseif expr.head == :(=)
            field = expr.args[1]
            default = expr.args[2]
            if Meta.isexpr(field, :(::))
                push!(keywords, field.args[1] => default)
                return field
            end
        end
        error("Not a field expr: $(expr), $(expr.head)")
    end

    kw_names = first.(keywords)
    arg_names = map(arg-> arg.args[1], arguments)

    set(argname) = :(obj.$(argname) = $(argname))

    set_args = set.(arg_names)
    set_kw = set.(kw_names)

    inner_constructor = quote
        function $(TypeName)($(arguments...), $(kw_names...)) where {$(typevars...)}
            obj = new{$(typevar_names...)}()
            setfield!(obj, :parent, nothing)
            setfield!(obj, :basics, PlotBasics())
            $(set_args...)
            $(set_kw...)
            return obj
        end
    end
    kw = map(keywords) do (name, default)
        return Expr(:kw, name, default)
    end
    all_fields = [f.args[1] for f in struct_field_expr if f isa Expr]
    outer_constructor = quote
        function $(TypeName)(args...; $(kw...))
            ($(arg_names...),) = convert_arguments($(TypeName), to_value.(args)...)
            obj = $(TypeName)(
                $(all_fields...)
            )
            onany(args...) do args...
                ($(arg_names...),) = convert_arguments($(TypeName), args...)
                $(set_args...)
            end
            return obj
        end
    end
    push!(struct_field_expr, :(basics::PlotBasics), :(parent::Any))

    struct_body = quote
        $(struct_field_expr...)
        $(inner_constructor)
    end
    new_type = Expr(arg.head, arg.args[1], arg.args[2], struct_body)

    return quote
        $new_type
        $outer_constructor
    end
end
