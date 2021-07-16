### indicator data -> string
########################################

vec2string(p::StaticVector{2}) = @sprintf("(%0.3f, %0.3f)", p[1], p[2])
vec2string(p::StaticVector{3}) = @sprintf("(%0.3f, %0.3f, %0.3f)", p[1], p[2], p[3])

position2string(p::StaticVector{2}) = @sprintf("x: %0.6f\ny: %0.6f", p[1], p[2])
position2string(p::StaticVector{3}) = @sprintf("x: %0.6f\ny: %0.6f\nz: %0.6f", p[1], p[2], p[3])

function bbox2string(bbox::Rect3D)
    p0 = origin(bbox)
    p1 = p0 .+ widths(bbox)
    @sprintf(
        """
        Bounding Box:
         x: (%0.3f, %0.3f)
         y: (%0.3f, %0.3f)
         z: (%0.3f, %0.3f)
        """,
        p0[1], p1[1], p0[2], p1[2], p0[3], p1[3]
    )
end

function bbox2string(bbox::Rect2D)
    p0 = origin(bbox)
    p1 = p0 .+ widths(bbox)
    @sprintf(
        """
        Bounding Box:
         x: (%0.3f, %0.3f)
         y: (%0.3f, %0.3f)
        """,
        p0[1], p1[1], p0[2], p1[2]
    )
end

color2text(c::AbstractFloat) = @sprintf("%0.3f", c)
color2text(c::Symbol) = string(c)
color2text(c) = color2text(to_color(c))
function color2text(c::RGBAf0)
    if c.alpha == 1.0
        @sprintf("RGB(%0.2f, %0.2f, %0.2f)", c.r, c.g, c.b)
    else
        @sprintf("RGBA(%0.2f, %0.2f, %0.2f, %0.2f)", c.r, c.g, c.b, c.alpha)
    end
end

color2text(name, i::Integer, j::Integer, c) = "$name[$i, $j] = $(color2text(c))"
function color2text(name, i, j, c)
    idxs = @sprintf("%0.2f, %0.2f", i, j)
    "$name[$idxs] = $(color2text(c))"
end


### dealing with markersize and rotations
########################################

to_scale(f::AbstractFloat, idx) = Vec3f0(f)
to_scale(v::Vec2f0, idx) = Vec3f0(v[1], v[2], 1)
to_scale(v::Vec3f0, idx) = v
to_scale(v::Vector, idx) = to_scale(v[idx], idx)

to_rotation(x, idx) = x
to_rotation(x::Vector, idx) = x[idx]


### Selecting a point on a nearby line
########################################

function closest_point_on_line(p0::Point2f0, p1::Point2f0, r::Point2f0)
    # This only works in 2D
    AP = P .- A; AB = B .- A
    A .+ AB * dot(AP, AB) / dot(AB, AB)
end

function view_ray(scene)
    inv_projview = inv(camera(scene).projectionview[])
    view_ray(inv_projview, events(scene).mouseposition[], pixelarea(scene)[])
end
function view_ray(inv_view_proj, mpos, area::Rect2D)
    # This figures out the camera view direction from the projectionview matrix (?)
    # and computes a ray from a near and a far point.
    # Based on ComputeCameraRay from ImGuizmo
    mp = 2f0 .* (mpos .- minimum(area)) ./ widths(area) .- 1f0
    v = inv_view_proj * Vec4f0(0, 0, -10, 1)
    reversed = v[3] < v[4]
    near = reversed ? 1f0 - 1e-6 : 0f0
    far = reversed ? 0f0 : 1f0 - 1e-6

    origin = inv_view_proj * Vec4f0(mp[1], mp[2], near, 1f0)
    origin = origin[SOneTo(3)] ./ origin[4]

    p = inv_view_proj * Vec4f0(mp[1], mp[2], far, 1f0)
    p = p[SOneTo(3)] ./ p[4]

    dir = normalize(p - origin)
    return origin, dir
end


# These work in 2D and 3D
function closest_point_on_line(A, B, origin, dir)
    closest_point_on_line(
        to_ndim(Point3f0, A, 0),
        to_ndim(Point3f0, B, 0),
        to_ndim(Point3f0, origin, 0),
        to_ndim(Vec3f0, dir, 0)
    )
end
function closest_point_on_line(A::Point3f0, B::Point3f0, origin::Point3f0, dir::Vec3f0)
    # See:
    # https://en.wikipedia.org/wiki/Line%E2%80%93plane_intersection
    AB_norm = norm(B .- A)
    u_AB = (B .- A) / AB_norm
    u_dir = normalize(dir)
    u_perp = normalize(cross(u_dir, u_AB))
    # e_RD, e_perp defines a plane with normal n
    n = normalize(cross(u_dir, u_perp))
    t = dot(origin .- A, n) / dot(u_AB, n)
    A .+ clamp(t, 0.0, AB_norm) * u_AB
