@recipe(RoundedRect) do scene
    Theme(
        rect = BBox(0, 100, 0, 100),
        cornerradius = 5,
        cornersegments = 10,
        raw = true,
        color = RGBf(0.9, 0.9, 0.9),
        strokecolor = RGBf(0, 0, 0)
    )
end

function plot!(roundrect::RoundedRect)
    @extract(roundrect, (
        rect, cornerradius, cornersegments, raw, color, strokecolor
    ))

    heightattr = roundrect.height
    widthattr = roundrect.width

    roundedrectpoints = lift(rect, cornerradius, cornersegments) do rect,
            cr, csegs

        cr = min(width(rect) / 2, height(rect) / 2, cr)

        # inner corners
        ictl = topleft(rect) .+ Point2(cr, -cr)
        ictr = topright(rect) .+ Point2(-cr, -cr)
        icbl = bottomleft(rect) .+ Point2(cr, cr)
        icbr = bottomright(rect) .+ Point2(-cr, cr)

        cstr = anglepoint.(Ref(ictr), LinRange(0, pi/2, csegs), cr)
        cstl = anglepoint.(Ref(ictl), LinRange(pi/2, pi, csegs), cr)
        csbl = anglepoint.(Ref(icbl), LinRange(pi, 3pi/2, csegs), cr)
        csbr = anglepoint.(Ref(icbr), LinRange(3pi/2, 2pi, csegs), cr)

        arr = [cstr; cstl; csbl; csbr]
    end

    poly!(roundrect, roundedrectpoints, raw = raw, color = color, strokecolor = strokecolor)
end
