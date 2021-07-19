"""
    errorbars(x, y, error_both; kwargs...)
    errorbars(x, y, error_low, error_high; kwargs...)
    errorbars(x, y, error_low_high; kwargs...)

    errorbars(xy, error_both; kwargs...)
    errorbars(xy, error_low, error_high; kwargs...)
    errorbars(xy, error_low_high; kwargs...)

    errorbars(xy_error_both; kwargs...)
    errorbars(xy_error_low_high; kwargs...)

Plots errorbars at xy positions, extending by errors in the given `direction`.

If you want to plot intervals from low to high values instead of relative errors, use `rangebars`.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Errorbars) do scene
    Theme(
        whiskerwidth = 0,
        color = theme(scene, :linecolor),
        linewidth = theme(scene, :linewidth),
        direction = :y,
        visible = theme(scene, :visible),
        colormap = theme(scene, :colormap),
        inspectable = theme(scene, :inspectable)
    )
end


"""
    rangebars(val, low, high; kwargs...)
    rangebars(val, low_high; kwargs...)
    rangebars(val_low_high; kwargs...)

Plots rangebars at `val` in one dimension, extending from `low` to `high` in the other dimension
given the chosen `direction`.

If you want to plot errors relative to a reference value, use `errorbars`.

## Attributes
$(ATTRIBUTES)
"""
@recipe(Rangebars) do scene
    Theme(
        whiskerwidth = 0,
        color = theme(scene, :linecolor),
        linewidth = theme(scene, :linewidth),
        direction = :y,
        visible = theme(scene, :visible),
        colormap = theme(scene, :colormap),
        inspectable = theme(scene, :inspectable)
    )
end

### conversions for errorbars

function Makie.convert_arguments(::Type{<:Errorbars}, x, y, error_both)
    xyerr = broadcast(x, y, error_both) do x, y, e
        Vec4f(x, y, e, e)
    end
    (xyerr,)
end

function Makie.convert_arguments(::Type{<:Errorbars}, x, y, error_low, error_high)
    xyerr = broadcast(Vec4f, x, y, error_low, error_high)
    (xyerr,)
end


function Makie.convert_arguments(::Type{<:Errorbars}, x, y, error_low_high::AbstractVector{<:VecTypes{2}})
    xyerr = broadcast(x, y, error_low_high) do x, y, (el, eh)
        Vec4f(x, y, el, eh)
    end
    (xyerr,)
end

function Makie.convert_arguments(::Type{<:Errorbars}, xy::AbstractVector{<:VecTypes{2}}, error_both)
    xyerr = broadcast(xy, error_both) do (x, y), e
        Vec4f(x, y, e, e)
    end
    (xyerr,)
end

function Makie.convert_arguments(::Type{<:Errorbars}, xy::AbstractVector{<:VecTypes{2}}, error_low, error_high)
    xyerr = broadcast(xy, error_low, error_high) do (x, y), el, eh
        Vec4f(x, y, el, eh)
    end
    (xyerr,)
end

function Makie.convert_arguments(::Type{<:Errorbars}, xy::AbstractVector{<:VecTypes{2}}, error_low_high::AbstractVector{<:VecTypes{2}})
    xyerr = broadcast(xy, error_low_high) do (x, y), (el, eh)
        Vec4f(x, y, el, eh)
    end
    (xyerr,)
end

function Makie.convert_arguments(::Type{<:Errorbars}, xy_error_both::AbstractVector{<:VecTypes{3}})
    xyerr = broadcast(xy_error_both) do (x, y, e)
        Vec4f(x, y, e, e)
    end
    (xyerr,)
end

### conversions for rangebars

function Makie.convert_arguments(::Type{<:Rangebars}, val, low, high)
    val_low_high = broadcast(Vec3f, val, low, high)
    (val_low_high,)
end

function Makie.convert_arguments(::Type{<:Rangebars}, val, low_high)
    val_low_high = broadcast(val, low_high) do val, (low, high)
        Vec3f(val, low, high)
    end
    (val_low_high,)
end

### the two plotting functions create linesegpairs in two different ways
### and then hit the same underlying implementation in `_plot_bars!`

function Makie.plot!(plot::Errorbars{T}) where T <: Tuple{AbstractVector{<:VecTypes{4}}}

    x_y_low_high = plot[1]

    is_in_y_direction = lift(plot.direction) do dir
        if dir == :y
            true
        elseif dir == :x
            false
        else
            error("Invalid direction $dir. Options are :x and :y.")
        end
    end

    linesegpairs = lift(x_y_low_high, is_in_y_direction) do x_y_low_high, in_y

        map(x_y_low_high) do (x, y, l, h)
            in_y ?
                (Point2f(x, y - l), Point2f(x, y + h)) :
                (Point2f(x - l, y), Point2f(x + h, y))
        end
    end

    _plot_bars!(plot, linesegpairs, is_in_y_direction)
end


function Makie.plot!(plot::Rangebars{T}) where T <: Tuple{AbstractVector{<:VecTypes{3}}}

    val_low_high = plot[1]

    is_in_y_direction = lift(plot.direction) do dir
        if dir == :y
            true
        elseif dir == :x
            false
        else
            error("Invalid direction $dir. Options are :x and :y.")
        end
    end

    linesegpairs = lift(val_low_high, is_in_y_direction) do vlh, in_y

        map(vlh) do (v, l, h)
            in_y ?
                (Point2f(v, l), Point2f(v, h)) :
                (Point2f(l, v), Point2f(h, v))
        end
    end

    _plot_bars!(plot, linesegpairs, is_in_y_direction)
end



function _plot_bars!(plot, linesegpairs, is_in_y_direction)

    f_if(condition, f, arg) = condition ? f(arg) : arg

    @extract plot (whiskerwidth, color, linewidth, visible, colormap, inspectable)

    scene = parent_scene(plot)

    whiskers = lift(linesegpairs, scene.camera.projectionview,
        scene.camera.pixel_space, whiskerwidth) do pairs, _, _, whiskerwidth

        endpoints = [p for pair in pairs for p in pair]

        screenendpoints = scene_to_screen(endpoints, scene)

        screenendpoints_shifted_pairs = map(screenendpoints) do sep
            (sep .+ f_if(is_in_y_direction[], reverse, Point(0, -whiskerwidth/2)),
             sep .+ f_if(is_in_y_direction[], reverse, Point(0,  whiskerwidth/2)))
        end

        screen_to_scene([p for pair in screenendpoints_shifted_pairs for p in pair], scene)
    end

    whiskercolors = lift(Any, color) do color
        # we have twice as many linesegments for whiskers as we have errorbars, so we
        # need to duplicate colors if a vector of colors is given
        if color isa AbstractVector
            repeat(color, inner = 2)
        else
            color
        end
    end

    whiskerlinewidths = lift(Any, linewidth) do linewidth
        # same for linewidth
        if linewidth isa AbstractVector
            repeat(linewidth, inner = 2)
        else
            linewidth
        end
    end

    linesegments!(
        plot, linesegpairs, color = color, linewidth = linewidth, visible = visible,
        colormap = colormap, inspectable = inspectable
    )
    linesegments!(
        plot, whiskers, color = whiskercolors, linewidth = whiskerlinewidths,
        visible = visible, colormap = colormap, inspectable = inspectable
    )
    plot
end

function scene_to_screen(pts, scene)
    p4 = to_ndim.(Vec4f, to_ndim.(Vec3f, pts, 0.0), 1.0)
    p1m1 = Ref(scene.camera.projectionview[]) .* p4
    projected = Ref(inv(scene.camera.pixel_space[])) .* p1m1
    [Point2.(p[1:2]...) for p in projected]
end

function screen_to_scene(pts, scene)
    p4 = to_ndim.(Vec4f, to_ndim.(Vec3f, pts, 0.0), 1.0)
    p1m1 = Ref(scene.camera.pixel_space[]) .* p4
    projected = Ref(inv(scene.camera.projectionview[])) .* p1m1
    [Point2.(p[1:2]...) for p in projected]
end

function scene_to_screen(p::T, scene) where T <: Point
    p4 = to_ndim(Vec4f, to_ndim(Vec3f, p, 0.0), 1.0)
    p1m1 = scene.camera.projectionview[] * p4
    projected = inv(scene.camera.pixel_space[]) * p1m1
    T(projected[1:2]...)
end

function screen_to_scene(p::T, scene) where T <: Point
    p4 = to_ndim(Vec4f, to_ndim(Vec3f, p, 0.0), 1.0)
    p1m1 = scene.camera.pixel_space[] * p4
    projected = inv(scene.camera.projectionview[]) * p1m1
    T(projected[1:2]...)
end


# ignore whiskers when determining data limits
function data_limits(bars::Union{Errorbars, Rangebars})
    data_limits(bars.plots[1])
end
