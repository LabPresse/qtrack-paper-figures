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
if length(ARGS) >= 1
    if ARGS[1] == "precomputed"
        sim_dir_name = "precomputed_simulations"
    else
        sim_dir_name = "simulations"
    end
else
    sim_dir_name = "simulations"
end
const SCRIPT_DIR = @__DIR__
const SIM_DIR = joinpath(SCRIPT_DIR, sim_dir_name)
const SAVE_DIR = joinpath(SCRIPT_DIR, "..", "figures")

function l2_diff(vec1, vec2)
    n_frames = size(vec1, 1)
    return reshape(sqrt.(sum(abs2, vec1 .- vec2, dims=2)), n_frames)
end

# ------- Load all simulations and results --------
burn_in = 100

dir_no_blink = joinpath(SIM_DIR, "sim_Fig_S4_S5_no_photoblink")
sim_toml = TOML.parsefile(joinpath(dir_no_blink, "sim_params_no_blink.toml"))
groundtruth = load(joinpath(dir_no_blink, "groundtruth.jld2"), "tracks")

# 45 percent on
dir_45perc = joinpath(SIM_DIR, "sim_Fig_S4_S5_photoblink_45perc_on")
sim_toml_blink = TOML.parsefile(joinpath(dir_45perc, "sim_params_blink_45perc.toml"))
frames_45perc = load(joinpath(dir_45perc, "frames.jld2"), "frames")
on_time = Integer(sim_toml_blink["blinking"]["off_rate_period"]*1000) # ms, I named things wrong but calculated it right.
off_time = Integer(sim_toml_blink["blinking"]["on_rate_period"]*1000) #ms
states_45perc = load(joinpath(dir_45perc, "states.jld2"), "states")

# 55 percent on
dir_55perc = joinpath(SIM_DIR, "sim_Fig_S4_S5_photoblink_55perc_on")
# sim_toml_55perc = TOML.parsefile(joinpath(dir_55perc, "sim_params_blink_55perc.toml"))
frames_55perc = load(joinpath(dir_55perc, "frames.jld2"), "frames")
states_55perc = load(joinpath(dir_55perc, "states.jld2"), "states")

# 79 percent on
dir_79perc = joinpath(SIM_DIR, "sim_Fig_S4_S5_photoblink_79perc_on")
# sim_toml_79perc = TOML.parsefile(joinpath(dir_79perc, "sim_params_blink_79perc.toml"))
frames_79perc = load(joinpath(dir_79perc, "frames.jld2"), "frames")
states_79perc = load(joinpath(dir_79perc, "states.jld2"), "states")

# -------- Set up plot params --------
inch = 96
pt = 4 / 3

font_size = 14pt
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

fig = Figure(size = (12inch, 4.8inch), fontsize = 14pt, font = "Arial")
# fig = Figure(size=(800, 320); figure_padding=2, rowgap=2, colgap=2)

ax1 = Axis(fig[1, 1], aspect=DataAspect())
ax2 = Axis(fig[1, 2], aspect=DataAspect())
ax3 = Axis(fig[1, 3], aspect=DataAspect())

for ax in (ax1, ax2, ax3)
    hidedecorations!(ax; ticks=true, ticklabels=true, label=true)
    hidespines!(ax)
    ax.xautolimitmargin = (0, 0)
    ax.yautolimitmargin = (0, 0)
end

x = (0:detector_size-1) .* pixel_size .+ pixel_size/2
y = (0:detector_size-1) .* pixel_size .+ pixel_size/2

function plot_state_segments!(ax, traj, states; on_color=:blue, off_color=:indigo)
    T = min(size(traj, 1), length(states))
    i = 1
    while i < T
        s = states[i]
        j = i
        while j < T && states[j] == s
            j += 1
        end
        col = (s == 1) ? on_color : off_color
        lines!(ax, @view(traj[i:j, 1]), @view(traj[i:j, 2]), color=col)
        i = j
    end
end

# 45%
heatmap!(ax1, x, y, view(sum(frames_45perc, dims=3), :, :, 1), colormap=:greys)
plot_state_segments!(ax1, view(groundtruth, :, :, 1), states_45perc)

# 55%
heatmap!(ax2, x, y, view(sum(frames_55perc, dims=3), :, :, 1), colormap=:greys)
plot_state_segments!(ax2, view(groundtruth, :, :, 1), states_55perc)

# 79%
heatmap!(ax3, x, y, view(sum(frames_79perc, dims=3), :, :, 1), colormap=:greys)
plot_state_segments!(ax3, view(groundtruth, :, :, 1), states_79perc)

# Scale bar (keep your manual placement)
x_start = 1.4  # µm
y_pos   = 2.1  # µm
length_um = 1.0
label = "1 μm"
lines!(ax3, [x_start, x_start + length_um], [y_pos, y_pos], color=:white, linewidth=4)
text!(ax3, x_start + length_um/2, y_pos + 0.08, text=label, align=(:center, :bottom),
      color=:white)#, strokecolor=:black, strokewidth=1)

# Panel labels INSIDE axes (no layout padding)
for (lab, ax) in zip(["a", "b", "c"], (ax1, ax2, ax3))
    text!(ax, 0.02, 0.98; text=lab, space=:relative,
          align=(:left, :top), font="Arial Bold", fontsize=20, color=:white,)
        #   strokecolor=:black, strokewidth=1)
end

# Legend: anchor it inside the middle axis (top) to avoid extra row whitespace
elems = [LineElement(color=:blue, linewidth=5), LineElement(color=:indigo, linewidth=5)]
Legend(fig[1, 2, Top()], elems, ["ON", "OFF"];
       orientation=:horizontal, framevisible=false, tellheight=false,
       patchsize=(18, 10), padding=(2, 2, 2, 2), margin = (0, 0, -25, 0))  # pulls it closer downward)

mkpath(SAVE_DIR)
save(joinpath(SAVE_DIR, "Fig_S4.pdf"), fig)
