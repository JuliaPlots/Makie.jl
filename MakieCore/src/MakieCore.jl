module MakieCore

using Observables
using Observables: to_value, AbstractObservable
using Base: RefValue
using GeometryBasics
using ColorTypes
using Parameters
using StaticArrays
using LinearAlgebra
using Random
using FreeTypeAbstraction
using IntervalSets

using GeometryBasics: VecTypes


"""
    abstract type Transformable
This is a bit of a weird name, but all scenes and plots are transformable,
so that's what they all have in common. This might be better expressed as traits.
"""
abstract type Transformable end

abstract type AbstractPlot{T} <: Transformable end
abstract type ScenePlot{T} <: AbstractPlot{T} end
abstract type AbstractScene <: Transformable end
abstract type AbstractScreen <: AbstractDisplay end

const SceneLike = Union{AbstractScene, AbstractPlot}

include("geometry/quaternions.jl")
include("geometry/projection_math.jl")
include("types.jl")
include("attributes.jl")
include("recipes.jl")
include("basic_plots/abstractplot.jl")
include("basic_plots/scatter.jl")
include("basic_plots/lines.jl")
include("basic_plots/text.jl")
include("basic_plots/others.jl")
include("conversion.jl")

end
