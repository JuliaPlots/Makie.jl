using StatsBase: Histogram
using Makie, StatsBase
import Distributions
using KernelDensity

using Random: seed!
using GeometryBasics: Rect2f

seed!(0)

@testset "histogram" begin
    v = randn(1000)
    h = fit(Histogram, v)
    fig, ax, plt = plot(h)

    @test plt isa BarPlot
    x = h.edges[1]
    @test plt[1][] ≈ Point{2, Float32}.(x[1:end-1] .+ step(x)/2, h.weights)

    v = (randn(1000), randn(1000))
    h = fit(Histogram, v, nbins = 30)
    fig, ax, plt = plot(h)
    @test plt isa Heatmap
    x = h.edges[1]
    y = h.edges[2]
    @test plt[1][] ≈ x[1:end-1] .+ step(x)/2
    @test plt[2][] ≈ y[1:end-1] .+ step(y)/2
    @test plt[3][] ≈ h.weights

    fig, ax, plt = surface(h)
    @test plt isa Surface
    x = h.edges[1]
    y = h.edges[2]
    @test plt[1][] ≈ x[1:end-1] .+ step(x)/2
    @test plt[2][] ≈ y[1:end-1] .+ step(y)/2
    @test plt[3][] ≈ h.weights

    v = (randn(1000), randn(1000), randn(1000))
    edges = ntuple(_ -> -3:0.3:3, 3)
    h = fit(Histogram, v, edges)
    fig, ax, plt = plot(h)
    @test plt isa Volume
    x = h.edges[1]
    y = h.edges[2]
    z = h.edges[3]
    @test plt[1][] ≈ x[1:end-1] .+ step(x)/2
    @test plt[2][] ≈ y[1:end-1] .+ step(y)/2
    @test plt[3][] ≈ z[1:end-1] .+ step(z)/2
    @test plt[4][] == h.weights
end

@testset "density" begin
    v = randn(1000)
    d = kde(v)
    fig, ax, p1 = plot(d)
    @test p1 isa Lines
    fig, ax, p2 = lines(d.x, d.density)
    @test p1[1][] == p2[1][]

    x = randn(1000)
    y = randn(1000)
    d = kde((x, y))
    fig, ax, p1 = plot(d)
    @test p1 isa Heatmap
    fig, ax, p2 = heatmap(d.x, d.y, d.density)
    @test p1[1][] == p2[1][]
    @test p1[2][] == p2[2][]
    @test p1[3][] == p2[3][]

    fig, ax, p1 = surface(d)
    @test p1 isa Surface
    fig, ax, p2 = surface(d.x, d.y, d.density)
    @test p1[1][] == p2[1][]
    @test p1[2][] == p2[2][]
    @test p1[3][] == p2[3][]
end

@testset "distribution" begin
    d = Distributions.Normal()
    rg = Makie.support(d)
    @test minimum(rg) ≈ -3.7190164854556866
    @test maximum(rg) ≈ 3.719016485455714
    fix, ax, plt = plot(d)
    @test plt isa Lines
    @test !Makie.isdiscrete(d)
    @test first(plt[1][][1]) ≈ minimum(rg) rtol = 1f-6
    @test first(plt[1][][end]) ≈ maximum(rg) rtol = 1f-6

    for (x, pd) in plt[1][]
        @test pd ≈ Distributions.pdf(d, x) rtol = 1f-6
    end

    d = Distributions.Poisson()
    rg = Makie.support(d)
    @test rg == 0:6
    fig, ax, p = plot(d)
    @test p isa ScatterLines
    plt = p.plots[1]
    @test Makie.isdiscrete(d)

    @test first.(plt[1][]) == 0:6
    @test last.(plt[1][]) ≈ Distributions.pdf.(d, first.(plt[1][]))
end

