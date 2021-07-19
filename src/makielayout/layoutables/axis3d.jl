"""
    layoutable(Axis3, fig_or_scene; bbox = nothing, kwargs...)

Creates an `Axis3` object in the parent `fig_or_scene` which consists of a child scene
with orthographic projection for 2D plots and axis decorations that live in the
parent.
"""
function layoutable(::Type{<:Axis3}, fig_or_scene::Union{Figure, Scene}; bbox = nothing, kwargs...)

    topscene = get_topscene(fig_or_scene)

    default_attrs = default_attributes(Axis3, topscene).attributes
    theme_attrs = subtheme(topscene, :Axis3)
    attrs = merge!(merge!(Attributes(kwargs), theme_attrs), default_attrs)

    @extract attrs (elevation, azimuth, perspectiveness, aspect, viewmode,
        xlabel, ylabel, zlabel,
    )

    decorations = Dict{Symbol, Any}()


    protrusions = lift(to_protrusions, attrs.protrusions)
    layoutobservables = LayoutObservables{Axis3}(attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight, attrs.halign, attrs.valign, attrs.alignmode;
        suggestedbbox = bbox, protrusions = protrusions)

    notify(protrusions)

    finallimits = Node(Rect3f(Vec3f(0f0, 0f0, 0f0), Vec3f(100f0, 100f0, 100f0)))

    scenearea = lift(round_to_IRect2D, layoutobservables.computedbbox)

    scene = Scene(topscene, scenearea, raw = true, clear = false, backgroundcolor = attrs.backgroundcolor)

    matrices = lift(calculate_matrices, finallimits, scene.px_area, elevation, azimuth, perspectiveness, aspect, viewmode)

    on(matrices) do (view, proj, eyepos)
        pv = proj * view
        scene.camera.projection[] = proj
        scene.camera.view[] = view
        scene.camera.eyeposition[] = eyepos
        scene.camera.projectionview[] = pv
    end

    ticknode_1 = lift(finallimits, attrs.xticks, attrs.xtickformat) do lims, ticks, format
        tl = get_ticks(ticks, identity, format, minimum(lims)[1], maximum(lims)[1])
    end

    ticknode_2 = lift(finallimits, attrs.yticks, attrs.ytickformat) do lims, ticks, format
        tl = get_ticks(ticks, identity, format, minimum(lims)[2], maximum(lims)[2])
    end

    ticknode_3 = lift(finallimits, attrs.zticks, attrs.ztickformat) do lims, ticks, format
        tl = get_ticks(ticks, identity, format, minimum(lims)[3], maximum(lims)[3])
    end

    mi1 = @lift(!(pi/2 <= $azimuth % 2pi < 3pi/2))
    mi2 = @lift(0 <= $azimuth % 2pi < pi)
    mi3 = @lift($elevation > 0)

    add_panel!(scene, 1, 2, 3, finallimits, mi3, attrs)
    add_panel!(scene, 2, 3, 1, finallimits, mi1, attrs)
    add_panel!(scene, 1, 3, 2, finallimits, mi2, attrs)

    add_gridlines_and_frames!(topscene, scene, 1, finallimits, ticknode_1, mi1, mi2, mi3, attrs)
    add_gridlines_and_frames!(topscene, scene, 2, finallimits, ticknode_2, mi2, mi1, mi3, attrs)
    add_gridlines_and_frames!(topscene, scene, 3, finallimits, ticknode_3, mi3, mi1, mi2, attrs)

    add_ticks_and_ticklabels!(topscene, scene, 1, finallimits, ticknode_1, mi1, mi2, mi3, attrs, azimuth)
    add_ticks_and_ticklabels!(topscene, scene, 2, finallimits, ticknode_2, mi2, mi1, mi3, attrs, azimuth)
    add_ticks_and_ticklabels!(topscene, scene, 3, finallimits, ticknode_3, mi3, mi1, mi2, attrs, azimuth)

    titlepos = lift(scene.px_area, attrs.titlegap, attrs.titlealign) do a, titlegap, align

        x = if align == :center
            a.origin[1] + a.widths[1] / 2
        elseif align == :left
            a.origin[1]
        elseif align == :right
            a.origin[1] + a.widths[1]
        else
            error("Title align $align not supported.")
        end

        yoffset = top(a) + titlegap

        Point2(x, yoffset)
    end

    titlealignnode = lift(attrs.titlealign) do align
        (align, :bottom)
    end

    titlet = text!(
        topscene, attrs.title,
        position = titlepos,
        visible = attrs.titlevisible,
        textsize = attrs.titlesize,
        align = titlealignnode,
        font = attrs.titlefont,
        color = attrs.titlecolor,
        space = :data,
        show_axis=false,
        inspectable = false)
    decorations[:title] = titlet


    mouseeventhandle = addmouseevents!(scene)
    scrollevents = Node(ScrollEvent(0, 0))
    keysevents = Node(KeysEvent(Set()))

    on(scene.events.scroll) do s
        if is_mouseinside(scene)
            scrollevents[] = ScrollEvent(s[1], s[2])
            return Consume(true)
        end
        return Consume(false)
    end

    on(scene.events.keyboardbutton) do e
        keysevents[] = KeysEvent(scene.events.keyboardstate)
        return Consume(false)
    end

    interactions = Dict{Symbol, Tuple{Bool, Any}}()


    ax = Axis3(fig_or_scene, layoutobservables, attrs, decorations, scene, finallimits,
        mouseeventhandle, scrollevents, keysevents, interactions, Cycler())

    on(attrs.limits) do lims
        reset_limits!(ax)
    end

    on(attrs.targetlimits) do lims
        # adjustlimits!(ax)
        # we have no aspect constraints here currently, so just update final limits
        ax.finallimits[] = lims
    end

    function process_event(event)
        for (active, interaction) in values(ax.interactions)
            if active
                maybe_consume = process_interaction(interaction, event, ax)
                maybe_consume == Consume(true) && return Consume(true)
            end
        end
        return Consume(false)
    end

    on(process_event, mouseeventhandle.obs)
    on(process_event, scrollevents)
    on(process_event, keysevents)

    register_interaction!(ax,
        :dragrotate,
        DragRotate())


    # in case the user set limits already
    notify(attrs.limits)

    ax
