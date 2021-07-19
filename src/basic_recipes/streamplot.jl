
"""
streamplot(f::function, xinterval, yinterval; kwargs...)

f must either accept `f(::Point)` or `f(x::Number, y::Number)`.
f must return a Point2.

Example:
```julia
v(x::Point2{T}) where T = Point2f(x[2], 4*x[1])
streamplot(v, -2..2, -2..2)
```
## Attributes
$(ATTRIBUTES)

## Implementation
See the function `Makie.streamplot_impl` for implementation details.
"""
@recipe(StreamPlot, f, limits) do scene
    merge(
        Attributes(
            stepsize = 0.01,
            gridsize = (32, 32, 32),
            maxsteps = 500,
            colormap = theme(scene, :colormap),
            colorrange = Makie.automatic,
            arrow_size = 0.03,
            arrow_head = automatic,
            density = 1.0,
            quality = 16
        ),
        default_theme(scene, Lines) # so that we can theme the lines as needed.
    )
end

function convert_arguments(::Type{<: StreamPlot}, f::Function, xrange, yrange)
    xmin, xmax = extrema(xrange)
    ymin, ymax = extrema(yrange)
    return (f, Rect(xmin, ymin, xmax - xmin, ymax - ymin))
end
function convert_arguments(::Type{<: StreamPlot}, f::Function, xrange, yrange, zrange)
    xmin, xmax = extrema(xrange)
    ymin, ymax = extrema(yrange)
    zmin, zmax = extrema(zrange)
    mini = Vec3f(xmin, ymin, zmin)
    maxi = Vec3f(xmax, ymax, zmax)
    return (f, Rect(mini, maxi .- mini))
end

function convert_arguments(::Type{<: StreamPlot}, f::Function, limits::Rect)
    return (f, limits)
end


scatterfun(N) = N == 2 ? scatter! : meshscatter!

"""
streamplot_impl(CallType, f, limits::Rect{N, T}, resolutionND, stepsize)

Code adapted from an example implementation by Moritz Schauer (@mschauer)
from https://github.com/JuliaPlots/Makie.jl/issues/355#issuecomment-504449775

Background: The algorithm puts an arrow somewhere and extends the
streamline in both directions from there. Then, it chooses a new
position (from the remaining ones), repeating the the exercise until the
streamline gets blocked, from which on a new starting point, the process
repeats.

So, ideally, the new starting points for streamlines are not too close to
current streamlines.

Links:

[Quasirandom sequences](http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/)
"""
function streamplot_impl(CallType, f, limits::Rect{N, T}, resolutionND, stepsize, maxsteps=500, dens=1.0) where {N, T}
    resolution = to_ndim(Vec{N, Int}, resolutionND, last(resolutionND))
    mask = trues(resolution...) # unvisited squares
    arrow_pos = Point{N, Float32}[]
    arrow_dir = Vec{N, Float32}[]
    line_points = Point{N, Float32}[]
    colors = Float64[]
    line_colors = Float64[]
    dt = Point{N, Float32}(stepsize)
    mini, maxi = minimum(limits), maximum(limits)
    r = ntuple(N) do i
        LinRange(mini[i], maxi[i], resolution[i] + 1)
    end
    apply_f(x0, P) = if P <: Point
        f(x0)
    else
        f(x0...)
    end
    # see http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
    ϕ = (MathConstants.φ, 1.324717957244746, 1.2207440846057596)[N]
    acoeff = ϕ.^(-(1:N))
    n_points = 0 # count visited squares
    ind = 0 # index of low discrepancy sequence
    while n_points < prod(resolution)*min(one(dens), dens) # fill up to 100*dens% of mask
        # next index from low discrepancy sequence
        c = CartesianIndex(ntuple(N) do i
            j = ceil(Int, ((0.5 + acoeff[i]*ind) % 1)*resolution[i])
            clamp(j, 1, size(mask, i))
        end)
        ind += 1
        if mask[c]
            x0 = Point(ntuple(N) do i
                first(r[i]) + (c[i] - 0.5) * step(r[i])
            end)
            point = apply_f(x0, CallType)
            if !(point isa Point2 || point isa Point3)
                error("Function passed to streamplot must return Point2 or Point3")
            end
            pnorm = norm(point)
            push!(arrow_pos, x0)
            push!(arrow_dir, point ./ pnorm)
            push!(colors, pnorm)
            mask[c] = false
            n_points += 1
            for d in (-1, 1)
                n_linepoints = 1
                x = x0
                ccur = c
                push!(line_points, Point{N, Float32}(NaN), x)
                push!(line_colors, 0.0, pnorm)
                while x in limits && n_linepoints < maxsteps
                    point = apply_f(x, CallType)
                    pnorm = norm(point)
                    x = x .+ d .* dt .* point ./ pnorm
                    if !(x in limits)
                        break
                    end
                    # WHAT? Why does point behave different from tuple in this
                    # broadcast
                    idx = CartesianIndex(searchsortedlast.(r, Tuple(x)))
                    if idx != ccur
                        if !mask[idx]
                            break
                        end
                        mask[idx] = false
                        n_points += 1
                        ccur = idx
                    end
                    push!(line_points, x)
                    push!(line_colors, pnorm)
                    n_linepoints += 1
                end
            end
        end
    end
    return (
        arrow_pos,
        arrow_dir,
        line_points,
        colors,
        line_colors,
    )
end

function plot!(p::StreamPlot)
    data = lift(p.f, p.limits, p.gridsize, p.stepsize, p.maxsteps, p.density) do f, limits, resolution, stepsize, maxsteps, density
        P = if applicable(f, Point2f(0)) || applicable(f, Point3f(0))
            Point
        else
            Number
        end
        streamplot_impl(P, f, limits, resolution, stepsize, maxsteps, density)
    end
    lines!(
        p,
        lift(x->x[3], data), color = lift(last, data), colormap = p.colormap, colorrange = p.colorrange,
        linestyle = p.linestyle,
        linewidth = p.linewidth,
        inspectable = p.inspectable
    )
    N = ndims(p.limits[])
    scatterfun(N)(
        p,
        lift(first, data), markersize = p.arrow_size,
        marker = @lift(arrow_head(N, $(p.arrow_head), $(p.quality))),
        color = lift(x-> x[4], data), rotations = lift(x-> x[2], data),
        colormap = p.colormap, colorrange = p.colorrange,
        inspectable = p.inspectable
    )
end
