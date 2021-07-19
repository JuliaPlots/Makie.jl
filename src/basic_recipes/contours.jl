
"""
    contour(x, y, z)

Creates a contour plot of the plane spanning x::Vector, y::Vector, z::Matrix

## Attributes
$(ATTRIBUTES)
"""
@recipe(Contour) do scene
    default = default_theme(scene)
    # pop!(default, :color)
    Attributes(;
        default...,
        color = nothing,
        colormap = theme(scene, :colormap),
        colorrange = Makie.automatic,
        levels = 5,
        linewidth = 1.0,
        alpha = 1.0,
        fillrange = false
    )
end

"""
    contour3d(x, y, z)

Creates a 3D contour plot of the plane spanning x::Vector, y::Vector, z::Matrix,
with z-elevation for each level.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Contour3d) do scene
    default_theme(scene, Contour)
end

function contourlines(::Type{<: Contour}, contours, cols)
    result = Point2f[]
    colors = RGBA{Float32}[]
    for (color, c) in zip(cols, Contours.levels(contours))
        for elem in Contours.lines(c)
            append!(result, elem.vertices)
            push!(result, Point2f(NaN32))
            append!(colors, fill(color, length(elem.vertices) + 1))
        end
    end
    result, colors
end

function contourlines(::Type{<: Contour3d}, contours, cols)
    result = Point3f[]
    colors = RGBA{Float32}[]
    for (color, c) in zip(cols, Contours.levels(contours))
        for elem in Contours.lines(c)
            for p in elem.vertices
                push!(result, Point3f(p[1], p[2], c.level))
            end
            push!(result, Point3f(NaN32))
            append!(colors, fill(color, length(elem.vertices) + 1))
        end
    end
    result, colors
end

to_levels(x::AbstractVector{<: Number}, cnorm) = x

function to_levels(n::Integer, cnorm)
    zmin, zmax = cnorm
    dz = (zmax - zmin) / (n + 1)
    range(zmin + dz; step = dz, length = n)
end

conversion_trait(::Type{<: Contour3d}) = ContinuousSurface()
conversion_trait(::Type{<: Contour}) = ContinuousSurface()
conversion_trait(::Type{<: Contour{<: Tuple{X, Y, Z, Vol}}}) where {X, Y, Z, Vol} = VolumeLike()
conversion_trait(::Type{<: Contour{<: Tuple{<: AbstractArray{T, 3}}}}) where T = VolumeLike()

function plot!(plot::Contour{<: Tuple{X, Y, Z, Vol}}) where {X, Y, Z, Vol}
    x, y, z, volume = plot[1:4]
    @extract plot (colormap, levels, linewidth, alpha)
    valuerange = lift(nan_extrema, volume)
    cliprange = replace_automatic!(plot, :colorrange) do
        valuerange
    end
    cmap = lift(colormap, levels, linewidth, alpha, cliprange, valuerange) do _cmap, l, lw, alpha, cliprange, vrange
        levels = to_levels(l, vrange)
        nlevels = length(levels)
        N = nlevels * 50
        iso_eps = nlevels * ((vrange[2] - vrange[1]) / N) # TODO calculate this
        cmap = to_colormap(_cmap)
        v_interval = cliprange[1] .. cliprange[2]
        # resample colormap and make the empty area between iso surfaces transparent
        map(1:N) do i
            i01 = (i-1) / (N - 1)
            c = Makie.interpolated_getindex(cmap, i01)
            isoval = vrange[1] + (i01 * (vrange[2] - vrange[1]))
            line = reduce(levels, init = false) do v0, level
                (isoval in v_interval) || return false
                v0 || (abs(level - isoval) <= iso_eps)
            end
            RGBAf(Colors.color(c), line ? alpha : 0.0)
        end
    end
    volume!(
        plot, x, y, z, volume, colormap = cmap, colorrange = cliprange, algorithm = 7,
        transparency = plot.transparency, overdraw = plot.overdraw,
        ambient = plot.ambient, diffuse = plot.diffuse, lightposition = plot.lightposition,
        shininess = plot.shininess, specular = plot.specular, inspectable = plot.inspectable
    )
end

function color_per_level(color, colormap, colorrange, alpha, levels)
    color_per_level(to_color(color), colormap, colorrange, alpha, levels)
end

function color_per_level(color::Colorant, colormap, colorrange, alpha, levels)
    fill(color, length(levels))
end

function color_per_level(colors::AbstractVector, colormap, colorrange, alpha, levels)
    color_per_level(to_colormap(colors), colormap, colorrange, alpha, levels)
end

function color_per_level(colors::AbstractVector{<: Colorant}, colormap, colorrange, alpha, levels)
    if length(levels) == length(colors)
        return colors
    else
        # TODO resample?!
        error("For a contour plot, `color` with an array of colors needs to
        have the same length as `levels`.
        Found $(length(colors)) colors, but $(length(levels)) levels")
    end
end

function color_per_level(::Nothing, colormap, colorrange, a, levels)
    cmap = to_colormap(colormap)
    map(levels) do level
        c = interpolated_getindex(cmap, level, colorrange)
        RGBAf(color(c), alpha(c) * a)
    end
end


function plot!(plot::T) where T <: Union{Contour, Contour3d}
    x, y, z = plot[1:3]
    if to_value(plot[:fillrange])
        plot[:interpolate] = true
        # TODO normalize linewidth for heatmap
        plot[:linewidth] = map(x-> x ./ 10f0, plot[:linewidth])
        heatmap!(plot, Attributes(plot), x, y, z)
    else
        zrange = lift(nan_extrema, z)
        levels = lift(plot[:levels], zrange) do levels, zrange
            if levels isa AbstractVector{<: Number}
                return levels
            elseif levels isa Integer
                to_levels(levels, zrange)
            else
                error("Level needs to be Vector of iso values, or a single integer to for a number of automatic levels")
            end
        end
        replace_automatic!(plot, :colorrange) do
            lift(nan_extrema, levels)
        end
        args = @extract plot (color, colormap, colorrange, alpha)
        level_colors = lift(color_per_level, args..., levels)
        result = lift(x, y, z, levels, level_colors) do x, y, z, levels, level_colors
            t = eltype(z)
            # Compute contours
            xv, yv = to_vector(x, size(z,1), t), to_vector(y, size(z,2), t)
            contours = Contours.contours(xv, yv, z,  convert(Vector{eltype(z)}, levels))
            contourlines(T, contours, level_colors)
        end
        lines!(
            plot, lift(first, result);
            color = lift(last, result), linewidth = plot[:linewidth],
            inspectable = plot[:inspectable]
        )
    end
    plot
end

function data_limits(x::Contour{<: Tuple{X, Y, Z}}) where {X, Y, Z}
    return xyz_boundingbox(transform_func(x), to_value.((x[1], x[2]))...)
end