end

can_be_current_axis(ax3::Axis3) = true

function calculate_matrices(limits, px_area, elev, azim, perspectiveness, aspect,
    viewmode)
    ws = widths(limits)


    t = Makie.translationmatrix(-Float64.(limits.origin))
    s = if aspect == :equal
        scales = 2 ./ Float64.(ws)
    elseif aspect == :data
        scales = 2 ./ max.(maximum(ws), Float64.(ws))
    elseif aspect isa VecTypes{3}
        scales = 2 ./ Float64.(ws) .* Float64.(aspect) ./ maximum(aspect)
    else
        error("Invalid aspect $aspect")
    end |> Makie.scalematrix

    t2 = Makie.translationmatrix(-0.5 .* ws .* scales)
    scale_matrix = t2 * s * t

    ang_max = 90
    ang_min = 0.5

    @assert 0 <= perspectiveness <= 1

    angle = ang_min + (ang_max - ang_min) * perspectiveness

    # vFOV = 2 * Math.asin(sphereRadius / distance);
    # distance = sphere_radius / Math.sin(vFov / 2)

    # radius = sqrt(3) / tand(angle / 2)
    radius = sqrt(3) / sind(angle / 2)

    x = radius * cos(elev) * cos(azim)
    y = radius * cos(elev) * sin(azim)
    z = radius * sin(elev)

    eyepos = Vec3{Float64}(x, y, z)

    lookat_matrix = Makie.lookat(
        eyepos,
        Vec3{Float64}(0, 0, 0),
        Vec3{Float64}(0, 0, 1))

    w = width(px_area)
    h = height(px_area)

    view_matrix = lookat_matrix * scale_matrix

    projection_matrix = projectionmatrix(view_matrix, limits, eyepos, radius, azim, elev, angle, w, h, scales, viewmode)

    # for eyeposition dependent algorithms, we need to present the position as if
    # there was no scaling applied
    eyeposition = Vec3f(inv(scale_matrix) * Vec4f(eyepos..., 1))

    view_matrix, projection_matrix, eyeposition
