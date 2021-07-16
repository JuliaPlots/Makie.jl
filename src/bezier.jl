abstract type PathCommand end

struct BezierPath
    commands::Vector{PathCommand}
end

struct MoveTo <: PathCommand
    p::Point2{Float64}
end

MoveTo(x, y) = MoveTo(Point(x, y))

struct LineTo <: PathCommand
    p::Point2{Float64}
end

LineTo(x, y) = LineTo(Point(x, y))

struct CurveTo <: PathCommand
    c1::Point2{Float64}
    c2::Point2{Float64}
    p::Point2{Float64}
end

CurveTo(cx1, cy1, cx2, cy2, p1, p2) = CurveTo(
    Point(cx1, cy1), Point(cx2, cy2), Point(p1, p1)
)

struct EllipticalArc <: PathCommand
    c::Point2{Float64}
    r1::Float64
    r2::Float64
    angle::Float64
    a1::Float64
    a2::Float64
end

EllipticalArc(cx, cy, r1, r2, angle, a1, a2) = EllipticalArc(Point(cx, cy),
    r1, r2, angle, a1, a2)

struct ClosePath <: PathCommand end

function Base.:+(pc::P, p::Point2) where P <: PathCommand
    fnames = fieldnames(P)
    P(map(f -> getfield(pc, f) + p, fnames)...)
end

scale(bp::BezierPath, s::Real) = BezierPath([scale(x, Vec(s, s)) for x in bp.commands])
scale(bp::BezierPath, v::VecTypes{2}) = BezierPath([scale(x, v) for x in bp.commands])
translate(bp::BezierPath, v::VecTypes{2}) = BezierPath([translate(x, v) for x in bp.commands])

translate(m::MoveTo, v::VecTypes{2}) = MoveTo(m.p .+ v)
translate(l::LineTo, v::VecTypes{2}) = LineTo(l.p .+ v)
translate(c::CurveTo, v::VecTypes{2}) = CurveTo(c.c1 .+ v, c.c2 .+ v, c.p .+ v)
translate(e::EllipticalArc, v::VecTypes{2}) = EllipticalArc(e.c .+ v, e.r1, e.r2, e.angle, e.a1, e.a2)
translate(c::ClosePath, v::VecTypes{2}) = c

scale(m::MoveTo, v::VecTypes{2}) = MoveTo(m.p .* v)
scale(l::LineTo, v::VecTypes{2}) = LineTo(l.p .* v)
scale(c::CurveTo, v::VecTypes{2}) = CurveTo(c.c1 .* v, c.c2 .* v, c.p .* v)
scale(e::EllipticalArc, v::VecTypes{2}) = EllipticalArc(e.c .* v, e.r1, e.r2, e.angle, e.a1, e.a2)
scale(c::ClosePath, v::VecTypes{2}) = c


Base.:+(pc::EllipticalArc, p::Point2) = EllipticalArc(pc.c + p, pc.r1, pc.r2, pc.angle, pc.a1, pc.a2)
Base.:+(pc::ClosePath, p::Point2) = pc
Base.:+(bp::BezierPath, p::Point2) = BezierPath(bp.commands .+ Ref(p))

# markers with unit area

BezierCircle = let
    r = sqrt(1/pi)
    BezierPath([
        EllipticalArc(Point(0.0, 0), r, r, 0.0, 0.0, 2pi),
        ClosePath()
    ])
end

BezierUTriangle = let
    r = Float32(sqrt(1 / (3 * sqrt(3) / 4)))
    BezierPath([
        MoveTo(Point2(cosd(90), sind(90)) .* r),
        LineTo(Point2(cosd(210), sind(210)) .* r),
        LineTo(Point2(cosd(330), sind(330)) .* r),
        ClosePath()
    ])
end

BezierDTriangle = let
    r = Float32(sqrt(1 / (3 * sqrt(3) / 4)))
    BezierPath([
        MoveTo(Point2(cosd(270), sind(270)) .* r),
        LineTo(Point2(cosd(390), sind(390)) .* r),
        LineTo(Point2(cosd(510), sind(510)) .* r),
        ClosePath()
    ])
end

BezierSquare = let
    BezierPath([
        MoveTo(Point2(0.5, -0.5)),
        LineTo(Point2(0.5, 0.5)),
        LineTo(Point2(-0.5, 0.5)),
        LineTo(Point2(-0.5, -0.5)),
        ClosePath()
    ])
end

