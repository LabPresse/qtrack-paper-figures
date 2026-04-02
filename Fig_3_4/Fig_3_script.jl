using SP2T
using CairoMakie
using JLD2

dir = joinpath(pwd(), "background")

metadata = load(joinpath(dir, "metadata.jld2"), "metadata")

factors = [0.5, 1.0, 2.0, 5.0, 10.0]

inch = 96
pt = 4 / 3
cm = inch / 2.54

fig = Figure(; size = (6inch, 4.15inch), fontsize = 7pt, font = "Arial")

axis = []

# maxcount = 0
# mincount = Inf
# for (i, factor) in enumerate(factors)
#     frames = load(joinpath(dir, "frames_$(factor).jld2"), "frames")
#     if maxcount < maximum(frames)
#         maxcount = maximum(frames)
#     end
#     if mincount > minimum(frames)
#         mincount = minimum(frames)
#     end
# end

for (i, factor) in enumerate(factors)
    push!(axis, Axis(fig[1, i], aspect = DataAspect()))
    frames = load(joinpath(dir, "frames_$(factor).jld2"), "frames")
    avgframes = sum(frames, dims = 3) ./ size(frames, 3)
    heatmap!(
        axis[end],
        (0:128) .* metadata["pixel size"],
        (0:128) .* metadata["pixel size"],
        view(avgframes, :, :, 1),
        colormap = :bone,
    )
    rangebars!(axis[end], [0.3], [0.1], [5.1], direction = :x, color = :white)
    text!(axis[end], 2.55, 0.3, text = "2 μm", color = :white, align = (:center, :bottom))
end
hidedecorations!.(axis)
hidespines!.(axis)

accuracyaxis = Axis(
    fig[3, :],
    xscale = Makie.pseudolog10,
    xticks = [30, 60, 120, 300, 600],
    xticklabelsvisible = false,
    ylabel = "Detection rate (%)",
)
accuracyTM = [100.0, 100.0, 97.0, 54.0, 10.0]
l1 = scatterlines!(accuracyaxis, 58.3737 .* factors, fill(100, length(factors)))
l2 = scatterlines!(accuracyaxis, 58.3737 .* factors, fill(100, length(factors)))
l3 = scatterlines!(accuracyaxis, 58.3737 .* factors, accuracyTM)

timeaxis = Axis(
    fig[4, :],
    xscale = Makie.pseudolog10,
    xlabel = "Number of background photons",
    # xticklabelsvisible = false,
    xticks = [30, 60, 120, 300, 600],
    ylabel = "Time per iteration (s)",
    yscale = log10,
    # yticks = [1, 0.1, 0.01, 0.001, 0.0001],
)
times1 = [17.547559, 16.944227, 17.000462, 16.743845, 16.334851] ./ 50
times2 =
    [
        (1 * 60 + 1) * 60 + 13,
        (1 * 60 + 1) * 60 + 18,
        (0 * 60 + 59) * 60 + 8,
        (1 * 60 + 3) * 60 + 10,
        ((1 * 50 + 55) * 60 + 33) / 2,
    ] ./ 500000
timesTM = [0.001, 0.001, 0.001, 0.001, 0.001]
scatterlines!(timeaxis, 58.3737 .* factors, times1)
scatterlines!(timeaxis, 58.3737 .* factors, times2)
scatterlines!(timeaxis, 58.3737 .* factors, timesTM)

linkxaxes!(accuracyaxis, timeaxis)
xlims!(timeaxis, 28.3, 600)
ylims!(timeaxis, nothing, 1)
# ylims!(accuracyaxis, 0, nothing)

Legend(
    fig[2, :],
    [l1, l2, l3],
    ["BNP-Track", "QTrack", "TrackMate"],
    orientation = :horizontal,
    framevisible = false,
) 

for (label, layout) in zip(["a", "b", "c"], [fig[1, :], fig[3, :], fig[4, :]])
    Label(
        layout[1, 1, TopLeft()],
        label,
        fontsize = 8pt,
        font = "Arial Bold",
        # padding = (0, 5, 5, 0), 
        halign = :right,
    )
end

colgap!(fig.layout, 0)
rowgap!(fig.layout, 0)
rowsize!(fig.layout, 2, 12)
save(joinpath(dir, "fig2.pdf"), fig)