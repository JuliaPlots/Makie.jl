# overloadable for other types that might want to offer similar interactions
function interactions end

interactions(ax::Axis) = ax.interactions
interactions(ax3::Axis3) = ax3.interactions

"""
    register_interaction!(parent, name::Symbol, interaction)

Register `interaction` with `parent` under the name `name`.
The parent will call `process_interaction(interaction, event, parent)`
whenever suitable events happen.

The interaction can be removed with `deregister_interaction!` or temporarily
toggled with `activate_interaction!` / `deactivate_interaction!`.
"""
function register_interaction!(parent, name::Symbol, interaction)
    haskey(interactions(parent), name) && error("Interaction $name already exists.")
    registration_setup!(parent, interaction)
    push!(interactions(parent), name => (true, interaction))
    return interaction
end

"""
    register_interaction!(interaction::Function, parent, name::Symbol)

Register `interaction` with `parent` under the name `name`.
The parent will call `process_interaction(interaction, event, parent)`
whenever suitable events happen.
This form with the first `Function` argument is especially intended for `do` syntax.

The interaction can be removed with `deregister_interaction!` or temporarily
toggled with `activate_interaction!` / `deactivate_interaction!`.
"""
function register_interaction!(interaction::Function, parent, name::Symbol)
    haskey(interactions(parent), name) && error("Interaction $name already exists.")
    registration_setup!(parent, interaction)
    push!(interactions(parent), name => (true, interaction))
    return interaction
end

"""
    deregister_interaction!(parent, name::Symbol)

Deregister the interaction named `name` registered in `parent`.
"""
function deregister_interaction!(parent, name::Symbol)
    !haskey(interactions(parent), name) && error("Interaction $name does not exist.")
    _, interaction = interactions(parent)[name]

    deregistration_cleanup!(parent, interaction)
    pop!(interactions(parent), name)
    return interaction
end

function registration_setup!(parent, interaction)
    # do nothing in the default case
end

function deregistration_cleanup!(parent, interaction)
    # do nothing in the default case
end

"""
    activate_interaction!(parent, name::Symbol)

Activate the interaction named `name` registered in `parent`.
"""
function activate_interaction!(parent, name::Symbol)
    !haskey(interactions(parent), name) && error("Interaction $name does not exist.")
    interactions(parent)[name] = (true, interactions(parent)[name][2])
    return nothing
end

"""
    deactivate_interaction!(parent, name::Symbol)

Deactivate the interaction named `name` registered in `parent`.
It can be reactivated with `activate_interaction!`.
"""
function deactivate_interaction!(parent, name::Symbol)
    !haskey(interactions(parent), name) && error("Interaction $name does not exist.")
    interactions(parent)[name] = (false, interactions(parent)[name][2])
    return nothing
end


function process_interaction(@nospecialize args...)
    # do nothing in the default case
    return Consume(false)
end

# a generic fallback for functions to have one really simple path to getting interactivity
# without needing to define a special type first
function process_interaction(f::Function, event, parent)
    # in case f is only defined for a specific type of event
    if applicable(f, event, parent)
        # TODO this is deprecation code, make this just `return f(event, parent)` eventually
        return f(event, parent)
    end
    return Consume(false)
end



############################################################################
#                            Axis interactions                            #
############################################################################

function _chosen_limits(rz, ax)

    r = positivize(Rect2f(rz.from, rz.to .- rz.from))
    lims = ax.finallimits[]
    # restrict to y change
    if rz.restrict_x || !ax.xrectzoom[]
        r = Rect2f(lims.origin[1], r.origin[2], widths(lims)[1], widths(r)[2])
    end
    # restrict to x change
    if rz.restrict_y || !ax.yrectzoom[]
        r = Rect2f(r.origin[1], lims.origin[2], widths(r)[1], widths(lims)[2])
    end
    return r
end

