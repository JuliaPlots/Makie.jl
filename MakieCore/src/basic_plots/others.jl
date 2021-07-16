
"""
`calculated_attributes!(trait::Type{<: AbstractPlot}, plot)`
trait version of calculated_attributes
"""
calculated_attributes!(trait, plot) = nothing

"""
`calculated_attributes!(plot::AbstractPlot)`
Fill in values that can only be calculated when we have all other attributes filled
"""
calculated_attributes!(plot::T) where T = calculated_attributes!(T, plot)

"""
image(x, y, image)
image(image)

Plots an image on range `x, y` (defaults to dimensions).

"""
@recipe(Image, x, y, image) do scene
Attributes(;
    default_theme(scene)...,
    colormap = [:black, :white],
    colorrange = automatic,
    interpolate = true,
    fxaa = false,
    lowclip = nothing,
    highclip = nothing,
    inspectable = theme(scene, :inspectable)
)
end

"""
heatmap(x, y, values)
heatmap(values)

Plots a heatmap as an image on `x, y` (defaults to interpretation as dimensions).

"""
@recipe(Heatmap, x, y, values) do scene
Attributes(;
    default_theme(scene)...,
    colormap = theme(scene, :colormap),
    colorrange = automatic,
    linewidth = 0.0,
    interpolate = false,
    levels = 1,
    fxaa = true,
    lowclip = nothing,
    highclip = nothing,
    inspectable = theme(scene, :inspectable)
)
end

"""
volume(volume_data)

Plots a volume. Available algorithms are:
* `:iso` => IsoValue
* `:absorption` => Absorption
* `:mip` => MaximumIntensityProjection
* `:absorptionrgba` => AbsorptionRGBA
* `:additive` => AdditiveRGBA
* `:indexedabsorption` => IndexedAbsorptionRGBA
"""
@recipe(Volume, x, y, z, volume) do scene
Attributes(;
    default_theme(scene)...,
    algorithm = :mip,
    isovalue = 0.5,
    isorange = 0.05,
    color = nothing,
    colormap = theme(scene, :colormap),
    colorrange = (0, 1),
    fxaa = true,
    inspectable = theme(scene, :inspectable)
)
end

"""
surface(x, y, z)

Plots a surface, where `(x, y)`  define a grid whose heights are the entries in `z`.
`x` and `y` may be `Vectors` which define a regular grid, **or** `Matrices` which define an irregular grid.

"""
@recipe(Surface, x, y, z) do scene
Attributes(;
    default_theme(scene)...,
    color = nothing,
    colormap = theme(scene, :colormap),
    colorrange = automatic,
    shading = true,
    fxaa = true,
    lowclip = nothing,
    highclip = nothing,
    invert_normals = false,
    inspectable = theme(scene, :inspectable)
)
end

# alternatively, mesh3d? Or having only mesh instead of poly + mesh and figure out 2d/3d via dispatch
"""
mesh(x, y, z)
mesh(mesh_object)
mesh(x, y, z, faces)
mesh(xyz, faces)

Plots a 3D or 2D mesh. Supported `mesh_object`s include `Mesh` types from [GeometryBasics.jl](https://github.com/JuliaGeometry/GeometryBasics.jl).

"""
@recipe(Mesh, mesh) do scene
Attributes(;
    default_theme(scene)...,
    color = :black,
    colormap = theme(scene, :colormap),
    colorrange = automatic,
    interpolate = false,
    shading = true,
    fxaa = true,
    inspectable = theme(scene, :inspectable),
    cycle = [:color => :patchcolor],
)
end

"""
meshscatter(positions)
meshscatter(x, y)
meshscatter(x, y, z)

Plots a mesh for each element in `(x, y, z)`, `(x, y)`, or `positions` (similar to `scatter`).
`markersize` is a scaling applied to the primitive passed as `marker`.

"""
@recipe(MeshScatter, positions) do scene
    Attributes(;
        default_theme(scene)...,
        color = :black,
        colormap = theme(scene, :colormap),
        colorrange = automatic,
        marker = :Sphere,
        markersize = 0.1,
        rotations = 0.0,
        # markerspace = relative,
        shading = true,
        fxaa = true,
        inspectable = theme(scene, :inspectable),
        cycle = [:color],
    )
end
