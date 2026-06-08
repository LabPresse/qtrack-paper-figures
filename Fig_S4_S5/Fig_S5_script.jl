using JLD2
using SP2T
using TOML
using CairoMakie
using Random
using Statistics
using ColorSchemes
include("../utils.jl")
# toml_dir = length(ARGS) >= 1 ? ARGS[1] : "."
# base_dir = abspath(joinpath(toml_dir, ".."))

const SCRIPT_DIR = @__DIR__
if length(ARGS) >= 1
    if ARGS[1] == "precomputed"
        inf_dir_name = "precomputed_inference_results"
        sim_dir_name = "precomputed_simulations"
    elseif ARGS[1] == "test"
        inf_dir_name = "test_inference_results"
        sim_dir_name = "simulations"
    else
        inf_dir_name = "inference_results"
        sim_dir_name = "simulations"
    end
else
    inf_dir_name = "inference_results"
    sim_dir_name = "simulations"
end
const INF_DIR = joinpath(SCRIPT_DIR, inf_dir_name)
const SIM_DIR = joinpath(SCRIPT_DIR, sim_dir_name)
const SAVE_DIR = joinpath(SCRIPT_DIR, "..", "figures")

function l2_diff(vec1, vec2)
    n_frames = size(vec1, 1)
    return reshape(sqrt.(sum(abs2, vec1 .- vec2, dims=2)), n_frames)
end

# ------- Load all simulations and results --------
burn_in = 100

dir_no_blink = joinpath(INF_DIR, "inf_Fig_S4_S5_no_photoblink")
sim_toml = TOML.parsefile(joinpath(dir_no_blink, "sim_params_no_blink.toml"))
diff_lim_488 = 1.22*sim_toml["camera"]["wavelength"]/(2*sim_toml["camera"]["numerical_aperture"])
inf_toml = TOML.parsefile(joinpath(dir_no_blink, "inference_params_no_blink.toml"))
groundtruth = load(joinpath(dir_no_blink, "groundtruth.jld2"), "tracks")
chain_no_blink = load(joinpath(dir_no_blink, "chain_1.jld2"), "chain")
# ~, i = findmax(chain_no_blink.loglikelihoods[burn_in+1:end])
~, i = findmax(chain_no_blink.logposteriors[burn_in+1:end])
map_sample, map_idx = chain_no_blink.samples[i+burn_in], i + burn_in
map_tracks_no_blink = map_sample.tracks

# 45 percent on
dir_45perc = joinpath(INF_DIR, "inf_Fig_S4_S5_photoblink_45perc_on")
sim_toml_blink = TOML.parsefile(joinpath(dir_45perc, "sim_params_blink_45perc.toml"))
inf_toml_blink = TOML.parsefile(joinpath(dir_45perc, "inference_params_45perc.toml"))
# frames_45perc = load(joinpath(toml_dir, inf_toml_blink["frames_path"]), "frames")
frames_45perc = load(joinpath(SIM_DIR, "sim_Fig_S4_S5_photoblink_45perc_on", "frames.jld2"), "frames")
on_time = Integer(sim_toml_blink["blinking"]["off_rate_period"]*1000) # ms, I named things wrong but calculated it right.
off_time = Integer(sim_toml_blink["blinking"]["on_rate_period"]*1000) #ms
println("ON time of $on_time ms")
println("OFF time of $off_time ms")
chain_45perc = load(joinpath(dir_45perc, "chain_1.jld2"), "chain")
states_45perc = load(joinpath(dir_45perc, "states.jld2"), "states");
# ~, i = findmax(chain_45perc.loglikelihoods[burn_in+1:end])
~, i = findmax(chain_45perc.logposteriors[burn_in+1:end])
map_sample, map_idx = chain_45perc.samples[i+burn_in], i + burn_in
map_tracks_45perc = map_sample.tracks;

# 55 percent on
dir_55perc = joinpath(INF_DIR, "inf_Fig_S4_S5_photoblink_55perc_on")
inf_toml_blink = TOML.parsefile(joinpath(dir_55perc, "inference_params_55perc.toml"))
# frames_55perc = load(joinpath(toml_dir, inf_toml_blink["frames_path"]), "frames")
frames_55perc = load(joinpath(SIM_DIR, "sim_Fig_S4_S5_photoblink_55perc_on", "frames.jld2"), "frames")
chain_55perc = load(joinpath(dir_55perc, "chain_1.jld2"), "chain")
states_55perc = load(joinpath(dir_55perc, "states.jld2"), "states");
#, i = findmax(chain_55perc.loglikelihoods[burn_in+1:end])
~, i = findmax(chain_55perc.logposteriors[burn_in+1:end])
map_sample, map_idx = chain_55perc.samples[i+burn_in], i + burn_in
map_tracks_55perc = map_sample.tracks;

