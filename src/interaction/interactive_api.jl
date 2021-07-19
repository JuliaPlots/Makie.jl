export mouseover, mouse_selection, mouseposition, hovered_scene
export select_rectangle, select_line, select_point


"""
    mouseover(scene::SceneLike, plots::AbstractPlot...)

Returns true if the mouse currently hovers any of `plots`.
"""
function mouseover(scene::SceneLike, plots::AbstractPlot...)
    p, idx = mouse_selection(scene)
    return p in flatten_plots(plots)
end

"""
    onpick(f, scene::SceneLike, plots::AbstractPlot...)

Calls `f(plot, idx)` whenever the mouse is over any of `plots`.
`idx` is an index, e.g. when over a scatter plot, it will be the index of the
hovered element
"""
function onpick(f, scene::SceneLike, plots::AbstractPlot...; range=1)
    fplots = flatten_plots(plots)
    args = range == 1 ? (scene,) : (scene, range)
    on(events(scene).mouseposition) do mp
        p, idx = mouse_selection(args...)
        (p in fplots) && f(p, idx)
        return Consume(false)
    end
end

"""
    mouse_selection(scene::Scene)

Returns the plot that is under the current mouse position
"""
function mouse_selection(scene::SceneLike)
    pick(scene, events(scene).mouseposition[])
end
function mouse_selection(scene::SceneLike, range)
    pick(scene, events(scene).mouseposition[], range)
end

function flatten_plots(x::Atomic, plots = AbstractPlot[])
    if isempty(x.plots)
        push!(plots, x)
    else
        flatten_plots(x.plots, plots)
    end
    plots
end

function flatten_plots(x::Combined, plots = AbstractPlot[])
    for elem in x.plots
        flatten_plots(elem, plots)
    end
    plots
end

function flatten_plots(array, plots = AbstractPlot[])
    for elem in array
        flatten_plots(elem, plots)
    end
    plots
end

"""
    mouse_in_scene(scene::Scene[, priority = 0])

Returns a new node that is true whenever the cursor is inside the given scene.

See also: [`is_mouseinside`](@ref)
"""
function mouse_in_scene(scene::SceneLike; priority = Int8(0))
    p = rootparent(scene)
    output = Node(Vec2(0.0))
    on(events(scene).mouseposition, priority = priority) do mp
        output[] = Vec(mp) .- minimum(pixelarea(scene)[])
        return Consume(false)
    end
    output
end


"""
    pick(scene, x, y)

Returns the plot under pixel position `(x, y)`.
"""
function pick(scene::SceneLike, x::Number, y::Number)
    return pick(scene, Vec{2, Float64}(x, y))
end


"""
    pick(scene::Scene, xy::VecLike)

Return the plot under pixel position xy.
"""
function pick(scene::SceneLike, xy)
    screen = getscreen(scene)
    screen === nothing && return (nothing, 0)
    pick(scene, screen, Vec{2, Float64}(xy))
end

"""
    pick(scene::Scene, xy::VecLike, range)

Return the plot closest to xy within a given range.
"""
function pick(scene::SceneLike, xy, range)
    screen = getscreen(scene)
    screen === nothing && return (nothing, 0)
    pick_closest(scene, screen, xy, range)
end

# The backend may handle this more optimally
function pick_closest(scene::SceneLike, screen, xy, range)
    w, h = widths(screen)
    ((1.0 <= xy[1] <= w) && (1.0 <= xy[2] <= h)) || return (nothing, 0)
    x0, y0 = max.(1, floor.(Int, xy .- range))
    x1, y1 = min.([w, h], floor.(Int, xy .+ range))
    dx = x1 - x0; dy = y1 - y0

    picks = pick(scene, screen, Rect2i(x0, y0, dx, dy))

    min_dist = range^2
    selected = (0, 0)
    x, y =  xy .+ 1 .- Vec2f(x0, y0)
    for i in 1:dx, j in 1:dy
        d = (x-i)^2 + (y-j)^2
        if (d < min_dist) && (picks[i, j][1] != nothing)
            min_dist = d
            selected = (i, j)
        end
    end

    return selected == (0, 0) ? (nothing, 0) : picks[selected[1], selected[2]]
end

"""
    pick_sorted(scene::Scene, xy::VecLike, range)

Return all `(plot, index)` pairs in a `(xy .- range, xy .+ range)` region
sorted by distance to `xy`.
"""
function pick_sorted(scene::SceneLike, xy, range)
    screen = getscreen(scene)
    screen === nothing && return Tuple{AbstractPlot, Int}[]
    pick_sorted(scene, screen, xy, range)
