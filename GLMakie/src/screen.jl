const ScreenID = UInt8
const ZIndex = Int
# ID, Area, clear, is visible, background color
const ScreenArea = Tuple{ScreenID, Scene}

abstract type GLScreen <: AbstractScreen end

mutable struct Screen <: GLScreen
    glscreen::GLFW.Window
    framebuffer::GLFramebuffer
    rendertask::RefValue{Task}
    screen2scene::Dict{WeakRef, ScreenID}
    screens::Vector{ScreenArea}
    renderlist::Vector{Tuple{ZIndex, ScreenID, RenderObject}}
    postprocessors::Vector{PostProcessor}
    cache::Dict{UInt64, RenderObject}
    cache2plot::Dict{UInt16, AbstractPlot}
    framecache::Matrix{RGB{N0f8}}
    render_tick::Observable{Nothing}
    window_open::Observable{Bool}
    function Screen(
            glscreen::GLFW.Window,
            framebuffer::GLFramebuffer,
            rendertask::RefValue{Task},
            screen2scene::Dict{WeakRef, ScreenID},
            screens::Vector{ScreenArea},
            renderlist::Vector{Tuple{ZIndex, ScreenID, RenderObject}},
            postprocessors::Vector{PostProcessor},
            cache::Dict{UInt64, RenderObject},
            cache2plot::Dict{UInt16, AbstractPlot},
        )
        s = size(framebuffer)
        obj = new(
            glscreen, framebuffer, rendertask, screen2scene,
            screens, renderlist, postprocessors, cache, cache2plot,
            Matrix{RGB{N0f8}}(undef, s), Observable(nothing),
            Observable(true)
        )
    end
end

GeometryBasics.widths(x::Screen) = size(x.framebuffer)

Base.wait(x::Screen) = isassigned(x.rendertask) && wait(x.rendertask[])
Base.wait(scene::Scene) = wait(Makie.getscreen(scene))
Base.show(io::IO, screen::Screen) = print(io, "GLMakie.Screen(...)")
Base.size(x::Screen) = size(x.framebuffer)

function insertplots!(screen::GLScreen, scene::Scene)
    get!(screen.screen2scene, WeakRef(scene)) do
        id = length(screen.screens) + 1
        push!(screen.screens, (id, scene))
        return id
    end
    for elem in scene.plots
        insert!(screen, scene, elem)
    end
    foreach(s-> insertplots!(screen, s), scene.children)
end

function Base.delete!(screen::Screen, scene::Scene, plot::AbstractPlot)
    if !isempty(plot.plots)
        # this plot consists of children, so we flatten it and delete the children instead
        delete!.(Ref(screen), Ref(scene), Makie.flatten_plots(plot))
    else
        renderobject = get(screen.cache, objectid(plot)) do
            error("Could not find $(typeof(subplot)) in current GLMakie screen!")
        end

        # These need explicit clean up because (some of) the source nodes
        # remain whe the plot is deleated.
        for k in (:lightposition, :normalmatrix)
            if haskey(renderobject.uniforms, k)
                n = renderobject.uniforms[k]
                for input in n.inputs
                    off(input)
                end
            end
        end

        filter!(x-> x[3] !== renderobject, screen.renderlist)
    end
end

function Base.empty!(screen::Screen)
    empty!(screen.renderlist)
    empty!(screen.screen2scene)
    empty!(screen.screens)
end

function destroy!(screen::Screen)
    empty!(screen)
    screen.window_open[] = false
    empty!(screen.cache)
    empty!(screen.cache2plot)
    destroy!(screen.glscreen)
end

Base.close(screen::Screen) = destroy!(screen)

