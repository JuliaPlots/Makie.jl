using Makie: volume

@cell "align" begin
    fig, ax, sc = scatter(RNG.rand(10), color=:red)
    text!(ax, "adding text", textsize=0.6, align=(:center, :center))
    fig
end

@cell "fillrange" begin
    x = LinRange(-1, 1, 20)
    y = LinRange(-1, 1, 20)
    z = x .* y'
    contour(x, y, z, levels=0, linewidth=0, fillrange=true)
end

@cell "font" begin
    fig, ax, sc = scatter(RNG.rand(10), color=:red)
    text!(ax, "adding text", textsize=0.6, align=(:center, :center), font="Blackchancery")
    fig
end

@cell "glowcolor, glowwidth" begin
    scatter(RNG.randn(10), color=:blue, glowcolor=:orange, glowwidth=10)
end

@cell "isorange, isovalue" begin
    r = range(-1, stop=1, length=100)
    matr = [(x.^2 + y.^2 + z.^2) for x = r, y = r, z = r]
    volume(matr .* (matr .> 1.4), algorithm=:iso, isorange=0.05, isovalue=1.7)
end

@cell "levels" begin
    x = LinRange(-1, 1, 20)
    y = LinRange(-1, 1, 20)
    z = x .* y'
    contour(x, y, z, linewidth=3, colormap=:colorwheel, levels=50)
end


@cell "position" begin
    fig, ax, sc = scatter(RNG.rand(10), color=:red)
    text!(ax, "adding text", textsize=0.6, position=(5.0, 1.1))
    fig
end

@cell "rotation" begin
    text("Hello World", rotation=1.1)
end

@cell "shading" begin
    mesh(Sphere(Point3f(0), 1f0), color=:orange, shading=false)
end

@cell "visible" begin
    fig = Figure()
    scatter(fig[1, 1], RNG.randn(20), color=to_colormap(:deep, 20), markersize=10, visible=true)
    scatter(fig[1, 2], RNG.randn(20), color=to_colormap(:deep, 20), markersize=10, visible=false)
    fig
end