end

function pick_sorted(scene::SceneLike, screen, xy, range)
    w, h = widths(screen)
    if !((1.0 <= xy[1] <= w) && (1.0 <= xy[2] <= h))
        return Tuple{AbstractPlot, Int}[]
    end
    x0, y0 = max.(1, floor.(Int, xy .- range))
    x1, y1 = min.([w, h], floor.(Int, xy .+ range))
    dx = x1 - x0; dy = y1 - y0

    picks = pick(scene, screen, Rect2i(x0, y0, dx, dy))

    selected = filter(x -> x[1] != nothing, unique(vec(picks)))
    distances = [range^2 for _ in selected]
    x, y =  xy .+ 1 .- Vec2f(x0, y0)
    for i in 1:dx, j in 1:dy
        if picks[i, j][1] != nothing
            d = (x-i)^2 + (y-j)^2
            i = findfirst(isequal(picks[i, j]), selected)
            if i === nothing
                @warn "This shouldn't happen..."
            elseif distances[i] > d
                distances[i] = d
            end
        end
    end

    idxs = sortperm(distances)
    permute!(selected, idxs)
    return selected
end

"""
    pick(scene::Scene, rect::Rect2i)

Return all `(plot, index)` pairs within the given rect. The rect must be within
screen boundaries.
"""
function pick(scene::SceneLike, rect::Rect2i)
    screen = getscreen(scene)
    screen === nothing && return Tuple{AbstractPlot, Int}[]
    return pick(scene, screen, rect)
end

"""
    screen_relative(scene, pos)

Normalizes mouse position `pos` relative to the screen rectangle.
"""
function screen_relative(scene::Scene, mpos)
    return Point2f(mpos) .- Point2f(minimum(pixelarea(scene)[]))
end

"""
    mouseposition(scene = hovered_scene())

Return the current position of the mouse in _data coordinates_ of the
given `scene`.

By default uses the `scene` that the mouse is currently hovering over.
"""
function mouseposition(scene = hovered_scene())
    to_world(scene, mouseposition_px(scene))
end

function mouseposition_px(scene = hovered_scene())
    screen_relative(
        scene,
        events(scene).mouseposition[]
    )
end

"""
    hovered_scene()

Returns the `scene` that the mouse is currently hovering over.

Properly identifies the scene for a plot with multiple sub-plots.
"""
hovered_scene() = error("hoevered_scene is not implemented yet.")


"""
    select_rectangle(scene; kwargs...) -> rect

Interactively select a rectangle on a 2D `scene` by clicking the left mouse button,
dragging and then un-clicking. The function returns an **observable** `rect` whose
value corresponds to the selected rectangle on the scene. In addition the function
_plots_ the selected rectangle on the scene as the user clicks and moves the mouse
around. When the button is not clicked any more, the plotted rectangle disappears.

The value of the returned observable is updated **only** when the user un-clicks
(i.e. when the final value of the rectangle has been decided) and only if the
rectangle has area > 0.

The `kwargs...` are propagated into `lines!` which plots the selected rectangle.
"""
function select_rectangle(scene; blocking = false, priority = 2, strokewidth = 3.0, kwargs...)
    key = Mouse.left
    waspressed = Node(false)
    rect = Node(Rectf(0, 0, 1, 1)) # plotted rectangle
    rect_ret = Node(Rectf(0, 0, 1, 1)) # returned rectangle

    # Create an initially hidden rectangle
    plotted_rect = poly!(
        scene, rect, raw = true, visible = false, color = RGBAf(0, 0, 0, 0), strokecolor = RGBAf(0.1, 0.1, 0.8, 0.5), strokewidth = strokewidth, kwargs...,
    )

    on(events(scene).mousebutton, priority=priority) do event
        if event.button == key
            if event.action == Mouse.press && is_mouseinside(scene)
                mp = mouseposition(scene)
                waspressed[] = true
                plotted_rect[:visible] = true # start displaying
                rect[] = Rectf(mp, 0.0, 0.0)
                return Consume(blocking)
            end
        end
        if !(event.button == key && event.action == Mouse.press)
            if waspressed[] # User has selected the rectangle
                waspressed[] = false
                r = absrect(rect[])
                w, h = widths(r)
                if w > 0.0 && h > 0.0 # Ensure that the rectangle has non0 size.
                    rect_ret[] = r
                end
            end
            # always hide if not the right key is pressed
            plotted_rect[:visible] = false # make the plotted rectangle invisible
            return Consume(blocking)
        end

        return Consume(false)
    end
    on(events(scene).mouseposition, priority=priority) do event
        if waspressed[]
            mp = mouseposition(scene)
            mini = minimum(rect[])
            rect[] = Rectf(mini, mp - mini)
            return Consume(blocking)
        end
        return Consume(false)
    end

    return rect_ret
