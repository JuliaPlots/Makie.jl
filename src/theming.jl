const DEFAULT_RESOLUTION = Ref((1920, 1080))

if Sys.iswindows()
    function primary_resolution()
        dc = ccall((:GetDC, :user32), Ptr{Cvoid}, (Ptr{Cvoid},), C_NULL)
        ntuple(2) do i
            Int(ccall((:GetDeviceCaps, :gdi32), Cint, (Ptr{Cvoid}, Cint), dc, (2 - i) + 117))
        end
    end
elseif Sys.isapple()
    const _CoreGraphics = "CoreGraphics.framework/CoreGraphics"
    function primary_resolution()
        dispid = ccall((:CGMainDisplayID, _CoreGraphics), UInt32,())
        height = ccall((:CGDisplayPixelsHigh,_CoreGraphics), Int, (UInt32,), dispid)
        width = ccall((:CGDisplayPixelsWide,_CoreGraphics), Int, (UInt32,), dispid)
        return (width, height)
    end
else
    # TODO implement linux
    primary_resolution() = DEFAULT_RESOLUTION[]
end

"""
Returns the resolution of the primary monitor.
If the primary monitor can't be accessed, returns (1920, 1080) (full hd)
"""
function primary_resolution end


#=
Conservative 7-color palette from Points of view: Color blindness, Bang Wong - Nature Methods
https://www.nature.com/articles/nmeth.1618?WT.ec_id=NMETH-201106
=#

function wong_colors(alpha = 1.0)
    colors = [
        RGB(0/255, 114/255, 178/255), # blue
        RGB(230/255, 159/255, 0/255), # orange
        RGB(0/255, 158/255, 115/255), # green
        RGB(204/255, 121/255, 167/255), # reddish purple
        RGB(86/255, 180/255, 233/255), # sky blue
        RGB(213/255, 94/255, 0/255), # vermillion
        RGB(240/255, 228/255, 66/255), # yellow
    ]
    @. RGBAf(red(colors), green(colors), blue(colors), alpha)
end

const default_palettes = Attributes(
    color = wong_colors(1),
    patchcolor = Makie.wong_colors(0.8),
    marker = [:circle, :utriangle, :cross, :rect, :diamond, :dtriangle, :pentagon, :xcross],
    linestyle = [nothing, :dash, :dot, :dashdot, :dashdotdot],
    side = [:left, :right]
)

const minimal_default = Attributes(
    palette = default_palettes,
    font = "Dejavu Sans",
    textcolor = :black,
    padding = Vec3f(0.05),
    figure_padding = 16,
    rowgap = 24,
    colgap = 24,
    backgroundcolor = :white,
    colormap = :viridis,
    marker = Circle,
    markersize = 9,
    markercolor = :black,
    markerstrokecolor = :black,
    markerstrokewidth = 0,
    linecolor = :black,
    linewidth = 1.5,
    linestyle = nothing,
    patchcolor = RGBAf(0, 0, 0, 0.6),
    patchstrokecolor = :black,
    patchstrokewidth = 0,
    resolution = (800, 600), # 4/3 aspect ratio
    visible = true,
    clear = true,
    show_axis = true,
    show_legend = false,
    scale_plot = true,
    center = true,
    update_limits = true,
    axis = Attributes(),
    axis3d = Attributes(),
    legend = Attributes(),
    axis_type = automatic,
    camera = automatic,
    limits = automatic,
    raw = false,
    SSAO = Attributes(
        # enable = false,
        bias = 0.025f0,       # z threshhold for occlusion
        radius = 0.5f0,       # range of sample positions (in world space)
        blur = Int32(2),      # A (2blur+1) by (2blur+1) range is used for blurring
        # N_samples = 64,       # number of samples (requires shader reload)
    ),
    inspectable = true
)

const _current_default_theme = deepcopy(minimal_default)

function current_default_theme(; kw_args...)
    return merge!(Attributes(kw_args), deepcopy(_current_default_theme))
end

"""
    set_theme(theme; kwargs...)

Set the global default theme to `theme` and add / override any attributes given
as keyword arguments.
"""
function set_theme!(new_theme = Theme()::Attributes; kwargs...)
    empty!(_current_default_theme)
    new_theme = merge!(deepcopy(new_theme), deepcopy(minimal_default))
    new_theme = merge!(Theme(kwargs), new_theme)
    merge!(_current_default_theme, new_theme)
    return
end

"""
    with_theme(f, theme = Theme(); kwargs...)

Calls `f` with `theme` temporarily activated. Attributes in `theme`
can be overridden or extended with `kwargs`. The previous theme is always
restored afterwards, no matter if `f` succeeds or fails.

Example:

```julia
my_theme = Theme(resolution = (500, 500), color = :red)
with_theme(my_theme, color = :blue, linestyle = :dashed) do
    scatter(randn(100, 2))
end
```
"""
function with_theme(f, theme = Theme(); kwargs...)
    previous_theme = Makie.current_default_theme()
    try
        set_theme!(theme; kwargs...)
        f()
    catch e
        rethrow(e)
    finally
        set_theme!(previous_theme)
    end
end

theme(::Nothing, key::Symbol) = deepcopy(current_default_theme()[key])
  
"""
    update_theme!(with_theme::Theme; kwargs...)

Updates the current theme incrementally, that means only the keys given in `with_theme` or through keyword arguments are changed, the rest is left intact.
Nested attributes are either also updated incrementally, or replaced if they are not attributes in the new theme.
"""
function update_theme!(with_theme = Theme()::Attributes; kwargs...)
    new_theme = merge!(with_theme, Theme(kwargs))
    _update_attrs!(_current_default_theme, new_theme)
    return
end

function _update_attrs!(attrs1, attrs2)
    for (key, value) in attrs2
        _update_key!(attrs1, key, value)
    end
end

function _update_key!(theme, key::Symbol, content)
    theme[key] = content
end

function _update_key!(theme, key::Symbol, content::Attributes)
    if haskey(theme, key) && theme[key] isa Attributes
        _update_attrs!(theme[key], content)
    else
        theme[key] = content
    end
    theme
end
