using CairoMakie
using JLD2
using SP2T
# using SP2TExtra
using TOML
using Statistics
using ColorSchemes
include("../utils.jl")

if length(ARGS) >= 1
    if ARGS[1] == "precomputed"
        sim_dir_name = "precomputed_sim_Fig_S3_motion_blur"
    else
        sim_dir_name = "sim_Fig_S3_motion_blur"
    end
else
    sim_dir_name = "sim_Fig_S3_motion_blur"
end
const SCRIPT_DIR = @__DIR__
const SAVE_DIR = joinpath(SCRIPT_DIR, "..", "figures")

# base_dir = length(ARGS) >= 1 ? ARGS[1] : "."

# ---- Load metadata and simulations ----
dir = joinpath(SCRIPT_DIR, sim_dir_name)

sim_toml = TOML.parsefile(joinpath(dir, "sim_params_emccd.toml"))
# sim_params = sim_toml["simulation"]
camera_params = sim_toml["camera"]
pixel_size = camera_params["pixel_size"]
detector_size = camera_params["detector_size"]

# There is only one simulation and one realization for this case
gt_tracks = load(joinpath(dir, "groundtruth.jld2"), "tracks")
gt_frames = load(joinpath(dir, "frames.jld2"), "frames")

batchsizes= [15, 255, 65535]
milliseconds = [0.15, 2.55, 655.35]

# ---- Figure / axes ----
fig = Figure(size=(700, 250); figure_padding=2, colgap=0, rowgap=0)

ax1 = Axis(fig[1, 1], aspect=DataAspect(), title="4-bit ($(milliseconds[1]) ms)",  titlegap=2)
ax2 = Axis(fig[1, 2], aspect=DataAspect(), title="8-bit ($(milliseconds[2]) ms)",  titlegap=2)
ax3 = Axis(fig[1, 3], aspect=DataAspect(), title="16-bit ($(milliseconds[3]) ms)", titlegap=2)

for ax in (ax1, ax2, ax3)
    hidedecorations!(ax; ticks=true, ticklabels=true, label=true)
    hidespines!(ax)
    ax.xautolimitmargin = (0, 0)
    ax.yautolimitmargin = (0, 0)
end

# ---- Heatmaps ----
start_idx = 53450 # which frame to start the 4 and 8 bit frames at
cmap = :grays
x = (0:detector_size-1) .* pixel_size .+ pixel_size/2
y = (0:detector_size-1) .* pixel_size .+ pixel_size/2

img4bit  = view(sum(gt_frames[:, :, start_idx:(start_idx + batchsizes[1])], dims=3), :, :, 1)
img8bit  = view(sum(gt_frames[:, :, start_idx:(start_idx + batchsizes[2])], dims=3), :, :, 1)
img16bit = view(sum(gt_frames, dims=3), :, :, 1)

heatmap!(ax1, x, y, img4bit;  colormap=cmap)
heatmap!(ax2, x, y, img8bit;  colormap=cmap)
heatmap!(ax3, x, y, img16bit; colormap=cmap)

# ---- Add scale bar ----
x_start=0.5
y_pos=0.5
length_um=1.0
label="1 μm"
lines!(ax1, [x_start, x_start + length_um], [y_pos, y_pos], color=:white, linewidth=4)
text!(ax1, x_start + length_um/2, y_pos + 0.08, text=label,
        align=(:center, :bottom), color=:white)

# ---- Motion blur PSF lines drawn on top of heatmaps ----
locs_y   = gt_tracks[start_idx:(start_idx + batchsizes[1]), 2, :]
line_cut = median(locs_y, dims=1)[1]
median_x = median(gt_tracks[start_idx:(start_idx + batchsizes[1]), 1, :], dims=1)[1]

σ, ~   = SP2T.getσ₀z₀(camera_params["numerical_aperture"],
                     camera_params["refractive_index"],
                     camera_params["wavelength"])

m      = 0.5  # vertical scaling for overlay
x_fine = (0:0.01:detector_size-1) .* pixel_size .+ pixel_size/2
ideal_psf = m ./ sqrt(2 * π * σ^2) .* exp.(-(x_fine .- median_x).^2 ./ (2 * σ^2))

line_idx = searchsortedfirst(y, line_cut)

normalize_slice(slice) = m .* slice ./ (sum(slice) * pixel_size)
s4  = normalize_slice(img4bit[:,  line_idx])
s8  = normalize_slice(img8bit[:,  line_idx])
s16 = normalize_slice(img16bit[:, line_idx])

psf_color = ColorSchemes.tab10.colors[end] # light blue
mb_color  = ColorSchemes.tab10.colors[2] # orange
p_gauss = lines!(ax1, x_fine, line_cut .+ ideal_psf; color=psf_color) # handles for legend
p_mb    = lines!(ax1, x,      line_cut .+ s4;       color=mb_color)

lines!(ax2, x_fine, line_cut .+ ideal_psf; color=psf_color)
lines!(ax2, x,      line_cut .+ s8;        color=mb_color)

lines!(ax3, x_fine, line_cut .+ ideal_psf; color=psf_color)
lines!(ax3, x,      line_cut .+ s16;       color=mb_color)

hlines!(ax1, line_cut; color=mb_color, linestyle=:dash)
hlines!(ax2, line_cut; color=mb_color, linestyle=:dash)
hlines!(ax3, line_cut; color=mb_color, linestyle=:dash)

# ---- Panel labels (inside axes, no layout whitespace) ----
for (label, layout) in zip(["a", "b", "c"], [fig[1, 1], fig[1, 2], fig[1, 3]])
    Label(
        layout[1, 1, TopLeft()],
        label,
        fontsize = 20,
        font = "Arial Bold",
        halign = :right,
    )
end

# ---- Legend under the middle plot (two elements side-by-side) ----
Legend(fig[2, 1:3], [p_mb, p_gauss], ["Motion blur PSF", "Gaussian PSF"];
       orientation=:horizontal,
       framevisible=false,
       tellheight=true, tellwidth=true,
       padding=(0, 0, 0, 0),
       patchsize=(22, 10),
       patchlabelgap=6)

rowsize!(fig.layout, 2, Fixed(10))

mkpath(SAVE_DIR)
save(joinpath(SAVE_DIR, "Fig_S3.pdf"), fig)