end

function ray_triangle_intersection(A, B, C, origin, dir)
    # See: https://www.iue.tuwien.ac.at/phd/ertl/node114.html
    AO = A .- origin
    BO = B .- origin
    CO = C .- origin
    A1 = 0.5 * dot(cross(BO, CO), dir)
    A2 = 0.5 * dot(cross(CO, AO), dir)
    A3 = 0.5 * dot(cross(AO, BO), dir)

    e = 1e-3
    if (A1 > -e && A2 > -e && A3 > -e) || (A1 < e && A2 < e && A3 < e)
        Point3f0((A1 * A .+ A2 * B .+ A3 * C) / (A1 + A2 + A3))
    else
        Point3f0(NaN)
    end
end


### Surface positions
########################################

surface_x(xs::ClosedInterval, i, j, N) = minimum(xs) + (maximum(xs) - minimum(xs)) * (i-1) / (N-1)
surface_x(xs, i, j, N) = xs[i]
surface_x(xs::AbstractMatrix, i, j, N) = xs[i, j]

surface_y(ys::ClosedInterval, i, j, N) = minimum(ys) + (maximum(ys) - minimum(ys)) * (j-1) / (N-1)
surface_y(ys, i, j, N) = ys[j]
surface_y(ys::AbstractMatrix, i, j, N) = ys[i, j]

function surface_pos(xs, ys, zs, i, j)
    N, M = size(zs)
    Point3f0(surface_x(xs, i, j, N), surface_y(ys, i, j, M), zs[i, j])
end


### Mapping mesh vertex indices to Vector{Polygon} index
########################################

function vertexindex2poly(polys, idx)
    counter = 0
    for i in eachindex(polys)
        step = ncoords(polys[i])
        if idx <= counter + step
            return i
        else
            counter += step
        end
    end
    return length(polys)
end

ncoords(x) = length(coordinates(x))
ncoords(mesh::Mesh) = length(coordinates(mesh))
function ncoords(poly::Polygon)
    N = length(poly.exterior) + 1
    for int in poly.interiors
        N += length(int) + 1
    end
    N
end


### Text bounding box
########################################

function Bbox_from_glyphcollection(text, gc)
    bbox = FRect2D(0, 0, 0, 0)
    bboxes = FRect2D[]
    broadcast_foreach(gc.extents, gc.fonts, gc.scales) do extent, font, scale
        b = FreeTypeAbstraction.height_insensitive_boundingbox(extent, font) * scale
        push!(bboxes, b)
    end
    for (c, o, bb) in zip(text, gc.origins, bboxes)
        c == '\n' && continue
        bbox2 = FRect2D(o[Vec(1,2)] .+ origin(bb), widths(bb))
        if bbox == FRect2D(0, 0, 0, 0)
            bbox = bbox2
        else
            bbox = union(bbox, bbox2)
        end
    end
    bbox
end


## Shifted projection
########################################

function shift_project(scene, plot, pos)
    project(
        camera(scene).projectionview[],
        Vec2f0(widths(pixelarea(scene)[])),
        apply_transform(transform_func_obs(plot)[], pos)
    ) .+ Vec2f0(origin(pixelarea(scene)[]))
end



################################################################################
### Base pixel-space plot for Indicator
################################################################################


@recipe(_Inspector, x) do scene
    # Attributes starting with _ are modified internally
    Attributes(
        # Text
        text_padding = Vec4f0(5, 5, 3, 3), # LRBT
        text_align = (:left, :bottom),
        textcolor = :black,
        textsize = 18,
        font = theme(scene, :font),
        _display_text = " ",
        _text_position = Point2f0(0),

        # Background
        background_color = :white,
        outline_color = :grey,
        outline_linestyle = nothing,
        outline_linewidth = 2,

        # pixel BBox/indicator
        indicator_color = :red,
        indicator_linewidth = 2,
        indicator_linestyle = nothing,
        _bbox2D = FRect2D(Vec2f0(0), Vec2f0(0)),
        _px_bbox_visible = true,

        # general
        tooltip_align = (:center, :top), # default tooltip position relative to cursor
        tooltip_offset = Vec2f0(20), # default offset in alignment direction
        depth = 9e3,
        enabled = true,
        range = 10,

        _root_px_projection = Mat4f0(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1),
        _model = Mat4f0(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1),
        _visible = true,
        _tooltip_align = (:center, :top),
        _bbox3D = FRect3D(Vec3f0(0), Vec3f0(0)),
        _bbox_visible = true,
        _position = Point3f0(0),
        _color = RGBAf0(0,0,0,0)
    )
