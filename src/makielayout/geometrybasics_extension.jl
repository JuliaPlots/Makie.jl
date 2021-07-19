
left(rect::Rect2) = minimum(rect)[1]
right(rect::Rect2) = maximum(rect)[1]
bottom(rect::Rect2) = minimum(rect)[2]
top(rect::Rect2) = maximum(rect)[2]

bottomleft(bbox::Rect2) = Point(left(bbox), bottom(bbox))
topleft(bbox::Rect2) = Point(left(bbox), top(bbox))
bottomright(bbox::Rect2) = Point(right(bbox), bottom(bbox))
topright(bbox::Rect2) = Point(right(bbox), top(bbox))

topline(bbox::Rect2) = (topleft(bbox), topright(bbox))
bottomline(bbox::Rect2) = (bottomleft(bbox), bottomright(bbox))
leftline(bbox::Rect2) = (bottomleft(bbox), topleft(bbox))
rightline(bbox::Rect2) = (bottomright(bbox), topright(bbox))

function shrinkbymargin(rect, margin)
    return Recti(minimum(rect) .+ margin, (widths(rect) .- 2 .* margin))
end

function limits(r::Rect{N, T}) where {N, T}
    mini, maxi = extrema(r)
    return ntuple(i -> (mini[i], maxi[i]), N)
end

function limits(r::Rect, dim::Integer)
    return (minimum(r)[dim], maximum(r)[dim])
end

xlimits(r::Rect) = limits(r, 1)
ylimits(r::Rect) = limits(r, 2)

function enlarge(bbox::Rect2, l, r, b, t)
    BBox(left(bbox) - l, right(bbox) + r, bottom(bbox) - b, top(bbox) + t)
end

function center(bbox::Rect2)
    Point2((right(bbox) + left(bbox)) / 2, (top(bbox) + bottom(bbox)) / 2)
end

"""
Converts a point in fractions of rect dimensions into real coordinates.
"""
function fractionpoint(bbox::Rect2f, point::T) where T <: Point2
    T(left(bbox) + point[1] * width(bbox), bottom(bbox) + point[2] * height(bbox))
end

function anglepoint(center::Point2, angle::Real, radius::Real)
    Ref(center) .+ Ref(Point2(cos(angle), sin(angle))) .* radius
end
