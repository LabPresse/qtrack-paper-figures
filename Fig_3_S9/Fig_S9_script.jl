using JLD2
using CairoMakie
using SP2T
using Statistics
using SP2TExtra
using ColorSchemes
# include(joinpath(@__DIR__, "..", "utils.jl"))

if length(ARGS) >= 1
    if ARGS[1] == "precomputed"
        inf_dir_name = "precomputed_inference_results"
    elseif ARGS[1] == "test"
        inf_dir_name = "test_inference_results"
    else
        inf_dir_name = "inference_results"
    end
else
    inf_dir_name = "inference_results"
end

const SCRIPT_DIR = @__DIR__
const INF_DIR = joinpath(SCRIPT_DIR, inf_dir_name, "inf_beads")
const SAVE_DIR = joinpath(SCRIPT_DIR, "..", "figures")


function make_fig()
    chain = load(joinpath(INF_DIR, "chain_15.jld2"), "chain")
    all_tracks = xml2tracks(joinpath(SCRIPT_DIR, "frames15_median_Tracks.xml"), batchsize=1, nframes=750)[:, 1:2, :]
    all_tracks[:,  [1,2], :] = all_tracks[:, [2,1], :]
    println("(nframes, dims, n_tracks) ", size(all_tracks))

    period = 20e-6
    detector_size = 55
    pixel_size = 0.1
    batchsize = 15
    dt = period * batchsize
    n_frames = 750
    t = 0:dt:(n_frames - 1) * dt
    burn_in = 750

    xshift = 0.025
    yshift = 0.045

    inch = 96
    pt = 4 / 3

    # fig = Figure(; size = (6inch, 4inch), fontsize = 7pt, font = "Arial", colgap=0, rowgap=0)
    fig = Figure(; size = (12inch, 8inch), fontsize = 14pt, font = "Arial")

    mean_track = zeros(n_frames, 2, 3) # frames x (x,y) x particles
    for i in burn_in:length(chain.samples)
        mean_track .+= chain.samples[i].tracks
    end
    mean_track ./= (length(chain.samples) - burn_in + 1);
    println("x mean: ", mean_track[1, 1, :])
    println("y mean: ", mean_track[1, 2, :])
    plot_bounds = [-0.25, 0.25]
    edges = plot_bounds[1]:5e-3:plot_bounds[2]
    crediblex1, credibley1 = @views credible1D(chain.samples[burn_in + 1:end], 1, edges, edges, factor=1, xshift=-mean(mean_track[:, 1, 1]) + xshift, yshift=-mean(mean_track[:, 2, 1]) + yshift)
    crediblex2, credibley2 = @views credible1D(chain.samples[burn_in + 1:end], 2, edges, edges, factor=1, xshift=-mean(mean_track[:, 1, 2]) + xshift, yshift=-mean(mean_track[:, 2, 2]) + yshift)
    crediblex3, credibley3 = @views credible1D(chain.samples[burn_in + 1:end], 3, edges, edges, factor=1, xshift=-mean(mean_track[:, 1, 3]) + xshift, yshift=-mean(mean_track[:, 2, 3]) + yshift)
    crediblex = [crediblex1, crediblex2, crediblex3]
    credibley = [credibley1, credibley2, credibley3]

    maxcount = log10(max(
        maximum(crediblex1), maximum(credibley1),
        maximum(crediblex2), maximum(credibley2),
        maximum(crediblex3), maximum(credibley3)))#, 0.1))
    mincount = min(
        minimum(replace(log10.(crediblex1), -Inf => Inf)),
        minimum(replace(log10.(credibley1), -Inf => Inf)), 
    )
    println(mincount, maxcount)

    ax_x = [
        Axis(fig[1,1], ylabel="Position (μm)", title="x-trajectory", xticklabelsvisible=false),
        Axis(fig[2,1], ylabel="Position (μm)", xticklabelsvisible=false),
        Axis(fig[3,1], ylabel="Position (μm)", xlabel="Time (s)")
    ]
    ax_y = [
        Axis(fig[1,2], title="y-trajectory", xticklabelsvisible=false, yticklabelsvisible=false),
        Axis(fig[2,2], xticklabelsvisible=false, yticklabelsvisible=false),
        Axis(fig[3,2], xlabel="Time (s)", yticklabelsvisible=false)
    ]
    hm = nothing
    for particle_idx in 1:3
        hm = heatmap!(
            ax_x[particle_idx],
            t,
            edges,
            log10.(crediblex[particle_idx]),
            colorrange=(mincount, maxcount),
            colormap=Reverse(ColorSchemes.oslo)
        )
        hm = heatmap!(
            ax_y[particle_idx],
            t,
            edges,
            log10.(credibley[particle_idx]),
            colorrange=(mincount, maxcount),
            colormap=Reverse(ColorSchemes.oslo)
        )
        ylims!(ax_x[particle_idx], plot_bounds...)
        ylims!(ax_y[particle_idx], plot_bounds...)
    end

    x_bounds = [[2,3], [3,4], [4,5]]
    y_bounds = [[0,1], [4,5], [3,4]]
    # x_shift_trackmate = [0.045, 0.01, 0.07]
    # y_shift_trackmate = [0.01, 0.025, 0.04]
    # x_shift_trackmate = [0,0,0]
    # y_shift_trackmate = [0,0,0]
    x_shift_trackmate = [0.05, 0.05, 0.05] # FIJI has 1/2 pixel origin shift relative to QTrack definition
    y_shift_trackmate = [0.05, 0.05, 0.05]
    sum_r2 = [0.0, 0.0, 0.0]
    n_valid = [0.0, 0.0, 0.0]
    for ti in 1: size(all_tracks, 3)
        x_traj = all_tracks[:, 1, ti] 
        y_traj = all_tracks[:, 2, ti] 
        mean_x = mean(filter(!isnan, x_traj))
        mean_y = mean(filter(!isnan, y_traj))
        if mean_x > x_bounds[1][1] && mean_x < x_bounds[1][2] && mean_y > y_bounds[1][1] && mean_y < y_bounds[1][2]
            particle_idx = 1
        elseif mean_x > x_bounds[2][1] && mean_x < x_bounds[2][2] && mean_y > y_bounds[2][1] && mean_y < y_bounds[2][2]
            particle_idx = 2
        elseif mean_x > x_bounds[3][1] && mean_x < x_bounds[3][2] && mean_y > y_bounds[3][1] && mean_y < y_bounds[3][2]
            particle_idx = 3
        else
            println("Trajectory segment $ti has x mean $mean_x and y mean $mean_y")
        end
        x_traj = x_traj .+ x_shift_trackmate[particle_idx] .- mean(mean_track[:, 1, particle_idx]) .+ xshift
        y_traj = y_traj .+ y_shift_trackmate[particle_idx] .- mean(mean_track[:, 2, particle_idx]) .+ yshift

        x_mean = mean_track[:, 1, particle_idx] .- mean(mean_track[:, 1, particle_idx]) .+ xshift
        y_mean = mean_track[:, 2, particle_idx] .- mean(mean_track[:, 2, particle_idx]) .+ yshift

        mask = isfinite.(x_traj) .& isfinite.(y_traj) .& isfinite.(x_mean) .& isfinite.(y_mean)
        dx = x_traj[mask] .- x_mean[mask]
        dy = y_traj[mask] .- y_mean[mask]
        # sum_r2 += sum(dx.^2 .+ dy.^2)
        # n_valid += length(dx)
        sum_r2[particle_idx] += sum(dx.^2 .+ dy.^2)
        n_valid[particle_idx] += length(dx)

        ## Plotting
        lines!(ax_x[particle_idx], t, x_traj, alpha=0.6)
        lines!(ax_y[particle_idx], t, y_traj, alpha=0.6)
        # lines!(ax_x[particle_idx], t, x_mean, color=:red, linestyle=:dash, alpha=0.6)
        # lines!(ax_y[particle_idx], t, y_mean, color=:red, linestyle=:dash, alpha=0.6)
        lines!(ax_x[particle_idx], t, chain.samples[end].tracks[:,1, particle_idx], color=:black)
        lines!(ax_y[particle_idx], t, chain.samples[end].tracks[:,2, particle_idx], color=:black)

    end
    for i in 1:3
        radial_rms = sqrt(sum_r2[i] / n_valid[i]) * sqrt(2)
        println("Radial RMS error: $radial_rms μm")
    end

    Colorbar(fig[1:3, 3], hm, vertical=true, ticks=(-3:-1, ["10⁻³", "10⁻²", "10⁻¹"]), ticksize=2, label="Confidence", width=10)

    for (label, layout) in zip(["a", "b", "c", "d", "e", "f"], [fig[1, 1], fig[1, 2], fig[2, 1], fig[2, 2], fig[3, 1], fig[3, 2]])
        Label(layout[1, 1, TopLeft()],
                label,
                # fontsize = 8pt,
                fontsize=16pt,
                font = "Arial Bold",
                halign = :right)
    end

    return fig
end

function main()
    fig = make_fig()
    mkpath(SAVE_DIR)
    save(joinpath(SAVE_DIR, "Fig_S9.pdf"), fig)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