end

function projectionmatrix(viewmatrix, limits, eyepos, radius, azim, elev, angle, width, height, scales, viewmode)
    near = radius - sqrt(3)
    far = radius + 2 * sqrt(3)

    aspect_ratio = width / height

    projection_matrix = if viewmode in (:fit, :fitzoom, :stretch)
        if height > width
            angle = angle / aspect_ratio
        end

        pm = Makie.perspectiveprojection(Float64, angle, aspect_ratio, near, far)

        if viewmode in (:fitzoom, :stretch)
            points = decompose(Point3f, limits)
            # @show points
            projpoints = Ref(pm * viewmatrix) .* to_ndim.(Point4f, points, 1)

            maxx = maximum(x -> abs(x[1] / x[4]), projpoints)
            maxy = maximum(x -> abs(x[2] / x[4]), projpoints)

            ratio_x = maxx
            ratio_y = maxy

            if viewmode == :fitzoom
                if ratio_y > ratio_x
                    pm = Makie.scalematrix(Vec3(1/ratio_y, 1/ratio_y, 1)) * pm
                else
                    pm = Makie.scalematrix(Vec3(1/ratio_x, 1/ratio_x, 1)) * pm
                end
            else
                pm = Makie.scalematrix(Vec3(1/ratio_x, 1/ratio_y, 1)) * pm
            end
        end
        pm
    else
        error("Invalid viewmode $viewmode")
    end
end


function Makie.plot!(
    ax::Axis3, P::Makie.PlotFunc,
    attributes::Makie.Attributes, args...;
    kw_attributes...)

    allattrs = merge(attributes, Attributes(kw_attributes))

    cycle = get_cycle_for_plottype(allattrs, P)
    add_cycle_attributes!(allattrs, P, cycle, ax.cycler, ax.palette)

    plot = Makie.plot!(ax.scene, P, allattrs, args...)

    reset_limits!(ax)
    plot
end

function Makie.plot!(P::Makie.PlotFunc, ax::Axis3, args...; kw_attributes...)
    attributes = Makie.Attributes(kw_attributes)
    Makie.plot!(ax, P, attributes, args...)
end

function autolimits!(ax::Axis3)
    xlims = getlimits(ax, 1)
    ylims = getlimits(ax, 2)
    zlims = getlimits(ax, 3)

    ori = Vec3f(xlims[1], ylims[1], zlims[1])
    widths = Vec3f(xlims[2] - xlims[1], ylims[2] - ylims[1], zlims[2] - zlims[1])

    enlarge_factor = 0.1

    nori = ori .- (0.5 * enlarge_factor) * widths
    nwidths = widths .* (1 + enlarge_factor)

    lims = Rect3f(nori, nwidths)

    ax.finallimits[] = lims
    nothing
end

to_protrusions(x::Number) = GridLayoutBase.RectSides{Float32}(x, x, x, x)
to_protrusions(x::Tuple{Any, Any, Any, Any}) = GridLayoutBase.RectSides{Float32}(x...)

function getlimits(ax::Axis3, dim)

    plots_with_autolimits = if dim == 1
        filter(p -> !haskey(p.attributes, :xautolimits) || p.attributes.xautolimits[], ax.scene.plots)
    elseif dim == 2
        filter(p -> !haskey(p.attributes, :yautolimits) || p.attributes.yautolimits[], ax.scene.plots)
    elseif dim == 3
        filter(p -> !haskey(p.attributes, :zautolimits) || p.attributes.zautolimits[], ax.scene.plots)
    else
        error("Dimension $dim not allowed. Only 1, 2 or 3.")
    end

    visible_plots = filter(
        p -> !haskey(p.attributes, :visible) || p.attributes.visible[],
        plots_with_autolimits)

    bboxes = Makie.data_limits.(visible_plots)
    finite_bboxes = filter(Makie.isfinite_rect, bboxes)

    isempty(finite_bboxes) && return nothing

    templim = (finite_bboxes[1].origin[dim], finite_bboxes[1].origin[dim] + finite_bboxes[1].widths[dim])

    for bb in finite_bboxes[2:end]
        templim = limitunion(templim, (bb.origin[dim], bb.origin[dim] + bb.widths[dim]))
    end

    templim