BezierCross = let
    cutfraction = 2/3
    # 1 = (2r)^2 - 4 * (r * c) ^ 2
    # c^2 - 1 != 0, r = 1/(2 sqrt(1 - c^2))
    # 
    r = 1/(2 * sqrt(1 - cutfraction^2))
    # test: (2r)^2 - 4 * (r * cutfraction) ^ 2 ≈ 1
    ri = r * (1 - cutfraction)
    
    first_three = Point2[(r, ri), (ri, ri), (ri, r)]
    all = map(0:pi/2:3pi/2) do a
        m = Mat2f0(sin(a), cos(a), cos(a), -sin(a))
        Ref(m) .* first_three
    end |> x -> reduce(vcat, x)

    BezierPath([
        MoveTo(all[1]),
        LineTo.(all[2:end])...,
        ClosePath()
    ])
end


# pathtokens(::Union{Val{:M}, Val{:m}, Val{:L}, Val{:l}}) = (Float64, Float64)
# pathtokens(::Union{Val{:H}, Val{:h}, Val{:V}, Val{:v}}) = (Float64,)
# pathtokens(::Union{Val{:Z}, Val{:z}}) = ()
# pathtokens(::Union{Val{:C}, Val{:c}}) = (Float64, Float64, Float64, Float64, Float64, Float64)
# pathtokens(::Union{Val{:S}, Val{:s}}) = (Float64, Float64, Float64, Float64)
# pathtokens(::Union{Val{:A}, Val{:a}}) = (Float64, Float64, Float64, Bool, Bool, Float64, Float64)
# # pathtokens

# function BezierPath(svg::AbstractString)
#     n = length(svg)
#     offset = 1

#     commands = PathCommand{Float64}[]

#     v = view(svg, 1:n)

#     while offset < n
#         offset += shift_to_nonseparator(v)
#         v = view(svg, offset:n)
#         command, offset = parsecommand(v)
#         push!(commands, command)
#     end

#     BezierPath(commands)
# end

# function shift_to_nonseparator(substr)
#     for (i, char) in enumerate(substr)
#         if char ∉ " ,\n\t"
#             return i - 1
#         end
#     end
#     return length(substr) - 1
# end

# function parsecommand(substr)
#     commandletters = "MmLlHhVvZzCcSsAa"
#     @show substr

#     command = substr[1]
#     if command ∉ commandletters
#         error("Expected a command letter but got $(substr[1]).")
#     end

#     types = pathtokens(Val(Symbol(command)))
# end

# function parsetypes(types, substr)
#     offset = 1
#     shift = 0
#     map(types) do T
#         offset += shift_to_nonseparator(substr)
#         val, shift = parsetype(T, substr)
#         offset += shift
#         val
#     end
# end

