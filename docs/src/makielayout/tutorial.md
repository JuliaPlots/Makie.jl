```@eval
using CairoMakie
CairoMakie.activate!()
```

# Layout Tutorial

In this tutorial, we will see some of the capabilities of layouts in Makie while
building a complex figure step by step. This is the final result we will create:

![layout_tutorial_final](layout_tutorial_final.svg)

```@raw html
<details><summary>You can click here to see the full code</summary>
```

```julia
using CairoMakie

noto_sans = assetpath("fonts", "NotoSans-Regular.ttf")
noto_sans_bold = assetpath("fonts", "NotoSans-Bold.ttf")

fig = Figure(backgroundcolor = RGBf(0.98, 0.98, 0.98),
    resolution = (1000, 700), font = noto_sans)

ax1 = fig[1, 1] = Axis(fig, title = "Pre Treatment")

data1 = randn(50, 2) * [1 2.5; 2.5 1] .+ [10 10]

line1 = lines!(ax1, 5..15, x -> x, color = :red, linewidth = 2)
scat1 = scatter!(ax1, data1,
    color = (:red, 0.3), markersize = 15px, marker = '■')

ax2, line2 = lines(fig[1, 2], 7..17, x -> -x + 26,
    color = :blue, linewidth = 2,
    axis = (title = "Post Treatment",))

data2 = randn(50, 2) * [1 -2.5; -2.5 1] .+ [13 13]

scat2 = scatter!(data2,
    color = (:blue, 0.3), markersize = 15px, marker = '▲')

linkaxes!(ax1, ax2)

hideydecorations!(ax2, grid = false)

ax1.xlabel = "Weight [kg]"
ax2.xlabel = "Weight [kg]"
ax1.ylabel = "Maximum Velocity [m/sec]"

leg = fig[1, end+1] = Legend(fig,
    [line1, scat1, line2, scat2],
    ["f(x) = x", "Data", "f(x) = -x + 26", "Data"])

fig[2, 1:2] = leg

trim!(fig.layout)

leg.tellheight = true

leg.orientation = :horizontal

hm_axes = fig[1:2, 3] = [Axis(fig, title = t) for t in ["Cell Assembly Pre", "Cell Assembly Post"]]

heatmaps = [heatmap!(ax, i .+ rand(20, 20)) for (i, ax) in enumerate(hm_axes)]

hm_sublayout = GridLayout()
fig[1:2, 3] = hm_sublayout

# there is another shortcut for filling a GridLayout vertically with
# a vector of content
hm_sublayout[:v] = hm_axes

hidedecorations!.(hm_axes)

for hm in heatmaps
    hm.colorrange = (1, 3)
end

cbar = hm_sublayout[:, 2] = Colorbar(fig, heatmaps[1], label = "Activity [spikes/sec]")

cbar.height = Relative(2/3)

cbar.ticks = 1:0.5:3

supertitle = fig[0, :] = Label(fig, "Complex Figures with Makie",
    textsize = 24, font = noto_sans_bold, color = (:black, 0.25))

label_a = fig[2, 1, TopLeft()] = Label(fig, "A", textsize = 24,
    font = noto_sans_bold, halign = :right)
label_b = fig[2, 3, TopLeft()] = Label(fig, "B", textsize = 24,
    font = noto_sans_bold, halign = :right)

label_a.padding = (0, 6, 16, 0)
label_b.padding = (0, 6, 16, 0)

# Aspect(1, 1) means that relative to row 1
# (row because we're setting a colsize,
# and aspect ratios are always about the other side)
# we set the column to an aspect ratio of 1

colsize!(hm_sublayout, 1, Aspect(1, 1))

save("layout_tutorial_final.svg", fig)
```

```@raw html
</details>
```

All right, let's get started!

## Importing a backend

First, we import CairoMakie, which re-exports Makie.

```@example tutorial
using CairoMakie
```

The same works for the other backends WGLMakie and GLMakie.
You can find an overview of the different backends with their capabilities in [Backends & Output](@ref).
The old MakieLayout package which you needed to install separately is deprecated, since it now lives directly in Makie.
As a side note, if you do not want to make plotting code backend dependent, for example inside a package where the user should choose the backend themselves, you can depend on `Makie` alone.
This allows the user to do:

```julia
using CustomPlots # depends only on Makie
using GLMakie # chooses GLMakie as the backend for CustomPlots
```

## Creating a figure

We create an empty `Figure` which will hold all our content elements and organize them in a layout.