end

# mutable struct LineAxis3D

# end

function dimpoint(dim, v, v1, v2)
    if dim == 1
        Point(v, v1, v2)
    elseif dim == 2
        Point(v1, v, v2)
    elseif dim == 3
        Point(v1, v2, v)
    end
end

function dim1(dim)
    if dim == 1
        2
    elseif dim == 2
        1
    elseif dim == 3
        1
    end
end

function dim2(dim)
    if dim == 1
        3
    elseif dim == 2
        3
    elseif dim == 3
        2
    end
end

function add_gridlines_and_frames!(topscene, scene, dim::Int, limits, ticknode, miv, min1, min2, attrs)

    dimsym(sym) = Symbol(string((:x, :y, :z)[dim]) * string(sym))
    attr(sym) = attrs[dimsym(sym)]

    dpoint = (v, v1, v2) -> dimpoint(dim, v, v1, v2)
    d1 = dim1(dim)
    d2 = dim2(dim)

    tickvalues = @lift($ticknode[1])

    endpoints = lift(limits, tickvalues, min1, min2) do lims, ticks, min1, min2
        f1 = min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]
        # from tickvalues and f1 and min2:max2
        mi = minimum(lims)
        ma = maximum(lims)
        map(filter(x -> !any(y -> x ≈ y[dim], extrema(lims)), ticks)) do t
            dpoint(t, f1, mi[d2]), dpoint(t, f1, ma[d2])
        end
    end
    linesegments!(scene, endpoints, color = attr(:gridcolor),
        linewidth = attr(:gridwidth),
        xautolimits = false, yautolimits = false, zautolimits = false, transparency = true,
        visible = attr(:gridvisible), inspectable = false)

    endpoints2 = lift(limits, tickvalues, min1, min2) do lims, ticks, min1, min2
        f1 = min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]
        # from tickvalues and f1 and min2:max2
        mi = minimum(lims)
        ma = maximum(lims)
        map(filter(x -> !any(y -> x ≈ y[dim], extrema(lims)), ticks)) do t
            dpoint(t, mi[d1], f2), dpoint(t, ma[d1], f2)
        end
    end
    linesegments!(scene, endpoints2, color = attr(:gridcolor),
        linewidth = attr(:gridwidth),
        xautolimits = false, yautolimits = false, zautolimits = false, transparency = true,
        visible = attr(:gridvisible), inspectable = false)


    framepoints = lift(limits, min1, min2,
            scene.camera.projectionview, scene.px_area) do lims, mi1, mi2, pview, pxa

        o = pxa.origin

        f(mi) = mi ? minimum : maximum
        p1 = dpoint(minimum(lims)[dim], f(!mi1)(lims)[d1], f(mi2)(lims)[d2])
        p2 = dpoint(maximum(lims)[dim], f(!mi1)(lims)[d1], f(mi2)(lims)[d2])
        p3 = dpoint(minimum(lims)[dim], f(mi1)(lims)[d1], f(mi2)(lims)[d2])
        p4 = dpoint(maximum(lims)[dim], f(mi1)(lims)[d1], f(mi2)(lims)[d2])
        p5 = dpoint(minimum(lims)[dim], f(mi1)(lims)[d1], f(!mi2)(lims)[d2])
        p6 = dpoint(maximum(lims)[dim], f(mi1)(lims)[d1], f(!mi2)(lims)[d2])
        # p7 = dpoint(minimum(lims)[dim], f(!mi1)(lims)[d1], f(!mi2)(lims)[d2])
        # p8 = dpoint(maximum(lims)[dim], f(!mi1)(lims)[d1], f(!mi2)(lims)[d2])

        # we are going to transform the 3d frame points into 2d of the topscene
        # because otherwise the frame lines can
        # be cut when they lie directly on the scene boundary
        to_topscene_z_2d.([p1, p2, p3, p4, p5, p6], Ref(scene))
    end

    colors = lift(vcat, Any, attr(:spinecolor_1), attr(:spinecolor_2), attr(:spinecolor_3))
    linesegments!(topscene, framepoints, color = colors, linewidth = attr(:spinewidth),
        # transparency = true,
        visible = attr(:spinesvisible), show_axis = false, inspectable = false)

    nothing
