import .GLAbstraction: Pipeline
const ScreenID = UInt8
const ZIndex = Int
const ScreenArea = Tuple{ScreenID, Node{IRect2D}, Node{Bool}, Node{RGBAf0}}

# The situation right now is that there is a 'queue' of pipelines (i.e. a `Vector` of them)
# and a dictionary with RObjs that should be rendered in them. When an RObj gets
# pushed to the screen there is an automatic check for the correct render pipeline.
# If not it will be created and added to the 'queue' of pipelines,
# a new entry in the renderlist will be created with the pipeline's tag and
# a length 1 `Vector` with the newly added RObj. Subsequent RObjs requesting the
# same pipeline will be pushed to the same `Vector`.
# This is hopefully a relatively temporary solution to get this up and running.
# It should at least give a semi good starting point to find a good balance
# between performant and flexible, although I think an altogther better method
# should be possible.
mutable struct Screen <: AbstractScreen
    glscreen::GLFW.Window
    rendertask::RefValue{Task}
    screen2scene::Dict{WeakRef, ScreenID}
    screens::Vector{ScreenArea}
    renderlist::Dict{Symbol, Vector{Tuple{ZIndex, ScreenID, RenderObject}}}
    cache::Dict{UInt64, RenderObject}
    cache2plot::Dict{UInt16, AbstractPlot}
    fullscreenvao::Int
    pipelines::Vector{Pipeline}
    function Screen(
            glscreen::GLFW.Window,
            rendertask::RefValue{Task},
            screen2scene::Dict{WeakRef, ScreenID},
            screens::Vector{ScreenArea},
            renderlist::Dict{Symbol, Vector{Tuple{ZIndex, ScreenID, RenderObject}}},
            cache::Dict{UInt64, RenderObject},
            cache2plot::Dict{UInt16, AbstractPlot},
            pipelines::Vector{Pipeline}
        )
        #TODO not sure if this is very correct
        obj = new(glscreen, rendertask, screen2scene, screens, renderlist, cache, cache2plot, glGenVertexArrays(),  pipelines)
        jl_finalizer(obj) do obj
            # save_print("Freeing screen")
            empty!.((obj.renderlist, obj.screens, obj.cache, obj.screen2scene, obj.cache2plot))
            return
        end
        obj
    end
end
Base.size(x::Screen) = Int.(GLFW.GetFramebufferSize(to_native(x)))
GeometryTypes.widths(x::Screen) = size(x)

function insertplots!(screen::Screen, scene::Scene)
    #I presume the elem are all the robjs that compose the plot
    for elem in scene.plots
        insert!(screen, scene, elem)
    end
    foreach(s-> insertplots!(screen, s), scene.children)
end

function Base.empty!(screen::Screen)
    empty!(screen.renderlist)
    empty!(screen.screen2scene)
    empty!(screen.screens)
    empty!(screen.cache)
    empty!(screen.cache2plot)
end

function Base.resize!(screen::Screen, w, h)
    if isopen(screen)
        GLFW.SetWindowSize(screen.glscreen, round(Int, w), round(Int, h))
    end
end

function Base.display(screen::Screen, scene::Scene)
    empty!(screen)
    resize!(screen, widths(AbstractPlotting.pixelarea(scene)[])...)
    register_callbacks(scene, to_native(screen))
    insertplots!(screen, scene)
    return
end

###WIP shadercleanup
function colorbuffer(screen::Screen)
    if isopen(screen)
        GLFW.PollEvents()
        yield()
        render_frame(screen) # let it render
        GLFW.SwapBuffers(to_native(screen))
        glFinish() # block until opengl is done rendering
        buffer = !isempty(screen.pipelines) ?
                    gpu_data(screen.pipelines[1].passes[1].target, 1) :
                    zeros(RGB{N0f8}, size(screen))
        return rotl90(ImageCore.clamp01nan.(RGB{N0f8}.(buffer)))
    else
        error("Screen not open!")
    end
end

Base.size(screen::Screen) = screen.size

Base.isopen(x::Screen) = isopen(x.glscreen)