end

function plot!(plot::_Inspector)
    @extract plot (
        text_padding, text_align, textcolor, textsize, font,
        background_color, outline_color, outline_linestyle, outline_linewidth,
        indicator_linestyle, indicator_linewidth, indicator_color,
        tooltip_offset, depth,
        _display_text, _text_position, _bbox2D, _px_bbox_visible,
        _tooltip_align, _root_px_projection, _visible
    )

    # tooltip text
    _aligned_text_position = Node(Point2f0(0))
    id = Mat4f0(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1)
    text_plot = text!(plot, _display_text,
        position = _aligned_text_position, visible = _visible, align = text_align,
        color = textcolor, font = font, textsize = textsize, show_axis = false,
        inspectable = false,
        # with https://github.com/JuliaPlots/Makie.jl/tree/master/GLMakie/pull/183 this should
        # allow the tooltip to work in any scene.
        space = :data,
        projection = _root_px_projection, view = id, projectionview = _root_px_projection
    )

    # compute text boundingbox and adjust _aligned_text_position
    bbox = map(text_plot.plots[1][1], text_plot.position, text_padding) do gc, pos, pad
        rect = Bbox_from_glyphcollection(_display_text[], gc)
        l, r, b, t = pad
        FRect2D(
            origin(rect) .+ Vec2f0(pos[1] - l, pos[2] - b),
            widths(rect) .+ Vec2f0(l + r, b + t)
        )
    end
    onany(_text_position, _tooltip_align, tooltip_offset, bbox) do pos, align, offset, bbox
        halign, valign = align
        ox, oy = offset
        wx, wy = widths(bbox)
        if halign == :left
            dx = -wx - ox
        elseif halign == :center
            dx = -0.5wx
        elseif halign == :right
            dx = + ox
        end
        if valign == :top
            dy = oy
        elseif valign == :center
            dy = -0.5wy
        elseif valign == :bottom
            dy = -wy - oy
        end
        new_pos = pos .+ Point2f0(dx, dy)
        if new_pos != _aligned_text_position[]
            _aligned_text_position[] = new_pos
        end
    end


    # tooltip background and frame
    background = mesh!(
        plot, bbox, color = background_color, shading = false, #fxaa = false,
        # TODO with fxaa here the text above becomes seethrough on a heatmap
        visible = _visible, show_axis = false, inspectable = false,
        projection = _root_px_projection, view = id, projectionview = _root_px_projection
    )
    outline = wireframe!(
        plot, bbox,
        color = outline_color, visible = _visible, show_axis = false, inspectable = false,
        linestyle = outline_linestyle, linewidth = outline_linewidth,
        projection = _root_px_projection, view = id, projectionview = _root_px_projection
    )

    # pixel-space marker for selected element (not always used)
    px_bbox = wireframe!(
        plot, _bbox2D,
        color = indicator_color, linewidth = indicator_linewidth,
        linestyle = indicator_linestyle, visible = _px_bbox_visible,
        show_axis = false, inspectable = false,
        projection = _root_px_projection, view = id, projectionview = _root_px_projection
    )

    # To make sure inspector plots end up in front
    on(depth) do d
        translate!(background, Vec3f0(0,0,d+1))
        translate!(outline,    Vec3f0(0,0,d+2))
        translate!(text_plot,  Vec3f0(0,0,d+3))
        translate!(px_bbox,    Vec3f0(0,0,d))
    end
    depth[] = depth[]
    nothing
end


################################################################################
### Interactive selection via DataInspector
################################################################################



struct PersistentTooltip
    plots::Vector{AbstractPlot}
end

# TODO destructor?
mutable struct DataInspector
    root::Scene
    temp_plots::Vector{AbstractPlot}
    plot::_Inspector
    selection::AbstractPlot
    obsfuncs::Vector{Any}
    persistent::Vector{PersistentTooltip}
end


function DataInspector(scene::Scene, plot::AbstractPlot)
    x = DataInspector(scene, AbstractPlot[], plot, plot, Any[], PersistentTooltip[])
    # finalizer(cleanup, x) # doesn't get triggered when this is dereferenced
    x
end

function cleanup(inspector::DataInspector)
    off.(inspector.obsfuncs)
    empty!(inspector.obsfuncs)
    delete!(inspector.root, inspector.plot)
    clear_temporary_plots!(inspector, inspector.slection)
    inspector
end

function Base.delete!(::Union{Scene, Figure}, inspector::DataInspector)
    cleanup(inspector)
end

enable!(inspector::DataInspector) = inspector.plot.enabled[] = true
disable!(inspector::DataInspector) = inspector.plot.enabled[] = false

