using Makie
new_theme = Theme(
    linewidth = 3,
    colormap = :RdYlGn,
    color = :red,
    scatter = Theme(
        marker = '⊝',
        markersize = 0.03,
        strokecolor = :black,
        strokewidth = 0.1,
    ),
)
AbstractPlotting.set_theme!(new_theme)
scene2 = scatter(rand(100), rand(100))
new_theme[:color] = :blue
new_theme[:scatter, :marker] = '◍'
new_theme[:scatter, :markersize] = 0.05
new_theme[:scatter, :strokewidth] = 0.1
new_theme[:scatter, :strokecolor] = :green
scene2 = scatter(rand(100), rand(100))
scene2[end][:marker] = 'π'

r = linspace(-0.5pi, pi + pi/4, 100)
AbstractPlotting.set_theme!(new_theme)
scene = surface(r, r, (x, y)-> sin(2x) + cos(2y))
scene[end][:colormap] = :PuOr
scene
surface!(r + 2pi - pi/4, r, (x, y)-> sin(2x) + cos(2y))
AbstractPlotting.set_theme!()
scene = surface(r + 2pi - pi/4, r, (x, y)-> sin(2x) + cos(2y))


#cell
using Makie
img = Makie.logo()
scene1 = image(0..1, 0..1, img)

scene2 = scatter(rand(100), rand(100))



scene3 = AbstractPlotting.vbox(scene1, scene2)
boundingbox(scene2)

scene3
scene3.children[2].plots[2].transformation.model[]
scene = Scene(resolution = (500, 500))
vx = -1:0.1:1;
vy = -1:0.1:1;

f(x, y) = (sin(x*10) + cos(y*10)) / 4
psurf = surface(vx, vy, f)

pos = lift_node(psurf[:x], psurf[:y], psurf[:z]) do x, y, z
    vec(Point3f0.(x, y', z .+ 0.5))
end
pscat = scatter(pos)
plines = lines(view(pos, 1:2:length(pos)))
center!(scene)
@theme theme = begin
    markersize = to_markersize2d(0.01)
    strokecolor = to_color(:white)
    strokewidth = to_float(0.01)
end
# this pushes all the values from theme to the plot
push!(pscat, theme)
pscat[:glow_color] = to_node(RGBA(0, 0, 0, 0.4), x->to_color((), x))
# apply it to the scene
custom_theme(scene)
# From now everything will be plotted with new theme
psurf = surface(vx, 1:0.1:2, psurf[:z])
center!(scene)



#cell
scene = Scene(resolution = (500, 500))

x = map([:dot, :dash, :dashdot], [2, 3, 4]) do ls, lw
    linesegment(linspace(1, 5, 100), rand(100), rand(100), linestyle = ls, linewidth = lw)
end
push!(x, scatter(linspace(1, 5, 100), rand(100), rand(100)))
center!(scene)
l = Makie.legend(x, ["attribute $i" for i in 1:4])
l[:position] = (0, 1)
l[:backgroundcolor] = RGBA(0.95, 0.95, 0.95)
l[:strokecolor] = RGB(0.8, 0.8, 0.8)
l[:gap] = 30
l[:textsize] = 19
l[:linepattern] = Point2f0[(0,-0.2), (0.5, 0.2), (0.5, 0.2), (1.0, -0.2)]
l[:scatterpattern] = decompose(Point2f0, Circle(Point2f0(0.5, 0), 0.3f0), 9)
l[:markersize] = 2f0
scene

#cell
scene = Scene(resolution = (500, 500))
cmap = collect(linspace(to_color(:red), to_color(:blue), 20))
l = Makie.legend(cmap, 1:4)
l[:position] = (1.0,1.0)
l[:textcolor] = :blue
l[:strokecolor] = :black
l[:strokewidth] = 1
l[:textsize] = 15
l[:textgap] = 5
scene



#cell
using Makie, GeometryTypes, ColorTypes
scene = Scene();
scatter([Point2f0(1.0f0,1.0f0),Point2f0(1.0f0,0.0f0)])
center!(scene);
text_overlay!(scene, "test", position = Point2f0(1.0f0,1.0f0), textsize=200,color= RGBA(0.0f0,0.0f0,0.0f0,1.0f0))
text_overlay!(scene, "test", position = Point2f0(1.0f0,0.0f0), textsize=200,color= RGBA(0.0f0,0.0f0,0.0f0,1.0f0))

scene = Scene();
scatter([Point2f0(1.0f0,1.0f0),Point2f0(1.0f0,0.0f0)])
center!(scene);

text_overlay!(scene,:scatter, "test", "test", textsize=200,color= RGBA(0.0f0,0.0f0,0.0f0,1.0f0))

scene = Scene();
scatter([Point2f0(1.0f0,1.0f0),Point2f0(1.0f0,0.0f0)])
center!(scene);
text_overlay!(scene, :scatter, 1=>"test1", 2=>"test2", textsize=200,color= RGBA(0.0f0,0.0f0,0.0f0,1.0f0))

#cell


# needs to be in a function for ∇ˢf to be fast and inferable
function test(scene)
    n = 20
    f   = (x,y,z) -> x*exp(cos(y)*z)
    ∇f  = (x,y,z) -> Point3f0(exp(cos(y)*z), -sin(y)*z*x*exp(cos(y)*z), x*cos(y)*exp(cos(y)*z))
    ∇ˢf = (x,y,z) -> ∇f(x,y,z) - Point3f0(x,y,z)*dot(Point3f0(x,y,z), ∇f(x,y,z))
    θ = [0;(0.5:n-0.5)/n;1]
    φ = [(0:2n-2)*2/(2n-1);2]
    x = [cospi(φ)*sinpi(θ) for θ in θ, φ in φ]
    y = [sinpi(φ)*sinpi(θ) for θ in θ, φ in φ]
    z = [cospi(θ) for θ in θ, φ in φ]

    pts = vec(Point3f0.(x, y, z))
    lns = Makie.streamlines!(scene, pts, ∇ˢf)
    # those can be changed interactively:
    lns[:color] = :black
    lns[:h] = 0.06
    lns[:linewidth] = 1.0
    lns
end


using Makie
main = Scene()
cam3d!(main)
main
plots = [
    heatmap(0..1, 0..1, rand(100, 100)),
    meshscatter(rand(10), rand(10), rand(10)),
    scatter(rand(10), rand(10)),
    mesh(Makie.loadasset("cat.obj")),
    volume(0..1, 0..1, 0..1, rand(32, 32, 32)),
]

for p in plots
    push!(main, p)
    translate!(p, rand()*3, rand()*3, rand()*3)
end
