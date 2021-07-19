# Animations

With Makie it is easy to create animated plots.
Animations work by making changes to data or plot attribute Observables and recording the changing figure frame by frame.
You can find out more about the Observables workflow on the [Observables & Interaction](@ref) page.

## A simple example

To create an animation you need to use the [`record`](@ref) function.

First you create a `Figure`. Next, you pass a function that modifies this figure frame-by-frame to `record`.
Any changes you make to the figure or its plots will appear in the final animation.
You also need to pass an iterable which has as many elements as you want frames in your animation.
The function that you pass as the first argument is called with each element from this iterator
over the course of the animation.

As a start, here is how you can change the color of a line plot:

```@example 1
using GLMakie
GLMakie.activate!() # hide
using Makie.Colors

fig, ax, lineplot = lines(0..10, sin; linewidth=10)

# animation settings
nframes = 30
framerate = 30
hue_iterator = range(0, 360, length=nframes)

record(fig, "color_animation.mp4", hue_iterator; framerate = framerate) do hue
    lineplot.color = HSV(hue, 1, 0.75)
end
nothing # hide
```

![color animation](color_animation.mp4)

Passing a function as the first argument is usually done with Julia's `do`-notation, which you might not be familiar with.
Instead of the above, we could also have written:

```julia
function change_function(hue)
    lineplot.color = HSV(hue, 1, 0.75)
end

record(change_function, fig, "color_animation.mp4", hue_iterator; framerate = framerate)
```

## File formats

Video files are created with [`FFMPEG.jl`](https://github.com/JuliaIO/FFMPEG.jl).
You can choose from the following file formats:

- `.mkv` (the default, doesn't need to convert)
- `.mp4` (good for web, widely supported)
- `.webm` (smallest file size)
- `.gif` (lowest quality with largest file size)

## Animations using `Observables`

Often, you want to animate a complex plot over time, and all the data that is displayed should be determined by the current time stamp.
Such a dependency is really easy to express with `Observables` or `Nodes`.

We can save a lot of work if we create our data depending on a single time `Node`, so we don't have to change every plot's data manually as the animation progresses.

Here is an example that plots two different functions.
The y-values of each depend on time and therefore we only have to change the time for both plots to change.
We use the convenient `@lift` macro which denotes that the `lift`ed expression depends on each Observable marked with a `$` sign.

```@example 1
time = Node(0.0)

xs = range(0, 7, length=40)

ys_1 = @lift(sin.(xs .- $time))
ys_2 = @lift(cos.(xs .- $time) .+ 3)

fig = lines(xs, ys_1, color = :blue, linewidth = 4,
    axis = (title = @lift("t = $(round($time, digits = 1))"),))
scatter!(xs, ys_2, color = :red, markersize = 15)

framerate = 30
timestamps = range(0, 2, step=1/framerate)

record(fig, "time_animation.mp4", timestamps; framerate = framerate) do t
    time[] = t
end
nothing # hide
```

![time animation](time_animation.mp4)

You can set most plot attributes equal to `Observable`s, so that you need only update
a single variable (like time) during your animation loop.

For example, to make a line with color dependent on time, you could write:

```@example 1
time = Node(0.0)
color_observable = @lift(RGBf($time, 0, 0))

fig = lines(0..10, sin, color = color_observable)

record(fig, "color_animation.mp4", timestamps; framerate = framerate) do t
    time[] = t
end
nothing # hide
```

![color animation](color_animation.mp4)

## Appending data with Observables

You can also append data to a plot during an animation.
Instead of passing `x` and `y` (or `z`) values separately,
it is better to make a `Node` with a vector of `Point`s,
so that the number of `x` and `y` values can not go out of sync.

```@example 1
points = Node(Point2f[(0, 0)])

fig, ax = scatter(points)
limits!(ax, 0, 30, 0, 30)

frames = 1:30

record(fig, "append_animation.mp4", frames; framerate = 30) do frame
    new_point = Point2f(frame, frame)
    points[] = push!(points[], new_point)
end
nothing # hide
```

![append animation](append_animation.mp4)

## Animating a plot "live"

You can animate a live plot easily using a loop.
Update all `Observables` that you need and then add a short sleep interval so that the display can refresh:

```@example 1
points = Node(Point2f[randn(2)])

fig, ax = scatter(points)
limits!(ax, -4, 4, -4, 4)

fps = 60
nframes = 120

for i = 1:nframes
    new_point = Point2f(randn(2))
    points[] = push!(points[], new_point)
    sleep(1/fps) # refreshes the display!
end
nothing # hide
```