function resize_native!(window::GLFW.Window, resolution...; wait_for_resize=true)
    if isopen(window)
        oldsize = windowsize(window)
        retina_scale = retina_scaling_factor(window)
        w, h = resolution ./ retina_scale
        if oldsize == (w, h)
            return
        end
        GLFW.SetWindowSize(window, round(Int, w), round(Int, h))
        # We don't wait for the window to be resized
        wait_for_resize || return
        # There is a problem, that window size update seems to take an arbitrary
        # amount of time - GLFW.WaitEvents() / a single GLFW.PollEvent()
        # doesn't help, so we try it a couple of times, to make sure
        # we have the desired size in the end
        for i in 1:100
            isopen(window) || return
            newsize = windowsize(window)
            # we aren't guaranteed to get exactly w & h, since the window
            # manager is allowed to restrict the size...
            # So we can only test, if the size changed, but not if it matches
            # the desired size!
            newsize != oldsize && return
            # There is a bug here, were without `sleep` it doesn't update the size
            # Not sure who's fault it is, but PollEvents/yield both dont work - only sleep!
            GLFW.PollEvents()
            sleep(0.0001)
        end
    end
end

function Base.resize!(screen::Screen, w, h)
    nw = to_native(screen)
    resize_native!(nw, w, h)
    fb = screen.framebuffer
    resize!(fb, (w, h))
end

function fast_color_data!(dest::Array{RGB{N0f8}, 2}, source::Texture{T, 2}) where T
    GLAbstraction.bind(source)
    glPixelStorei(GL_PACK_ALIGNMENT, 1)
    glGetTexImage(source.texturetype, 0, GL_RGB, GL_UNSIGNED_BYTE, dest)
    GLAbstraction.bind(source, 0)
    nothing
end

"""
depthbuffer(screen::Screen)
Gets the depth buffer of screen.
Usage:
```
using Makie, GLMakie
x = scatter(1:4)
screen = display(x)
depth_color = GLMakie.depthbuffer(screen)
# Look at result:
heatmap(depth_color, colormap=:grays, show_axis=false)
```
"""
function depthbuffer(screen::Screen)
    render_frame(screen, resize_buffers=false) # let it render
    glFinish() # block until opengl is done rendering
    source = screen.framebuffer.buffers[:depth]
    depth = Matrix{Float32}(undef, size(source))
    GLAbstraction.bind(source)
    GLAbstraction.glGetTexImage(source.texturetype, 0, GL_DEPTH_COMPONENT, GL_FLOAT, depth)
    GLAbstraction.bind(source, 0)
    return depth
end

function Makie.colorbuffer(screen::Screen, format::Makie.ImageStorageFormat = Makie.JuliaNative)
    if !isopen(screen)
        error("Screen not open!")
    end
    ctex = screen.framebuffer.buffers[:color]
    # polling may change window size, when its bigger than monitor!
    # we still need to poll though, to get all the newest events!
    # GLFW.PollEvents()
    # keep current buffer size to allows larger-than-window renders
    render_frame(screen, resize_buffers=false) # let it render
    glFinish() # block until opengl is done rendering
    if size(ctex) != size(screen.framecache)
        screen.framecache = Matrix{RGB{N0f8}}(undef, size(ctex))
    end
    fast_color_data!(screen.framecache, ctex)
    if format == Makie.GLNative
        return screen.framecache
    elseif format == Makie.JuliaNative
        @static if VERSION < v"1.6"
            bufc = copy(screen.framecache)
            ind1, ind2 = axes(bufc)
            n = first(ind2) + last(ind2)
            for i in ind1
                @simd for j in ind2
                    @inbounds bufc[i, n-j] = screen.framecache[i, j]
                end
            end
            screen.framecache = bufc
        else
            reverse!(screen.framecache, dims = 2)
        end
        return PermutedDimsArray(screen.framecache, (2,1))
    end
end


Base.isopen(x::Screen) = isopen(x.glscreen)
function Base.push!(screen::GLScreen, scene::Scene, robj)
    # filter out gc'ed elements
    filter!(screen.screen2scene) do (k, v)
        k.value !== nothing
    end
    screenid = get!(screen.screen2scene, WeakRef(scene)) do
        id = length(screen.screens) + 1
        push!(screen.screens, (id, scene))
        return id
    end
    push!(screen.renderlist, (0, screenid, robj))
    return robj
end

to_native(x::Screen) = x.glscreen

