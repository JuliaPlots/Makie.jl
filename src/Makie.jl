__precompile__(true)
module Makie

const has_ffmpeg = Ref(false)

function __init__()
    has_ffmpeg[] = try
        success(`ffmpeg -h`)
    catch
        false
    end
end

function logo()
    FileIO.load(joinpath(@__DIR__, "..", "docs", "src", "assets", "logo.png"))
end

using AbstractPlotting
using Reactive, GeometryTypes, Colors, ColorVectorSpace, StaticArrays
import IntervalSets
using IntervalSets: ClosedInterval, (..)
using ImageCore

module ContoursTemp
    import Contour
end
using .ContoursTemp
const Contours = ContoursTemp.Contour

using Primes

using Base.Iterators: repeated, drop
using FreeType, FreeTypeAbstraction, UnicodeFun
using PlotUtils, Showoff
using Base: RefValue
import Base: push!, isopen, show

for name in names(AbstractPlotting)
    @eval import AbstractPlotting: $(name)
    @eval export $(name)
end

# Unexported names
using AbstractPlotting: @info, @log_performance, @warn, jl_finalizer, NativeFont, Key, @key_str

export (..), GLNormalUVMesh
# conflicting identifiers
using AbstractPlotting: Text, volume, VecTypes
using GeometryTypes: widths
export widths, decompose

# NamedTuple shortcut for 0.6, for easy creation of nested attributes
const NT = Theme
export NT

# functions we overload

include("makie_recipes.jl")
include("tickranges.jl")
include("utils.jl")
include("glbackend/glbackend.jl")
include("cairo/cairo.jl")
include("output.jl")
include("video_io.jl")

# conversion infrastructure



end