"""
    DataInspector(figure; kwargs...)

Creates a data inspector which will show relevant information in a tooltip
when you hover over a plot. If you wish to exclude a plot you may set
`plot.inspectable[] = false`.

### Keyword Arguments:
- `range = 10`: Controls the snapping range for selecting an element of a plot.
- `enabled = true`: Disables inspection of plots when set to false. Can also be
    adjusted with `enable!(inspector)` and `disable!(inspector)`.
- `text_padding = Vec4f0(5, 5, 3, 3)`: Padding for the box drawn around the
    tooltip text. (left, right, bottom, top)
- `text_align = (:left, :bottom)`: Alignment of text within the tooltip. This
    does not affect the alignment of the tooltip relative to the cursor.
- `textcolor = :black`: Tooltip text color.
- `textsize = 20`: Tooltip text size.
- `font = "Dejavu Sans"`: Tooltip font.
- `background_color = :white`: Background color of the tooltip.
- `outline_color = :grey`: Outline color of the tooltip.
- `outline_linestyle = nothing`: Linestyle of the tooltip outline.
- `outline_linewidth = 2`: Linewidth of the tooltip outline.
- `indicator_color = :red`: Color of the selection indicator.
- `indicator_linewidth = 2`: Linewidth of the selection indicator.
- `indicator_linestyle = nothing`: Linestyle of the selection indicator
- `tooltip_align = (:center, :top)`: Default position of the tooltip relative to
    the cursor or current selection. The real align may adjust to keep the
    tooltip in view.
- `tooltip_offset = Vec2f0(20)`: Offset from the indicator to the tooltip.
- `depth = 9e3`: Depth value of the tooltip. This should be high so that the
    tooltip is always in front.
- `priority = 100`: The priority of creating a tooltip on a mouse movement or
    scrolling event.
"""
function DataInspector(fig_or_layoutable; kwargs...)
    DataInspector(fig_or_layoutable.scene; kwargs...)
end

function DataInspector(scene::Scene; priority = 100, kwargs...)
    parent = root(scene)
    @assert origin(pixelarea(parent)[]) == Vec2f0(0)

    plot = _inspector!(
        parent, 1,
        show_axis=false, _root_px_projection = camera(parent).pixel_space;
        kwargs...
    )
    inspector = DataInspector(parent, plot)

    e = events(parent)
    of1 = on(_ -> on_hover(inspector), e.mouseposition, priority = priority)
    of2 = on(_ -> on_hover(inspector), e.scroll, priority = priority)
    of3 = on(event -> on_click(inspector, event), e.mousebutton, priority=priority)
    of4 = on(event -> on_key(inspector, event), e.keyboardbutton, priority=priority)

    push!(inspector.obsfuncs, of1, of2, of3, of4)

    inspector
end

function on_click(inspector, event)
    root = inspector.root
    if event.button == Mouse.left && event.action == Mouse.press && (
            ispressed(root, Keyboard.left_alt) || ispressed(root, Keyboard.right_alt)
        )

        # This copies all the data from the existing tooltip into new fully
        # detached plots. For some attributes/inputs it makes sense to 
        # create a disconnected copy because they're adjusted on mousemovement,
        # but some others should probably get copied directly...
        detached_copy = map(inspector.plot.attributes) do (key, node)
            key => node[]
        end |> Attributes

        base = _inspector!(root, 1; detached_copy...)
        all_plots = [base]
        for p in inspector.temp_plots
            p.visible[] || continue
            
            scene = parent_scene(p)
            plot_type = typeof(p)
            detached_attr = map(p.attributes) do (key, node)
                key => node[]
            end |> Attributes
            input_args = map(x -> Node(x[]), p.input_args)
            converted = Node(p.converted[])

            new_p = plot!(scene, plot_type, static_attr, detached_args, converted)
            push!(all_plots, new_p)
        end

        push!(inspector.persistent, PersistentTooltip(all_plots))
        
        # Blocking to avoid triggering axis interaction?
        return true
    end

    return false
end

function on_key(inspector, event)
    if event.key == Keyboard.escape && event.action == Keyboard.press
        for tooltip in inspector.persistent
            for p in tooltip.plots
                delete!(parent_scene(p), p)
            end
        end
        empty!(inspector.persistent)
    end

    return false
end


function on_hover(inspector)
    parent = inspector.root
    (inspector.plot.enabled[] && is_mouseinside(parent)) || return Consume(false)

    mp = mouseposition_px(parent)
    should_clear = true
    for (plt, idx) in pick_sorted(parent, mp, inspector.plot.range[])
        if to_value(get(plt.attributes, :inspectable, true)) &&
            # show_data should return true if it created a tooltip
            if show_data_recursion(inspector, plt, idx)
                should_clear = false
                break
            end
        end
    end

    if should_clear
        inspector.plot._visible[] = false
        inspector.plot._bbox_visible[] = false
        inspector.plot._px_bbox_visible[] = false
    end

    return Consume(false)