end

# this function projects a point from a 3d subscene into the parent space with a really
# small z value
function to_topscene_z_2d(p3d, scene)
    o = scene.px_area[].origin
    p2d = Point2f(o + Makie.project(scene, p3d))
    # -10000 is an arbitrary weird constant that in preliminary testing didn't seem
    # to clip into plot objects anymore
    Point3f(p2d..., -10000)
end

function add_ticks_and_ticklabels!(topscene, scene, dim::Int, limits, ticknode, miv, min1, min2, attrs, azimuth)

    dimsym(sym) = Symbol(string((:x, :y, :z)[dim]) * string(sym))
    attr(sym) = attrs[dimsym(sym)]

    dpoint = (v, v1, v2) -> dimpoint(dim, v, v1, v2)
    d1 = dim1(dim)
    d2 = dim2(dim)

    tickvalues = @lift($ticknode[1])
    ticklabels = @lift($ticknode[2])

    tick_segments = lift(limits, tickvalues, miv, min1, min2,
            scene.camera.projectionview, scene.px_area) do lims, ticks, miv, min1, min2,
                pview, pxa

        f1 = !min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]

        f1_oppo = min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2_oppo = !min2 ? minimum(lims)[d2] : maximum(lims)[d2]

        diff_f1 = f1 - f1_oppo
        diff_f2 = f2 - f2_oppo

        map(ticks) do t
            p1 = dpoint(t, f1, f2)
            p2 = if dim == 3
                # special case the z axis, here it depends on azimuth in which direction the ticks go
                if 45 <= (rad2deg(azimuth[]) % 180) <= 135
                    dpoint(t, f1 + 0.03 * diff_f1, f2)
                else
                    dpoint(t, f1, f2 + 0.03 * diff_f2)
                end
            else
                dpoint(t, f1 + 0.03 * diff_f1, f2)
            end

            (p1, p2)
        end
    end

    # we are going to transform the 3d tick segments into 2d of the topscene
    # because otherwise they
    # be cut when they extend beyond the scene boundary
    tick_segments_2dz = lift(tick_segments,
            scene.camera.projectionview, scene.px_area) do ts, _, _
        map(ts) do p1_p2
            to_topscene_z_2d.(p1_p2, Ref(scene))
        end
    end

    linesegments!(topscene, tick_segments_2dz,
        xautolimits = false, yautolimits = false, zautolimits = false,
        transparency = true, inspectable = false,
        color = attr(:tickcolor), linewidth = attr(:tickwidth), visible = attr(:ticksvisible))

    labels_positions = lift(scene.px_area, scene.camera.projectionview,
            tick_segments, ticklabels, attr(:ticklabelpad)) do pxa, pv, ticksegs, ticklabs, pad

        o = pxa.origin

        points = map(ticksegs) do (tstart, tend)
            tstartp = Point2f(o + Makie.project(scene, tstart))
            tendp = Point2f(o + Makie.project(scene, tend))

            offset = pad * Makie.GeometryBasics.normalize(
                Point2f(tendp - tstartp))
            tendp + offset
        end

        v = collect(zip(ticklabs, points))
        v::Vector{Tuple{String, Point2f}}
    end

    align = lift(miv, min1, min2) do mv, m1, m2
        if dim == 1
            (mv ⊻ m1 ? :right : :left, m2 ? :top : :bottom)
        elseif dim == 2
            (mv ⊻ m1 ? :left : :right, m2 ? :top : :bottom)
        elseif dim == 3
            (m1 ⊻ m2 ? :left : :right, :center)
        end
    end

    ticklabel_obj = annotations!(topscene, labels_positions, align = align, show_axis = false,
        color = attr(:ticklabelcolor), textsize = attr(:ticklabelsize),
        font = attr(:ticklabelfont), visible = attr(:ticklabelsvisible), inspectable = false
    )

    translate!(ticklabel_obj, 0, 0, 1000)

    label_pos_rot_valign = lift(scene.px_area, scene.camera.projectionview,
            limits, miv, min1, min2, attr(:labeloffset),
            attr(:labelrotation)) do pxa, pv, lims, miv, min1, min2,
                labeloffset, lrotation

        o = pxa.origin

        f1 = !min1 ? minimum(lims)[d1] : maximum(lims)[d1]
        f2 = min2 ? minimum(lims)[d2] : maximum(lims)[d2]

        # get end points of axis
        p1 = dpoint(minimum(lims)[dim], f1, f2)
        p2 = dpoint(maximum(lims)[dim], f1, f2)

        # project them into screen space
        pp1 = Point2f(o + Makie.project(scene, p1))
        pp2 = Point2f(o + Makie.project(scene, p2))

        # find the midpoint
        midpoint = (pp1 + pp2) / 2

        # and the difference vector
        diff = pp2 - pp1

        diffsign = if dim == 1 || dim == 3
            !(min1 ⊻ min2) ? 1 : -1
        else
            (min1 ⊻ min2) ? 1 : -1
        end

        a = pi/2

        # get the vector pointing from the axis in the direction of the label anchor
        offset_vec = (Makie.Mat2f(cos(a), sin(a), -sin(a), cos(a)) *
            Makie.GeometryBasics.normalize(diffsign * diff))

        # calculate the label offset from the axis midpoint
        plus_offset = midpoint + labeloffset * offset_vec

        offset_ang = atan(offset_vec[2], offset_vec[1])
        offset_ang_90deg = offset_ang + pi/2
        offset_ang_90deg_alwaysup = ((offset_ang + pi/2 + pi/2) % pi) - pi/2

        # # prefer rotated left 90deg to rotated right 90deg
        slight_flip = offset_ang_90deg_alwaysup < -deg2rad(88)
        if slight_flip
            offset_ang_90deg_alwaysup += pi
        end
        offset_ang_90deg_alwaysup

        labelrotation = if lrotation == Makie.automatic
            offset_ang_90deg_alwaysup
        else
            lrotation
        end

        valign = offset_vec[2] > 0 || slight_flip ? :bottom : :top

        plus_offset, labelrotation, valign
    end

    labelalign = lift(label_pos_rot_valign, attr(:labelalign)) do (_, _, valign), lalign
        if lalign == Makie.automatic
            (:center, valign)
        else
            lalign
        end
    end

    text!(topscene, attr(:label),
        color = attr(:labelcolor),
        textsize = attr(:labelsize),
        font = attr(:labelfont),
        position = @lift($label_pos_rot_valign[1]),
        rotation = @lift($label_pos_rot_valign[2]),
        align = labelalign,
        visible = attr(:labelvisible),
        inspectable = false
    )

    nothing
