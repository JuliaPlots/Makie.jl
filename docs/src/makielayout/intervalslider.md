# IntervalSlider

The interval slider selects an interval (low, high) from the supplied attribute `range`.
The (approximate) start values can be set with `startvalues`.

The currently selected interval is in the attribute `interval` and is a Tuple of `(low, high)`.
Don't change this value manually, but use the function `set_close_to!(intslider, v1, v2)`.
This is necessary to ensure the values are actually present in the `range` attribute.

You can click anywhere outside of the currently selected range and the closer interval edge will jump to the point.
You can then drag the edge around.
When hovering over the slider, the larger button indicates the edge that will react.

If the mouse hovers over the central area of the interval and both buttons are enlarged, clicking and dragging shifts the interval around as a whole.

You can double-click the slider to reset it to the values present in `startvalues`.
If `startvalues === Makie.automatic`, the full interval will be selected (this is the default).

If you set the attribute `snap = false`, the slider will move continously while dragging and only jump to the closest available values when releasing the mouse.

```@example
using CairoMakie
Makie.inline!(true) # hide
CairoMakie.activate!() # hide

f = Figure()
Axis(f[1, 1], limits = (0, 1, 0, 1))

rs_h = IntervalSlider(f[2, 1], range = LinRange(0, 1, 1000),
    startvalues = (0.2, 0.8))
rs_v = IntervalSlider(f[1, 2], range = LinRange(0, 1, 1000),
    startvalues = (0.4, 0.9), horizontal = false)

Label(f[3, 1], @lift(string(round.($(rs_h.interval), digits = 2))),
    tellwidth = false)
Label(f[1, 3], @lift(string(round.($(rs_v.interval), digits = 2))),
    tellheight = false, rotation = pi/2)

points = rand(Point2f, 300)

# color points differently if they are within the two intervals
colors = lift(rs_h.interval, rs_v.interval) do h_int, v_int
    map(points) do p
        (h_int[1] < p[1] < h_int[2]) && (v_int[1] < p[2] < v_int[2])
    end
end

scatter!(points, color = colors, colormap = [:black, :orange], strokewidth = 0)

f
```
