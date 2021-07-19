# # RecipesPipeline API implementation

# ## Types and aliases

const PlotContext = Union{
                    AbstractScene,
                    AbstractPlot,
                    MakieLayout.LAxis
                }

# ## API implementation

# Define overrides for RecipesPipeline hooks.

RecipesBase.apply_recipe(plotattributes, ::Type{T}, ::PlotContext) where T = throw(MethodError("Unmatched plot type: $T"))

# Preprocessing involves resetting the palette for now.
# Later, it may involve setting up a layouting context, among other things.
function RecipesPipeline.preprocess_attributes!(plt::PlotContext, plotattributes)
    plt.palette[].i[] = zero(UInt8)
end


# Allow a series type to be plotted.
RecipesPipeline.is_seriestype_supported(sc::PlotContext, st) = haskey(makie_seriestype_map, st)

# Forward the argument preprocessing to Plots for now.
RecipesPipeline.series_defaults(sc::PlotContext, args...) = Dict{Symbol, Any}()

# Pre-processing of user recipes
function RecipesPipeline.process_userrecipe!(sc::PlotContext, kw_list, kw)
    if isa(get(kw, :marker_z, nothing), Function)
        # TODO: should this take y and/or z as arguments?
        kw[:marker_z] = isa(kw[:z], Nothing) ? map(kw[:marker_z], kw[:x], kw[:y]) :
            map(kw[:marker_z], kw[:x], kw[:y], kw[:z])
    end

    # map line_z if it's a Function
    if isa(get(kw, :line_z, nothing), Function)
        kw[:line_z] = isa(kw[:z], Nothing) ? map(kw[:line_z], kw[:x], kw[:y]) :
            map(kw[:line_z], kw[:x], kw[:y], kw[:z])
    end

    push!(kw_list, kw)
end

# Determine axis limits
function RecipesPipeline.get_axis_limits(sc::PlotContext, f, letter)
    lims = to_value(data_limits(sc))
    i = if letter === :x
            1
        elseif letter === :y
            2
        elseif letter === :z
            3
        else
            throw(ArgumentError("Letter $letter does not correspond to an axis."))
        end

    o = origin(lims)
    return (o[i], o[i] + widths(lims)[i])
end

########################################
#       Series argument slicing        #
########################################

function slice_arg(v::AbstractMatrix, idx::Int)
    c = mod1(idx, size(v,2))
    m,n = axes(v)
    size(v,1) == 1 ? v[first(m),n[c]] : v[:,n[c]]
end
# slice_arg(wrapper::Plots.InputWrapper, idx) = wrapper.obj
slice_arg(v, idx) = v

# function RecipesPipeline.slice_series_attributes!(sc::PlotContext, kw_list, kw)
#     idx = Int(kw[:series_plotindex]) - Int(kw_list[1][:series_plotindex]) + 1
#
#     for k in keys(Plots._series_defaults)
#         if haskey(kw, k)
#         end
#     end
# end

# Series type conversions

"""
    makie_plottype(st::Symbol)

Returns the Makie plot type which corresponds to the given seriestype.
The plot type is returned as a Type (`Lines`, `Scatter`, ...).
"""
function makie_plottype(st::Symbol)
    return get(makie_seriestype_map, st, Lines)
end

makie_args(::Type{T}, plotattributes) where T <: AbstractPlot = makie_args(conversion_trait(T), plotattributes)

function makie_args(::PointBased, plotattributes)

    x, y = (plotattributes[:x], plotattributes[:y])

    if isempty(x) && isempty(y)
        @debug "Encountered an empty series of seriestype $(plotattributes[:seriestype])"
        return
    end

    if !isnothing(get(plotattributes, :z, nothing))
        return (plotattributes[:x], plotattributes[:y], plotattributes[:z])
    else
        return (plotattributes[:x], plotattributes[:y])
    end
end

# TODO use Makie.plottype
makie_args(::SurfaceLike, plotattributes) = (plotattributes[:x], plotattributes[:y], plotattributes[:z].surf)

makie_args(::Type{<: Contour}, plotattributes) = (plotattributes[:x], plotattributes[:y], plotattributes[:z].surf)

function makie_args(::Type{<: Poly}, plotattributes)
    return (from_nansep_vec(Point2f.(plotattributes[:x], plotattributes[:y])),)