"""
OpenGL shares all data containers between shared contexts, but not vertexarrays -.-
So to share a robjs between a context, we need to rewrap the vertexarray into a new one for that
specific context.
"""
function rewrap(robj::RenderObject{Pre}) where Pre
    RenderObject{Pre}(
        robj.main,
        robj.uniforms,
        GLVertexArray(robj.vertexarray),
        robj.prerenderfunction,
        robj.postrenderfunction,
        robj.boundingbox,
    )
end

const GLOBAL_GL_SCREEN = Ref{Screen}()
const gl_screens = GLFW.Window[]

function global_gl_screen()
    screen = if isassigned(GLOBAL_GL_SCREEN) && isopen(GLOBAL_GL_SCREEN[])
        GLOBAL_GL_SCREEN[]
    else
        GLOBAL_GL_SCREEN[] = Screen()
        GLOBAL_GL_SCREEN[]
    end
    return screen
end

"""
Loads the makie loading icon and embedds it in an image the size of resolution
"""
function get_loading_image(resolution)
    icon = Matrix{N0f8}(undef, 192, 192)
    open(joinpath(@__DIR__, "..", "assets", "loading.bin")) do io
        read!(io, icon)
    end
    img = zeros(RGBA{N0f8}, resolution...)
    center = resolution .÷ 2
    center_icon = size(icon) .÷ 2
    start = CartesianIndex(max.(center .- center_icon, 1))
    I1 = CartesianIndex(1, 1)
    stop = min(start + CartesianIndex(size(icon)) - I1, CartesianIndex(resolution))
    for idx in start:stop
        gray = icon[idx - start + I1]
        img[idx] = RGBA{N0f8}(gray, gray, gray, 1.0)
    end
    return img
end

function display_loading_image(screen::Screen)
    fb = screen.framebuffer
    fbsize = size(fb)
    image = get_loading_image(fbsize)
    if size(image) == fbsize
        nw = to_native(screen)
        # transfer loading image to gpu framebuffer
        fb.buffers[:color][1:size(image, 1), 1:size(image, 2)] = image
        ShaderAbstractions.is_context_active(nw) || return
        w, h = fbsize
        glBindFramebuffer(GL_FRAMEBUFFER, 0) # transfer back to window
        glViewport(0, 0, w, h)
        glClearColor(0, 0, 0, 0)
        glClear(GL_COLOR_BUFFER_BIT)
        # GLAbstraction.render(fb.postprocess[end]) # copy postprocess
        GLAbstraction.render(screen.postprocessors[end].robjs[1])
        GLFW.SwapBuffers(nw)
    else
        error("loading_image needs to be Matrix{RGBA{N0f8}} with size(loading_image) == resolution")
    end
end


