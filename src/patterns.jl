"""
    AbstractPattern{T} <: AbstractArray{T, 2}

`AbstractPatterns` are image-like array types which can be used to color
plottable objects. There are currently two subtypes: `LinePattern` and
`ImagePattern`. Any abstract pattern must implement the `to_image(pat)`
function, which must return a `Matrix{<: AbstractRGB}`.
"""
abstract type AbstractPattern{T} <: AbstractArray{T, 2} end

function Base.show(io::IO, ::MIME"text/plain", p::AbstractPattern)
    println(io, typeof(p))
    show(io, mime, image(p))
end
struct ImagePattern{T<:Colorant} <: AbstractPattern{T}
    img::Matrix{T}
end

"""
    Pattern(image)
    Pattern(mask[; color1, color2])

Creates an `ImagePattern` from an `image` (a matrix of colors) or a `mask`
(a matrix of real numbers). The pattern can be passed as a `color` to a plot to
texture it. If a `mask` is passed, one can specify to colors between which colors are
interpolated.
"""
Pattern(img::Array{<: Colorant, 2}) = ImagePattern(img)

function Pattern(mask::Matrix{<: Real}; color1=RGBA(0,0,0,1), color2=RGBA(1,1,1,0))
    img = map(x -> to_color(color1) * x + to_color(color2) * (1-x), mask)
    return ImagePattern(img)
end

to_image(p::ImagePattern) = p.img

struct LinePattern{T} <: AbstractPattern{T}
    dirs::Vector{Vec2}
    widths::Vector{AbstractFloat}
    shifts::Vector{Vec2}

    tilesize::NTuple{2, Integer}
    colors::NTuple{2, T}
end

"""
    LinePattern([; kwargs...])

Creates a `LinePattern` for the given keyword arguments:
- `direction`: The direction of the line.
- `width`: The width of the line
- `tilesize`: The size of the image on which the line is drawn. This should be
compatible with the direction.
- `shift`: Sets the starting point for the line.
- `linecolor`: The color with which the line is replaced.
- `background_color`:: The background color.

Multiple `direction`s, `width`s and `shift`s can also be given to create more
complex patterns, e.g. a cross-hatching pattern.
"""
function LinePattern(;
        direction = Vec2f(1), width = 2f0, tilesize = (10,10),
        shift = map(w -> Vec2f(0.5 - 0.5(w%2)), width),
        linecolor = RGBA(0,0,0,1), background_color = RGBA(1,1,1,0)
    )
    N = 1
    direction isa Vector{<:Vec2} && (N = length(direction))
    width isa Vector && (length(width) > N) && (N = length(width))
    shift isa Vector{<:Vec2} && (length(shift) > N) && (N = length(shift))

    dirs = direction isa Vector{<:Vec2} ? direction : [direction for _ in 1:N]
    widths = width isa Vector ? width : [width for _ in 1:N]
    shifts = shift isa Vector{<:Vec2} ? shift : [shift for _ in 1:N]
    colors = (to_color(linecolor), to_color(background_color))

    return LinePattern{eltype(colors)}(dirs, widths, shifts, tilesize, colors)
end

"""
    Pattern(style::String = "/"; kwargs...)
    Pattern(style::Char = '/'; kwargs...)

Creates a line pattern based on the given argument. Available patterns are
`'/'`, `'\\'`, `'-'`, `'|'`, `'x'`, and `'+'`. All keyword arguments correspond
to the keyword arguments for [`LinePattern`](@ref).
"""
Pattern(style::String; kwargs...) = Pattern(style[1]; kwargs...)
function Pattern(style::Char = '/'; kwargs...)
    if style == '/'
        LinePattern(direction=Vec2f(1); kwargs...)
    elseif style == '\\'
        LinePattern(direction=Vec2f(1, -1); kwargs...)
    elseif style == '-'
        LinePattern(direction=Vec2f(1, 0); kwargs...)
    elseif style == '|'
        LinePattern(direction=Vec2f(0, 1); kwargs...)
    elseif style == 'x'
        LinePattern(direction=[Vec2f(1), Vec2f(1, -1)]; kwargs...)
    elseif style == '+'
        LinePattern(direction=[Vec2f(1, 0), Vec2f(0, 1)]; kwargs...)
    else
        LinePattern(; kwargs...)
    end
end

function to_image(p::LinePattern)
    tilesize = p.tilesize
    full_mask = zeros(tilesize...)
    for (dir, width, shift) in zip(p.dirs, p.widths, p.shifts)
        mask = zeros(tilesize...)
        width -= 1 # take away center
        if abs(dir[1]) < abs(dir[2])
            # m = dx / dy; x = m * (y-1) + 1
            m = dir[1] / dir[2]
            for y in 1:tilesize[2]
                cx = m * (y-shift[2]) + shift[1]
                r = floor(Int64, cx-0.5width):ceil(Int64, cx+0.5width)
                for x in r[2:end-1]
                    mask[mod1(x, tilesize[1]), y] = 1.0
                end
                mask[mod1(r[1], tilesize[1]), y] = 1 - abs(cx-0.5width - r[1])
                mask[mod1(r[end], tilesize[1]), y] = 1 - abs(cx+0.5width - r[end])
            end
        else
            # m = dy / dx; y = m * (x-1) + 1
            m = dir[2] / dir[1]
            for x in 1:tilesize[1]
                cy = m * (x-shift[1]) + shift[2]
                r = floor(Int64, cy-0.5width):ceil(Int64, cy+0.5width)
                for y in r[2:end-1]
                    mask[x, mod1(y, tilesize[2])] = 1.0
                end
                mask[x, mod1(r[1], tilesize[2])] = 1 - abs(cy-0.5width - r[1])
                mask[x, mod1(r[end], tilesize[2])] = 1 - abs(cy+0.5width - r[end])
            end
        end
        full_mask .+= mask
    end

    return map(full_mask) do x
        p.colors[1] * clamp(x, 0, 1) + p.colors[2] * (1-clamp(x, 0, 1))
    end
end
