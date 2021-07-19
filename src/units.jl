#########
## Move attributes into certain unit spaces
# Future:
# Every plot / scene axis will hold a space attribute
# with the following allowed (per axis):
# (may not actually be a type hierarchy, just here for illustration)
# abstract type DataSpace end
# abstract type DisplaySpace end
# #...
# struct Log <: DataSpace end
# struct Polar <: DataSpace end
# struct GeoProjection <: DataSpace end
# # and more!
# #...
# struct Pixel <: DisplaySpace end
# struct DPI <: DisplaySpace end
# struct DIP <: DisplaySpace end
#########

function to_screen(scene::Scene, mpos)
    return Point2f(mpos) .- Point2f(minimum(pixelarea(scene)[]))
end

number(x::Unit) = x.value
number(x) = x

Base.:(*)(a::T, b::Number) where {T<:Unit} = basetype(T)(number(a) * b)
Base.:(*)(a::Number, b::T) where {T<:Unit} = basetype(T)(a * number(b))
Base.convert(::Type{T}, x::Unit) where T<:Number = convert(T, number(x))

"""
Unit space of the scene it's displayed on.
Also referred to as data units
"""
struct SceneSpace{T} <: Unit{T}
    value::T
end

"""
https://en.wikipedia.org/wiki/Device-independent_pixel
A device-independent pixel (also: density-independent pixel, dip, dp) is a
physical unit of measurement based on a coordinate system held by a
computer and represents an abstraction of a pixel for use by an
application that an underlying system then converts to physical pixels.
"""
struct DeviceIndependentPixel{T <: Number} <: Unit{T}
    value::T
end
basetype(::Type{<: DeviceIndependentPixel}) = DeviceIndependentPixel

const DIP = DeviceIndependentPixel
const dip = DIP(1)
const dip_in_millimeter = 0.15875
const dip_in_inch = 1/160

basetype(::Type{<: Pixel}) = Pixel

"""
Millimeter on screen. This unit respects the dimension and pixel density of the screen
to represent millimeters on the screen. This is the must use unit for layouting,
that needs to look the same on all kind of screens. Similar as with the `Pixel` unit,
a camera can change the actually displayed dimensions of any object using the millimeter unit.
"""
struct Millimeter{T} <: Unit{T}
    value::T
end
basetype(::Type{<: Millimeter}) = Millimeter
const mm = Millimeter(1)

Base.show(io::IO, x::DIP) = print(io, number(x), "dip")
Base.:(*)(a::Number, b::DIP) = DIP(a * number(b))

dpi(scene::Scene) = events(scene).window_dpi[]

function pixel_per_mm(scene)
    dpi(scene) ./ 25.4
end

function Base.convert(::Type{<: Millimeter}, scene::Scene, x::SceneSpace)
    pixel = convert(Pixel, scene, x)
    Millimeter(number(pixel_per_mm(scene) / pixel))
end

function Base.convert(::Type{<: SceneSpace}, scene::Scene, x::DIP)
    mm = convert(Millimeter, scene, x)
    SceneSpace(number(mm * dip_in_millimeter))
end

function Base.convert(::Type{<: Millimeter}, scene::Scene, x::DIP)
    Millimeter(number(x * dip_in_millimeter))
end

function Base.convert(::Type{<: Pixel}, scene::Scene, x::Millimeter)
    px = pixel_per_mm(scene) * x
    Pixel(number(px))
end

function Base.convert(::Type{<: Pixel}, scene::Scene, x::DIP)
    inch = (x * dip_in_inch)
    dots = dpi(scene) * inch
    Pixel(number(dots))
end

function Base.convert(::Type{<: SceneSpace}, scene::Scene, x::Vec{2, <:Pixel})
    zero = to_world(scene, to_screen(scene, Point2f(0)))
    s = to_world(scene, to_screen(scene, number.(Point(x))))
    SceneSpace.(Vec(s .- zero))
end

function Base.convert(::Type{<: SceneSpace}, scene::Scene, x::Pixel)
    zero = to_world(scene, to_screen(scene, Point2f(0)))
    s = to_world(scene, to_screen(scene, Point2f(number(x), 0.0)))
    SceneSpace(norm(s .- zero))
end

function Base.convert(::Type{<: SceneSpace}, scene::Scene, x::Millimeter)
    pix = convert(Pixel, scene, x)
    (SceneSpace, mm)
end

to_2d_scale(x::Pixel) = Vec2f(number(x))
to_2d_scale(x::Tuple{<:Pixel, <:Pixel}) = Vec2f(number.(x))
to_2d_scale(x::VecTypes{2, <:Pixel}) = Vec2f(number.(x))

# Exports of units
export px
