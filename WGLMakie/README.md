WGLMakie is a WebGL backend for the [Makie.jl](https://www.github.com/JuliaPlots/Makie.jl) plotting package, implemented using Three.js.

Read the docs for Makie and it's backends [here](http://makie.juliaplots.org/.dev)

# Usage

Now, it should just work like Makie:

```julia
using WGLMakie
scatter(rand(4))
```

In the REPL, this will open a browser tab, that will refresh on a new display.
In VSCode, this should open in the plotpane.
You can also embed plots in a JSServe webpage:

```julia
function dom_handler(session, request)
    return DOM.div(
        DOM.h1("Some Makie Plots:"),
        meshscatter(1:4, color=1:4),
        meshscatter(1:4, color=rand(RGBAf, 4)),
        meshscatter(1:4, color=rand(RGBf, 4)),
        meshscatter(1:4, color=:red),
        meshscatter(rand(Point3f, 10), color=rand(RGBf, 10)),
        meshscatter(rand(Point3f, 10), marker=Pyramid(Point3f(0), 1f0, 1f0)),
    )
end
isdefined(Main, :app) && close(app)
app = JSServe.Server(dom_handler, "127.0.0.1", 8082)
```

## Sponsors

<img src="https://github.com/JuliaPlots/Makie.jl/blob/master/assets/BMBF_gefoerdert_2017_en.jpg?raw=true" width="300"/>
Förderkennzeichen: 01IS10S27, 2020
