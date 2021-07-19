function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    precompile(Makie.backend_display, (GLBackend, Scene))

    # These are awful and will go stale as gensyms change (check by putting `@assert` in front of each one).
    # It would be far better to fix the inference problems.
    isdefined(GLMakie, Symbol("#89#90")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#89#90")),Text{Tuple{String}}})   # time: 1.7054044
    isdefined(GLMakie, Symbol("#72#78")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#72#78")),SMatrix{4, 4, Float32, 16},SMatrix{4, 4, Float32, 16}})   # time: 0.18958463
    isdefined(GLMakie, Symbol("#44#46")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#44#46")),GLFW.Window})   # time: 0.098638594
    isdefined(GLMakie, Symbol("#81#82")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#81#82")),Symbol})   # time: 0.07212781
    Base.precompile(Tuple{typeof(draw_atomic),Screen,Scene,Union{Scatter{ArgType} where ArgType, MeshScatter{ArgType} where ArgType}})   # time: 0.06695828
    isdefined(GLMakie, Symbol("#89#90")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#89#90")),LineSegments{Tuple{Vector{Point{2, Float32}}}}})   # time: 0.050924074
    isdefined(GLMakie, Symbol("#104#109")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#104#109")),String,Vector{Point{3, Float32}},Vector{Float32},Vector{FTFont},Vec{2, Float32},Vector{Quaternionf},SMatrix{4, 4, Float32, 16},Float64,Float64})   # time: 0.038516257
    isdefined(GLMakie, Symbol("#81#82")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#81#82")),Bool})   # time: 0.030008739
    isdefined(GLMakie, Symbol("#101#102")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#101#102")),Int64,Point{3, Float32},Float32,FTFont,Vec{2, Float32}})   # time: 0.029477166
    isdefined(GLMakie, Symbol("#81#82")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#81#82")),Symbol})   # time: 0.019217245
    isdefined(GLMakie, Symbol("#81#82")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#81#82")),Billboard})   # time: 0.016408404
    isdefined(GLMakie, Symbol("#81#82")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#81#82")),Type})   # time: 0.006553374
    Base.precompile(Tuple{typeof(renderloop),Screen})   # time: 0.005448615
    isdefined(GLMakie, Symbol("#81#82")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#81#82")),RGBA{N0f8}})   # time: 0.004190753
    Base.precompile(Tuple{typeof(push!),Screen,Scene,RenderObject{GLMakie.GLAbstraction.StandardPrerender}})   # time: 0.002534885
    isdefined(GLMakie, Symbol("#81#82")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#81#82")),Any})   # time: 0.002144091
    isdefined(GLMakie, Symbol("#81#82")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#81#82")),Any})   # time: 0.001724354
    isdefined(GLMakie, Symbol("#12#20")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#12#20"))})   # time: 0.00144086
    isdefined(GLMakie, Symbol("#81#82")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#81#82")),Vector{RGBA{Float32}}})   # time: 0.001202468
    Base.precompile(Tuple{typeof(draw_atomic),Screen,Scene,Lines{ArgType} where ArgType})   # time: 0.001200726
    isdefined(GLMakie, Symbol("#81#82")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#81#82")),Tuple{Symbol, Float64}})   # time: 0.001081687
    isdefined(GLMakie, Symbol("#81#82")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#81#82")),Vector{Float32}})   # time: 0.001065034
    isdefined(GLMakie, Symbol("#89#90")) && Base.precompile(Tuple{getfield(GLMakie, Symbol("#89#90")),Annotations{Tuple{Vector{Tuple{String, Point{2, Float32}}}}}})   # time: 0.001031033
end
