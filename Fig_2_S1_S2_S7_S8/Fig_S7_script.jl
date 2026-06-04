using JLD2
using SP2T
using CairoMakie
using Statistics
using LinearAlgebra
using TOML
using ColorSchemes
include("../utils.jl")

function calculate_msd(track)
    distances = diff(track, dims=1)
    squared_displacements = sum(distances .^ 2, dims=2) # x^2 + y^2
    msd = mean(squared_displacements, dims=1)
    return msd[1]
end

const SCRIPT_DIR = @__DIR__
const SAVE_DIR = abspath(joinpath(SCRIPT_DIR, "../figures"))
const INF_ROOT = abspath(joinpath(SCRIPT_DIR, "inference_results"))

blue = ColorSchemes.tab10.colors[1]
green = ColorSchemes.tab10.colors[3]
red = ColorSchemes.tab10.colors[4]
colors = [blue, green, red]

period = 10e-6
burnin = 100
batchsizes = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 3000]
size_limit = 1001
indep_interval = 1 

fig = Figure(size=(1000, 700), rowgap=0)
scale = :width
axes_list = []
bin_ranges = [
    [0,17],
    [0,2.2],
    [0,0.35]
]

D_true_vals = [10.0, 1.0, 0.1]
for (di, D_true) in enumerate(D_true_vals)
    dir = joinpath(INF_ROOT, "inf_Fig_2_D$D_true")

    ############# Get inferred D samples ###############
    n_samples = length(collect(burnin:indep_interval:size_limit))
    D_inf_vals = []
    xs_violin = []
    for (j,batchsize) in enumerate(batchsizes)
        chainfile = joinpath(dir, "chain_$(batchsize).jld2")
        chain = load(chainfile, "chain")
        samples = collect(burnin:indep_interval:size_limit)
        # msd_chain_vals = Float64[]
        # tracks_to_avg = zeros(length(samples), size(chain.samples[1].tracks, 1), size(chain.samples[1].tracks, 2))
        D_inf_j = []
        for (i, s) in enumerate(samples)
            track = chain.samples[s].tracks
            msd = calculate_msd(track)
            Dinf = msd ./ (2 * 2 * period * batchsize) # 2 * dim * dt
            # D_inf_vals[j, i] = Dinf[1]
            push!(D_inf_j, Dinf)
        end
        # println(size(D_inf_j))
        push!(xs_violin, fill(j, n_samples))
        push!(D_inf_vals, D_inf_j)
    end

    xs_violin = vcat(xs_violin...);
    D_inf_vals_list = copy(D_inf_vals)
    D_inf_vals = vcat(D_inf_vals...);

    ######### Get the apparent diffusion coefficient from ground truth ############
    tracks_gt = load(joinpath(dir, "groundtruth.jld2"), "tracks")
    n_frames = size(tracks_gt, 1)

    Ds_batched_gt = []
    xs_gt = [] # the batchsize index for each MSD value, for plotting purposes
    for (b,batchsize) in enumerate(batchsizes)
        n_batched_frames = n_frames ÷ batchsize
        # construct xy averaged track
        batched_track = zeros(n_batched_frames, 2)
        for j in 1:n_batched_frames
            batched_track[j, :] = mean(tracks_gt[(j-1)*batchsize+1:j*batchsize, :], dims=1)
        end
        msd_gt = calculate_msd(batched_track)
        push!(Ds_batched_gt, msd_gt ./ (4 * batchsize * period))
    end

    ######################### Plot #########################
    ax = Axis(fig[di, 1],
        xlabel = di==3 ? "Batch size"  : "",
        ylabel = rich("Diffusion coefficient (μm", superscript("2"), "/s)")
    )
    push!(axes_list, ax)
    if di!=3
        hidexdecorations!(grid=false)
    end

    n_bins = 50
    bins = bin_ranges[di][1]:bin_ranges[di][2]/n_bins:bin_ranges[di][2]
    # vertical histogram
    for i in 1:length(batchsizes)
        hist!(ax, 
            D_inf_vals_list[i],
            bins=bins,
            direction=:x,
            scale_to=0.7,
            color=colors[di],
            normalization=:pdf,
            offset=i
            )
    end

    scatter!(1:length(batchsizes), Ds_batched_gt; 
        label="Apparent diffusion coefficient", 
        markersize=20,
        marker=:xcross,
        color=:black
    )
    hlines!(D_true, linestyle=:dash, color=:black, label="Ensemble diffusion coefficient (D=$D_true μm²/s)")
    # tick_labels = ["1\n(10 μs)", "2", "5", "10\n(100 μs)", "20", "50", "100\n(1 ms)"]
    tick_labels = string.(batchsizes)
    ax.xticks = (1:length(batchsizes), tick_labels)
    axislegend()
end

ylims!(axes_list[3], -0.05, 0.35)


display(fig)

save(joinpath(SAVE_DIR, "Fig_S7.pdf"), fig)
