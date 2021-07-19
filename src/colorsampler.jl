@enum Interpolation Linear Nearest

struct Scaling{F, R}
    # a function to scale a value by, e.g. log10, sqrt etc
    scaling_function::F
    # If nothing, no scaling applied!
    range::R
end

Scaling() = Scaling(identity, nothing)

const NoScaling = Scaling{typeof(identity), Nothing}

struct Sampler{N, V} <: AbstractArray{RGBAf, 1}
    # the colors to sample from!
    colors::AbstractArray{T, N} where T
    # or an array of values, which are used to index into colors via interpolation!
    values::V
    # additional alpha that gets multiplied
    alpha::Float64
    # interpolation method for sampling
    interpolation::Interpolation
    scaling::Scaling
end

Base.size(sampler::Sampler) = size(sampler.values)

"""
    interpolated_getindex(cmap::AbstractArray, value::AbstractFloat, norm = (0.0, 1.0))

Like getindex, but accepts values between 0..1 and interpolates those to the full range.
You can use `norm`, to change the range of 0..1 to whatever you want.
"""
function interpolated_getindex(cmap::AbstractArray, value::Number, norm::VecTypes)
    cmin, cmax = norm
    i01 = clamp((value - cmin) / (cmax - cmin), 0.0, 1.0)
    if !isfinite(i01)
        i01 = 0.0
    end
    return interpolated_getindex(cmap, i01)
end

"""
    interpolated_getindex(cmap::AbstractArray, value::AbstractFloat)

Like getindex, but accepts values between 0..1 for `value` and interpolates those to the full range of `cmap`.
"""
function interpolated_getindex(cmap::AbstractArray{T}, i01::AbstractFloat) where T
    i1len = (i01 * (length(cmap) - 1)) + 1
    down = floor(Int, i1len)
    up = ceil(Int, i1len)
    down == up && return cmap[down]
    interp_val = i1len - down
    downc, upc = cmap[down], cmap[up]
    return convert(T, (downc * (1.0 - interp_val)) + (upc * interp_val))
end

function nearest_getindex(cmap::AbstractArray, value::AbstractFloat)
    idx = round(Int, i01 * (length(cmap) - 1)) + 1
    return cmap[idx]
end

"""
    apply_scaling(value::Number, scaling::Scaling)

Scales a number to the range 0..1.
"""
function apply_scaling(value::Number, scaling::NoScaling)::Float64
    return Float64(value)
end

function apply_scaling(value::Number, scaling::Scaling)::Float64
    value_scaled = scaling.scaling_function(value)
    if scaling.range === nothing
        return value_scaled
    end
    cmin, cmax = scaling.range
    clamped = clamp((value_scaled - cmin) / (cmax - cmin), 0.0, 1.0)
    if isfinite(clamped)
        return clamped
    else
        return 0.0
    end
end

function Base.getindex(sampler::Sampler, i)::RGBAf
    value = sampler.values[i]
    scaled = apply_scaling(value, sampler.scaling)
    c = if sampler.interpolation == Linear
        interpolated_getindex(sampler.colors, scaled)
    else
        nearest_getindex(sampler.colors, scaled)
    end
    return RGBAf(color(c), alpha(c) * sampler.alpha)
end

function Base.getindex(sampler::Sampler{2, <: AbstractVector{Vec2f}}, i)::RGBAf
    uv = sampler.values[i]
    colors = sampler.colors
    # indexing confirming to OpenGL uv indexing
    wsize = reverse(size(colors))
    wh = wsize .- 1
    x, y = round.(Int, Tuple(uv) .* wh) .+ 1
    c = colors[size(colors, 1) - (y - 1), x]
    return RGBAf(color(c), alpha(c) * sampler.alpha)
end

function sampler(cmap::Union{Symbol, String}, n::Int = 20;
                 scaling=Scaling(), alpha=1.0, interpolation=Linear)
    return sampler(cmap, LinRange(0, 1, n); scaling = scaling, alpha = alpha, interpolation = interpolation)
end

function sampler(cmap::Union{Symbol, String}, values::AbstractVector{<: AbstractFloat};
                 scaling=Scaling(), alpha=1.0, interpolation=Linear)

    cs = PlotUtils.get_colorscheme(cmap)

    colors = getindex.(Ref(cs), values)

    return Sampler(colors, values, alpha, interpolation, scaling)
end

function sampler(cmap::Vector{<: Colorant}, values::AbstractVector{<: AbstractFloat};
                 scaling=Scaling(), alpha=1.0, interpolation=Linear)
    return Sampler(RGBAf.(cmap), values, alpha, interpolation, scaling)
end

function sampler(cmap::AbstractVector, values, crange;
                 alpha=1.0, interpolation=Linear)
    return Sampler(to_color.(cmap), values, alpha, interpolation, Scaling(identity, crange))
end
# uv texture sampler
function sampler(cmap::Matrix{<: Colorant}, uv::AbstractVector{Vec2f};
                 alpha=1.0, interpolation=Linear)
    return Sampler(cmap, uv, alpha, interpolation, Scaling())
end