end

"""
    select_line(scene; kwargs...) -> line

Interactively select a line (typically an arrow) on a 2D `scene` by clicking the left mouse button,
dragging and then un-clicking. Return an **observable** whose value corresponds
to the selected line on the scene. In addition the function
_plots_ the line on the scene as the user clicks and moves the mouse
around. When the button is not clicked any more, the plotted line disappears.

The value of the returned line is updated **only** when the user un-clicks
and only if the selected line has non-zero length.

The `kwargs...` are propagated into `lines!` which plots the selected line.
"""
function select_line(scene; blocking = false, priority = 2, kwargs...)
    key = Mouse.left
    waspressed = Node(false)
    line = Node([Point2f(0,0), Point2f(1,1)])
    line_ret = Node([Point2f(0,0), Point2f(1,1)])
    # Create an initially hidden  arrow
    plotted_line = lines!(
        scene, line; visible = false, color = RGBAf(0.1, 0.1, 0.8, 0.5),
        linewidth = 4, kwargs...,
    )

    on(events(scene).mousebutton, priority=priority) do event
        if event.button == key && is_mouseinside(scene)
            mp = mouseposition(scene)
            if event.action == Mouse.press
                waspressed[] = true
                plotted_line[:visible] = true  # start displaying
                line[][1] = mp
                line[][2] = mp
                line[] = line[]
                return Consume(blocking)
            end
        end
        if !(event.button == key && event.action == Mouse.press)
            if waspressed[] # User has selected the rectangle
                waspressed[] = false
                if line[][1] != line[][2]
                    line_ret[] = copy(line[])
                end
            end
            plotted_line[:visible] = false
            return Consume(blocking)
        end
        return Consume(false)
    end
    on(events(scene).mouseposition, priority=priority) do event
        if waspressed[]
            mp = mouseposition(scene)
            line[][2] = mp
            line[] = line[] # actually update observable
            return Consume(blocking)
        end
        return Consume(false)
    end

    return line_ret
end

"""
    select_point(scene; kwargs...) -> point

Interactively select a point on a 2D `scene` by clicking the left mouse button,
dragging and then un-clicking. Return an **observable** whose value corresponds
to the selected point on the scene. In addition the function
_plots_ the point on the scene as the user clicks and moves the mouse
around. When the button is not clicked any more, the plotted point disappears.

The value of the returned point is updated **only** when the user un-clicks.

The `kwargs...` are propagated into `scatter!` which plots the selected point.
"""
function select_point(scene; blocking = false, priority=2, kwargs...)
    key = Mouse.left
    pmarker = Circle(Point2f(0, 0), Float32(1))
    waspressed = Node(false)
    point = Node([Point2f(0,0)])
    point_ret = Node(Point2f(0,0))
    # Create an initially hidden  arrow
    plotted_point = scatter!(
        scene, point; visible = false, marker = pmarker, markersize = 20px,
        color = RGBAf(0.1, 0.1, 0.8, 0.5), kwargs...,
    )

    on(events(scene).mousebutton, priority=priority) do event
        if event.button == key && is_mouseinside(scene)
            mp = mouseposition(scene)
            if event.action == Mouse.press
                waspressed[] = true
                plotted_point[:visible] = true  # start displaying
                point[][1] = mp
                point[] = point[]
                return Consume(blocking)
            end
        end
        if !(event.button == key && event.action == Mouse.press)
            if waspressed[] # User has selected the rectangle
                waspressed[] = false
                point_ret[] = copy(point[][1])
            end
            plotted_point[:visible] = false
            return Consume(blocking)
        end
        return Consume(false)
    end
    on(events(scene).mouseposition, priority=priority) do event
        if waspressed[]
            mp = mouseposition(scene)
            point[][1] = mp
            point[] = point[] # actually update observable
            return Consume(blocking)
        end
        return Consume(false)
    end

    return point_ret
end
