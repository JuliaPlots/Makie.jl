# Minimal sanity checks for MakieLayout
@testset "Layoutables constructors" begin
    scene, layout = layoutscene()
    ax = layout[1, 1] = Axis(scene)
    cb = layout[1, 2] = Colorbar(scene)
    gl2 = layout[2, :] = MakieLayout.GridLayout()
    bu = gl2[1, 1] = Button(scene)
    sl = gl2[1, 2] = Slider(scene)

    scat = scatter!(ax, rand(10))
    le = gl2[1, 3] = Legend(scene, [scat], ["scatter"])

    to = gl2[1, 4] = Toggle(scene)
    te = layout[0, :] = Label(scene, "A super title")
    me = layout[end + 1, :] = Menu(scene, options=["one", "two", "three"])
    tb = layout[end + 1, :] = Textbox(scene)
    is = layout[end + 1, :] = IntervalSlider(scene)
    @test true
end

@testset "deleting from axis" begin
    f = Figure()
    ax = Axis(f[1, 1])
    sc = scatter!(ax, randn(100, 2))
    li = lines!(ax, randn(100, 2))
    hm = heatmap!(ax, randn(20, 20))
    # axis contains 3 + 1 plots, one for the zoomrectangle
    @test length(ax.scene.plots) == 4
    delete!(ax, sc)
    @test length(ax.scene.plots) == 3
    @test sc ∉ ax.scene.plots
    empty!(ax)
    @test isempty(ax.scene.plots)
end

@testset "Axis limits basics" begin
    f = Figure()
    ax = Axis(f[1, 1], limits = (nothing, nothing))
    ax.targetlimits[] = BBox(0, 10, 0, 20)
    @test ax.finallimits[] == BBox(0, 10, 0, 20)
    @test ax.limits[] == (nothing, nothing)
    xlims!(ax, -10, 10)
    @test ax.limits[] == ((-10, 10), nothing)
    @test ax.finallimits[] == BBox(-10, 10, 0, 20)
    ylims!(ax, -20, 30)
    @test ax.limits[] == ((-10, 10), (-20, 30))
    @test ax.finallimits[] == BBox(-10, 10, -20, 30)
    limits!(ax, -5, 5, -10, 10)
    @test ax.finallimits[] == BBox(-5, 5, -10, 10)
    @test ax.limits[] == ((-5, 5), (-10, 10))
    ax.limits[] = (nothing, nothing)
    ax.xautolimitmargin = (0, 0)
    ax.yautolimitmargin = (0, 0)
    scatter!(Point2f[(0, 0), (1, 2)])
    @test ax.limits[] == (nothing, nothing)
    @test ax.targetlimits[] == BBox(0, 1, 0, 2)
    @test ax.finallimits[] == BBox(0, 1, 0, 2)
    scatter!(Point2f(3, 4))
    @test ax.limits[] == (nothing, nothing)
    @test ax.targetlimits[] == BBox(0, 3, 0, 4)
    @test ax.finallimits[] == BBox(0, 3, 0, 4)
    limits!(ax, -1, 1, 0, 2)
    @test ax.limits[] == ((-1, 1), (0, 2))
    @test ax.targetlimits[] == BBox(-1, 1, 0, 2)
    @test ax.finallimits[] == BBox(-1, 1, 0, 2)
    scatter!(Point2f(5, 6))
    @test ax.limits[] == ((-1, 1), (0, 2))
    @test ax.targetlimits[] == BBox(-1, 1, 0, 2)
    @test ax.finallimits[] == BBox(-1, 1, 0, 2)
    autolimits!(ax)
    @test ax.limits[] == (nothing, nothing)
    @test ax.targetlimits[] == BBox(0, 5, 0, 6)
    @test ax.finallimits[] == BBox(0, 5, 0, 6)
    xlims!(-10, 10)
    @test ax.limits[] == ((-10, 10), nothing)
    @test ax.targetlimits[] == BBox(-10, 10, 0, 6)
    @test ax.finallimits[] == BBox(-10, 10, 0, 6)
    scatter!(Point2f(11, 12))
    @test ax.limits[] == ((-10, 10), nothing)
    @test ax.targetlimits[] == BBox(-10, 10, 0, 12)
    @test ax.finallimits[] == BBox(-10, 10, 0, 12)
    autolimits!(ax)
    ylims!(ax, 5, 7)
    @test ax.limits[] == (nothing, (5, 7))
    @test ax.targetlimits[] == BBox(0, 11, 5, 7)
    @test ax.finallimits[] == BBox(0, 11, 5, 7)
    scatter!(Point2f(-5, -7))
    @test ax.limits[] == (nothing, (5, 7))
    @test ax.targetlimits[] == BBox(-5, 11, 5, 7)
    @test ax.finallimits[] == BBox(-5, 11, 5, 7)
end

@testset "Colorbar plot object kwarg clash" begin
    for attr in (:colormap, :limits)
        f, ax, p = scatter(1:10, 1:10, color = 1:10, colorrange = (1, 10))
        Colorbar(f[2, 1], p)
        @test_throws ErrorException Colorbar(f[2, 1], p; Dict(attr => nothing)...)
    end

    for attr in (:colormap, :limits, :highclip, :lowclip)
        for F in (heatmap, contourf)
            f, ax, p = F(1:10, 1:10, randn(10, 10))
            Colorbar(f[1, 2], p)
            @test_throws ErrorException Colorbar(f[1, 3], p; Dict(attr => nothing)...)
        end
    end
end

@testset "Tick functions" begin
    automatic = Makie.automatic
    Automatic = Makie.Automatic

    get_ticks = MakieLayout.get_ticks
    get_tickvalues = MakieLayout.get_tickvalues
    get_ticklabels = MakieLayout.get_ticklabels

    for func in [identity, log, log2, log10, Makie.logit]
        tup = ([1, 2, 3], ["a", "b", "c"])
        @test get_ticks(tup, func, automatic, 0, 5) == tup

        rng = 1:5
        @test get_ticks(rng, func, automatic, 0, 5) == ([1, 2, 3, 4, 5], ["1", "2", "3", "4", "5"])

        numbers = [1.0, 1.5, 2.0]
        @test get_ticks(numbers, func, automatic, 0, 5) == (numbers, ["1.0", "1.5", "2.0"])

        @test get_ticks(numbers, func, xs -> string.(xs) .* "kg", 0, 5) == (numbers, ["1.0kg", "1.5kg", "2.0kg"])

        @test get_ticks(WilkinsonTicks(5), identity, automatic, 1, 5) == ([1, 2, 3, 4, 5], ["1", "2", "3", "4", "5"])
    end
end