end


function show_data_recursion(inspector, plot, idx)
    processed = show_data_recursion(inspector, plot.parent, idx, plot)
    if processed
        return true
    else
        return show_data(inspector, plot, idx)
    end
end
show_data_recursion(inspector, plot, idx, source) = false
function show_data_recursion(inspector, plot::AbstractPlot, idx, source)
    processed = show_data_recursion(inspector, plot.parent, idx, source)
    if processed
        return true
    else
        return show_data(inspector, plot, idx, source)
    end
end

# clears temporary plots (i.e. bboxes) and update selection
function clear_temporary_plots!(inspector::DataInspector, plot)
    inspector.selection = plot
    for i in length(inspector.obsfuncs):-1:5
        off(pop!(inspector.obsfuncs))
    end
    for p in inspector.temp_plots
        delete!(parent_scene(p), p)
    end
    empty!(inspector.temp_plots)
end

# update alignment direction
function update_tooltip_alignment!(inspector, proj_pos)
    a = inspector.plot.attributes
    a._text_position[] = proj_pos

    wx, wy = widths(pixelarea(inspector.root)[])
    px, py = proj_pos
    halign, valign = a.tooltip_align[]
    px < wx/4  && (halign = :right)
    px > 3wx/4 && (halign = :left)
    py < wy/4  && (valign = :top)
    py > 3wy/4 && (valign = :bottom)
    a._tooltip_align[] = (halign, valign)
end



################################################################################
### show_data for primitive plots
################################################################################



# TODO: better 3D scaling
function show_data(inspector::DataInspector, plot::Scatter, idx)
    a = inspector.plot.attributes
    scene = parent_scene(plot)

    proj_pos = shift_project(scene, plot, to_ndim(Point3f0, plot[1][][idx], 0))
    update_tooltip_alignment!(inspector, proj_pos)
    ms = plot.markersize[]

    a._display_text[] = position2string(plot[1][][idx])
    a._bbox2D[] = FRect2D(proj_pos .- 0.5 .* ms .- Vec2f0(5), Vec2f0(ms) .+ Vec2f0(10))
    a._px_bbox_visible[] = true
    a._bbox_visible[] = false
    a._visible[] = true

    return true
end


function show_data(inspector::DataInspector, plot::MeshScatter, idx)
    a = inspector.plot.attributes
    scene = parent_scene(plot)

    proj_pos = shift_project(scene, plot, to_ndim(Point3f0, plot[1][][idx], 0))
    update_tooltip_alignment!(inspector, proj_pos)
    bbox = Rect{3, Float32}(plot.marker[])

    a._model[] = transformationmatrix(
        plot[1][][idx],
        to_scale(plot.markersize[], idx),
        to_rotation(plot.rotations[], idx)
    )

    if inspector.selection != plot
        eyeposition = cameracontrols(scene).eyeposition[]
        lookat = cameracontrols(scene).lookat[]
        upvector = cameracontrols(scene).upvector[]

        # To avoid putting a bbox outside the plots bbox
        a._bbox3D[] = boundingbox(plot)

        clear_temporary_plots!(inspector, plot)
        p = wireframe!(
            scene, a._bbox3D, model = a._model, color = a.indicator_color,
            linewidth = a.indicator_linewidth, linestyle = a.indicator_linestyle,
            visible = a._bbox_visible, show_axis = false, inspectable = false
        )
        push!(inspector.temp_plots, p)

        # Restore camera
        update_cam!(scene, eyeposition, lookat, upvector)
    end

    a._display_text[] = position2string(plot[1][][idx])
    a._bbox3D[] = bbox
    a._px_bbox_visible[] = false
    a._bbox_visible[] = true
    a._visible[] = true

    return true
end


function show_data(inspector::DataInspector, plot::Union{Lines, LineSegments}, idx)
    a = inspector.plot.attributes
    scene = parent_scene(plot)

    # cast ray from cursor into screen, find closest point to line
    p0, p1 = plot[1][][idx-1:idx]
    origin, dir = view_ray(scene)
    pos = closest_point_on_line(p0, p1, origin, dir)
    lw = plot.linewidth[] isa Vector ? plot.linewidth[][idx] : plot.linewidth[]

    proj_pos = shift_project(scene, plot, to_ndim(Point3f0, pos, 0))
    update_tooltip_alignment!(inspector, proj_pos)

    a._display_text[] = position2string(typeof(p0)(pos))
    a._bbox2D[] = FRect2D(proj_pos .- 0.5 .* lw .- Vec2f0(5), Vec2f0(lw) .+ Vec2f0(10))
    a._px_bbox_visible[] = true
    a._bbox_visible[] = false
    a._visible[] = true

    return true