@testset "qqplot" begin
    v = randn(1000)
    q = Distributions.qqbuild(fit(Distributions.Normal, v), v)
    fig, ax, p = qqnorm(v)

    @test length(p.plots) == 2
    plt = p.plots[1]
    @test plt isa Scatter
    @test first.(plt[1][]) ≈ q.qx rtol = 1e-6
    @test last.(plt[1][]) ≈ q.qy rtol = 1e-6

    plt = p.plots[2]
    @test plt isa LineSegments
    @test first.(plt[1][]) ≈ [extrema(q.qx)...] rtol = 1e-6
    @test last.(plt[1][]) ≈ [extrema(q.qx)...] rtol = 1e-6

    fig, ax, p = qqnorm(v, qqline = nothing)
    @test length(p.plots) == 1
    plt = p.plots[1]
    @test plt isa Scatter
    @test first.(plt[1][]) ≈ q.qx rtol = 1e-6
    @test last.(plt[1][]) ≈ q.qy rtol = 1e-6

    fig, ax, p = qqnorm(v, qqline = :fit)
    plt = p.plots[2]
    itc, slp = hcat(fill!(similar(q.qx), 1), q.qx) \ q.qy
    xs = [extrema(q.qx)...]
    ys = slp .* xs .+ itc
    @test first.(plt[1][]) ≈ xs rtol = 1e-6
    @test last.(plt[1][]) ≈ ys rtol = 1e-6

    fig, ax, p = qqnorm(v, qqline = :quantile)
    plt = p.plots[2]
    xs = [extrema(q.qx)...]
    quantx, quanty = quantile(q.qx, [0.25, 0.75]), quantile(q.qy, [0.25, 0.75])
    slp = diff(quanty) ./ diff(quantx)
    ys = quanty .+ slp .* (xs .- quantx)
    @test first.(plt[1][]) ≈ xs rtol = 1e-6
    @test last.(plt[1][]) ≈ ys rtol = 1e-6
end

@testset "crossbar" begin
    fig, ax, p = crossbar(1, 3, 2, 4)
    @test p isa CrossBar
    @test p.plots[1] isa Poly
    @test p.plots[1][1][] == [Rect2f(Float32[0.6, 2.0], Float32[0.8, 2.0]),]
    @test p.plots[2] isa LineSegments
    @test p.plots[2][1][] == Point{2,Float32}[Float32[0.6, 3.0], Float32[1.4, 3.0]]

    fig, ax, p = crossbar(1, 3, 2, 4; show_notch = true, notchmin = 2.5, notchmax = 3.5);
    @test p isa CrossBar
    @test p.plots[1] isa Poly
    @test p.plots[1][1][][1] isa Makie.AbstractMesh
    poly = Point{2,Float32}[[0.6, 2.0], [1.4, 2.0], [1.4, 2.5], [1.2, 3.0], [1.4, 3.5],
                            [1.4, 4.0], [0.6, 4.0], [0.6, 3.5], [0.8, 3.0], [0.6, 2.5]]
    @test map(Point2f, p.plots[1][1][][1].position) == poly
    @test p.plots[2] isa LineSegments
    @test p.plots[2][1][] == Point{2,Float32}[Float32[0.8, 3.0], Float32[1.2, 3.0]]
end