function Screen(;
        resolution = (10, 10), visible = false, title = WINDOW_CONFIG.title[],
        kw_args...
    )
    if !isempty(gl_screens)
        for elem in gl_screens
            isopen(elem) && destroy!(elem)
        end
        empty!(gl_screens)
    end
    # Somehow this constant isn't wrapped by glfw
    GLFW_FOCUS_ON_SHOW = 0x0002000C
    windowhints = [
        (GLFW.SAMPLES,      0),
        (GLFW.DEPTH_BITS,   0),

        # SETTING THE ALPHA BIT IS REALLY IMPORTANT ON OSX, SINCE IT WILL JUST KEEP SHOWING A BLACK SCREEN
        # WITHOUT ANY ERROR -.-
        (GLFW.ALPHA_BITS,   8),
        (GLFW.RED_BITS,     8),
        (GLFW.GREEN_BITS,   8),
        (GLFW.BLUE_BITS,    8),

        (GLFW.STENCIL_BITS, 0),
        (GLFW.AUX_BUFFERS,  0),
        (GLFW_FOCUS_ON_SHOW, WINDOW_CONFIG.focus_on_show[]),
        (GLFW.DECORATED, WINDOW_CONFIG.decorated[]),
        (GLFW.FLOATING, WINDOW_CONFIG.float[]),
    ]

    window = try
        GLFW.Window(
            name = title, resolution = (10, 10), # 10, because smaller sizes seem to error on some platforms
            windowhints = windowhints,
            visible = false,
            focus = false,
            kw_args...
        )
    catch e
        @warn("""
            GLFW couldn't create an OpenGL window.
            This likely means, you don't have an OpenGL capable Graphic Card,
            or you don't have an OpenGL 3.3 capable video driver installed.
            Have a look at the troubleshooting section in the GLMakie readme:
            https://github.com/JuliaPlots/Makie.jl/tree/master/GLMakie#troubleshooting-opengl.
        """)
        rethrow(e)
    end

    GLFW.SetWindowIcon(window, Makie.icon())

    # tell GLAbstraction that we created a new context.
    # This is important for resource tracking, and only needed for the first context
    ShaderAbstractions.switch_context!(window)
    GLAbstraction.empty_shader_cache!()
    push!(gl_screens, window)

    resize_native!(window, resolution...; wait_for_resize=false)
    fb = GLFramebuffer(resolution)

    postprocessors = [
        enable_SSAO[] ? ssao_postprocessor(fb) : empty_postprocessor(),
        enable_FXAA[] ? fxaa_postprocessor(fb) : empty_postprocessor(),
        to_screen_postprocessor(fb)
    ]

    screen = Screen(
        window, fb,
        RefValue{Task}(),
        Dict{WeakRef, ScreenID}(),
        ScreenArea[],
        Tuple{ZIndex, ScreenID, RenderObject}[],
        postprocessors,
        Dict{UInt64, RenderObject}(),
        Dict{UInt16, AbstractPlot}(),
    )

    GLFW.SetWindowRefreshCallback(window, window -> begin
        screen.render_tick[] = nothing
        render_frame(screen)
        GLFW.SwapBuffers(window)
    end)

    screen.rendertask[] = @async((WINDOW_CONFIG.renderloop[])(screen))
    # display window if visible!
    if visible
        GLFW.ShowWindow(window)
    else
        GLFW.HideWindow(window)
    end
    return screen
end

function global_gl_screen(resolution::Tuple, visibility::Bool, tries = 1)
    # ugly but easy way to find out if we create new screen.
    # could just be returned by global_gl_screen, but dont want to change the API
    isold = isassigned(GLOBAL_GL_SCREEN) && isopen(GLOBAL_GL_SCREEN[])
    screen = global_gl_screen()
    GLFW.set_visibility!(to_native(screen), visibility)
    resize!(screen, resolution...)
    new_size = windowsize(to_native(screen))
    # I'm not 100% sure, if there are platforms where I'm never
    # able to resize the screen (opengl might just allow that).
    # so, we guard against that with just trying another resize one time!
    if (new_size != resolution) && tries == 1
        # resize failed. This may happen when screen was previously
        # enlarged to fill screen. WE NEED TO DESTROY!! (I think)
        destroy!(screen)
        # try again
        return global_gl_screen(resolution, visibility, 2)
    end
    # show loading image on fresh screen
    isold || display_loading_image(screen)
    screen
end



#################################################################################
### Point picking
################################################################################



function pick_native(screen::Screen, rect::Rect2i)
    isopen(screen) || return Matrix{SelectionID{Int}}(undef, 0, 0)
    window_size = widths(screen)
    fb = screen.framebuffer
    buff = fb.buffers[:objectid]
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id[1])
    glReadBuffer(GL_COLOR_ATTACHMENT1)
    rx, ry = minimum(rect)
    rw, rh = widths(rect)
    w, h = window_size
    sid = zeros(SelectionID{UInt32}, widths(rect)...)
    if rx > 0 && ry > 0 && rx + rw <= w && ry + rh <= h
        glReadPixels(rx, ry, rw, rh, buff.format, buff.pixeltype, sid)
        for i in eachindex(sid)
            if sid[i][2] > 0x3f800000
                sid[i] = SelectionID(0, sid[i].index)
            end
        end
        return sid
    else
        error("Pick region $rect out of screen bounds ($w, $h).")
    end
