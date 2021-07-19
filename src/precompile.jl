macro warnpcfail(ex::Expr)
    modl = __module__
    file = __source__.file === nothing ? "?" : String(__source__.file)
    line = __source__.line
    quote
        $(esc(ex)) || @warn """precompile directive
     $($(Expr(:quote, ex)))
 failed. Please report an issue in $($modl) (after checking for duplicates) or remove this directive.""" _file=$file _line=$line
    end
end

function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    @warnpcfail precompile(Scene, ())
    @warnpcfail precompile(update_limits!, (Scene,))
    @warnpcfail precompile(update_limits!, (Scene, Automatic))
    @warnpcfail precompile(update_limits!, (Scene, Rect3f))

    @warnpcfail precompile(boundingbox, (Scene,))
    Ngonf0 = GeometryBasics.Ngon{2, Float32, 3, Point2f}
    # @warnpcfail precompile(boundingbox, (Mesh{Tuple{Vector{GeometryBasics.Mesh{2, Float32, Ngonf0, FaceView{Ngonf0}}}}},))  # doesn't seem to work
    @warnpcfail precompile(boundingbox, (Poly{Tuple{Vector{Vector{Point2f}}}},))
    @warnpcfail precompile(boundingbox, (String, Vector{Point3f}, Vector{Float32}, Vector{FTFont}, Vec2f, Vector{Quaternionf}, SMatrix{4, 4, Float32, 16}, Float64, Float64))

    @warnpcfail precompile(poly_convert, (Vector{Vector{Point2f}},))
    @warnpcfail precompile(rotatedrect, (Rect2f, Float32))

    @warnpcfail precompile(plot!, (Scene, Type{Poly{Tuple{Rect2i}}}, Attributes, Tuple{Observable{Rect2i}}, Observable{Tuple{Vector{Vector{Point2f}}}}))
    @warnpcfail precompile(plot!, (Mesh{Tuple{Vector{GeometryBasics.Mesh{2, Float32, Ngonf0, FaceView{Ngonf0}}}}},))
    @warnpcfail precompile(plot!, (Scene, Type{Annotations{Tuple{Vector{Tuple{String, Point2f}}}}}, Attributes, Tuple{Observable{Vector{Tuple{String, Point2f}}}}, Observable{Tuple{Vector{Tuple{String, Point2f}}}}))

    # A big dump from SnoopCompile. These will go stale rapidly, but until work is done on inferrability this is probably the best we can do
    isdefined(Makie, Symbol("#303#305")) && Base.precompile(Tuple{getfield(Makie, Symbol("#303#305")),Int64,FTFont,Tuple{String, Point{2, Float32}},RGBA{Float32},Float32,Vec{2, Float32},Quaternionf,Float64,Float64})   # time: 0.8072854
    Base.precompile(Tuple{typeof(transformationmatrix),Vec{3, Float32},Vec{3, Float32},Quaternionf,Observable{Vec{2, Float32}},Tuple{Bool, Bool, Bool},GeometryBasics.HyperRectangle{3, Float32}})   # time: 0.70518523
    Base.precompile(Tuple{typeof(update_cam!),Scene,Camera2D,GeometryBasics.HyperRectangle{3, Float32}})   # time: 0.44654787
    Base.precompile(Tuple{typeof(scatter),Vector{Float64},Vararg{Vector{Float64}, 100}})   # time: 0.32425407
    isdefined(Makie, Symbol("#302#304")) && Base.precompile(Tuple{getfield(Makie, Symbol("#302#304")),SMatrix{4, 4, Float32, 16},Vector{FTFont},Vector{Tuple{String, Point{2, Float32}}},Vector{RGBA{Float32}},Vararg{Any, 100}})   # time: 0.23708302
    Base.precompile(Tuple{typeof(plot!),Scene,Type{Lines{Tuple{GeometryBasics.HyperRectangle{2, Float32}}}},Attributes,Tuple{Observable{GeometryBasics.HyperRectangle{2, Float32}}},Observable{Tuple{Vector{Point{2, Float32}}}}})   # time: 0.23567033
    Base.precompile(Tuple{typeof(default_theme),Scene,Type{Scatter{Tuple{Vector{Point{2, Float32}}}}}})   # time: 0.22432384
    Base.precompile(Tuple{typeof(plot),Type{Scatter{ArgType} where ArgType},Vector{Float64},Vector{Float64}})   # time: 0.19391601
    Base.precompile(Tuple{typeof(default_labels),Vector{Float64},typeof(Makie.Formatters.plain)})   # time: 0.19084986
    Base.precompile(Tuple{typeof(convert_arguments),Type{LineSegments{ArgType} where ArgType},Vector{Point{2, Float32}}})   # time: 0.18835282
    Base.precompile(Tuple{typeof(boundingbox),Scatter{Tuple{Vector{Point{2, Float32}}}}})   # time: 0.15786158
    Base.precompile(Tuple{typeof(same_length_array),Vector{Tuple{String, Point{2, Float32}}},Float64,Key{:rotation}})   # time: 0.15258642
    Base.precompile(Tuple{typeof(plot!),Scene,Type{Scatter{Tuple{Vector{Float64}, Vector{Float64}}}},Attributes,Tuple{Observable{Vector{Float64}}, Observable{Vector{Float64}}},Observable{Tuple{Vector{Point{2, Float32}}}}})   # time: 0.096797995
    Base.precompile(Tuple{typeof(data_limits),Text{Tuple{String}}})   # time: 0.09453959
    Base.precompile(Tuple{typeof(convert_arguments),Type{Annotations{ArgType} where ArgType},Vector{String},Vector{Point{2, Float32}}})   # time: 0.09197935
    isdefined(Makie, Symbol("#719#720")) && Base.precompile(Tuple{getfield(Makie, Symbol("#719#720")),Int64,Quaternionf,FTFont,Float32})   # time: 0.081979275
    let fbody = try Base.bodyfunction(which(convert_arguments, (Type{Scatter{Tuple{Vector{Float64}, Vector{Float64}}}},Vector{Float64},Vararg{Vector{Float64}, 100},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Base.Iterators.Pairs{Union{}, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},typeof(convert_arguments),Type{Scatter{Tuple{Vector{Float64}, Vector{Float64}}}},Vector{Float64},Vararg{Vector{Float64}, 100},))
        end
    end   # time: 0.07799169
    Base.precompile(Tuple{typeof(icon)})   # time: 0.07657142
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:color, :linewidth, :transformation, :model, :visible, :transparency, :overdraw, :ambient, :diffuse, :specular, :shininess, :lightposition, :nan_color, :ssao), Tuple{Observable{Any}, Int64, Automatic, Automatic, Bool, Bool, Bool, Vec{3, Float32}, Vec{3, Float32}, Vec{3, Float32}, Float32, Symbol, RGBA{Float32}, Bool}},Type{Attributes}})   # time: 0.06820207
    Base.precompile(Tuple{typeof(project_widths),SMatrix{4, 4, Float32, 16},Vec{3, Float32}})   # time: 0.06811111
    isdefined(Makie, Symbol("#340#343")) && Base.precompile(Tuple{getfield(Makie, Symbol("#340#343")),Float64,Tuple{Tuple{Float32, Float32}, Tuple{Float32, Float32}},Automatic,Automatic,Function})   # time: 0.055591293
    isdefined(Makie, Symbol("#302#304")) && Base.precompile(Tuple{getfield(Makie, Symbol("#302#304")),Any,Any,Vector{Tuple{String, Point{2, Float32}}},Any,Any,Any,Any,Any,Any})   # time: 0.05321678
    let fbody = try Base.bodyfunction(which(cam2d!, (Scene,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Base.Iterators.Pairs{Union{}, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},typeof(cam2d!),Scene,))
        end
    end   # time: 0.05295532
    isdefined(Makie, Symbol("#340#343")) && Base.precompile(Tuple{getfield(Makie, Symbol("#340#343")),Any,Tuple{Tuple{Float32, Float32}, Tuple{Float32, Float32}},Any,Any,Any})   # time: 0.043772664
    isdefined(Makie, Symbol("#672#686")) && Base.precompile(Tuple{getfield(Makie, Symbol("#672#686")),Tuple{Vector{Float64}, Float64}})   # time: 0.04195882
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:axisnames, :title, :textcolor, :textsize, :rotation, :align, :font), Tuple{Tuple{String, String}, Nothing, Tuple{Symbol, Symbol}, Tuple{Int64, Int64}, Tuple{Float64, Float64}, Tuple{Tuple{Symbol, Symbol}, Tuple{Symbol, Symbol}}, Observable{Tuple{String, String}}}},Type{Attributes}})   # time: 0.036071636
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:transparency, :shininess, :overdraw, :specular, :visible, :transformation, :model, :ssao, :color, :ambient, :linewidth, :diffuse, :lightposition, :nan_color, :colormap, :marker, :markersize, :strokecolor, :strokewidth, :glowcolor, :glowwidth, :rotations, :marker_offset, :transform_marker, :uv_offset_width, :distancefield, :markerspace, :fxaa), Tuple{Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Symbol, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Symbol, UnionAll, Int64, Symbol, Float64, RGBA{N0f8}, Float64, Billboard, Automatic, Bool, Vec{4, Float32}, Nothing, UnionAll, Bool}},Type{Attributes}})   # time: 0.030648092
    let fbody = try Base.bodyfunction(which(plot!, (Scene,Type{Scatter{ArgType} where ArgType},Attributes,Vector{Float64},Vararg{Vector{Float64}, 100},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Base.Iterators.Pairs{Union{}, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},typeof(plot!),Scene,Type{Scatter{ArgType} where ArgType},Attributes,Vector{Float64},Vararg{Vector{Float64}, 100},))
        end
    end   # time: 0.029508112
    Base.precompile(Tuple{Type{Text{ArgType} where ArgType},Annotations{Tuple{Vector{Tuple{String, Point{2, Float32}}}}},Attributes,Tuple{Observable{String}},Observable{Tuple{String}}})   # time: 0.028124427
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:ranges_labels, :formatter, :gap, :title_gap, :linewidth, :linecolor, :linestyle, :textcolor, :textsize, :rotation, :align, :font), Tuple{Tuple{Automatic, Automatic}, typeof(Makie.Formatters.plain), Int64, Int64, Tuple{Int64, Int64}, Tuple{Tuple{Symbol, Float64}, Tuple{Symbol, Float64}}, Tuple{Nothing, Nothing}, Tuple{Symbol, Symbol}, Tuple{Int64, Int64}, Tuple{Float64, Float64}, Tuple{Tuple{Symbol, Symbol}, Tuple{Symbol, Symbol}}, Observable{Tuple{String, String}}}},Type{Attributes}})   # time: 0.028094089
    Base.precompile(Tuple{Core.kwftype(typeof(text!)),NamedTuple{(:align, :model, :position, :color, :visible, :textsize, :font, :rotation), Tuple{Vec{2, Float32}, SMatrix{4, 4, Float32, 16}, Vector{Point{3, Float32}}, Vector{RGBA{Float32}}, Observable{Any}, Vector{Float32}, Vector{FTFont}, Vector{Quaternionf}}},typeof(text!),Annotations{Tuple{Vector{Tuple{String, Point{2, Float32}}}}},Vararg{Any, 100}})   # time: 0.027778953
    Base.precompile(Tuple{typeof(selection_rect!),Scene,Camera2D,Observable{Any}})   # time: 0.02611231
    Base.precompile(Tuple{typeof(map_once),Function,Observable{Annotations{Tuple{Vector{Tuple{String, Point{2, Float32}}}}}},Observable{LineSegments{Tuple{Vector{Point{2, Float32}}}}},Vararg{Observable, 100}})   # time: 0.024804583
    let fbody = try Base.bodyfunction(which(map_once, (Function,Observable{Vec{3, Float32}},Observable{Vec{3, Float32}},Vararg{Observable, 100},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (SMatrix{4, 4, Float32, 16},Type,typeof(map_once),Function,Observable{Vec{3, Float32}},Observable{Vec{3, Float32}},Vararg{Observable, 100},))
        end
    end   # time: 0.023796478
    let fbody = try Base.bodyfunction(which(Scene, ())) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Bool,Function,Base.Iterators.Pairs{Union{}, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},Type{Scene},))
        end
    end   # time: 0.023688106
    Base.precompile(Tuple{typeof(safe_off),Observable{Any},Function})   # time: 0.022924356
    Base.precompile(Tuple{typeof(lift),Function,Observable{Any},Observable{Tuple{Tuple{Float32, Float32}, Tuple{Float32, Float32}}},Vararg{Any, 100}})   # time: 0.020434486
    Base.precompile(Tuple{typeof(broadcast_foreach),Function,UnitRange{Int64},Vararg{Any, 100}})   # time: 0.019735442
    Base.precompile(Tuple{typeof(map_once),Function,Observable{Vec{3, Float32}},Observable{Vec{3, Float32}},Vararg{Observable, 100}})   # time: 0.019173674
    isdefined(Makie, Symbol("#666#680")) && Base.precompile(Tuple{getfield(Makie, Symbol("#666#680")),Vector{Float32},Float32})   # time: 0.015830928
    isdefined(Makie, Symbol("#669#683")) && Base.precompile(Tuple{getfield(Makie, Symbol("#669#683")),Vector{Float64}})   # time: 0.015553104
    isdefined(Makie, Symbol("#340#343")) && Base.precompile(Tuple{getfield(Makie, Symbol("#340#343")),Float64,Any,Any,Any,Any})   # time: 0.014724698
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:transparency, :shininess, :overdraw, :specular, :visible, :transformation, :model, :ssao, :color, :ambient, :linewidth, :diffuse, :lightposition, :nan_color, :font, :strokecolor, :strokewidth, :align, :rotation, :textsize, :position, :justification, :lineheight), Tuple{Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Tuple{Symbol, Float64}, Int64, Tuple{Symbol, Symbol}, Float64, Int64, Point{2, Float32}, Float64, Float64}},Type{Attributes}})   # time: 0.014095342
    Base.precompile(Tuple{typeof(on),Function,Camera,Observable{Scene},Vararg{Observable, 100}})   # time: 0.012858183
    Base.precompile(Tuple{Core.kwftype(typeof(Type)),NamedTuple{(:transparency, :shininess, :overdraw, :specular, :visible, :transformation, :model, :ssao, :color, :ambient, :linewidth, :diffuse, :lightposition, :nan_color, :colormap, :linestyle, :fxaa), Tuple{Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Observable{Any}, Symbol, Observable{Any}, Float64, Observable{Any}, Observable{Any}, Observable{Any}, Symbol, Nothing, Bool}},Type{Attributes}})   # time: 0.012534027
    let fbody = try Base.bodyfunction(which(map_once, (Function,Observable{Annotations{Tuple{Vector{Tuple{String, Point{2, Float32}}}}}},Observable{LineSegments{Tuple{Vector{Point{2, Float32}}}}},Vararg{Observable, 100},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Nothing,Type,typeof(map_once),Function,Observable{Annotations{Tuple{Vector{Tuple{String, Point{2, Float32}}}}}},Observable{LineSegments{Tuple{Vector{Point{2, Float32}}}}},Vararg{Observable, 100},))
        end
    end   # time: 0.012269881
    Base.precompile(Tuple{typeof(lift),Function,Observable{Any},Observable{Union{Nothing, Rect3f, Rectf{3}, Rect3{Float32}}}})   # time: 0.012067013
    isdefined(Makie, Symbol("#89#92")) && Base.precompile(Tuple{getfield(Makie, Symbol("#89#92")),Tuple{Int64, Int64}})   # time: 0.010871829
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Tuple{Vector{Tuple{String, Point{2, Float32}}}}},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Vector{Tuple{String, Point{2, Float32}}},Type,Symbol,typeof(lift),Function,Observable{Tuple{Vector{Tuple{String, Point{2, Float32}}}}},))
        end
    end   # time: 0.01042566
    isdefined(Makie, Symbol("#174#176")) && Base.precompile(Tuple{getfield(Makie, Symbol("#174#176")),Vector{RGBA{Float32}}})   # time: 0.010158016
    Base.precompile(Tuple{typeof(color_and_colormap!),Scatter{Tuple{Vector{Point{2, Float32}}}},Observable{Any}})   # time: 0.009793119
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{GeometryBasics.HyperRectangle{2, Int64}},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (SMatrix{4, 4, Float32, 16},Type,Symbol,typeof(lift),Function,Observable{GeometryBasics.HyperRectangle{2, Int64}},))
        end
    end   # time: 0.009753768
    Base.precompile(Tuple{typeof(xyz_boundingbox),Function,Vector{Point{2, Float32}}})   # time: 0.009729207
    Base.precompile(Tuple{typeof(setindex!),Attributes,Attributes,Symbol})   # time: 0.009677326
    Base.precompile(Tuple{typeof(lift),Function,Observable{Any}})   # time: 0.009117238
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Tuple{Tuple{Tuple{Float32, Float32}, Tuple{Float32, Float32}}}},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Tuple{Tuple{Float32, Float32}, Tuple{Float32, Float32}},Type,Symbol,typeof(lift),Function,Observable{Tuple{Tuple{Tuple{Float32, Float32}, Tuple{Float32, Float32}}}},))
        end
    end   # time: 0.00889073
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Tuple{Vector{Point{2, Float32}}}},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Vector{Point{2, Float32}},Type,Symbol,typeof(lift),Function,Observable{Tuple{Vector{Point{2, Float32}}}},))
        end
    end   # time: 0.00867902
    Base.precompile(Tuple{typeof(default_theme),Scene,Type{Lines{Tuple{Vector{Point{2, Float32}}}}}})   # time: 0.008428088
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{GeometryBasics.HyperRectangle{2, Float32}},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Tuple{GeometryBasics.HyperRectangle{2, Float32}},Type,Symbol,typeof(lift),Function,Observable{GeometryBasics.HyperRectangle{2, Float32}},))
        end
    end   # time: 0.007614269
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Tuple{String}},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (String,Type,Symbol,typeof(lift),Function,Observable{Tuple{String}},))
        end
    end   # time: 0.007157104
    Base.precompile(Tuple{typeof(lift),Function,Observable{String}})   # time: 0.006988709
    isdefined(Makie, Symbol("#165#170")) && Base.precompile(Tuple{getfield(Makie, Symbol("#165#170")),Int64})   # time: 0.006825633
    Base.precompile(Tuple{typeof(lift),Function,Observable{Vector{Float64}},Observable{Vector{Float64}}})   # time: 0.006378372
    Base.precompile(Tuple{typeof(setindex!),LineSegments{Tuple{Vector{Point{2, Float32}}}},Observable{Vector{RGBA{Float32}}},Symbol})   # time: 0.006341601
    Base.precompile(Tuple{typeof(convert_attribute),Vector{Float32},Key{:textsize}})   # time: 0.006148856
    isdefined(Makie, Symbol("#634#635")) && Base.precompile(Tuple{getfield(Makie, Symbol("#634#635")),Vec{3, Float32},Vec{3, Float32},Quaternionf,Vec{2, Float32},SMatrix{4, 4, Float32, 16},Tuple{Bool, Bool, Bool}})   # time: 0.006117055
    Base.precompile(Tuple{typeof(default_labels),Automatic,Tuple{Vector{Float64}, Vector{Float64}},Function})   # time: 0.005572814
    Base.precompile(Tuple{Core.kwftype(typeof(plot!)),NamedTuple{(:align, :model, :position, :color, :visible, :textsize, :font, :rotation), Tuple{Vec{2, Float32}, SMatrix{4, 4, Float32, 16}, Vector{Point{3, Float32}}, Vector{RGBA{Float32}}, Observable{Any}, Vector{Float32}, Vector{FTFont}, Vector{Quaternionf}}},typeof(plot!),Type{Text{ArgType} where ArgType},Annotations{Tuple{Vector{Tuple{String, Point{2, Float32}}}}},String})   # time: 0.005202268
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{GeometryBasics.HyperRectangle{2, Int64}},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Vec{2, Float32},Type,Symbol,typeof(lift),Function,Observable{GeometryBasics.HyperRectangle{2, Int64}},))
        end
    end   # time: 0.004954409
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Any},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Vector{RGBA{Float32}},Type,Symbol,typeof(lift),Function,Observable{Any},))
        end
    end   # time: 0.004715678
    Base.precompile(Tuple{typeof(setindex!),Scatter{Tuple{Vector{Point{2, Float32}}}},Observable{Vec{2, Float32}},Symbol})   # time: 0.004576182
    isdefined(Makie, Symbol("#liftdim2#370")) && Base.precompile(Tuple{getfield(Makie, Symbol("#liftdim2#370")),Observable{Any}})   # time: 0.004413254
    Base.precompile(Tuple{typeof(default_theme),Annotations{Tuple{Vector{Tuple{String, Point{2, Float32}}}}},Type{Text{Tuple{String}}}})   # time: 0.004375755
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Any},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Tuple{Bool, Bool},Type,Symbol,typeof(lift),Function,Observable{Any},))
        end
    end   # time: 0.003239549
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{String},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Tuple{String},Type,Symbol,typeof(lift),Function,Observable{String},))
        end
    end   # time: 0.003196933
    let fbody = try Base.bodyfunction(which(Scene, (Scene,))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Events,Observable{GeometryBasics.HyperRectangle{2, Int64}},Bool,Camera,RefValue{Any},Transformation,Attributes,Vector{AbstractScreen},Base.Iterators.Pairs{Symbol, Bool, Tuple{Symbol}, NamedTuple{(:raw,), Tuple{Bool}}},Type{Scene},Scene,))
        end
    end   # time: 0.003125787
    Base.precompile(Tuple{typeof(safe_off),Observable{Vec{2, Float32}},Function})   # time: 0.002785086
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Vector{Point{2, Float32}}},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Tuple{Vector{Point{2, Float32}}},Type,Symbol,typeof(lift),Function,Observable{Vector{Point{2, Float32}}},))
        end
    end   # time: 0.002697386
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Any},Observable{Tuple{Tuple{Float32, Float32}, Tuple{Float32, Float32}}},Vararg{Any, 100},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Tuple{Tuple{Vector{Float64}, Vector{Float64}}, Tuple{Vector{String}, Vector{String}}},Type,Symbol,typeof(lift),Function,Observable{Any},Observable{Tuple{Tuple{Float32, Float32}, Tuple{Float32, Float32}}},Vararg{Any, 100},))
        end
    end   # time: 0.002580008
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Vector{Float64}},Observable{Vector{Float64}},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Tuple{Vector{Float64}, Vector{Float64}},Type,Symbol,typeof(lift),Function,Observable{Vector{Float64}},Observable{Vector{Float64}},))
        end
    end   # time: 0.00256485
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Any},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Tuple{String, String},Type,Symbol,typeof(lift),Function,Observable{Any},))
        end
    end   # time: 0.002564525
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Vector{String}},Observable{Vector{Point{2, Float32}}},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Tuple{Vector{Tuple{String, Point{2, Float32}}}},Type,Symbol,typeof(lift),Function,Observable{Vector{String}},Observable{Vector{Point{2, Float32}}},))
        end
    end   # time: 0.002538605
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{GeometryBasics.HyperRectangle{3, Float32}},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Tuple{Tuple{Tuple{Float32, Float32}, Tuple{Float32, Float32}}},Type,Symbol,typeof(lift),Function,Observable{GeometryBasics.HyperRectangle{3, Float32}},))
        end
    end   # time: 0.002528649
    Base.precompile(Tuple{typeof(setindex!),Attributes,Observable{Tuple{Tuple{Vector{Float64}, Vector{Float64}}, Tuple{Vector{String}, Vector{String}}}},Symbol})   # time: 0.00244883
    Base.precompile(Tuple{typeof(safe_off),Observable{Quaternionf},Function})   # time: 0.002366797
    Base.precompile(Tuple{typeof(to_ndim),Type{Point{3, Float32}},Vec2{Float64},Int64})   # time: 0.002294592
    let fbody = try Base.bodyfunction(which(current_default_theme, ())) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Base.Iterators.Pairs{Union{}, Union{}, Tuple{}, NamedTuple{(), Tuple{}}},typeof(current_default_theme),))
        end
    end   # time: 0.002075753
    Base.precompile(Tuple{typeof(safe_off),Observable{Tuple{LineSegments{Tuple{Vector{Point{2, Float32}}}}, LineSegments{Tuple{Vector{Point{2, Float32}}}}}},Function})   # time: 0.001949723
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Any},Observable{Union{Nothing, Rect3f, Rectf{3}, Rect3{Float32}}},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (GeometryBasics.HyperRectangle{3, Float32},Type,Symbol,typeof(lift),Function,Observable{Any},Observable{Union{Nothing, Rect3f, Rectf{3}, Rect3{Float32}}},))
        end
    end   # time: 0.001892332
    Base.precompile(Tuple{typeof(lift),Function,Observable{Vector{Point{2, Float32}}}})   # time: 0.001853503
    Base.precompile(Tuple{typeof(node_any),Any})   # time: 0.001851864
    Base.precompile(Tuple{typeof(safe_off),Observable{Tuple{Bool, Bool, Bool}},Function})   # time: 0.001766532
    Base.precompile(Tuple{typeof(safe_off),Observable{Tuple{Bool, Bool}},Function})   # time: 0.001738557
    Base.precompile(Tuple{typeof(lift),Function,Observable{Vector{String}},Observable{Vector{Point{2, Float32}}}})   # time: 0.001728866
    Base.precompile(Tuple{typeof(data_limits),LineSegments{Tuple{Vector{Point{2, Float32}}}}})   # time: 0.001720389
    Base.precompile(Tuple{typeof(safe_off),Observable{SMatrix{4, 4, Float32, 16}},Function})   # time: 0.0017107
    Base.precompile(Tuple{typeof(color_and_colormap!),Lines{Tuple{Vector{Point{2, Float32}}}},Observable{Any}})   # time: 0.00169273
    let fbody = try Base.bodyfunction(which(lift, (Function,Observable{Any},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (GeometryBasics.HyperRectangle{2, Int64},Type,Symbol,typeof(lift),Function,Observable{Any},))
        end
    end   # time: 0.001687491
    Base.precompile(Tuple{typeof(safe_off),Observable{LineSegments{Tuple{Vector{Point{2, Float32}}}}},Function})   # time: 0.001671355
    Base.precompile(Tuple{typeof(color_and_colormap!),LineSegments{Tuple{Vector{Point{2, Float32}}}},Observable{Any}})   # time: 0.001637833
    Base.precompile(Tuple{typeof(safe_off),Observable{Tuple{Tuple{Float32, Float32}, Tuple{Float32, Float32}}},Function})   # time: 0.00162075
    isdefined(Makie, Symbol("#186#188")) && Base.precompile(Tuple{getfield(Makie, Symbol("#186#188"))})   # time: 0.001442432
    Base.precompile(Tuple{typeof(same_length_array),Vector{Tuple{String, Point{2, Float32}}},Tuple{Symbol, Symbol},Key{:align}})   # time: 0.001406379
    Base.precompile(Tuple{typeof(lift),Function,Observable{GeometryBasics.HyperRectangle{3, Float32}}})   # time: 0.001330926
    Base.precompile(Tuple{typeof(to_ndim),Type{Vec{3, Float32}},Vec{2, Float32},Float32})   # time: 0.001274049
    Base.precompile(Tuple{typeof(getindex),Scene,Type{Axis}})   # time: 0.001070641
    Base.precompile(Tuple{Type{Scatter{Tuple{Vector{Point{2, Float32}}}}},Scene,Transformation,Attributes,Tuple{Observable{Vector{Float64}}, Observable{Vector{Float64}}},Tuple{Observable{Vector{Point{2, Float32}}}}})   # time: 0.001059559
    Base.precompile(Tuple{typeof(is2d),GeometryBasics.HyperRectangle{3, Float32}})   # time: 0.001005834
    Base.precompile(Tuple{Type{Lines{Tuple{Vector{Point{2, Float32}}}}},Scene,Transformation,Attributes,Tuple{Observable{GeometryBasics.HyperRectangle{2, Float32}}},Tuple{Observable{Vector{Point{2, Float32}}}}})   # time: 0.001005373

    # DataInspector
    @warnpcfail precompile(on_hover, (DataInspector, ))
    for PT in (
            Scatter{Tuple{Vector{Point2f}}},
            Scatter{Tuple{Vector{Point3f}}},
            MeshScatter{Tuple{Vector{Point3f}}},
            Lines{Tuple{Vector{Point2f}}},
            Lines{Tuple{Vector{Point3f}}},
            LineSegments{Tuple{Vector{Point2f}}},
            LineSegments{Tuple{Vector{Point3f}}},
            # Mesh,
            Surface{Tuple{IntervalSets.ClosedInterval{Float32}, IntervalSets.ClosedInterval{Float32}, Matrix{Float32}}},
            Surface{Tuple{Vector{Float32}, Vector{Float32}, Matrix{Float32}}},
            Surface{Tuple{Matrix{Float32}, Matrix{Float32}, Matrix{Float32}}},
            Heatmap{Tuple{IntervalSets.ClosedInterval{Float32}, IntervalSets.ClosedInterval{Float32}, Matrix{Float32}}},
            Heatmap{Tuple{Vector{Float32}, Vector{Float32}, Matrix{Float32}}},
            Image{Tuple{IntervalSets.ClosedInterval{Float32}, IntervalSets.ClosedInterval{Float32}, Matrix{Float32}}},
            Image{Tuple{Vector{Float32}, Vector{Float32}, Matrix{Float32}}},
            BarPlot{Tuple{Vector{Point{2, Float32}}}}
        )

        @warnpcfail precompile(show_data_recursion, (DataInspector, PT, UInt64))
        @warnpcfail precompile(show_data, (DataInspector, PT, UInt64))
    end
end
