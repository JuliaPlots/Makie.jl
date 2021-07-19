# text

```@docs
text
```

## Screen space text

By default, text is drawn in screen space (`space = :screen`).
The text anchor is given in data coordinates, but the size of the glyphs is independent of data scaling.
The boundingbox of the text will include every data point or every text anchor point.
This also means that `autolimits!` might cut off your text, because the glyphs don't have a meaningful size in data coordinates (the size is independent of zoom level), and you have to take some care to manually place the text or set data limits such that it is fully visible.

You can either plot one string with one position, or a vector of strings with a vector of positions.

```@example
using CairoMakie
CairoMakie.activate!() # hide
Makie.inline!(true) # hide

f = Figure()

Axis(f[1, 1], aspect = DataAspect(), backgroundcolor = :gray50)

scatter!(Point2f(0, 0))
text!("center", position = (0, 0), align = (:center, :center))

circlepoints = [(cos(a), sin(a)) for a in LinRange(0, 2pi, 16)[1:end-1]]
scatter!(circlepoints)
text!(
    "this is point " .* string.(1:15),
    position = circlepoints,
    rotation = LinRange(0, 2pi, 16)[1:end-1],
    align = (:right, :baseline),
    color = cgrad(:Spectral)[LinRange(0, 1, 15)]
)

f
```

## Data space text

For text whose dimensions are meaningful in data space, set `space = :data`.
This means that the boundingbox of the text in data coordinates will include every glyph.

```@example
using CairoMakie
CairoMakie.activate!() # hide
Makie.inline!(true) # hide

f = Figure()
LScene(f[1, 1])

text!(
    fill("Makie", 7),
    rotation = [i / 7 * 1.5pi for i in 1:7],
    position = [Point3f(0, 0, i/2) for i in 1:7],
    color = [cgrad(:viridis)[x] for x in LinRange(0, 1, 7)],
    align = (:left, :baseline),
    textsize = 1,
    space = :data
)

f
```

## Justification

By default, justification of multiline text follows alignment.
Text that is left aligned is also left justified.
You can override this with the `justification` attribute.

```@example
using CairoMakie
CairoMakie.activate!() # hide
Makie.inline!(true) # hide

scene = Scene(camera = campixel!, show_axis = false, resolution = (800, 800))

points = [Point(x, y) .* 200 for x in 1:3 for y in 1:3]
scatter!(scene, points, marker = :circle, markersize = 10px)

symbols = (:left, :center, :right)

for ((justification, halign), point) in zip(Iterators.product(symbols, symbols), points)

    t = text!(scene, "a\nshort\nparagraph",
        color = (:black, 0.5),
        position = point,
        align = (halign, :center),
        justification = justification)

    bb = boundingbox(t)
    wireframe!(scene, bb, color = (:red, 0.2))
end

for (p, al) in zip(points[3:3:end], (:left, :center, :right))
    text!(scene, "align :" * string(al), position = p .+ (0, 80),
        align = (:center, :baseline))
end

for (p, al) in zip(points[7:9], (:left, :center, :right))
    text!(scene, "justification\n:" * string(al), position = p .+ (80, 0),
        align = (:center, :top), rotation = pi/2)
end

scene
```

## Offset

The offset attribute can be used to shift text away from its position.
This is especially useful with `space = :screen`, for example to place text together with barplots.
You can specify the end of the barplots in data coordinates, and then offset the text a little bit to the left.

```@example
using CairoMakie
CairoMakie.activate!() # hide
Makie.inline!(true) # hide

f = Figure()

horsepower = [52, 78, 80, 112, 140]
cars = ["Kia", "Mini", "Honda", "Mercedes", "Ferrari"]

ax = Axis(f[1, 1], xlabel = "horse power")
tightlimits!(ax, Left())
hideydecorations!(ax)

barplot!(horsepower, direction = :x)
text!(cars, position = Point.(horsepower, 1:5), align = (:right, :center),
    offset = (-20, 0), color = :white)

f
```

## MathTeX

Makie can render LaTeXStrings via [MathTeXEngine.jl](https://github.com/Kolaru/MathTeXEngine.jl/).
For example, you can pass L-strings as labels to the legend.

```@example
using CairoMakie
CairoMakie.activate!() # hide
Makie.inline!(true) # hide

f = Figure()
ax = Axis(f[1, 1])

lines!(0..10, x -> sin(3x) / (cos(x) + 2),
    label = L"\frac{\sin(3x)}{\cos(x) + 2}")
lines!(0..10, x -> sin(x^2) / (cos(sqrt(x)) + 2),
    label = L"\frac{\sin(x^2)}{\cos(\sqrt{x}) + 2}")

Legend(f[1, 2], ax)

f
```