end


function show_data(inspector::DataInspector, plot::Mesh, idx)
    a = inspector.plot.attributes
    scene = parent_scene(plot)

    bbox = boundingbox(plot)
    proj_pos = Point2f0(mouseposition_px(inspector.root))
    update_tooltip_alignment!(inspector, proj_pos)

    a._bbox3D[] = bbox

    if inspector.selection != plot
        eyeposition = cameracontrols(scene).eyeposition[]
        lookat = cameracontrols(scene).lookat[]
        upvector = cameracontrols(scene).upvector[]

        clear_temporary_plots!(inspector, plot)
        p = wireframe!(
            scene, a._bbox3D, color = a.indicator_color,
            linewidth = a.indicator_linewidth, linestyle = a.indicator_linestyle,
            visible = a._bbox_visible, show_axis = false, inspectable = false
        )
        push!(inspector.temp_plots, p)

        # Restore camera
        update_cam!(scene, eyeposition, lookat, upvector)
    end

    a._text_position[] = proj_pos
    a._display_text[] = bbox2string(bbox)
    a._px_bbox_visible[] = false
    a._bbox_visible[] = true
    a._visible[] = true

    return true
end


function show_data(inspector::DataInspector, plot::Surface, idx)
    a = inspector.plot.attributes
    scene = parent_scene(plot)

    proj_pos = Point2f0(mouseposition_px(inspector.root))
    update_tooltip_alignment!(inspector, proj_pos)

    xs = plot[1][]
    ys = plot[2][]
    zs = plot[3][]
    w, h = size(zs)
    _i = mod1(idx, w); _j = div(idx-1, w)

    # This isn't the most accurate so we include some neighboring faces
    origin, dir = view_ray(scene)
    pos = Point3f0(NaN)
    for i in _i-1:_i+1, j in _j-1:_j+1
        (1 <= i <= w) && (1 <= j < h) || continue

        if i - 1 > 0
            pos = ray_triangle_intersection(
                surface_pos(xs, ys, zs, i, j),
                surface_pos(xs, ys, zs, i-1, j),
                surface_pos(xs, ys, zs, i, j+1),
                origin, dir
            )
        end

        if i + 1 <= w && isnan(pos)
            pos = ray_triangle_intersection(
                surface_pos(xs, ys, zs, i, j),
                surface_pos(xs, ys, zs, i, j+1),
                surface_pos(xs, ys, zs, i+1, j+1),
                origin, dir
            )
        end

        isnan(pos) || break
    end

    if !isnan(pos)
        a._display_text[] = position2string(pos)
        a._text_position[] = proj_pos
        a._bbox2D[] = FRect2D(proj_pos .- Vec2f0(5), Vec2f0(10))
        a._bbox_visible[] = false
        a._px_bbox_visible[] = true
        a._visible[] = true
    else
        a._bbox_visible[] = false
        a._px_bbox_visible[] = false
        a._visible[] = false
    end

    return true
end

function show_data(inspector::DataInspector, plot::Heatmap, idx)
    show_imagelike(inspector, plot, "H", true)
end

function show_data(inspector::DataInspector, plot::Image, idx)
    show_imagelike(inspector, plot, "img", false)
end

