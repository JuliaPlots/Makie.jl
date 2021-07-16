module Makie

module ContoursHygiene
    import Contour
end

using .ContoursHygiene
const Contours = ContoursHygiene.Contour
using Base64

using LaTeXStrings
export @L_str
using MathTeXEngine
using Artifacts
using Random
using FFMPEG # get FFMPEG on any system!
using Observables, GeometryBasics, IntervalSets, PlotUtils
using ColorBrewer, ColorTypes, Colors, ColorSchemes
using FixedPointNumbers, Packing, SignedDistanceFields
using Markdown, DocStringExtensions # documentation
using Serialization # serialize events
using StructArrays
using GeometryBasics: widths, positive_widths, VecTypes, AbstractPolygon, value
using StaticArrays
import StatsBase, Distributions, KernelDensity
using Distributions: Distribution, VariateForm, Discrete, QQPair, pdf, quantile, qqbuild
# Text related packages
using FreeType, FreeTypeAbstraction, UnicodeFun
using LinearAlgebra, Statistics
import ImageIO, FileIO, SparseArrays
import FileIO: save
using Printf: @sprintf
import Isoband
import PolygonOps
import GridLayoutBase
using MakieCore

import MakieCore: plot, plot!, theme, plotfunc, plottype, merge_attributes!, calculated_attributes!, get_attribute, plotsym, plotkey, attributes, used_attributes

using MakieCore: SceneLike, AbstractScreen, ScenePlot, AbstractScene, AbstractPlot, Transformable, Attributes, Combined, Theme, Plot

using MakieCore: Heatmap, Image, Lines, LineSegments, Mesh, MeshScatter, Scatter, Surface, Text, Volume
import MakieCore: heatmap, image, lines, linesegments, mesh, meshscatter, scatter, surface, text, volume
import MakieCore: heatmap!, image!, lines!, linesegments!, mesh!, meshscatter!, scatter!, surface!, text!, volume!

import MakieCore: convert_arguments, convert_attribute, default_theme, conversion_trait
using MakieCore: ConversionTrait, NoConversion, PointBased, SurfaceLike, ContinuousSurface, DiscreteSurface, VolumeLike
export ConversionTrait, NoConversion, PointBased, SurfaceLike, ContinuousSurface, DiscreteSurface, VolumeLike
using MakieCore: Key, @key_str, Automatic, automatic, @recipe
using MakieCore: Pixel, px, Unit, Billboard
using MakieCore: VecTypes, Quaternionf0, Quaternion, RGBAf0, RGBf0, NativeFont, RealVector
import MakieCore: project_point2, project, to_world, transformationmatrix, orthographicprojection, perspectiveprojection, lookat, translationmatrix, scalematrix
using MakieCore: Camera, Transformation, PlotFunc
import MakieCore: to_colormap, to_color, to_font, to_rotation, FastPixel, Reverse
import MakieCore: assetpath
import MakieCore: el32convert, to_textsize, to_align, qrotation, available_gradients
export to_colormap, to_color, to_font, to_rotation
export Pixel, px, Unit, plotkey, attributes, used_attributes

using StatsFuns: logit, logistic

# Imports from Base which we don't want to have to qualify
using Base: RefValue
using Base.Iterators: repeated, drop
import Base: getindex, setindex!, push!, append!, parent, get, get!, delete!, haskey
using Observables: listeners, to_value, notify

const Node = Observable # shorthand

include("documentation/docstringextension.jl")
include("interaction/PriorityObservable.jl")
include("types.jl")
include("utilities/utilities.jl")
include("utilities/texture_atlas.jl")
include("interaction/nodes.jl")
include("interaction/liftmacro.jl")
include("colorsampler.jl")
include("patterns.jl")
# Basic scene/plot/recipe interfaces + types
include("scenes.jl")

include("theming.jl")
include("themes/theme_ggplot2.jl")
include("themes/theme_black.jl")
include("themes/theme_minimal.jl")
include("themes/theme_light.jl")
include("themes/theme_dark.jl")
include("interfaces.jl")
include("units.jl")
# include("conversions.jl")
include("shorthands.jl")

# camera types + functions
include("camera/camera.jl")
include("camera/camera2d.jl")
include("camera/camera3d.jl")
include("camera/old_camera3d.jl")

# basic recipes
include("basic_recipes/convenience_functions.jl")
include("basic_recipes/annotations.jl")
include("basic_recipes/arc.jl")
include("basic_recipes/arrows.jl")
include("basic_recipes/axis.jl")
include("basic_recipes/band.jl")
include("basic_recipes/barplot.jl")
include("basic_recipes/buffers.jl")
include("basic_recipes/contours.jl")
include("basic_recipes/contourf.jl")
include("basic_recipes/error_and_rangebars.jl")
include("basic_recipes/pie.jl")
include("basic_recipes/poly.jl")
include("basic_recipes/scatterlines.jl")
include("basic_recipes/spy.jl")
include("basic_recipes/stairs.jl")
include("basic_recipes/stem.jl")
include("basic_recipes/streamplot.jl")
include("basic_recipes/timeseries.jl")
include("basic_recipes/volumeslices.jl")
include("basic_recipes/wireframe.jl")