end

function pick_native(screen::Screen, xy::Vec{2, Float64})
    isopen(screen) || return SelectionID{Int}(0, 0)
    sid = Base.RefValue{SelectionID{UInt32}}()
    window_size = widths(screen)
    fb = screen.framebuffer
    buff = fb.buffers[:objectid]
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id[1])
    glReadBuffer(GL_COLOR_ATTACHMENT1)
    x, y = floor.(Int, xy)
    w, h = window_size
    if x > 0 && y > 0 && x <= w && y <= h
        glReadPixels(x, y, 1, 1, buff.format, buff.pixeltype, sid)
        return convert(SelectionID{Int}, sid[])
    end
    return SelectionID{Int}(0, 0)
end

function Makie.pick(scene::SceneLike, screen::Screen, xy::Vec{2, Float64})
    sid = pick_native(screen, xy)
    if haskey(screen.cache2plot, sid.id)
        plot = screen.cache2plot[sid.id]
        return (plot, sid.index)
    else
        return (nothing, 0)
    end
end

function Makie.pick(scene::SceneLike, screen::Screen, rect::Rect2i)
    map(pick_native(screen, rect)) do sid
        if haskey(screen.cache2plot, sid.id)
            (screen.cache2plot[sid.id], sid.index)
        else
            (nothing, sid.index)
        end
    end
end


# Skips one set of allocations
function Makie.pick_closest(scene::SceneLike, screen::Screen, xy, range)
    isopen(screen) || return (nothing, 0)
    w, h = widths(screen)
    ((1.0 <= xy[1] <= w) && (1.0 <= xy[2] <= h)) || return (nothing, 0)

    x0, y0 = max.(1, floor.(Int, xy .- range))
    x1, y1 = min.((w, h), floor.(Int, xy .+ range))
    dx = x1 - x0; dy = y1 - y0
    sid = pick_native(screen, Rect2i(x0, y0, dx, dy))

    min_dist = range^2
    id = SelectionID{Int}(0, 0)
    x, y =  xy .+ 1 .- Vec2f(x0, y0)
    for i in 1:dx, j in 1:dy
        d = (x-i)^2 + (y-j)^2
        if (d < min_dist) && (sid[i, j][1] > 0x00000000) &&
            (sid[i, j][2] < 0x3f800000) && haskey(screen.cache2plot, sid[i, j][1])
            min_dist = d
            id = convert(SelectionID{Int}, sid[i, j])
        end
    end

    if haskey(screen.cache2plot, id[1])
        return (screen.cache2plot[id[1]], id[2])
    else
        return (nothing, 0)
    end
end

# Skips some allocations
function Makie.pick_sorted(scene::SceneLike, screen::Screen, xy, range)
    isopen(screen) || return (nothing, 0)
    w, h = widths(screen)
    if !((1.0 <= xy[1] <= w) && (1.0 <= xy[2] <= h))
        return Tuple{AbstractPlot, Int}[]
    end
    x0, y0 = max.(1, floor.(Int, xy .- range))
    x1, y1 = min.([w, h], floor.(Int, xy .+ range))
    dx = x1 - x0; dy = y1 - y0

    picks = pick_native(screen, Rect2i(x0, y0, dx, dy))

    selected = filter(x -> x[1] > 0 && haskey(screen.cache2plot, x[1]), unique(vec(picks)))
    distances = [range^2 for _ in selected]
    x, y =  xy .+ 1 .- Vec2f(x0, y0)
    for i in 1:dx, j in 1:dy
        if picks[i, j][1] > 0
            d = (x-i)^2 + (y-j)^2
            i = findfirst(isequal(picks[i, j]), selected)
            if i === nothing
                @warn "This shouldn't happen..."
            elseif distances[i] > d
                distances[i] = d
            end
        end
    end

    idxs = sortperm(distances)
    permute!(selected, idxs)
    return map(id -> (screen.cache2plot[id[1]], id[2]), selected)
end


pollevents(::GLScreen) = nothing
pollevents(::Screen) = GLFW.PollEvents()