end

function dim3point(dim1, dim2, dim3, v1, v2, v3)
    if (dim1, dim2, dim3) == (1, 2, 3)
        Point(v1, v2, v3)
    elseif (dim1, dim2, dim3) == (2, 3, 1)
        Point(v3, v1, v2)
    elseif (dim1, dim2, dim3) == (1, 3, 2)
        Point(v1, v3, v2)
    else
        error("Invalid dim order $dim1, $dim2, $dim3")
    end
end

function add_panel!(scene, dim1, dim2, dim3, limits, min3, attrs)

    dimsym(sym) = Symbol(string((:x, :y, :z)[dim1]) *
        string((:x, :y, :z)[dim2]) * string(sym))
    attr(sym) = attrs[dimsym(sym)]

    vertices = lift(limits, min3) do lims, mi3

        mi = minimum(lims)
        ma = maximum(lims)

        v3 = if mi3
            mi[dim3] + 0.005 * (mi[dim3] - ma[dim3])
        else
            ma[dim3] + 0.005 * (ma[dim3] - mi[dim3])
        end

        p1 = dim3point(dim1, dim2, dim3, mi[dim1], mi[dim2], v3)
        p2 = dim3point(dim1, dim2, dim3, mi[dim1], ma[dim2], v3)
        p3 = dim3point(dim1, dim2, dim3, ma[dim1], ma[dim2], v3)
        p4 = dim3point(dim1, dim2, dim3, ma[dim1], mi[dim2], v3)
        [p1, p2, p3, p4]
    end

    faces = [1 2 3; 3 4 1]

    mesh!(scene, vertices, faces, shading = false, inspectable = false,
        xautolimits = false, yautolimits = false, zautolimits = false,
        color = attr(:panelcolor), visible = attr(:panelvisible))
