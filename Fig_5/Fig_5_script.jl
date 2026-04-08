using SP2T
using CairoMakie
using JLD2

dir = joinpath(pwd(), "Fig_5")

# metadata = load(joinpath(dir, "metadata.jld2"), "metadata")

factors = [0.1, 0.2, 0.5, 1.0, 2.0]

inch = 96
pt = 4 / 3
cm = inch / 2.54

fig = Figure(; size = (6inch, 4inch), fontsize = 7pt, font = "Arial")
axis_framesize = Axis(
    fig[1, 1],
    xlabel = "Number of pixels",
    ylabel = "Time per iteration (s)",
    yscale = log10,
    xscale = log2,
)
sizes = [16, 32, 64, 128, 256, 512, 1024] .^ 2
scatterlines!(
    axis_framesize,
    sizes,
    [
        21.094782 / 500,
        26.334853 / 200,
        63.290671 / 100,
        176.705872 / 50,
        165.458489 / 10,
        313.395908 / 5,
        249.874673 / 1,
    ],
)
scatterlines!(
    axis_framesize,
    sizes,
    [8.748255, 21.756765, 38.175688, 108.681775, 372.529724, 1370.256918, 5523.995111] ./
    2000,
)
scatterlines!(
    axis_framesize,
    sizes,
    [6.311231, 6.595078, 10.332345, 26.258859, 81.828142, 302.311302, 1141.116050] ./ 2000,
)

axis_nframes = Axis(
    fig[2, 1],
    xlabel = "Number of frames",
    ylabel = "Time per iteration (s)",
    yscale = log10,
    xscale = log10,
)
nframes = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000]
l1 = scatterlines!(
    axis_nframes,
    nframes,
    [
        NaN,
        8.447668 / 1000,
        7.452241 / 500,
        5.960519 / 200,
        11.488794 / 200,
        32.639796 / 200,
        33.879345 / 100,
        40.945823 / 50,
        48.986453 / 20,
        57.378373 / 10,
    ],
)
l2 = scatterlines!(
    axis_nframes,
    nframes,
    [
        0.447546,
        0.763726,
        2.005623,
        3.298759,
        6.404777,
        15.588880,
        30.844945,
        67.182005,
        173.621677,
        323.893421,
    ] ./ 2000,
)
l3 = scatterlines!(
    axis_nframes,
    nframes,
    [
        5.659603,
        7.178892,
        6.353883,
        6.534477,
        6.513216,
        6.983892,
        9.095428,
        12.796379,
        25.110002,
        43.667029,
    ] ./ 2000,
)

axis_nparticles = Axis(
    fig[1, 2],
    xlabel = "Number of emitting particles",
    # ylabel = "Time per iteration (s)",
    yscale = log10,
    xscale = log10,
)
nparticles = [1, 2, 5, 10, 20, 50, 100, 200]
l1 = scatterlines!(
    axis_nparticles,
    nparticles,
    reverse([
        83.574467 / 10,
        42.474948 / 10,
        64.690378 / 20,
        86.746821 / 30,
        58.928878 / 20,
        55.761306 / 20,
        54.457826 / 20,
        55.520056 / 20,
    ]),
)
l2 = scatterlines!(
    axis_nparticles,
    nparticles,
    reverse([
        90.129906,
        62.076980,
        48.111907,
        38.806874,
        35.881798,
        34.783449,
        34.564337,
        32.485655,
    ]) ./ 1000,
)
l3 = scatterlines!(
    axis_nparticles,
    nparticles,
    reverse([
        40.907088,
        38.889104,
        36.968032,
        36.686156,
        36.926828,
        37.427132,
        36.653276,
        36.849085,
    ]) ./ 1000,
)

axis_weaklim = Axis(
    fig[2, 2],
    xlabel = "Number of particle candidates",
    # ylabel = "Time per iteration (s)",
    yscale = log10,
    xscale = log10,
)
weaklim = [1, 2, 5, 10, 20, 50, 100, 200]
l1 = scatterlines!(
    axis_weaklim,
    weaklim,
    reverse([
        55.520056 / 20,
        30.212563 / 20,
        38.343333 / 50,
        32.764996 / 100,
        39.815461 / 200,
        68.425664 / 500,
        NaN,
        NaN,
    ]),
)
l2 = scatterlines!(
    axis_weaklim,
    weaklim,
    reverse([
        33.019432,
        18.049709,
        10.079853,
        5.541876,
        3.972533,
        3.237083,
        2.761136,
        2.613482,
    ]) ./ 1000,
)
l3 = scatterlines!(
    axis_weaklim,
    weaklim,
    reverse([
        37.521583,
        20.038792,
        11.028439,
        5.389633,
        3.673720,
        2.682955,
        2.075929,
        1.852915,
    ]) ./ 1000,
)

Legend(
    fig[0, :],
    [l1, l2, l3],
    ["BNP-Track on CPU", "QTrack on CPU", "QTrack on GPU"],
    orientation = :horizontal,
    framevisible = false,
)

for (label, layout) in
    zip(["a", "b", "c", "d"], [fig[1, 1], fig[2, 1], fig[1, 2], fig[2, 2]])
    Label(
        layout[1, 1, TopLeft()],
        label,
        fontsize = 7pt,
        font = "Arial Bold",
        # padding = (0, 5, 5, 0), 
        halign = :right,
    )
end

save(joinpath(dir, "fig4.pdf"), fig)