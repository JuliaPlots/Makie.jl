# poly

```@docs
poly
```

### Examples

```@example
using CairoMakie
CairoMakie.activate!() # hide
using Makie.GeometryBasics
Makie.inline!(true) # hide

f = Figure()
Axis(f[1, 1])

poly!(Point2f[(0, 0), (2, 0), (3, 1), (1, 1)], color = :red, strokecolor = :black, strokewidth = 1)

f
```

```@example
using CairoMakie
CairoMakie.activate!() # hide
using Makie.GeometryBasics
Makie.inline!(true) # hide

f = Figure()
Axis(f[1, 1])

# polygon with hole
p = Polygon(
    Point2f[(0, 0), (2, 0), (3, 1), (1, 1)],
    [Point2f[(0.75, 0.25), (1.75, 0.25), (2.25, 0.75), (1.25, 0.75)]]
)

poly!(p, color = :blue)

f
```

```@example
using CairoMakie
CairoMakie.activate!() # hide
using Makie.GeometryBasics
Makie.inline!(true) # hide

f = Figure()
Axis(f[1, 1])

# vector of shapes
poly!(
    [Rect(i, j, 0.75, 0.5) for i in 1:5 for j in 1:3],
    color = 1:15,
    colormap = :heat
)

f
```

```@example
using CairoMakie
CairoMakie.activate!() # hide
using Makie.GeometryBasics
Makie.inline!(true) # hide

f = Figure()
Axis(f[1, 1], aspect = DataAspect())

# shape decomposition
poly!(Circle(Point2f(0, 0), 15f0), color = :pink)

f
```

```@example
using CairoMakie
CairoMakie.activate!() # hide
using Makie.GeometryBasics
Makie.inline!(true) # hide

f = Figure()
Axis(f[1, 1])

# vector of polygons
ps = [Polygon(rand(Point2f, 3) .+ Point2f(i, j))
    for i in 1:5 for j in 1:10]

poly!(ps, color = rand(RGBf, length(ps)),
    axis = (backgroundcolor = :gray15,))

f
```