@testset "boxplot" begin
    a = repeat(1:5, inner = 20)
    b = 1:100
    fig, ax, p = boxplot(a, b)
    plts = p.plots
    @test length(plts) == 3
    @test plts[1] isa Scatter
    @test isempty(plts[1][1][])

    # test categorical
    a = repeat(["a", "b", "c", "d", "e"], inner = 20)
    b = 1:100
    fig, ax, p = boxplot(a, b; whiskerwidth = 1.0)
    plts = p.plots
    @test length(plts) == 3
    @test plts[1] isa Scatter
    @test isempty(plts[1][1][])

    @test plts[2] isa LineSegments
    pts = Point{2, Float32}[
        [1.0, 5.75], [1.0, 1.0], [0.6, 1.0], [1.4, 1.0], [1.0, 15.25],
        [1.0, 20.0], [1.4, 20.0], [0.6, 20.0], [2.0, 25.75], [2.0, 21.0],
        [1.6, 21.0], [2.4, 21.0], [2.0, 35.25], [2.0, 40.0], [2.4, 40.0],
        [1.6, 40.0], [3.0, 45.75], [3.0, 41.0], [2.6, 41.0], [3.4, 41.0],
        [3.0, 55.25], [3.0, 60.0], [3.4, 60.0], [2.6, 60.0], [4.0, 65.75],
        [4.0, 61.0], [3.6, 61.0], [4.4, 61.0], [4.0, 75.25], [4.0, 80.0],
        [4.4, 80.0], [3.6, 80.0], [5.0, 85.75], [5.0, 81.0], [4.6, 81.0],
        [5.4, 81.0], [5.0, 95.25], [5.0, 100.0], [5.4, 100.0], [4.6, 100.0]
    ]
    @test plts[2][1][] == pts

    @test plts[3] isa CrossBar
    @test plts[3].plots[1] isa Poly

    poly = [
        Rect2f(Float32[0.6, 5.75], Float32[0.8, 9.5]),
        Rect2f(Float32[1.6, 25.75], Float32[0.8, 9.5]),
        Rect2f(Float32[2.6, 45.75], Float32[0.8, 9.5]),
        Rect2f(Float32[3.6, 65.75], Float32[0.8, 9.5]),
        Rect2f(Float32[4.6, 85.75], Float32[0.8, 9.5]),
    ]

    @test plts[3].plots[1][1][] == poly

    #notch
    fig, ax, p = boxplot(a, b, show_notch=true)
    plts = p.plots

    @test length(plts) == 3

    pts = Point{2,Float32}[
        [1.0, 5.75], [1.0, 1.0], [1.0, 1.0], [1.0, 1.0], [1.0, 15.25],
        [1.0, 20.0], [1.0, 20.0], [1.0, 20.0], [2.0, 25.75], [2.0, 21.0],
        [2.0, 21.0], [2.0, 21.0], [2.0, 35.25], [2.0, 40.0], [2.0, 40.0],
        [2.0, 40.0], [3.0, 45.75], [3.0, 41.0], [3.0, 41.0], [3.0, 41.0],
        [3.0, 55.25], [3.0, 60.0], [3.0, 60.0], [3.0, 60.0], [4.0, 65.75],
        [4.0, 61.0], [4.0, 61.0], [4.0, 61.0], [4.0, 75.25], [4.0, 80.0],
        [4.0, 80.0], [4.0, 80.0], [5.0, 85.75], [5.0, 81.0], [5.0, 81.0],
        [5.0, 81.0], [5.0, 95.25], [5.0, 100.0], [5.0, 100.0], [5.0, 100.0],
    ]

    @test plts[2] isa LineSegments
    @test plts[2][1][] == pts

    @test plts[3] isa CrossBar
    @test plts[3].plots[1] isa Poly

    notch_boxes = Vector{Point{2,Float32}}[map(Point2f, [[0.6, 5.75], [1.4, 5.75], [1.4, 7.14366], [1.2, 10.5], [1.4, 13.8563], [1.4, 15.25], [0.6, 15.25], [0.6, 13.8563], [0.8, 10.5], [0.6, 7.14366]]),
                                           map(Point2f, [[1.6, 25.75], [2.4, 25.75], [2.4, 27.1437], [2.2, 30.5], [2.4, 33.8563], [2.4, 35.25], [1.6, 35.25], [1.6, 33.8563], [1.8, 30.5], [1.6, 27.1437]]),
                                           map(Point2f, [[2.6, 45.75], [3.4, 45.75], [3.4, 47.1437], [3.2, 50.5], [3.4, 53.8563], [3.4, 55.25], [2.6, 55.25], [2.6, 53.8563], [2.8, 50.5], [2.6, 47.1437]]),
                                           map(Point2f, [[3.6, 65.75], [4.4, 65.75], [4.4, 67.1437], [4.2, 70.5], [4.4, 73.8563], [4.4, 75.25], [3.6, 75.25], [3.6, 73.8563], [3.8, 70.5], [3.6, 67.1437]]),
                                           map(Point2f, [[4.6, 85.75], [5.4, 85.75], [5.4, 87.1437], [5.2, 90.5], [5.4, 93.8563], [5.4, 95.25], [4.6, 95.25], [4.6, 93.8563], [4.8, 90.5], [4.6, 87.1437]])]
    meshes = plts[3].plots[1][1][]
    @testset for (i, mesh) in enumerate(meshes)
        @test mesh isa Makie.AbstractMesh
        vertices = map(Point2f, mesh.position)
        @test vertices ≈ notch_boxes[i]
    end
end

@testset "violin" begin
    x = repeat(1:4, 250)
    y = x .+ randn.()
    fig, ax, p = violin(x, y, side = :left, color = :blue)
    @test p isa Violin
    @test p.plots[1] isa Poly
    @test p.plots[1][:color][] == :blue
    @test p.plots[2] isa LineSegments
    @test p.plots[2][:color][] == :white
    @test p.plots[2][:visible][] == :false

    # test categorical
    x = repeat(["a", "b", "c", "d"], 250)
    fig2, ax2, p2 = violin(x, y, side = :left, color = :blue)
    @test p2 isa Violin
    @test p2.plots[1] isa Poly
    @test p2.plots[1][:color][] == :blue
    @test p2.plots[2] isa LineSegments
    @test p2.plots[2][:color][] == :white
    @test p2.plots[2][:visible][] == :false
end
