@plottype mutable struct Text{S <: AbstractString, N} <: AbstractPlot{Any}
    text::AbstractVector{Tuple{S, Point{N, Float32}}}
    position::Point{N, Float32} = Point(0, 0)
    color::ColorType = :black
    font::NativeFont = "Dejavue Sans"
    strokecolor::ColorType = (:black, 0.0)
    strokewidth::TorVector{Float32} = 0
    align::Vec2f0 = (:left, :bottom)
    rotation::TorVector{Quaternionf0} = 0.0
    textsize::TorVector{Float32} = 20
    justification::Any = automatic
    lineheight::TorVector{Float32} = 1.0
    space::Space = Pixel
    offset::TorVector{Vec2f0} = (0.0, 0.0)
    glyphlayout::Any = nothing

    anti_aliasing::AntiAliasing = NOAA
    inspectable::Bool = true
    visible::Bool = true
end

function text(args...; attributes...)
    plot(Text, args...; attributes...)
end

function text!(args...; attributes...)
    plot!(Text, args...; attributes...)
end

function convert_arguments(::Type{<:Text}, str::AbstractString)
    return ([(str, Point2f0(0))],)
end

function convert_arguments(::Type{<:Text}, str::AbstractVector{<: Tuple{<:AbstractString, <: Point{N, T}}}) where {N, T}
    return (map(((s, p),)-> (string(s), Point{N, Float32}(p)), str),)
end

convert_attribute(::Type{<:Text}, lineheight::Number, ::key"lineheight") = Float32(lineheight)
function convert_attribute(::Type{<:Text}, space::Symbol, ::key"space")
    space === :data && return Data
    space === :screen && return Pixel
    error("Unknown space: $(space)")
end

function convert_attribute(::Type{<:Text}, offset, ::key"offset")
    return Vec2f0(offset)
end


function assetpath end