function show_imagelike(inspector, plot, name, edge_based)
    a = inspector.plot.attributes
    scene = parent_scene(plot)
    mpos = mouseposition(scene)

    i, j, z = if plot.interpolate[]
        _interpolated_getindex(plot[1][], plot[2][], plot[3][], mpos)
    else
        _pixelated_getindex(plot[1][], plot[2][], plot[3][], mpos, edge_based)
    end

    a._color[] = if z isa AbstractFloat
        interpolated_getindex(
            to_colormap(plot.colormap[]), z,
            to_value(get(plot.attributes, :colorrange, (0, 1)))
        )
    else
        z
    end

    a._position[] = to_ndim(Point3f0, mpos, 0)
    proj_pos = Point2f0(mouseposition_px(inspector.root))
    update_tooltip_alignment!(inspector, proj_pos)

    if plot.interpolate[]
        if inspector.selection != plot || !(inspector.temp_plots[1] isa Scatter)
            clear_temporary_plots!(inspector, plot)
            p = scatter!(
                scene, map(p -> [p], a._position), color = a._color,
                visible = a._bbox_visible,
                show_axis = false, inspectable = false,
                marker=:rect, markersize = map(r -> 2r - 4, a.range),
                strokecolor = a.indicator_color,
                strokewidth = a.indicator_linewidth #, linestyle = a.indicator_linestyle no?
            )
            translate!(p, Vec3f0(0, 0, a.depth[]))
            push!(inspector.temp_plots, p)
            # Hacky?
            push!(
                inspector.obsfuncs,
                Observables.ObserverFunction(a._position.listeners[end], a._position, false)
            )
        end
        a._display_text[] = color2text(name, mpos[1], mpos[2], z)
    else
        a._bbox2D[] = _pixelated_image_bbox(plot[1][], plot[2][], plot[3][], i, j, edge_based)
        if inspector.selection != plot || !(inspector.temp_plots[1][1][] isa Rect2D)
            clear_temporary_plots!(inspector, plot)
            p = wireframe!(
                scene, a._bbox2D, model = a._model, color = a.indicator_color,
                strokewidth = a.indicator_linewidth, linestyle = a.indicator_linestyle,
                visible = a._bbox_visible, show_axis = false, inspectable = false
            )
            translate!(p, Vec3f0(0, 0, a.depth[]))
            push!(inspector.temp_plots, p)
        end
        a._display_text[] = color2text(name, i, j, z)
    end

    a._bbox_visible[] = true
    a._px_bbox_visible[] = false
    a._visible[] = true
    return true
end


function _interpolated_getindex(xs, ys, img, mpos)
    x0, x1 = extrema(xs)
    y0, y1 = extrema(ys)
    x, y = clamp.(mpos, (x0, y0), (x1, y1))

    i = clamp((x - x0) / (x1 - x0) * size(img, 1) + 0.5, 1, size(img, 1))
    j = clamp((y - y0) / (y1 - y0) * size(img, 2) + 0.5, 1, size(img, 2))
    l = clamp(floor(Int, i), 1, size(img, 1)-1);
    r = clamp(l+1, 2, size(img, 1))
    b = clamp(floor(Int, j), 1, size(img, 2)-1);
    t = clamp(b+1, 2, size(img, 2))
    z = ((r-i) * img[l, b] + (i-l) * img[r, b]) * (t-j) +
        ((r-i) * img[l, t] + (i-l) * img[r, t]) * (j-b)

    # float, float, value (i, j are no longer used)
    return i, j, z
end
function _pixelated_getindex(xs, ys, img, mpos, edge_based)
    x0, x1 = extrema(xs)
    y0, y1 = extrema(ys)
    x, y = clamp.(mpos, (x0, y0), (x1, y1))

    i = clamp(round(Int, (x - x0) / (x1 - x0) * size(img, 1) + 0.5), 1, size(img, 1))
    j = clamp(round(Int, (y - y0) / (y1 - y0) * size(img, 2) + 0.5), 1, size(img, 2))

    # int, int, value
    return i, j, img[i,j]
end

function _interpolated_getindex(xs::Vector, ys::Vector, img, mpos)
    # x, y = mpos
    # i, j, _ = _pixelated_getindex(xs, ys, img, mpos, false)
    # w = (xs[i+1] - xs[i]); h = (ys[j+1] - ys[j])
    # z = ((xs[i+1] - x) / w * img[i, j]   + (x - xs[i]) / w * img[i+1, j])   * (ys[j+1] - y) / h +
    #     ((xs[i+1] - x) / w * img[i, j+1] + (x - xs[i]) / w * img[i+1, j+1]) * (y - ys[j]) / h
    # return i, j, z
    _interpolated_getindex(minimum(xs)..maximum(xs), minimum(ys)..maximum(ys), img, mpos)
end
function _pixelated_getindex(xs::Vector, ys::Vector, img, mpos, edge_based)
    if edge_based
        x, y = mpos
        i = max(1, something(findfirst(v -> v >= x, xs), length(xs))-1)
        j = max(1, something(findfirst(v -> v >= y, ys), length(ys))-1)
        return i, j, img[i, j]
    else
        _pixelated_getindex(minimum(xs)..maximum(xs), minimum(ys)..maximum(ys), img, mpos, edge_based)
    end
end

function _pixelated_image_bbox(xs, ys, img, i::Integer, j::Integer, edge_based)
    x0, x1 = extrema(xs)
    y0, y1 = extrema(ys)
    nw, nh = ((x1 - x0), (y1 - y0)) ./ size(img)
    FRect2D(x0 + nw * (i-1), y0 + nh * (j-1), nw, nh)