# 79 percent on
dir_79perc = joinpath(INF_DIR, "inf_Fig_S4_S5_photoblink_79perc_on")
inf_toml_blink = TOML.parsefile(joinpath(dir_79perc, "inference_params_79perc.toml"))
# frames_79perc = load(joinpath(toml_dir, inf_toml_blink["frames_path"]), "frames")
frames_79perc = load(joinpath(SIM_DIR, "sim_Fig_S4_S5_photoblink_79perc_on", "frames.jld2"), "frames")
chain_79perc = load(joinpath(dir_79perc, "chain_1.jld2"), "chain")
states_79perc = load(joinpath(dir_79perc, "states.jld2"), "states");
~, i = findmax(chain_79perc.logposteriors[burn_in+1:end])
map_sample, map_idx = chain_79perc.samples[i+burn_in], i + burn_in
map_tracks_79perc = map_sample.tracks;


# -------- Set up plot params --------
font_size = 20
ticks_size = 18
set_theme!(
    fontsize = font_size,              # Default for everything
    Axis = (
        xlabelsize = font_size, 
        ylabelsize = font_size,
        xticklabelsize = ticks_size,
        yticklabelsize = ticks_size
    ),
    font="Arial Bold"
)

# ------- Plot --------
detector_size = sim_toml["camera"]["detector_size"]
pixel_size = sim_toml["camera"]["pixel_size"]
lightblue = ColorSchemes.tab10.colors[10]
pink = ColorSchemes.tab10.colors[7]

############## Plot all 3 states ####################
savefig = true
states_perc = [states_45perc, states_55perc, states_79perc]
chains_perc = [chain_45perc, chain_55perc, chain_79perc]
map_tracks_perc = [map_tracks_45perc, map_tracks_55perc, map_tracks_79perc]

dt = sim_toml["camera"]["period"]
t_vals = collect(0:dt:(sim_toml["simulation"]["n_frames"]*dt - dt/2))
norm_sp2t_no_blink = l2_diff(groundtruth, map_tracks_no_blink)
mae_sp2t_no_blink = mean(norm_sp2t_no_blink)
mse_sp2t_no_blink = sqrt(mean(norm_sp2t_no_blink.^2))
println("MAE QTrack (no photoblinking): ", mae_sp2t_no_blink)
println("sqrt(MSE) QTrack (no photoblinking): ", mse_sp2t_no_blink)

fig_err = Figure(size = (1000, 800), rowgap=0)
axes_list = []
off_segments_all = []
localization_error_all = []
for (j, state) in enumerate(states_perc)
    perc_on = round((sum(state)/length(state)*100), digits=2)
    ax = Axis(fig_err[j, 1],
        xlabel = j==3 ? "Time (s)" : "",
        ylabel = "Localization Error (μm)",
  )
    push!(axes_list, ax)
    if j!=3
        hidexdecorations!(ax, grid=false)
    end

    # Find contiguous regions where states_43perc == 0
    off_segments = Tuple{Int,Int}[]
    n = length(state)
    k = 1
    while k <= n
        if state[k] == 0
            start_idx = k
            while k <= n && state[k] == 0
                k += 1
            end
            end_idx = k - 1
            push!(off_segments, (start_idx, end_idx))
        else
            k += 1
        end
    end
    push!(off_segments_all, off_segments)

    println("Groundtruth: $(size(groundtruth)), $(any(isnan.(groundtruth)))")
    println("Map: $(size(map_tracks_perc[j])), $(any(isnan.(map_tracks_perc[j])))")
    norm_sp2t_perc = l2_diff(groundtruth, map_tracks_perc[j])
    push!(localization_error_all, norm_sp2t_perc)
    mae_sp2t_perc = mean(norm_sp2t_perc)
    mse_sp2t_perc = sqrt(mean(norm_sp2t_perc.^2))
    println("MAE QTrack ($perc_on% on): ", mae_sp2t_perc)
    println("sqrt(MSE) QTrack ($perc_on% on): ", mse_sp2t_perc)

    # Add OFF background shading first
    for (i_start, i_end) in off_segments
        vspan!(ax, t_vals[i_start], t_vals[i_end],
            color = (:gray, 0.25),
            label = nothing
        )
    end

    # Plot error traces
    lines!(ax, t_vals, norm_sp2t_no_blink, 
        # color=:skyblue,
        color=lightblue, 
        linewidth=2,
        label="QTrack (no photoblinking)")

    lines!(ax, t_vals, norm_sp2t_perc, 
        # color=:gold, 
        color=pink,
        linewidth=2,
        label="QTrack (photoblinking)")

    off_idxs = state .== 0
    perc = mean(norm_sp2t_perc[off_idxs] .<= diff_lim_488)
    println("Loc. err. for case $j < diffraction limit $perc of the dark periods")

    hlines!(ax, sim_toml["camera"]["pixel_size"],
            linestyle=:dash, color=:black, linewidth=2,
            label="Pixel width")

    println("Diffraction limit: $diff_lim_488 m")
    hlines!(ax, diff_lim_488,
            linestyle=:dashdot, color=:red, linewidth=2,
            label="Diffraction limit")

    if j==1
        axislegend(position=:lt)
    end
end
linkyaxes!(axes_list...)

for (label, layout) in zip(["a", "b", "c"], [fig_err[1, :], fig_err[2, :], fig_err[3, :]])
    Label(
        layout[1, 1, TopLeft()],
        label,
        fontsize = 20,
        font = "Arial Bold",
        halign = :right,
    )
end

mkpath(SAVE_DIR)
save(joinpath(SAVE_DIR, "Fig_S5.pdf"), fig_err)