# TEMP with regards to the pipeline <=> RObj system
###WIP shadercleanup
function Base.push!(screen::Screen, scene::Scene, robj)
    filter!(screen.screen2scene) do k, v
        k.value != nothing
    end
    screenid = get!(screen.screen2scene, WeakRef(scene)) do
        id = length(screen.screens) + 1
        bg = map(to_color, scene.theme[:backgroundcolor])
        push!(screen.screens, (id, scene.px_area, Node(true), bg))
        id
    end
    #TEMP this might be done better
    #TODO shadercleanup
    #TODO screencleanup: fbo should be created somewhere else
    pipesym = get(robj.uniforms, :pipeline, :default)
    #TODO rendercleanup: one fbo per pipeline could be ok, but then we need a
    #                    final render pass that combines all of them. Right now
    #                    that is not there, and so we render everything to the first
    #                    fbo. Also clearing needs to get attention!
    fbo = length(screen.renderlist) >= 1 ?
        screen.pipelines[1].passes[1].target :
        defaultframebuffer(size(screen))
    if !haskey(screen.renderlist, pipesym)
        push!(screen, makiepipeline(pipesym, fbo, robj.uniforms[:shader]))
        screen.renderlist[pipesym] = [(0, screenid, robj)]
    else
        push!(screen.renderlist[pipesym], (0, screenid, robj))
    end

    return robj
end

Base.push!(screen::Screen, pipeline::Pipeline) = push!(screen.pipelines, pipeline)

to_native(x::Screen) = x.glscreen
const gl_screens = GLFW.Window[]


# """
# OpenGL shares all data containers between shared contexts, but not vertexarrays -.-
# So to share a robjs between a context, we need to rewrap the vertexarray into a new one for that
# specific context.
# """
# function rewrap(robj::RenderObject{Pre}) where Pre
#     RenderObject{Pre}(
#         robj.main,
#         robj.uniforms,
#         GLVertexArray(robj.vertexarray),
#         robj.prerenderfunction,
#         robj.postrenderfunction,
#         robj.boundingbox,
#     )
# end
function GLAbstraction.native_switch_context!(x::Screen)
    GLFW.MakeContextCurrent(x.glscreen)
end
function GLAbstraction.native_context_active(x::Screen)
    isopen(x.glscreen)
end
function GLAbstraction.set_context!(x::Screen)
    GLAbstraction.set_context!(GLAbstraction.DummyContext(x))
    GLAbstraction.native_switch_context!(x)
end
function Screen(;resolution = (960, 540), visible = true, kw_args...)
    if !isempty(gl_screens)
        for elem in gl_screens
            isopen(elem) && destroy!(elem)
        end
        empty!(gl_screens)
    end
    window = GLFW.Window(
        name = "Makie", resolution = resolution,
        windowhints = [
            (GLFW.SAMPLES,      0),
            (GLFW.DEPTH_BITS,   0),

            (GLFW.ALPHA_BITS,   0),
            (GLFW.RED_BITS,     8),
            (GLFW.GREEN_BITS,   8),
            (GLFW.BLUE_BITS,    8),

            (GLFW.STENCIL_BITS, 0),
            (GLFW.AUX_BUFFERS,  0)
        ],
        kw_args...
    )
    # tell GLAbstraction that we created a new context.
    # This is important for resource tracking, and only needed for the first context
    # else
    #     # share OpenGL Context
    #     create_glcontext("Makie"; parent = first(gl_screens), kw_args...)
    # end
    push!(gl_screens, window)
    if visible
        GLFW.ShowWindow(window)
    else
        GLFW.HideWindow(window)
    end
    GLFW.SwapInterval(0)

    screen = Screen(
        window,
        RefValue{Task}(),
        Dict{WeakRef, ScreenID}(),
        ScreenArea[],
        Dict{Symbol, Vector{Tuple{ZIndex, ScreenID, RenderObject}}}(),
        Dict{UInt64, RenderObject}(),
        Dict{UInt16, AbstractPlot}(),
        Pipeline[])
    GLAbstraction.set_context!(screen)
    GLAbstraction.empty_shader_cache!()
    screen.rendertask[] = @async(renderloop(screen))
    screen
