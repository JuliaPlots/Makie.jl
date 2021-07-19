"""
    timeseries(x::Node{{Union{Number, Point2}}})

Plots a sampled signal.
Usage:
```julia
signal = Node(1.0)
scene = timeseries(signal)
display(scene)
# @async is optional, but helps to continue evaluating more code
@async while isopen(scene)
    # aquire data from e.g. a sensor:
    data = rand()
    # update the signal
    signal[] = data
    # sleep/ wait for new data/ whatever...
    # It's important to yield here though, otherwise nothing will be rendered
    sleep(1/30)
end

```
"""
@recipe(TimeSeries, signal) do scene
    Attributes(
        history = 100;
        default_theme(scene, Lines)...
    )
end

signal2point(signal::Number, start) = Point2f(time() - start, signal)
signal2point(signal::Point2, start) = signal
signal2point(signal, start) = error(""" Signal needs to be of type Number or Point.
Found: $(typeof(signal))
""")


function Makie.plot!(plot::TimeSeries)
    # normal plotting code, building on any previously defined recipes
    # or atomic plotting operations, and adding to the combined `plot`:
    points = Node(fill(Point2f(NaN), plot.history[]))
    buffer = copy(points[])
    lines!(plot, points)
    start = time()
    on(plot.signal) do x
        points[][end] = signal2point(x, start)
        circshift!(buffer, points[], 1)
        buff_ref = buffer
        buffer = points[]
        points[] = buff_ref
        update!(parent(plot))
    end
    plot
end
