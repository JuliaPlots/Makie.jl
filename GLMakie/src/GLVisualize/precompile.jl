function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    Base.precompile(Tuple{typeof(line_visualization),Observable{Vector{Point{2, Float32}}},Dict{Symbol, Any}})   # time: 0.22955656
    Base.precompile(Tuple{typeof(assemble_robj),Dict{Symbol, Any},GLVisualizeShader,GeometryBasics.HyperRectangle{3, Float32},UInt32,Nothing,Nothing})   # time: 0.112225175
    Base.precompile(Tuple{typeof(to_index_buffer),Observable{Vector{Int64}}})   # time: 0.09670886
    Base.precompile(Tuple{typeof(ticks),Vector{T} where T,Int64})   # time: 0.07404702
    Base.precompile(Tuple{typeof(vec2quaternion),Observable{Vector{Quaternionf}}})   # time: 0.043232486
    isdefined(GLVisualize, Symbol("#GLVisualizeShader#8#10")) && Base.precompile(Tuple{getfield(GLVisualize, Symbol("#GLVisualizeShader#8#10")),Dict{String, String},Base.Iterators.Pairs{Union{}, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},Type{GLVisualizeShader},String,Vararg{String, N} where N})   # time: 0.035577767
    Base.precompile(Tuple{typeof(_position_calc),Observable{Vector{Point{3, Float32}}},Type{GLBuffer}})   # time: 0.016643895
    Base.precompile(Tuple{typeof(_position_calc),Observable{Vector{Point{2, Float32}}},Type{GLBuffer}})   # time: 0.013070196
    Base.precompile(Tuple{typeof(vec2quaternion),Observable{Quaternionf}})   # time: 0.012976533
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:view,), Tuple{Dict{String, String}}},Type{GLVisualizeShader},String,String,String,String,String})   # time: 0.009165488
    Base.precompile(Tuple{typeof(visualize),Any,Any,Any})   # time: 0.00876585
    Base.precompile(Tuple{typeof(ticks),Vector{Float64},Int64})   # time: 0.008059256
    Base.precompile(Tuple{typeof(position_calc),Observable{Vector{Point{3, Float32}}},Vararg{Any, N} where N})   # time: 0.00481658
    Base.precompile(Tuple{typeof(assemble_shader),Any})   # time: 0.004637692
    Base.precompile(Tuple{typeof(position_calc),Observable{Vector{Point{2, Float32}}},Vararg{Any, N} where N})   # time: 0.004362621
    Base.precompile(Tuple{typeof(primitive_uv_offset_width),Circle{Float32}})   # time: 0.0011835
    Base.precompile(Tuple{typeof(primitive_offset),Observable{Circle{Float32}},Any})   # time: 0.001028085
end
