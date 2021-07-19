# streamplot

```@docs
streamplot
```

### Examples

```@example
using CairoMakie
CairoMakie.activate!() # hide
Makie.inline!(true) # hide

struct FitzhughNagumo{T}
    ϵ::T
    s::T
    γ::T
    β::T
end

P = FitzhughNagumo(0.1, 0.0, 1.5, 0.8)

f(x, P::FitzhughNagumo) = Point2f(
    (x[1]-x[2]-x[1]^3+P.s)/P.ϵ,
    P.γ*x[1]-x[2] + P.β
)

f(x) = f(x, P)

streamplot(f, -1.5..1.5, -1.5..1.5, colormap = :magma)

save("example_streamplot.png", current_figure(), px_per_unit = 2); nothing # hide
```

![example streamplot](example_streamplot.png)
