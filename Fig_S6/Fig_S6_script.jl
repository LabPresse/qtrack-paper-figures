using SP2T
using CairoMakie
using Statistics
using StatsBase
using Random
using ColorSchemes
include("../utils.jl") 

const SCRIPT_DIR = @__DIR__
const SAVE_DIR = abspath(joinpath(SCRIPT_DIR, "../figures"))
mkpath(SAVE_DIR)

const blue = ColorSchemes.tab10.colors[1]

function calculate_msds(trajectories)
    distances = diff(trajectories, dims=1)
    squared_displacements = sum(distances .^ 2, dims=2)   # x^2 + y^2
    msd = mean(squared_displacements, dims=1)
    return dropdims(msd, dims=(1, 2))
end

function calculate_D_apparent(trajectories, dt)
    msds = calculate_msds(trajectories)
    return msds ./ (4 * dt)
end

function main()
    n_simulations = 50000
    n_frames = 6000
    period = 1e-5
    diffusion_coefficient = 0.1

    trajectories = Array{Float64}(undef, n_frames, 2, n_simulations)
    trajectories[1, :, :] = zeros(2, n_simulations)

    msd = 2 * diffusion_coefficient * period
    simulate!(trajectories, msd)

    println(size(trajectories))

    binned = bintracks(trajectories, 100)
    println(size(binned))

    batchsizes = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 3000]

    d_samples = Vector{Vector{Float64}}()

    max_val = -Inf
    max_idx = 0
    min_val = Inf
    min_idx = 0

    for batchsize in batchsizes
        println("Batchsize: $batchsize")

        binned = bintracks(trajectories, batchsize)
        d_app_bs = calculate_D_apparent(binned, period * batchsize)

        push!(d_samples, d_app_bs)

        this_max, this_max_idx = findmax(d_app_bs)
        if this_max > max_val
            max_val = this_max
            max_idx = this_max_idx
        end

        this_min, this_min_idx = findmin(d_app_bs)
        if this_min < min_val
            min_val = this_min
            min_idx = this_min_idx
        end
    end

    println("(min, max) = ($min_val, $max_val)")

    n_bins = 150
    max_val_plot = 0.2
    step_val = max_val_plot / n_bins
    bins = 0:step_val:max_val_plot
    hist_scale_factor = 0.7

    fig = Figure(size=(1000, 500))
    ax = Axis(
        fig[1, 1],
        xlabel = "Batchsize",
        ylabel = "Apparent diffusion coefficient",
        xticks = (1:length(batchsizes), string.(batchsizes))
    )

    hlines!(ax, [diffusion_coefficient], color=:black, linestyle=:dash)

    for i in eachindex(batchsizes)
        d_apparent = d_samples[i]
        hist!(
            ax,
            d_apparent,
            bins = bins,
            offset = i,
            direction = :x,
            color = blue,
            normalization = :pdf,
            scale_to = hist_scale_factor,
        )
    end

    save(joinpath(SAVE_DIR, "Fig_S6.pdf"), fig)
    display(fig)
end

main()