function _selection_vertices(outer, inner)
    _clamp(p, plow, phigh) = Point2f(clamp(p[1], plow[1], phigh[1]), clamp(p[2], plow[2], phigh[2]))

    outer = positivize(outer)
    inner = positivize(inner)

    obl = bottomleft(outer)
    obr = bottomright(outer)
    otl = topleft(outer)
    otr = topright(outer)

    ibl = _clamp(bottomleft(inner), obl, otr)
    ibr = _clamp(bottomright(inner), obl, otr)
    itl = _clamp(topleft(inner), obl, otr)
    itr = _clamp(topright(inner), obl, otr)

    return [obl, obr, otr, otl, ibl, ibr, itr, itl]
end

function process_interaction(r::RectangleZoom, event::MouseEvent, ax::Axis)

    # TODO: actually, the data from the mouse event should be transformed already
    # but the problem is that these mouse events are generated all the time
    # and outside of log axes, you would quickly run into domain errors
    transf = Makie.transform_func(ax)
    inv_transf = Makie.inverse_transform(transf)

    if isnothing(inv_transf)
        @warn "Can't rectangle zoom without inverse transform"
        # TODO, what can we do without inverse?
        return Consume(false)
    end

    if event.type === MouseEventTypes.leftdragstart
        data = Makie.apply_transform(inv_transf, event.data)
        prev_data = Makie.apply_transform(inv_transf, event.prev_data)

        r.from = prev_data
        r.to = data
        r.rectnode[] = _chosen_limits(r, ax)
        r.active[] = true
        return Consume(true)

    elseif event.type === MouseEventTypes.leftdrag
        # clamp mouse data to shown limits
        rect = Makie.apply_transform(transf, ax.finallimits[])
        data = Makie.apply_transform(inv_transf, rectclamp(event.data, rect))

        r.to = data
        r.rectnode[] = _chosen_limits(r, ax)
        return Consume(true)

    elseif event.type === MouseEventTypes.leftdragstop
        try
            r.callback(r.rectnode[])
        catch e
            @warn "error in rectangle zoom" exception=e
        end
        r.active[] = false
        return Consume(true)
    end

    return Consume(false)
end

function rectclamp(p::Point, r::Rect)
    map(p, minimum(r), maximum(r)) do pp, mi, ma
        clamp(pp, mi, ma)
    end |> Point
end

function process_interaction(r::RectangleZoom, event::KeysEvent, ax::Axis)
    r.restrict_y = Keyboard.x in event.keys
    r.restrict_x = Keyboard.y in event.keys
    r.active[] || return Consume(false)

    r.rectnode[] = _chosen_limits(r, ax)
    return Consume(true)
end


function positivize(r::Rect2f)
    negwidths = r.widths .< 0
    newori = ifelse.(negwidths, r.origin .+ r.widths, r.origin)
    newwidths = ifelse.(negwidths, -r.widths, r.widths)
    Rect2f(newori, newwidths)
end

function process_interaction(l::LimitReset, event::MouseEvent, ax::Axis)

    if event.type === MouseEventTypes.leftclick
        if ispressed(ax.scene, Keyboard.left_control)
            if ispressed(ax.scene, Keyboard.left_shift)
                autolimits!(ax)
            else
                reset_limits!(ax)
            end
            return Consume(true)
        end
    end

    return Consume(false)
end

