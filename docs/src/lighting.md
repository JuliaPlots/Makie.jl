# Lighting

For 3D scenes, `GLMakie` offers several attributes to control the lighting of the scene. These are set per plot.

- `ambient::Vec3f`: Objects should never be completely dark; we use an ambient light to simulate background lighting, and give the object some color. Each element of the vector represents the intensity of color in R, G or B respectively.
- `diffuse::Vec3f`: Simulates the directional impact which the light source has on the plot object. This is the most visually significant component of the lighting model; the more a part of an object faces the light source, the brighter it becomes. Each element of the vector represents the intensity of color in R, G or B respectively.
- `specular::Vec3f`: Simulates the bright spot of a light that appears on shiny objects. Specular highlights are more inclined to the color of the light than the color of the object. Each element of the vector represents the intensity of color in R, G or B respectively.

- `shininess::Float32`: Controls the shininess of the object. Higher shininess reduces the size of the highlight, and makes it sharper. This value must be positive.
- `lightposition::Vec3f`: The location of the main light source; by default, the light source is at the location of the camera.

You can find more information on how these were implemented [here](https://learnopengl.com/Lighting/Basic-Lighting).

## SSAO

GLMakie also implements [_screen-space ambient occlusion_](https://learnopengl.com/Advanced-Lighting/SSAO), which is an algorithm to more accurately simulate the scattering of light. There are a couple of controllable scene attributes nested within the `SSAO` toplevel attribute:

- `radius` sets the range of SSAO. You may want to scale this up or
  down depending on the limits of your coordinate system
- `bias` sets the minimum difference in depth required for a pixel to
  be occluded. Increasing this will typically make the occlusion
  effect stronger.
- `blur` sets the (pixel) range of the blur applied to the occlusion texture.
  The texture contains a (random) pattern, which is washed out by
  blurring. Small `blur` will be faster, sharper and more patterned.
  Large `blur` will be slower and smoother. Typically `blur = 2` is
  a good compromise.

!!! note
    The SSAO postprocessor is turned off by default to save on resources. To turn it on, set `GLMakie.enable_SSAO[] = true`, close any existing GLMakie window and reopen it.

## Matcap

A matcap (material capture) is a texture which is applied based on the normals of a given mesh. They typically include complex materials and lighting and offer a cheap way to apply those to any mesh. You may pass a matcap via the `matcap` attribute of a `mesh`, `meshscatter` or `surface` plot. Setting `shading = false` is suggested. You can find a lot matcaps [here](https://github.com/nidorx/matcaps).

## Examples

```@example 1
using GLMakie
GLMakie.activate!() # hide

xs = -10:0.1:10
ys = -10:0.1:10
zs = [10 * (cos(x) * cos(y)) * (.1 + exp(-(x^2 + y^2 + 1)/10)) for x in xs, y in ys]

# Or use an LScene within a Figure
scene = Scene()
surface!(
    scene, xs, ys, zs, colormap = (:white, :white),

    # Light comes from (0, 0, 15), i.e the sphere
    lightposition = Vec3f(0, 0, 15),
    # base light of the plot only illuminates red colors
    ambient = Vec3f(0.3, 0, 0),
    # light from source (sphere) illuminates yellow colors
    diffuse = Vec3f(0.4, 0.4, 0),
    # reflections illuminate blue colors
    specular = Vec3f(0, 0, 1.0),
    # Reflections are sharp
    shininess = 128f0
)
mesh!(scene, Sphere(Point3f(0, 0, 15), 1f0), color=RGBf(1, 0.7, 0.3))
scene
```

```@example 1
using GLMakie
GLMakie.activate!() # hide
GLMakie.enable_SSAO[] = true
close(GLMakie.global_gl_screen()) # close any open screen

# Alternatively:
# fig = Figure()
# scene = LScene(fig[1, 1], scenekw = (SSAO = (radius = 5.0, blur = 3), show_axis=false, camera=cam3d!))
# scene.scene[:SSAO][:bias][] = 0.025

scene = Scene(show_axis = false)

# SSAO attributes are per scene
scene[:SSAO][:radius][] = 5.0
scene[:SSAO][:blur][] = 3
scene[:SSAO][:bias][] = 0.025

box = Rect3(Point3f(-0.5), Vec3f(1))
positions = [Point3f(x, y, rand()) for x in -5:5 for y in -5:5]
meshscatter!(scene, positions, marker=box, markersize=1, color=:lightblue, ssao=true)
scene

GLMakie.enable_SSAO[] = false # hide
close(GLMakie.global_gl_screen()) # hide
scene # hide
```

```@example 1
using FileIO
using GLMakie
GLMakie.activate!() # hide
catmesh = FileIO.load(assetpath("cat.obj"))
gold = FileIO.load(download("https://raw.githubusercontent.com/nidorx/matcaps/master/1024/E6BF3C_5A4719_977726_FCFC82.png"))

mesh(catmesh, matcap=gold, shading=false)
```