end

function hidexdecorations!(ax::Axis3;
    label = true, ticklabels = true, ticks = true, grid = true)

    if label
        ax.xlabelvisible = false
    end
    if ticklabels
        ax.xticklabelsvisible = false
    end
    if ticks
        ax.xticksvisible = false
    end
    if grid
        ax.xgridvisible = false
    end
    # if minorgrid
    #     ax.xminorgridvisible = false
    # end
    # if minorticks
    #     ax.xminorticksvisible = false
    # end

    ax
end

function hideydecorations!(ax::Axis3;
    label = true, ticklabels = true, ticks = true, grid = true)

    if label
        ax.ylabelvisible = false
    end
    if ticklabels
        ax.yticklabelsvisible = false
    end
    if ticks
        ax.yticksvisible = false
    end
    if grid
        ax.ygridvisible = false
    end
    # if minorgrid
    #     ax.yminorgridvisible = false
    # end
    # if minorticks
    #     ax.yminorticksvisible = false
    # end

    ax
end

function hidezdecorations!(ax::Axis3;
    label = true, ticklabels = true, ticks = true, grid = true)

    if label
        ax.zlabelvisible = false
    end
    if ticklabels
        ax.zticklabelsvisible = false
    end
    if ticks
        ax.zticksvisible = false
    end
    if grid
        ax.zgridvisible = false
    end
    # if minorgrid
    #     ax.zminorgridvisible = false
    # end
    # if minorticks
    #     ax.zminorticksvisible = false
    # end

    ax
end

function hidedecorations!(ax::Axis3;
    label = true, ticklabels = true, ticks = true, grid = true)

    hidexdecorations!(ax; label = label, ticklabels = ticklabels,
        ticks = ticks, grid = grid)
    hideydecorations!(ax; label = label, ticklabels = ticklabels,
        ticks = ticks, grid = grid)
    hidezdecorations!(ax; label = label, ticklabels = ticklabels,
        ticks = ticks, grid = grid)

    ax
end

function hidespines!(ax::Axis3)
    ax.xspinesvisible = false
    ax.yspinesvisible = false
    ax.zspinesvisible = false
    ax
end



# this is so users can do limits = (x1, x2, y1, y2, z1, z2)
function convert_limit_attribute(lims::Tuple{Any, Any, Any, Any, Any, Any})
    (lims[1:2], lims[3:4], lims[5:6])
end

function convert_limit_attribute(lims::Tuple{Any, Any, Any})
    lims
end


function xautolimits(ax::Axis3)
    xlims = getlimits(ax, 1)

    if isnothing(xlims)
        xlims = (ax.targetlimits[].origin[1], ax.targetlimits[].origin[1] + ax.targetlimits[].widths[1])
    else
        xlims = expandlimits(xlims,
            ax.attributes.xautolimitmargin[][1],
            ax.attributes.xautolimitmargin[][2],
            identity)
    end
    xlims
end

function yautolimits(ax::Axis3)
    ylims = getlimits(ax, 2)

    if isnothing(ylims)
        ylims = (ax.targetlimits[].origin[2], ax.targetlimits[].origin[2] + ax.targetlimits[].widths[2])
    else
        ylims = expandlimits(ylims,
            ax.attributes.yautolimitmargin[][1],
            ax.attributes.yautolimitmargin[][2],
            identity)
    end
    ylims
