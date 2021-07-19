function Makie.plot!(plot::Plot(AbstractVector{<: Complex}))
    plot[:axis, :labels] = ("Re(x)", "Im(x)")
    lines!(plot, lift(im-> Point2f.(real.(im), imag.(im)), x[1]))
end


"""
    showlibrary(lib::Symbol)::Scene

Shows all colour gradients in the given library.
Returns a Scene with these colour gradients arranged
as horizontal colourbars.
"""
function showlibrary(lib::Symbol)::Scene

    cgrads = sort(PlotUtils.cgradients(lib))

    PlotUtils.clibrary(lib)

    showgradients(cgrads)

end


"""
    showgradients(
        cgrads::AbstractVector{Symbol};
        h = 0.0, offset = 0.2, textsize = 0.7,
        resolution = (800, length(cgrads) * 84)
    )::Scene

Plots the given colour gradients arranged as horizontal colourbars.
If you change the offsets or the font size, you may need to change the resolution.
"""
function showgradients(
        cgrads::AbstractVector{Symbol};
        h = 0.0,
        offset = 0.4,
        textsize = 0.7,
        resolution = (800, length(cgrads) * 84),
        monospace = true
    )::Scene

    scene = Scene(resolution = resolution)

    map(collect(cgrads)) do cmap

         c = to_colormap(cmap)

         cbar = image!(
             scene,
             range(0, stop = 10, length = length(c)),
             range(0, stop = 1, length = length(c)),
             reshape(c, (length(c),1)),
             show_axis = false
         )[end]

         cmapstr = monospace ? UnicodeFun.to_latex("\\mono{$cmap}") : string(cmap, ":")

         text!(
             scene,
             cmapstr,
             position = Point2f(-0.1, 0.5 + h),
             align = (:right, :center),
             show_axis = false,
             textsize = textsize
         )

         translate!(cbar, 0, h, 0)

         h -= (1 + offset)

    end

    scene

end
