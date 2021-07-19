# Extending

There are 3 ways to extend Makie:

1) By creating a new function combining multiple plotting commands (duh)
2) By overloading conversions for your custom type
3) By overloading plot(...) for your own type

## Option 1

The first option is quite trivial and can be done in any plotting package and language:
just create a function that scripts together a Plot.

## Option 2

The plotting pipeline heavily relies on conversion functions which check the attributes for validity,
document what's possible to pass and convert them to the types that the backends need.
They usually look like this:

```julia
to_positions(backend, positions) = Point3f.(positions) # E.g. everything that can be converted to a Point
```

As you can see, the first argument is the backend, so you can overload this for a specific backend
or for a specific position type.
This can look something like this:

@library[example] "overload to position"

since the pipeline for converting attributes also knows about Circle now,
we can update the attribute directly with our own type

@library[example] "change size"

## Option 3

Option 3 is very similar to Plots.jl recipes.
Inside the function you can just use all of the plotting and drawing API to create
a rich visual representation of your type.
The signature that needs overloading is:

```julia
function plot(obj::MyType, kw_args::Dict)
    # use primitives and other recipes to create a new plot
    scatter(obj, kw_arg[:my_attribute])
    lines(...)
    polygon(...)
end
```