```@example tutorial
using CairoMakie
using Random # hide
Random.seed!(2) # hide

noto_sans = assetpath("fonts", "NotoSans-Regular.ttf")
noto_sans_bold = assetpath("fonts", "NotoSans-Bold.ttf")

fig = Figure(backgroundcolor = RGBf(0.98, 0.98, 0.98),
    resolution = (1000, 700), font = noto_sans)

fig
```

## First axis

The figure is completely empty, I have made the background light gray so it's easier
to see. Now we add an `Axis`.

We create the axis and place it into the figure's layout in one go. You place objects in
a figure by using indexing syntax. You can save the axis in a variable by chaining
the `=` expressions.

We call the axis title "Pre Treatment" because we're going to plot some made up measurements,
like they could result from an experimental trial.

```@example tutorial
ax1 = fig[1, 1] = Axis(fig, title = "Pre Treatment")

fig
```

## Plotting into an axis

We can plot into the axis with the ! versions of Makie's plotting functions.
Such mutating function calls return the plot object that is created, which we save for later.

```@example tutorial
data1 = randn(50, 2) * [1 2.5; 2.5 1] .+ [10 10]

line1 = lines!(ax1, 5..15, x -> x, color = :red, linewidth = 2)
scat1 = scatter!(ax1, data1,
    color = (:red, 0.3), markersize = 15px, marker = '■')

fig
```

## Multiple axes

This looks nice already, but we want another axis with a second dataset, to
the right of the one we have. Currently our layout has one row and one cell, and
only one Axis inside of it:

```@example tutorial
fig.layout
```

We can extend the grid with a new axis by plotting into a new grid position. Let's place a new axis
with another line plot next to the one we have, in row 1 and column 2.

We can use the non-mutating plotting syntax and pass a position in our figure as the first argument.
When we index into a figure, we get a `GridPosition` object which describes the position we want
to put our new axis in.

The plotting call returns an `AxisPlot` object which we can directly destructure into axis and plot.

```@example tutorial
ax2, line2 = lines(fig[1, 2], 7..17, x -> -x + 26,
    color = :blue, linewidth = 2,
    axis = (title = "Post Treatment",))

fig
```

As you can see, the first axis has shrunk to the left to make space for the new
axis on the right. We can take another look at the `layout` to see how it has
changed:

```@example tutorial
fig.layout
```

Let's plot into the new axis, the same way we did the scatter plots before.
We can also leave out the axis as the first argument if we just want to plot into
the current axis.

```@example tutorial
data2 = randn(50, 2) * [1 -2.5; -2.5 1] .+ [13 13]

scat2 = scatter!(data2,
    color = (:blue, 0.3), markersize = 15px, marker = '▲')

fig
```

## Linking axes

We want to make the left and right axes correspond to each other, so we can compare
the plots more easily. To do that, we link both x and y axes. That will keep them
synchronized. The function `linkaxes!` links both x and y, `linkxaxes!` links only x and
`linkyaxes!` links only y.

```@example tutorial
linkaxes!(ax1, ax2)

fig
```

This looks good, but now both y-axes are the same, so we can hide the right one
to make the plot less cluttered. We keep the grid lines, though. You can see that
now that the y-axis is gone, the two Axes grow to fill the gap.

```@example tutorial
hideydecorations!(ax2, grid = false)

fig
```

Even though our plots are entirely made up, we should follow best practice and label
the axes. We can do this with the `xlabel` and `ylabel` attributes of the `Axis`.

```@example tutorial
ax1.xlabel = "Weight [kg]"
ax2.xlabel = "Weight [kg]"
ax1.ylabel = "Maximum Velocity [m/sec]"

fig
```

## Adding a legend

Let's add a legend to our figure that describes elements from both axes. We use
Legend for that. Legend is a relatively complex object and there are many
ways to create it, but here we'll keep it simple. We place the legend on the
right again, in row 1 and column 3. Instead of specifying column three, we can
also say `end+1`.

```@example tutorial
leg = fig[1, end+1] = Legend(fig,
    [line1, scat1, line2, scat2],
    ["f(x) = x", "Data", "f(x) = -x + 26", "Data"])

fig
```

You can see one nice feature of Makie here, which is that the legend takes
much less horizontal space than the two axes. In fact, it takes exactly the space
that it needs. This is possible because layoutable objects in Makie can tell their width
or height to their parent `GridLayout`, which can then shrink the row or column
appropriately.