end
function _pixelated_image_bbox(xs::Vector, ys::Vector, img, i::Integer, j::Integer, edge_based)
    if edge_based
        FRect2D(xs[i], ys[j], xs[i+1] - xs[i], ys[j+1] - ys[j])
    else
        _pixelated_image_bbox(
            minimum(xs)..maximum(xs), minimum(ys)..maximum(ys),
            img, i, j, edge_based
        )
    end
end

function show_data(inspector::DataInspector, plot, idx, source=nothing)
    return false
end


################################################################################
### show_data for Combined/recipe plots
################################################################################



function show_data(inspector::DataInspector, plot::BarPlot, idx, ::Lines)
    return show_data(inspector, plot, div(idx-1, 6)+1)
end

function show_data(inspector::DataInspector, plot::BarPlot, idx, ::Mesh)
    return show_data(inspector, plot, div(idx-1, 4)+1)
end



function show_data(inspector::DataInspector, plot::BarPlot, idx)
    a = inspector.plot.attributes
    scene = parent_scene(plot)

    pos = plot[1][][idx]
    proj_pos = shift_project(scene, plot, to_ndim(Point3f0, pos, 0))
    update_tooltip_alignment!(inspector, proj_pos)
    a._model[] = plot.model[]
    a._bbox2D[] = plot.plots[1][1][][idx]

    if inspector.selection != plot
        clear_temporary_plots!(inspector, plot)
        p = wireframe!(
            scene, a._bbox2D, model = a._model, color = a.indicator_color,
            strokewidth = a.indicator_linewidth, linestyle = a.indicator_linestyle,
            visible = a._bbox_visible, show_axis = false, inspectable = false
        )
        translate!(p, Vec3f0(0, 0, a.depth[]))
        push!(inspector.temp_plots, p)
    end

    a._display_text[] = position2string(pos)
    a._bbox_visible[] = true
    a._px_bbox_visible[] = false
    a._visible[] = true

    return true
end

function show_data(inspector::DataInspector, plot::Arrows, idx, ::LineSegments)
    return show_data(inspector, plot, div(idx+1, 2), nothing)
end
function show_data(inspector::DataInspector, plot::Arrows, idx, source)
    a = inspector.plot.attributes
    scene = parent_scene(plot)

    pos = plot[1][][idx]
    proj_pos = shift_project(scene, plot, to_ndim(Point3f0, pos, 0))

    mpos = Point2f0(mouseposition_px(inspector.root))
    update_tooltip_alignment!(inspector, mpos)

    p = vec2string(pos)
    v = vec2string(plot[2][][idx])

    a._text_position[] = mpos
    a._display_text[] = "Position:\n  $p\nDirection\n  $v"
    a._bbox2D[] = FRect2D(proj_pos .- Vec2f0(5), Vec2f0(10))
    a._bbox_visible[] = false
    a._px_bbox_visible[] = true
    a._visible[] = true

    return true
end

# This should work if contourf would place computed levels in colors and let the
# backend handle picking colors from a colormap
function show_data(inspector::DataInspector, plot::Contourf, idx, source::Mesh)
    a = inspector.plot.attributes
    scene = parent_scene(plot)
    idx, ext = show_poly(inspector, plot.plots[1], idx, source)
    level = plot.plots[1].color[][idx]

    a._text_position[] = Point2f0(mouseposition_px(inspector.root))
    a._display_text[] = @sprintf("level = %0.3f", level)
    return true
end

# What should this display?
# function show_data(
#         inspector::DataInspector, plot::Poly{<: Tuple{<: AbstractVector}},
#         idx, source::Mesh
#     )
#     @info "PolyMesh"
#     idx, ext = show_poly(inspectable, plot, idx, source)
#     return true
# end

function show_poly(inspector, plot, idx, source)
    a = inspector.plot.attributes
    scene = parent_scene(plot)

    idx = vertexindex2poly(plot[1][], idx)
    m = GeometryBasics.mesh(plot[1][][idx])

    clear_temporary_plots!(inspector, plot)
    ext = plot[1][][idx].exterior
    p = lines!(
        scene, ext, color = a.indicator_color,
        strokewidth = a.indicator_linewidth, linestyle = a.indicator_linestyle,
        visible = a._visible, show_axis = false, inspectable = false
    )
    translate!(p, Vec3f0(0,0,a.depth[]))
    push!(inspector.temp_plots, p)

    for int in plot[1][][idx].interiors
        p = lines!(
            scene, int, color = a.indicator_color,
            strokewidth = a.indicator_linewidth, linestyle = a.indicator_linestyle,
            visible = a._visible, show_axis = false, inspectable = false
        )
        translate!(p, Vec3f0(0,0,a.depth[]))
        push!(inspector.temp_plots, p)
    end

    a._px_bbox_visible[] = false
    a._bbox_visible[] = true
    a._visible[] = true

    return idx, ext
end