end

const _global_gl_screen = Ref{Screen}()
function global_gl_screen()
    if isassigned(_global_gl_screen) && isopen(_global_gl_screen[])
        _global_gl_screen[]
    else
        _global_gl_screen[] = Screen()
        _global_gl_screen[]
    end
end

# TODO per scene screen
getscreen(scene) = global_gl_screen()

function pick_native(scene::SceneLike, xy::VecTypes{2}, sid = Base.RefValue{SelectionID{UInt16}}())
    screen = getscreen(scene)
    screen == nothing && return SelectionID{Int}(0, 0)
    window_size = widths(screen)
    fb = screen.framebuffer
    buff = fb.objectid
    glBindFramebuffer(GL_FRAMEBUFFER, fb.id[1])
    glReadBuffer(GL_COLOR_ATTACHMENT1)
    x, y = Int.(floor.(xy))
    w, h = window_size
    if x > 0 && y > 0 && x <= w && y <= h
        glReadPixels(x, y, 1, 1, buff.format, buff.pixeltype, sid)
        return convert(SelectionID{Int}, sid[])
    end
    return SelectionID{Int}(0, 0)
end

pick(scene::SceneLike, xy...) = pick(scene, Float64.(xy))

function pick(scene::SceneLike, xy::VecTypes{2})
    sid = pick_native(scene, xy)
    screen = getscreen(scene)
    if screen != nothing && haskey(screen.cache2plot, sid.id)
        plot = screen.cache2plot[sid.id]
        return (plot, sid.index)
    end
    return (nothing, 0)
end

# TODO does this actually needs to be a global?
const _mouse_selection_id = Base.RefValue{SelectionID{UInt16}}()
function mouse_selection_native(scene::SceneLike)
    function query_mouse()
        screen = getscreen(scene)
        screen == nothing && return SelectionID{Int}(0, 0)
        window_size = widths(screen)
        fb = screen.framebuffer
        buff = fb.objectid
        glReadBuffer(GL_COLOR_ATTACHMENT1)
        xy = events(scene).mouseposition[]
        x, y = Int.(floor.(xy))
        w, h = window_size
        if x > 0 && y > 0 && x <= w && y <= h
            glReadPixels(x, y, 1, 1, buff.format, buff.pixeltype, _mouse_selection_id)
        end
        return
    end
    if !(query_mouse in selection_queries)
        push!(selection_queries, query_mouse)
    end
    convert(SelectionID{Int}, _mouse_selection_id[])
end
function mouse_selection(scene::SceneLike)
    sid = mouse_selection_native(scene)
    screen = getscreen(scene)
    if screen != nothing && haskey(screen.cache2plot, sid.id)
        plot = screen.cache2plot[sid.id]
        return (plot, sid.index)
    end
    return (nothing, 0)
end
function mouseover(scene::SceneLike, plots::AbstractPlot...)
    p, idx = mouse_selection(scene)
    p in plots
end

function onpick(f, scene::SceneLike, plots::AbstractPlot...)
    map_once(events(scene).mouseposition) do mp
        p, idx = mouse_selection(scene, mp)
        (p in plots) && f(idx)
        return
    end
end

function pick(screen::Screen, rect::IRect2D)
    window_size = widths(screen)
    buff = screen.framebuffer.objectid
    sid = zeros(SelectionID{UInt16}, widths(rect)...)
    glReadBuffer(GL_COLOR_ATTACHMENT1)
    x, y = minimum(rect)
    rw, rh = widths(rect)
    w, h = window_size
    if x > 0 && y > 0 && x <= w && y <= h
        glReadPixels(x, y, rw, rh, buff.format, buff.pixeltype, sid)
        return map(unique(vec(SelectionID{Int}.(sid)))) do sid
            screen.cache2plot[sid.id], Int(sid.index)
        end
    end
    return SelectionID{Int}[]
end
