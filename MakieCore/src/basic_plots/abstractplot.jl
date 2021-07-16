function update!(plot::AbstractPlot, values::Dict{Symbol})
    for (key, value) in values
        setproperty_noupdate!(plot, key, value)
    end
    plot.basics.on_update[] = keys(values)
    return
end

function setproperty_noupdate!(scatter::T, field::Symbol, value::Any) where T <: AbstractPlot
    converted = convert_attribute(scatter, value, Key(field))
    FT = fieldtype(T, field)
    if !(converted isa FT)
        error("Attribute $(field) couldn't be converted to required type. Converted type $(typeof(converted)). Required type: $(FT)")
    end
    setfield!(scatter, field, converted)
    return converted
end

function Base.setproperty!(plot::T, field::Symbol, value::Any) where T <: AbstractPlot
    setproperty_noupdate!(plot, field, value)
    plot.basics.on_update[] = Set([field])
    return
end

function Base.setproperty!(plot::T, field::Symbol, value::Observable) where T <: AbstractPlot
    f(value) = setproperty!(plot, field, value)
    on(f, value)
    f(value[])
    return
end

function on_update(f, plot::T, ::Key{field}) where {T <: AbstractPlot, field}
    FT = fieldtype(T, field)
    return on(plot.basics.on_update) do updated_fields
        if field in updated_fields
            f(plot[field]::FT)
        end
        return
    end
end

function Base.getindex(plot::T, field::Symbol) where T <: AbstractPlot
    return getfield(plot, field)
end

function Base.getproperty(plot::T, field::Symbol) where T <: AbstractPlot
    field === :basics && return getfield(plot, :basics)
    field === :parent && return getfield(plot, :parent)
    return get!(plot.basics.observables, field) do
        obs = Observable{fieldtype(T, field)}(plot[field])
        on_update(plot, Key(field)) do new_value
            obs[] = new_value
        end
        return obs
    end
end

mutable struct PlotBasics
    on_update::Observable{Set{Symbol}}
    on_event::Observable{Tuple{Symbol,Any}}
    defaults::Set{Symbol}
    observables::Dict{Symbol, Observable}
    camera::Camera
    transformation::Transformation
end

function PlotBasics()
    return PlotBasics(
        Observable{Set{Symbol}}(),
        Observable{Tuple{Symbol,Any}}(),
        Set{Symbol}(),
        Dict{Symbol, Observable}(),
        Camera(),
        Transformation(),
    )
end

function plot!(P::Type{<:AbstractPlot}, scene::AbstractScene, args...; attributes...)
    scatter = P(args...; attributes...)
    plot!(scene, scatter)
    return scatter
end

function plot!(P::PlotFunc, scene::SceneLike, args...; kw_attributes...)
    attributes = Attributes(kw_attributes)
    plot!(scene, P, attributes, args...)
end

function plot!(scene::SceneLike, scatter::AbstractPlot)
    push!(scene.plots, scatter)
end
