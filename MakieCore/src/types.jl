
const TorVector{T} = Union{T, AbstractVector{T}}
const RealVector{T} = AbstractVector{T} where T <: Number
const RGBAf0 = RGBA{Float32}
const RGBf0 = RGB{Float32}
const NativeFont = FreeTypeAbstraction.FTFont

"""
Main structure for holding attributes, for theming plots etc!
Will turn all values into nodes, so that they can be updated.
"""
struct Attributes
    attributes::Dict{Symbol, Observable}
end

struct Combined{Typ, T} <: ScenePlot{Typ}
    parent::SceneLike
    transformation::Transformable
    attributes::Attributes
    input_args::Tuple
    converted::Tuple
    plots::Vector{AbstractPlot}
end

# all the plotting functions that get a plot type
const PlotFunc = Union{Type{Any}, Type{<: AbstractPlot}}

function Base.show(io::IO, plot::Combined)
    print(io, typeof(plot))
end

Base.parent(x::AbstractPlot) = x.parent

struct Key{K} end
macro key_str(arg)
    :(Key{$(QuoteNode(Symbol(arg)))})
end
Base.broadcastable(x::Key) = (x,)
Key(sym) = Key{sym}()

"""
Type to indicate that an attribute will get calculated automatically
"""
struct Automatic end

"""
Singleton instance to indicate that an attribute will get calculated automatically
"""
const automatic = Automatic()

abstract type Unit{T} <: Number end

"""
Unit in pixels on screen.
This one is a bit tricky, since it refers to a static attribute (pixels on screen don't change)
but since every visual is attached to a camera, the exact scale might change.
So in the end, this is just relative to some normed camera - the value on screen, depending on the camera,
will not actually sit on those pixels. Only camera that guarantees the correct mapping is the
`:pixel` camera type.
"""
struct Pixel{T} <: Unit{T}
    value::T
end

const px = Pixel(1)

const Space = Type{<: Unit}

struct Data{T} <: Unit{T}
    value::T
end

"""
    Billboard([angle::Real])
    Billboard([angles::Vector{<: Real}])

Billboard attribute to always have a primitive face the camera.
Can be used for rotation.
"""
struct Billboard{T <: Union{Float32, Vector{Float32}}}
    rotation::T
end
Billboard() = Billboard(0f0)
Billboard(angle::Real) = Billboard(Float32(angle))
Billboard(angles::Vector) = Billboard(Float32.(angles))

@enum AntiAliasing FXAA NOAA MULTISAMPLE

mutable struct Camera
    pixel_area::Observable{Rect2D}
    pixel_space::Observable{Mat4f0}
    view::Observable{Mat4f0}
    projection::Observable{Mat4f0}
    projectionview::Observable{Mat4f0}
    eyeposition::Observable{Vec3f0}
    steering_nodes::Vector{Observables.ObserverFunction}
end

function Camera(pixel_area = Observable(Rect(0.0, 0.0, 0.0, 0.0)))
    pixel_space = map(pixel_area) do window_size
        nearclip = -10_000f0
        farclip = 10_000f0
        w, h = Float32.(widths(window_size))
        return orthographicprojection(0f0, w, 0f0, h, nearclip, farclip)
    end
    Camera(
        pixel_area,
        pixel_space,
        Observable(Mat4f0(I)),
        Observable(Mat4f0(I)),
        Observable(Mat4f0(I)),
        Observable(Vec3f0(1)),
        Observables.ObserverFunction[]
    )
end

"""
Holds the transformations for Scenes.
"""
struct Transformation <: Transformable
    parent::RefValue{Transformable}
    translation::Observable{Vec3f0}
    scale::Observable{Vec3f0}
    rotation::Observable{Quaternionf0}
    model::Observable{Mat4f0}
    flip::Observable{NTuple{3, Bool}}
    align::Observable{Vec2f0}
    # data conversion node, for e.g. log / log10 etc
    transform_func::Observable{Any}
    function Transformation(translation, scale, rotation, model, flip, align, transform_func)
        return new(
            RefValue{Transformable}(),
            translation, scale, rotation, model, flip, align, transform_func
        )
    end
end

function Transformation(transform_func=identity)
    flip = Observable((false, false, false))
    scale = Observable(Vec3f0(1))
    scale = map(flip, scale) do f, s
        map((f, s)-> f ? -s : s, Vec(f), s)
    end
    translation, rotation, align = (
        Observable(Vec3f0(0)),
        Observable(Quaternionf0(0, 0, 0, 1)),
        Observable(Vec2f0(0))
    )
    trans = nothing
    model = map(scale, translation, rotation, align, flip) do s, o, q, a, flip
        parent = if trans !== nothing && isassigned(trans.parent)
            boundingbox(trans.parent[])
        else
            nothing
        end
        transformationmatrix(o, s, q, a, flip, parent)
    end
    return Transformation(
        translation,
        scale,
        rotation,
        model,
        flip,
        align,
        Observable{Any}(transform_func)
    )
end