One thing that could be better about this plot, is that the legend looks like
it belongs only to the right axis, even though it describes elements from both
axes. So let's move it in the middle below the two. This is easily possible in
Makie, without having to recreate the plot from scratch. We simply assign
the legend to its new slot.

We want it in the second row, and spanning the first two columns.

```@example tutorial
fig[2, 1:2] = leg

fig
```

## Fixing spacing issues

There are a couple of things wrong with this. The legend is where we want it, below the
two axes. But it takes too much space vertically, and there is a large gap on the right.

Let's deal with the gap on the right first. It's the hole that was left by the
legend, and it's even bigger now because it gets an equal share of space with the
two axes, now that there is no legend shrinking the column width to its own size.

We can remove empty cells in a layout by calling `trim!` on it:

```@example tutorial
trim!(fig.layout)

fig
```

This is much better already! But the legend still takes too much space vertically.
The reason for that is the default `tellheight` setting of the legend. It's set to
`false`, which essentially means that it can compute its own height, but
doesn't tell the layout about it. This makes sense for the most common situation
where the legend sits on the right of an axis. We wouldn't want the axis to shrink
to the height of the legend. But now that the legend has its own row, we do want
this behavior. So we set the `tellheight` attribute to `true`.

```@example tutorial
leg.tellheight = true

fig
```

Now the legend's row is shrunk to fit. One thing that we can do to improve the
use of space is to change the legend's orientation to `:horizontal`.

```@example tutorial
leg.orientation = :horizontal

fig
```

## Nested layouts

Let's add two new axes with heatmaps! We want them stacked on top of each other
on the right side of the figure. We'll do the naive thing first, which is to
place them in the first and second row of the third column. There are multiple
versions of layout assignment syntax for convenience. Here, we create and assign
two axes at once. The number of cells and objects has to match to do this.

```@example tutorial
hm_axes = fig[1:2, 3] = [Axis(fig, title = t) for t in ["Cell Assembly Pre", "Cell Assembly Post"]]

heatmaps = [heatmap!(ax, i .+ rand(20, 20)) for (i, ax) in enumerate(hm_axes)]

fig
```

This looks weird, the two axes do not have the same height. Rather, the lower
one has the height of the legend in the same row. What can we do to remedy this
situation?

We have to recognize that what we want is not possible with one layout. We don't care
about the heatmap axes being the same height as the other two axes and the legend,
respectively. We only care that the top and the bottom of the two groups are aligned.

There is usually more than one solution for any given layout problem. In other
plotting software, people sometimes circumvent our current issue by dividing the layout
into many more cells than there are content objects, and have the content span several rows or
columns. For example the left axes span rows 1:10, the legend 10:12, while the
heatmap axes span rows 1:6 and 7:12, respectively.
This is complicated, not very flexible, and luckily unnecessary in MakieLayout.

We will instead help ourselves by using a nested `GridLayout`, just for the two
heatmap axes. We move the axes into it by assigning them to their new slots.
The detaching from the main layout happens automatically.

```@example tutorial
hm_sublayout = GridLayout()
fig[1:2, 3] = hm_sublayout

# there is another shortcut for filling a GridLayout vertically with
# a vector of content
hm_sublayout[:v] = hm_axes

fig
```

We don't care about the axis decorations, as it's often the case with image plots.
The function `hidedecorations!` hides both x and y decorations at once.

```@example tutorial

hidedecorations!.(hm_axes)

fig
```

## Adding a colorbar

Now, we also want to add a color bar for the two heatmaps. Right now, their colors
are independently scaled from each other. We choose a scale that makes sense for
both of them (in our case, we know data ranges only from 1 to 3) and assign that
to both heatmaps. Then we create a `Colorbar` object with one of the heatmaps.
This way, the color bar copies color range and color map from that heatmap.

We want to place the color bar to the right of the heatmaps, spanning the full
height. We could either place it within the sublayout we just created, or in the
main layout. Both versions can be made to look the same, but we'll choose the
sublayout, because that is a more meaningful grouping, and we could move the whole
assembly around later by moving only the sublayout.

We can place an object along all existing rows or columns using the `:` notation.

```@example tutorial
for hm in heatmaps
    hm.colorrange = (1, 3)
end

cbar = hm_sublayout[:, 2] = Colorbar(fig, heatmaps[1], label = "Activity [spikes/sec]")

fig
```

Objects can have a width or height relative to the space given to them by their
parent `GridLayout`. If we feel that the colorbar is a bit too tall, we can shrink it
to two thirds of the available height using `Relative(2/3)`.