# layouting of plots
include("layouting/transformation.jl")
include("layouting/data_limits.jl")
include("layouting/layouting.jl")
include("layouting/boundingbox.jl")
# more default recipes
# statistical recipes
include("stats/conversions.jl")
include("stats/hist.jl")
include("stats/density.jl")
include("stats/distributions.jl")
include("stats/crossbar.jl")
include("stats/boxplot.jl")
include("stats/violin.jl")

# Interactiveness
include("interaction/events.jl")
include("interaction/interactive_api.jl")
include("interaction/inspector.jl")

# documentation and help functions
include("documentation/documentation.jl")
include("display.jl")


# help functions and supporting functions
export help, help_attributes, help_arguments

# Abstract/Concrete scene + plot types
export AbstractScene, SceneLike, Scene, AbstractScreen
export AbstractPlot, Combined, Atomic, OldAxis

# Theming, working with Plots
export Attributes, Theme, attributes, default_theme, theme, set_theme!, with_theme, update_theme!
export xlims!, ylims!, zlims!
export xlabel!, ylabel!, zlabel!

export theme_ggplot2
export theme_black
export theme_minimal
export theme_light
export theme_dark

export xticklabels, yticklabels, zticklabels
export xtickrange, ytickrange, ztickrange
export xticks!, yticks!, zticks!
export xtickrotation, ytickrotation, ztickrotation
export xtickrotation!, ytickrotation!, ztickrotation!

# Node/Signal related
export Node, Observable, lift, map_once, to_value, on, onany, @lift, off, connect!

# utilities and macros
export @recipe, @extract, @extractvalue, @key_str, @get_attribute
export broadcast_foreach, to_vector, replace_automatic!

# conversion infrastructure
export @key_str, convert_attribute, convert_arguments
export to_color, to_colormap, to_rotation, to_font, to_align, to_textsize
export to_ndim, Reverse

# Transformations
export translated, translate!, scale!, rotate!, Accum, Absolute
export boundingbox, insertplots!, center!, translation, scene_limits

# Spaces for widths and markers
const PixelSpace = Pixel
export SceneSpace, PixelSpace, Pixel

# camera related
export AbstractCamera, EmptyCamera, Camera, Camera2D, Camera3D, cam2d!, cam2d
export campixel!, campixel, cam3d!, cam3d_cad!, old_cam3d!, old_cam3d_cad!
export update_cam!, rotate_cam!, translate_cam!, zoom!
export pixelarea, plots, cameracontrols, cameracontrols!, camera, events
export to_world

# picking + interactive use cases + events
export mouseover, ispressed, onpick, pick, Events, Keyboard, Mouse, mouse_selection
export register_callbacks
export window_area
export window_open
export mouse_buttons
export mouse_position
export scroll
export keyboard_buttons
export unicode_input
export dropped_files
export hasfocus
export entered_window
export disconnect!, must_update, force_update!, update!, update_limits!
export DataInspector
export Consume

# Raymarching algorithms
export RaymarchAlgorithm, IsoValue, Absorption, MaximumIntensityProjection, AbsorptionRGBA, IndexedAbsorptionRGBA
export Billboard

# Reexports of
# Color/Vector types convenient for 3d/2d graphics
export Quaternion, Quaternionf0, qrotation
export RGBAf0, RGBf0, VecTypes, RealVector, FRect, FRect2D, IRect2D
export FRect3D, IRect3D, Rect3D, Transformation
export IRect, FRect, Rect, Rect2D, Sphere, Circle
export Vec4f0, Vec3f0, Vec2f0, Point4f0, Point3f0, Point2f0
export Vec, Vec2, Vec3, Vec4, Point, Point2, Point3, Point4
export (..), GLNormalUVMesh

export widths, decompose

# building blocks for series recipes
export PlotSpec

export plot!, plot


export Stepper, replay_events, record_events, RecordEvents, record, VideoStream
export VideoStream, recordframe!, record
export save

# colormap stuff from PlotUtils, and showgradients
export cgrad, available_gradients, showgradients

export Pattern

assetpath(files...) = normpath(joinpath(artifact"assets", files...))

export assetpath
# default icon for Makie
function icon()
    path = assetpath("icons")
    icons = FileIO.load.(joinpath.(path, readdir(path)))
    return reinterpret.(NTuple{4,UInt8}, icons)
end

function logo()
    FileIO.load(assetpath("misc", "makie_logo.png"))
end

function __init__()
    cfg_path = joinpath(homedir(), ".config", "makie", "theme.jl")
    if isfile(cfg_path)
        @warn "The global configuration file is no longer supported." *
        "Please include the file manually with `include(\"$cfg_path\")` before plotting."
    end
end


include("figures.jl")
export content

include("makielayout/MakieLayout.jl")
# re-export MakieLayout
for name in names(MakieLayout)
    @eval import .MakieLayout: $(name)
    @eval export $(name)
end

include("figureplotting.jl")
include("basic_recipes/series.jl")
include("basic_recipes/text.jl")

export Heatmap, Image, Lines, LineSegments, Mesh, MeshScatter, Scatter, Surface, Text, Volume
export heatmap, image, lines, linesegments, mesh, meshscatter, scatter, surface, text, volume
export heatmap!, image!, lines!, linesegments!, mesh!, meshscatter!, scatter!, surface!, text!, volume!


end # module
