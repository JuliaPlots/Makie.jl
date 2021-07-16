const MarkerSizeTypes{N} = TorVector{Union{Float32, Vec{N, Float32}}}
const MarkerTypes = TorVector{<:Union{Symbol,Char, Type{Circle}, Type{Rect2D}}}
const DistanceFieldType = Union{Nothing, AbstractMatrix{<: Union{Colorant, Number}}}
const ColorType = TorVector{RGBAf0}

@plottype mutable struct Scatter{N} <: AbstractPlot{Any}
    position::AbstractVector{Point{N,Float32}}
    color::ColorType = :black
    marker::MarkerTypes = Circle
    markersize::MarkerSizeTypes{N} = 5
    marker_offset::TorVector{Vec{N,Float32}} = automatic
    strokecolor::ColorType = :black
    strokewidth::TorVector{Float32} = 0
    markerspace::Space = Pixel
    transform_marker::Bool = false
    distancefield::DistanceFieldType = nothing

    cycle::Vector{Symbol} = [:color]
    anti_aliasing::AntiAliasing = NOAA
    inspectable::Bool = true
    visible::Bool = true
end

function convert_attribute(scatter::Scatter, ::Automatic, ::key"marker_offset")
    return scatter[:markersize] ./ 2
end

function scatter(args...; attributes...)
    plot(Scatter, args...; attributes...)
end

function scatter!(args...; attributes...)
    plot!(Scatter, args...; attributes...)
end

export Scatter, scatter, scatter!