If you only specify a number like `30`, it is interpreted as `Fixed(30)`.

```@example tutorial
cbar.height = Relative(2/3)

fig
```

We don't really like the automatically chosen tick values here. Sometimes, the automatic
algorithms just don't choose the values we want, so let's change them.
We can set the `ticks` attribute to any iterable of numbers that we want.

```@example tutorial
cbar.ticks = 1:0.5:3

fig
```

## Adding a title

Now the plot could use a title! While other plotting packages sometimes have
functions like `supertitle`, they often don't work quite right or force you to
make manual adjustments. In Makie, the `Label` object is much more flexible
as it allows you to place text anywhere you want. We therefore create our super
title not with a dedicated function but as a simple part of the whole layout.

How can we place content in a row above row 1? This is easy in Makie, as
indexing outside of the current GridLayout cells works not only with higher numbers
but also with lower numbers. Therefore, we can index into the zero-th row, which
will create a new row and push all other content down.

Note that after this, all the cell indices of our current content will have changed
to reflect the new GridLayout size.

```@example tutorial
supertitle = fig[0, :] = Label(fig, "Complex Figures with Makie",
    textsize = 24, font = noto_sans_bold, color = (:black, 0.25))

fig
```

## Subplot labels

In figures meant for publication, you often need to label subplots with letters
or numbers. These can sometimes cause trouble because they overlap with other
content, which has to be fixed after the fact in vector graphics software.

This is not necessary in Makie. Let's place letters in the upper left corners
of the left group and the right group. To do that, we will make use of a property
of layouts that we have used without mentioning it. When we place our letters, we
want them to act similarly to the axis titles or labels. In Makie, layoutable
objects have an inner part, which is considered the "important" area that should
align with other "important" inner areas. You can see that the three upper axes
align with their top spines, and not their titles.

All that is outside of the main area is part of the "protrusions". These help keeping
the logic of the layout simple while allowing to easily align what is supposed to
be aligned.

So for our corner letters, we don't want to create new columns or rows. Doing that
would probably cause alignment issues in most cases. Instead, we place these objects
_inside_ the protrusions of existing cells. That means they are part of the gaps
between columns and rows, which is fitting for our labels.

We can do this by specifying the `Side` as a third argument when indexing the layout.
The default we have used so far is `Inside()`. For us, `TopLeft()` is the correct
choice. (Remember that our previously first row is now the second row, due to the
super title.)

```@example tutorial
label_a = fig[2, 1, TopLeft()] = Label(fig, "A", textsize = 24,
    font = noto_sans_bold, halign = :right)
label_b = fig[2, 3, TopLeft()] = Label(fig, "B", textsize = 24,
    font = noto_sans_bold, halign = :right)

fig
```

That looks good! You can see that the letters, larger than the axis titles, have
increased the gap between the title and the axes to fit them. In most other
plotting software, you can easily get overlap issues when you add labels like these between other elements.

We still want to give the labels a bit of padding at the bottom and the right,
so they are not too close to the axes. The order of the padding values
is (left, right, bottom, top).

```@example tutorial
label_a.padding = (0, 6, 16, 0)
label_b.padding = (0, 6, 16, 0)

fig
```

## Tweaking aspect ratios

One last thing we could improve is the shape of the heatmaps. We have square heatmaps in terms of data ratios,
but they are a bit rectangular in the plot. In order to correctly make them square and have the rest of the layout
adapt correctly, we don't just set the aspect ratio of each heatmap axis to 1. This would be possible,
but would leave gaps where the assigned space which is still rectangular isn't used.

Instead, we will tell the layout, that we want the column in which both heatmaps are should be at an aspect ratio of
1 with the first row. As both rows are at Auto size, they will both be square afterwards, and the layout will still be tight
because the left two axes will grow to fill the remaining space.

```@example tutorial
# Aspect(1, 1) means that relative to row 1
# (row because we're setting a colsize,
# and aspect ratios are always about the other side)
# we set the column to an aspect ratio of 1

colsize!(hm_sublayout, 1, Aspect(1, 1))

save("layout_tutorial_final.svg", fig) # hide
fig
```

And there we have it! Hopefully this tutorial has given you an overview how to
approach the creation of a complex figure in Makie. Check the rest of the
documentation for more details and other dynamic parts like sliders and buttons!

```@eval
using GLMakie
GLMakie.activate!()
```