end

function zautolimits(ax::Axis3)
    zlims = getlimits(ax, 3)

    if isnothing(zlims)
        zlims = (ax.targetlimits[].origin[3], ax.targetlimits[].origin[3] + ax.targetlimits[].widths[3])
    else
        zlims = expandlimits(zlims,
            ax.attributes.zautolimitmargin[][1],
            ax.attributes.zautolimitmargin[][2],
            identity)
    end
    zlims
end

function Makie.xlims!(ax::Axis3, xlims::Tuple{Union{Real, Nothing}, Union{Real, Nothing}})
    if length(xlims) != 2
        error("Invalid xlims length of $(length(xlims)), must be 2.")
    elseif xlims[1] == xlims[2]
        error("Can't set x limits to the same value $(xlims[1]).")
    # elseif all(x -> x isa Real, xlims) && xlims[1] > xlims[2]
    #     xlims = reverse(xlims)
    #     ax.xreversed[] = true
    # else
    #     ax.xreversed[] = false
    end

    ax.limits.val = (xlims, ax.limits[][2], ax.limits[][3])
    reset_limits!(ax, yauto = false, zauto = false)
    nothing
end

function Makie.ylims!(ax::Axis3, ylims::Tuple{Union{Real, Nothing}, Union{Real, Nothing}})
    if length(ylims) != 2
        error("Invalid ylims length of $(length(ylims)), must be 2.")
    elseif ylims[1] == ylims[2]
        error("Can't set y limits to the same value $(ylims[1]).")
    # elseif all(x -> x isa Real, ylims) && ylims[1] > ylims[2]
    #     ylims = reverse(ylims)
    #     ax.yreversed[] = true
    # else
    #     ax.yreversed[] = false
    end

    ax.limits.val = (ax.limits[][1], ylims, ax.limits[][3])
    reset_limits!(ax, xauto = false, zauto = false)
    nothing
end

function Makie.zlims!(ax::Axis3, zlims)
    if length(zlims) != 2
        error("Invalid zlims length of $(length(zlims)), must be 2.")
    elseif zlims[1] == zlims[2]
        error("Can't set y limits to the same value $(zlims[1]).")
    # elseif all(x -> x isa Real, zlims) && zlims[1] > zlims[2]
    #     zlims = reverse(zlims)
    #     ax.zreversed[] = true
    # else
    #     ax.zreversed[] = false
    end

    ax.limits.val = (ax.limits[][1], ax.limits[][2], zlims)
    reset_limits!(ax, xauto = false, yauto = false)
    nothing
end


"""
    limits!(ax::Axis3, xlims, ylims)

Set the axis limits to `xlims` and `ylims`.
If limits are ordered high-low, this reverses the axis orientation.
"""
function limits!(ax::Axis3, xlims, ylims, zlims)
    Makie.xlims!(ax, xlims)
    Makie.ylims!(ax, ylims)
    Makie.zlims!(ax, zlims)
end

"""
    limits!(ax::Axis3, x1, x2, y1, y2, z1, z2)

Set the axis x-limits to `x1` and `x2` and the y-limits to `y1` and `y2`.
If limits are ordered high-low, this reverses the axis orientation.
"""
function limits!(ax::Axis3, x1, x2, y1, y2, z1, z2)
    Makie.xlims!(ax, x1, x2)
    Makie.ylims!(ax, y1, y2)
    Makie.zlims!(ax, z1, z2)
end

"""
    limits!(ax::Axis3, rect::Rect3)

Set the axis limits to `rect`.
If limits are ordered high-low, this reverses the axis orientation.
"""
function limits!(ax::Axis3, rect::Rect3)
    xmin, ymin, zmin = minimum(rect)
    xmax, ymax, zmax = maximum(rect)
    Makie.xlims!(ax, xmin, xmax)
    Makie.ylims!(ax, ymin, ymax)
    Makie.zlims!(ax, zmin, zmax)
end