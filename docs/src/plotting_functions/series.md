# series

```@docs
series
```

## Examples

```@example 1
using CairoMakie
CairoMakie.activate!() # hide
Makie.inline!(true) # hide

fig, ax, sp = series(rand(4, 10), labels=["label $i" for i in 1:4])
axislegend(ax)
fig
```

```@example 1
series([Point2f.(1:10, rand(10)) for i in 1:4], markersize=5, color=:Set1)
```

```@example 1
series(LinRange(0, 1, 10), rand(4, 10), solid_color=:black)
```
