using SP2T
using JLD2
using CairoMakie
using Statistics
using ColorSchemes

const FIG_DIR = @__DIR__
const BASE_DIR = abspath(joinpath(FIG_DIR, ".."))
const INF_ROOT = abspath(joinpath(FIG_DIR, "inference_results"))
const SIM_ROOT = abspath(joinpath(FIG_DIR, "simulations"))

batchsizes = [1, 2, 5, 10, 20, 50, 100]#, 200, 500, 1000, 2000, 3000]
burn_in = 100
period = 1e-5
color = ColorSchemes.tab10.colors[4]
cyan = ColorSchemes.tab10.colors[10]
markersize = 20

fig = Figure(size=(800, 600))

####### Frame for Figure 2 ########
pixel_size = 0.133
ax_1 = Axis(fig[1,1])
frames = load(joinpath(SIM_ROOT, "sim_Fig_2_D0.1", "frames.jld2"), "frames")
W, H, _ = size(frames)
x = (0:W-1) .* pixel_size .+ pixel_size/2
y = (0:H-1) .* pixel_size .+ pixel_size/2
gt_1 = load(joinpath(SIM_ROOT, "sim_Fig_2_D0.1", "groundtruth.jld2"), "tracks")
sum_frames = dropdims(sum(frames, dims=3), dims=3)
heatmap!(ax_1, x, y, sum_frames, colormap=:grays)
lines!(ax_1, gt_1[:, 1], gt_1[:, 2], color=cyan, linewidth=2, label="Ground truth")
hidedecorations!(ax_1)
xlims!(ax_1, 1.75, 2.5)
ylims!(ax_1, 0.4, 1.15)

######### Frame with different parameters and same trajectory as Fig 2 ########
pixel_size = 0.1
ax_2 = Axis(fig[1,2])
frames = load(joinpath(SIM_ROOT, "sim_Fig_S1_D0.1", "frames.jld2"), "frames")
W, H, _ = size(frames)
x = (0:W-1) .* pixel_size .+ pixel_size/2
y = (0:H-1) .* pixel_size .+ pixel_size/2
sum_frames = dropdims(sum(frames, dims=3), dims=3)
heatmap!(ax_2, x, y, sum_frames, colormap=:grays)
gt = load(joinpath(SIM_ROOT, "sim_Fig_S1_D0.1", "groundtruth.jld2"), "tracks")
lines!(ax_2, gt[:, 1], gt[:, 2], color=cyan, linewidth=2, label="Ground truth")
# lines!(ax_2, gt_1[:, 1] .- 0.3, gt_1[:, 2] .- 0.4, color=:red, linewidth=2, label="Ground truth")
xlims!(ax_2, 1.5, 2.25)
ylims!(ax_2, 0.0, 0.75)
# ylims!(ax_2, 0.1, 0.85)
hidedecorations!(ax_2)


########## Frame with different trajectory and same parameters as Fig 2 #########
pixel_size = 0.133
ax_3 = Axis(fig[1,3])
frames = load(joinpath(SIM_ROOT, "sim_Fig_S2_D0.1", "frames.jld2"), "frames")
W, H, _ = size(frames)
x = (0:W-1) .* pixel_size .+ pixel_size/2
y = (0:H-1) .* pixel_size .+ pixel_size/2
sum_frames = dropdims(sum(frames, dims=3), dims=3)
heatmap!(ax_3, x, y, sum_frames, colormap=:grays)
gt = load(joinpath(SIM_ROOT, "sim_Fig_S2_D0.1", "groundtruth.jld2"), "tracks")
lines!(ax_3, gt[:, 1], gt[:, 2], color=cyan, linewidth=2, label="Ground truth")
xlims!(ax_3, 1.55, 2.3)
ylims!(ax_3, 1.46, 2.21)
hidedecorations!(ax_3)

################ Plot localization error vs exposure time ########

ax = Axis(fig[3,1:3],
    ylabel="Dynamic localization error (nm)",
    xlabel="Exposure time (s)",
    xscale=log10,
    # yscale=log10
)
s1 = nothing
s2 = nothing
s3 = nothing
for batchsize in batchsizes
    # First chain, original trajectory with Fig 2 parameters
    chain = load(joinpath(INF_ROOT, "inf_Fig_2_D0.1", "chain_$batchsize.jld2"), "chain")
    localization_errors = zeros(size(chain.samples[1].tracks, 1))
    for k = burn_in+1:length(chain)
        localization_errors .+= sqrt.(vec(sum((chain.samples[k].tracks .- chain.samples[1].tracks).^2, dims = 2)))
    end
    localization_errors ./= length(chain) - burn_in
    mean_sq_loc_err = mean(localization_errors) * 2 * 1000
    # println("\tBatchsize=$batchsize, loc err = $( mean(localization_errors) * 2)")
    s1 = scatter!(ax, batchsize * period, mean_sq_loc_err, markersize = markersize, color = color, marker=:circle)

    # Second chain, original trajectory with Fig S1 parameters
    chain = load(joinpath(INF_ROOT, "inf_Fig_S1_D0.1", "chain_$batchsize.jld2"), "chain")
    localization_errors = zeros(size(chain.samples[1].tracks, 1))
    for k = burn_in+1:length(chain)
        localization_errors .+= sqrt.(vec(sum((chain.samples[k].tracks .- chain.samples[1].tracks).^2, dims = 2)))
    end
    localization_errors ./= length(chain) - burn_in
    mean_sq_loc_err = mean(localization_errors) * 2 * 1000
    # println("\tBatchsize=$batchsize, loc err = $( mean(localization_errors) * 2)")
    s2 = scatter!(ax, batchsize * period, mean_sq_loc_err, markersize = markersize, color = color, marker=:rect)

    # Third chain, different trajectory with Fig 2 parameters
    chain = load(joinpath(INF_ROOT, "inf_Fig_S2_D0.1", "chain_$batchsize.jld2"), "chain")
    localization_errors = zeros(size(chain.samples[1].tracks, 1))
    for k = burn_in+1:length(chain)
        localization_errors .+= sqrt.(vec(sum((chain.samples[k].tracks .- chain.samples[1].tracks).^2, dims = 2)))
    end
    localization_errors ./= length(chain) - burn_in
    mean_sq_loc_err = mean(localization_errors) * 2 * 1000
    # println("\tBatchsize=$batchsize, loc err = $( mean(localization_errors) * 2)")
    s3 = scatter!(ax, batchsize * period, mean_sq_loc_err, markersize = markersize, color = color, marker=:star5)
end

######## Legend in row 2 using s1, s2, s3 as dummy scatter plots
legend_params = (
    orientation = :horizontal,
    patchsize = (15, 15),
    rowgap = 1,
    colgap = 3,
    titlegap = 1,
    patchlabelgap = 1,
    framevisible = false
)
Legend(
    fig[2, 1],
    [s1],
    ["Trajectory #1, 133 nm pixels"];
    legend_params...,
)
Legend(
    fig[2, 2],
    [s2],
    ["Trajectory #1, 100 nm pixels"];
    legend_params...,
)
Legend(
    fig[2, 3],
    [s3],
    ["Trajectory #2, 133 nm pixels"];
    legend_params...,
)
save("../figures/Fig_S2.pdf", fig)
display(fig)