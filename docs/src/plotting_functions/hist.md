# hist

```@docs
hist
```

### Examples

```@example hist
using GLMakie
GLMakie.activate!() # hide
Makie.inline!(true) # hide

data = randn(1000)

f = Figure()
hist(f[1, 1], data, bins = 10)
hist(f[1, 2], data, bins = 20, color = :red, strokewidth = 1, strokecolor = :black)
hist(f[2, 1], data, bins = [-5, -2, -1, 0, 1, 2, 5], color = :gray)
hist(f[2, 2], data, normalization = :pdf)
f
```

#### Histogram with labels

You can use all the same arguments as [`barplot`](@ref):
```@example hist
using CairoMakie
CairoMakie.activate!()
hist(data, normalization = :pdf, bar_labels = :values,
     label_formatter=x-> round(x, digits=2), label_size = 15,
     strokewidth = 0.5, strokecolor = (:black, 0.5), color = :values)
```

#### Moving histograms

With `scale_to`, `offset`, `fillto` and `flip`, one can put multiple histograms into the same plot:

```@example hist
fig = Figure()
ax = Axis(fig[1, 1])
for i in 1:5
     hist!(ax, randn(1000), scale_to=0.6, offset=i, fillto=i, direction=:x, flip=true)
end
fig
```