function BezierPath(svg::AbstractString)

    # args = [e.match for e in eachmatch(r"([a-zA-Z])|(\-?\d*\.?\d+)", svg)]
    args = [e.match for e in eachmatch(r"(?:0(?=\d))|(?:[a-zA-Z])|(?:\-?\d*\.?\d+)", svg)]

    i = 1

    commands = PathCommand[]
    lastcomm = nothing
    function lastp()
        c = commands[end]
        if isnothing(lastcomm)
            Point(0, 0)
        elseif c isa ClosePath
            r = reverse(commands)
            backto = findlast(x -> !(x isa ClosePath), r)
            if isnothing(backto)
                error("No point to go back to")
            end
            r[backto].p
        elseif c isa EllipticalArc
            let
                ϕ = c.angle
                a2 = c.a2
                rx = c.r1
                ry = c.r2
                m = Mat2(cos(ϕ), sin(ϕ), -sin(ϕ), cos(ϕ))
                m * Point(rx * cos(a2), ry * sin(a2)) + c.c
            end
        else
            c.p
        end
    end

    while i <= length(args)

        comm = args[i]

        # command letter is omitted, use last command
        if isnothing(match(r"[a-zA-Z]", comm))
            comm = lastcomm
            i -= 1
        end

        if comm == "M"
            x, y = parse.(Float64, args[i+1:i+2])
            push!(commands, MoveTo(Point2(x, y)))
            i += 3
        elseif comm == "m"
            x, y = parse.(Float64, args[i+1:i+2])
            push!(commands, MoveTo(Point2(x, y) + lastp()))
            i += 3
        elseif comm == "L"
            x, y = parse.(Float64, args[i+1:i+2])
            push!(commands, LineTo(Point2(x, y)))
            i += 3
        elseif comm == "l"
            x, y = parse.(Float64, args[i+1:i+2])
            push!(commands, LineTo(Point2(x, y) + lastp()))
            i += 3
        elseif comm == "H"
            x = parse(Float64, args[i+1])
            push!(commands, LineTo(Point2(x, lastp().y)))
            i += 2
        elseif comm == "h"
            x = parse(Float64, args[i+1])
            push!(commands, LineTo(X(x) + lastp()))
            i += 2
        elseif comm == "Z"
            push!(commands, ClosePath())
            i += 1
        elseif comm == "z"
            push!(commands, ClosePath())
            i += 1
        elseif comm == "C"
            x1, y1, x2, y2, x3, y3 = parse.(Float64, args[i+1:i+6])
            push!(commands, CurveTo(Point2(x1, y1), Point2(x2, y2), Point2(x3, y3)))
            i += 7
        elseif comm == "c"
            x1, y1, x2, y2, x3, y3 = parse.(Float64, args[i+1:i+6])
            l = lastp()
            push!(commands, CurveTo(Point2(x1, y1) + l, Point2(x2, y2) + l, Point2(x3, y3) + l))
            i += 7
        elseif comm == "S"
            x1, y1, x2, y2 = parse.(Float64, args[i+1:i+4])
            prev = commands[end]
            reflected = prev.p + (prev.p - prev.c2)
            push!(commands, CurveTo(reflected, Point2(x1, y1), Point2(x2, y2)))
            i += 5
        elseif comm == "s"
            x1, y1, x2, y2 = parse.(Float64, args[i+1:i+4])
            prev = commands[end]
            reflected = prev.p + (prev.p - prev.c2)
            l = lastp()
            push!(commands, CurveTo(reflected, Point2(x1, y1) + l, Point2(x2, y2) + l))
            i += 5
        elseif comm == "A"
            args[i+1:i+7]
            r1, r2 = parse.(Float64, args[i+1:i+2])
            angle = parse(Float64, args[i+3])
            large_arc_flag, sweep_flag = parse.(Bool, args[i+4:i+5])
            x2, y2 = parse.(Float64, args[i+6:i+7])
            x1, y1 = lastp()

            push!(commands, EllipticalArc(x1, y1, x2, y2, r1, r2,
                angle, large_arc_flag, sweep_flag))
            i += 8
        elseif comm == "a"
            r1, r2 = parse.(Float64, args[i+1:i+2])
            angle = parse(Float64, args[i+3])
            large_arc_flag, sweep_flag = parse.(Bool, args[i+4:i+5])
            x1, y1 = lastp()
            x2, y2 = parse.(Float64, args[i+6:i+7]) .+ (x1, y1)

            push!(commands, EllipticalArc(x1, y1, x2, y2, r1, r2,
                angle, large_arc_flag, sweep_flag))
            i += 8
        elseif comm == "v"
            dy = parse(Float64, args[i+1])
            l = lastp()
            push!(commands, LineTo(Point2(l[1], l[2] + dy)))
            i += 2
        else
            for c in commands
                println(c)
            end
            error("Parsing $comm not implemented.")
        end

        lastcomm = comm

    end

    BezierPath(commands)

end

function EllipticalArc(x1, y1, x2, y2, rx, ry, ϕ, largearc::Bool, sweepflag::Bool)
    # https://www.w3.org/TR/SVG11/implnote.html#ArcImplementationNotes

    p1 = Point(x1, y1)
    p2 = Point(x2, y2)

    m1 = Mat2(cos(ϕ), -sin(ϕ), sin(ϕ), cos(ϕ))
    x1′, y1′ = m1 * (0.5 * (p1 - p2))

    tempsqrt = (rx^2 * ry^2 - rx^2 * y1′^2 - ry^2 * x1′^2) /
        (rx^2 * y1′^2 + ry^2 * x1′^2)

    c′ = (largearc == sweepflag ? -1 : 1) *
        sqrt(tempsqrt) * Point(rx * y1′ / ry, -ry * x1′ / rx)

    c = Mat2(cos(ϕ), sin(ϕ), -sin(ϕ), cos(ϕ)) * c′ + 0.5 * (p1 + p2)

    vecangle(u, v) = sign(u[1] * v[2] - u[2] * v[1]) *
        acos(dot(u, v) / (norm(u) * norm(v)))

    px(sign) = Point((sign * x1′ - c′[1]) / rx, (sign * y1′ - c′[2]) / rx)

    θ1 = vecangle(Point(1.0, 0.0), px(1))
    Δθ_pre = mod(vecangle(px(1), px(-1)), 2pi)
    Δθ = if Δθ_pre > 0 && !sweepflag
        Δθ_pre - 2pi
    elseif Δθ_pre < 0 && sweepflag
        Δθ_pre + 2pi
    else
        Δθ_pre
    end

    EllipticalArc(c, rx, ry, ϕ, θ1, θ1 + Δθ)
end