function process_interaction(s::ScrollZoom, event::ScrollEvent, ax::Axis)
    # use vertical zoom
    zoom = event.y

    tlimits = ax.targetlimits
    xzoomlock = ax.xzoomlock
    yzoomlock = ax.yzoomlock
    xzoomkey = ax.xzoomkey
    yzoomkey = ax.yzoomkey

    scene = ax.scene
    e = events(scene)
    cam = camera(scene)

    if zoom != 0
        pa = pixelarea(scene)[]

        z = (1f0 - s.speed)^zoom

        mp_axscene = Vec4f((e.mouseposition[] .- pa.origin)..., 0, 1)

        # first to normal -1..1 space
        mp_axfraction =  (cam.pixel_space[] * mp_axscene)[1:2] .*
            # now to 1..-1 if an axis is reversed to correct zoom point
            (-2 .* ((ax.xreversed[], ax.yreversed[])) .+ 1) .*
            # now to 0..1
            0.5 .+ 0.5

        xscale = ax.xscale[]
        yscale = ax.yscale[]

        transf = (xscale, yscale)
        tlimits_trans = Makie.apply_transform(transf, tlimits[])

        xorigin = tlimits_trans.origin[1]
        yorigin = tlimits_trans.origin[2]

        xwidth = tlimits_trans.widths[1]
        ywidth = tlimits_trans.widths[2]

        newxwidth = xzoomlock[] ? xwidth : xwidth * z
        newywidth = yzoomlock[] ? ywidth : ywidth * z

        newxorigin = xzoomlock[] ? xorigin : xorigin + mp_axfraction[1] * (xwidth - newxwidth)
        newyorigin = yzoomlock[] ? yorigin : yorigin + mp_axfraction[2] * (ywidth - newywidth)

        timed_ticklabelspace_reset(ax, s.reset_timer, s.prev_xticklabelspace, s.prev_yticklabelspace, s.reset_delay)

        newrect_trans = if ispressed(scene, xzoomkey[])
            Rectf(newxorigin, yorigin, newxwidth, ywidth)
        elseif ispressed(scene, yzoomkey[])
            Rectf(xorigin, newyorigin, xwidth, newywidth)
        else
            Rectf(newxorigin, newyorigin, newxwidth, newywidth)
        end

        inv_transf = Makie.inverse_transform(transf)
        tlimits[] = Makie.apply_transform(inv_transf, newrect_trans)
    end

    # NOTE this might be problematic if if we add scrolling to something like Menu
    return Consume(true)
end

function process_interaction(dp::DragPan, event::MouseEvent, ax)

    if event.type !== MouseEventTypes.rightdrag
        return Consume(false)
    end

    tlimits = ax.targetlimits
    xpanlock = ax.xpanlock
    ypanlock = ax.ypanlock
    xpankey = ax.xpankey
    ypankey = ax.ypankey
    panbutton = ax.panbutton

    scene = ax.scene
    cam = camera(scene)
    pa = pixelarea(scene)[]

    mp_axscene = Vec4f((event.px .- pa.origin)..., 0, 1)
    mp_axscene_prev = Vec4f((event.prev_px .- pa.origin)..., 0, 1)

    mp_axfraction, mp_axfraction_prev = map((mp_axscene, mp_axscene_prev)) do mp
        # first to normal -1..1 space
        (cam.pixel_space[] * mp)[1:2] .*
        # now to 1..-1 if an axis is reversed to correct zoom point
        (-2 .* ((ax.xreversed[], ax.yreversed[])) .+ 1) .*
        # now to 0..1
        0.5 .+ 0.5
    end

    xscale = ax.xscale[]
    yscale = ax.yscale[]

    transf = (xscale, yscale)
    tlimits_trans = Makie.apply_transform(transf, tlimits[])

    movement_frac = mp_axfraction .- mp_axfraction_prev

    xscale = ax.xscale[]
    yscale = ax.yscale[]

    transf = (xscale, yscale)
    tlimits_trans = Makie.apply_transform(transf, tlimits[])

    xori, yori = tlimits_trans.origin .- movement_frac .* widths(tlimits_trans)

    if xpanlock[] || ispressed(scene, ypankey[])
        xori = tlimits_trans.origin[1]
    end

    if ypanlock[] || ispressed(scene, xpankey[])
        yori = tlimits_trans.origin[2]
    end

    timed_ticklabelspace_reset(ax, dp.reset_timer, dp.prev_xticklabelspace, dp.prev_yticklabelspace, dp.reset_delay)

    inv_transf = Makie.inverse_transform(transf)
    newrect_trans = Rectf(Vec2f(xori, yori), widths(tlimits_trans))
    tlimits[] = Makie.apply_transform(inv_transf, newrect_trans)

    return Consume(true)
end


function process_interaction(dr::DragRotate, event::MouseEvent, ax3d)
    if event.type !== MouseEventTypes.leftdrag
        return Consume(false)
    end

    dpx = event.px - event.prev_px

    ax3d.azimuth[] += -dpx[1] * 0.01
    ax3d.elevation[] = clamp(ax3d.elevation[] - dpx[2] * 0.01, -pi/2 + 0.001, pi/2 - 0.001)

    return Consume(true)
end