end

function translate_to_makie!(st, pa)

    # general translations first

    # handle colormap
    haskey(pa, :cgrad) && (pa[:colormap] = pa[:cgrad])

    # series color population
    haskey(pa, :seriescolor) && (pa[:color] = pa[:seriescolor])

    haskey(pa, :fill_z) && (pa[:color] = pa[:fill_z])
    pa[:shading] = false # set shading to false, default in Plots

    pa[:linestyle] = get(pa, :linestyle, :auto)

    if pa[:linestyle] ∈ (:auto, :solid)
        pa[:linestyle] = nothing
    end

    # series color
    if st ∈ (:path, :path3d, :curves)

        if !isnothing(get(pa, :line_z, nothing))
            pa[:color] = pa[:line_z]
        elseif !isnothing(get(pa, :linecolor, nothing))
            pa[:color] = pa[:linecolor]
        elseif !isnothing(get(pa, :seriescolor, nothing))
            pa[:color] = pa[:seriescolor]
        end

        pa[:linewidth] = get(pa, :linewidth, 1)

    elseif st == :scatter
        if !isnothing(get(pa, :color, nothing))
            # pa[:color] = pa[:color]
        end
        if !isnothing(get(pa, :marker_z, nothing))
            pa[:color] = pa[:marker_z]
        end
        if !isnothing(get(pa, :markercolor, nothing))
            pa[:color] = pa[:markercolor]
        end
        if haskey(pa, :nodecolor)
            if pa[:nodecolor] isa Int
                pa[:color] = get(pa, :palette, default_palette).colors[pa[:nodecolor]]
            else
                pa[:color] = pa[:nodecolor]
            end
            return
        end

        if haskey(pa, :markercolor)
            if pa[:markercolor] isa Int
                pa[:color] = get(pa, :palette, default_palette).colors[pa[:markercolor]]
            else
                pa[:color] = pa[:markercolor]
            end
            return
        end
        if !isnothing(get(pa, :seriescolor, nothing))
            pa[:color] = pa[:seriescolor]
        end

        pa[:markersize] = get(pa, :markersize, 5) * 5 * px

        # handle strokes
        pa[:strokewidth] = get(pa, :markerstrokewidth, 1)
        pa[:strokecolor] = get(pa, :markerstrokecolor, :transparent)
    elseif st ∈ (:surface, :heatmap, :image)
        haskey(pa, :fill_z) && (pa[:color] = pa[:fill_z])
        pa[:shading] = false # set shading to false, default in Plots
    elseif st == :contour
        # pa[:levels] = pa[:levels]
    elseif st == :bar
        haskey(pa, :widths) && (pa[:width] = pa[:widths])
    elseif st == :shape
        if haskey(pa, :nodecolor)
            if pa[:nodecolor] isa Int
                pa[:color] = get(pa, :palette, default_palette).colors[pa[:nodecolor]]

            else
                pa[:color] = pa[:nodecolor]
            end
            return
        end

        if haskey(pa, :fillcolor)
            if pa[:fillcolor] isa Int
                pa[:color] = get(pa, :palette, default_palette).colors[pa[:fillcolor]]
            else
                pa[:color] = pa[:fillcolor]
            end
            return
        end

        haskey(pa, :fillcolor) && (pa[:color] = pa[:fillcolor]; return)
        haskey(pa, :markercolor) && (pa[:color] = pa[:markercolor]; return)

        # handle strokes
        pa[:strokewidth] = get(pa, :markerstrokewidth, 1)
        pa[:strokecolor] = get(pa, :markerstrokecolor, :transparent)
    else
        # some default transformations
    end

end

########################################
#      The real plotting function      #
########################################

function set_series_color!(scene, st, plotattributes)

    has_color = (haskey(plotattributes, :color) && plotattributes[:color] !== automatic) || any(
        if st ∈ (:path, :path3d, :curves)
            haskey.(Ref(plotattributes), (:linecolor, :line_z, :seriescolor))
        elseif st == :scatter
            haskey.(Ref(plotattributes), (:markercolor, :marker_z, :seriescolor))
        elseif st ∈ (:shape, :heatmap, :image, :surface, :contour, :bar)
            haskey.(Ref(plotattributes), (:fillcolor, :fill_z, :seriescolor, :cgrad))
        else # what else?
            haskey.(Ref(plotattributes), (:linecolor, :markercolor, :fillcolor, :line_z, :marker_z, :fill_z, :seriescolor))
        end
    )

    has_seriescolor = haskey(plotattributes, :seriescolor)

    if has_color
        if haskey(plotattributes, :color) && plotattributes[:color] isa Automatic
            delete!(plotattributes, :color)
        end
        if has_seriescolor
            if plotattributes[:seriescolor] ∈ (:match, :auto)
                @debug "Assigning new seriescolor from automatic"
                delete!(plotattributes, :seriescolor)
                # printstyled(st, color=:yellow)
                # println()
            else
                # printstyled(st, color=:green)
                # println()
                return nothing # series has seriescolor
            end
        else
            # printstyled(st; color = :blue)
            # println()
            return nothing
        end


    else # TODO FIXME DEBUG REMOVE
        # printstyled(st; color = :red)
        # println()
    end

    if !(plot isa Union{Heatmap, Surface, Image, Spy, Axis2D, Axis3D})

        get!(plotattributes, :seriescolor, to_color(plotattributes[:palette]))

    end

    return nothing

end

function set_palette!(plt, plotattributes)
    pt = get!(plotattributes, :palette, default_palette)
    if pt isa Palette
        # nothing
    elseif pt isa Vector{<: Colorant}
        plotattributes[:palette] = Palette(pt)
    else
        @warn "Palette was unrecognizable!"
    end
end

function plot_series_annotations!(plt, args, pt, plotattributes)

    sa = plotattributes[:series_annotations]

    positions = Point2f.(plotattributes[:x], plotattributes[:y])

    strs = sa[1]

    bbox_shape = sa[2]

    fontsize = sa[3]

    @debug("Series annotations say hi")

    annotations!(plt, strs, positions; textsize = fontsize/30, align = (:center, :center), color = get(plotattributes, :textcolor, :black))

end

function plot_annotations!(plt, args, pt, plotattributes)

    sa = plotattributes[:annotations]

    positions = Point2f.(plotattributes[:x], plotattributes[:y])

    strs = string.(getindex.(sa, 3))

    fontsizes = Float32.(getindex.(sa, 4))

    @debug("Annotations say hi")

    annotations!(plt, strs, positions; textsize = fontsizes ./ 80, align = (:center, :center), color = get(plotattributes, :textcolor, :black))

end

function plot_fill!(plt, args, pt, plotattributes)
    lowerval, opacity, color = plotattributes[:fill]
    upper = plotattributes[:y]
    x = plotattributes[:x]

    lower = fill(lowerval, size(x))

    c = to_color(color)
    bandcolor = RGBA(red(c), green(c), blue(c), alpha(c) * opacity)

    band!(plt, x, upper, lower; color = bandcolor)
end

# Add the "series" to the Scene.
function RecipesPipeline.add_series!(plt::PlotContext, plotattributes)

    # extract the seriestype
    st = plotattributes[:seriestype]

    pt = makie_plottype(st)

    theme = default_theme(plt, pt)

    set_palette!(plt, plotattributes)

    set_series_color!(plt, st, plotattributes)

    translate_to_makie!(st, plotattributes)

    args = makie_args(pt, plotattributes)

    for (k, v) in pairs(plotattributes)
        isnothing(v) && delete!(plotattributes, k)
    end

    ap_attrs = copy(plotattributes)
    for (k, v) in pairs(ap_attrs)
        haskey(theme, k) || delete!(ap_attrs, k)
    end

    # @infiltrate

    if args === nothing
        @debug "Found an empty series with type $(plotattributes[:seriestype])."
        return plt
    end

    plot!(plt, pt, args...; ap_attrs...)

    # handle fill and series annotations after, so they can overdraw

    !isnothing(get(plotattributes, :fill, nothing)) && plot_fill!(plt, args, pt, plotattributes)

    haskey(plotattributes, :annotations) && plot_annotations!(plt, args, pt, plotattributes)

    !isnothing(get(plotattributes, :series_annotations, nothing)) && plot_series_annotations!(plt, args, pt, plotattributes)

    return plt
end
