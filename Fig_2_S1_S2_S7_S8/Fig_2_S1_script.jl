using Statistics
using StatsBase
using JLD2
using SP2T
using SP2TExtra
using CairoMakie
using ColorSchemes
using GeometryBasics
using TOML
include("../utils.jl")

# =========================
# User-configurable settings
# =========================

figure_name = length(ARGS) >= 1 ? ARGS[1] : "Fig_2"
if length(ARGS) >= 2
    if ARGS[2] == "precomputed"
        inf_dir_name = "precomputed_inference_results"
        sim_dir_name = "precomputed_simulations"
    elseif ARGS[2] == "test"
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


# Base directory for this figure family
const SCRIPT_DIR = @__DIR__
const BASE_DIR = abspath(joinpath(SCRIPT_DIR, ".."))
const SIM_ROOT = joinpath(SCRIPT_DIR, sim_dir_name)
const INF_ROOT = joinpath(SCRIPT_DIR, inf_dir_name)
const EXP_ROOT = joinpath(SCRIPT_DIR, inf_dir_name, "inf_exp_data")
const EXP_DATA_ROOT = joinpath(SCRIPT_DIR, "experimental_data")
const SAVE_DIR = joinpath(SCRIPT_DIR, "..", "figures")


const FIGURE_OPTIONS = Dict(
    "Fig_2" => (
        sim_prefix = "sim_Fig_2_D",
        inf_prefix = "inf_Fig_2_D",
        output_name = "Fig_2.pdf",
        bounds_ab = (5, 9, 14, 18) #pixels
    ),
    "Fig_S1" => (
        sim_prefix = "sim_Fig_S1_D",
        inf_prefix = "inf_Fig_S1_D",
        output_name = "Fig_S1.pdf",
        bounds_ab = (4.5, 8.5, 14, 18) #pixels
    ),
)

haskey(FIGURE_OPTIONS, figure_name) || error(
    "Unknown figure '$figure_name'. Expected one of: $(join(sort(collect(keys(FIGURE_OPTIONS))), ", "))",
)
figure_cfg = FIGURE_OPTIONS[figure_name]

# Plotting / inference settings
burn_in = 100

# =========================
# Helper functions
# =========================

"""
Convert a data-coordinate point in an axis into figure-scene coordinates.
Used to draw connector lines from a ROI box to the zoomed axis.
"""
function posFig(ax, x, y)
    o = ax.scene.viewport[].origin
    return Makie.project(ax.scene, Point2f(x, y)) + o
end

# Precomputed equations from your derivations/paper/notes
pre_eq1(σ₀, D, tₑ, s₀) = @. σ₀ * sqrt(1 + D * tₑ / s₀^2) # dynamic localization error
pre_eq5(tₑ, Δt)        = @. 1 / 6 * tₑ / Δt # motion blur coefficient
pre_eq12(d, N, x)      = @. sqrt(2 / (d * (N - 1))) * sqrt(1 + 2 * sqrt(1 + 2x)) # diffusion coefficient error
pre_eq13(σ, D, Δt, R)  = @. σ^2 / (D * Δt) - 2 * R # approx dynamic localization error
pre_eq14(s₀, Q, tₑ)    = @. s₀ / sqrt(Q * tₑ) # static localization error (in absence of 
# pixelation, background, detector noise, and amplifier excess noise)


"""
Load all inference chain files from a directory and return (batchsize, chain) pairs.
Assumes filenames follow the `chain_<batchsize>.jld2` convention.
"""
function load_chains_from_dir(dir::AbstractString)
    if !isdir(dir)
        return Tuple{Int,Any}[]
    end

    out = Vector{Tuple{Int, Any}}()
    for chainfile in readdir(dir)
        startswith(chainfile, "chain_") && endswith(chainfile, ".jld2") || continue
        batchsize = tryparse(Int, replace(replace(chainfile, "chain_" => ""), ".jld2" => ""))
        batchsize === nothing && continue

        chain = try
            load(joinpath(dir, chainfile), "chain")
        catch err
            @warn "Skipping unreadable chain file" path=joinpath(dir, chainfile) exception=(err, catch_backtrace())
            continue
        end
        push!(out, (batchsize, chain))
    end

    sort!(out, by = first)
    return out
end

function simulation_dir(D)
    joinpath(SIM_ROOT, string(figure_cfg.sim_prefix, D))
end

function inference_dir(D)
    joinpath(INF_ROOT, string(figure_cfg.inf_prefix, D))
end

function find_sim_toml(dir::AbstractString)
    !isdir(dir) && return nothing
    tomls = filter(f -> startswith(f, "sim_params") && endswith(f, ".toml"), readdir(dir))
    isempty(tomls) && return nothing
    return joinpath(dir, first(sort(tomls)))
end

function load_camera_params(dir::AbstractString)
    toml_path = find_sim_toml(dir)
    toml_path === nothing && error("Could not find sim_params TOML in $dir")
    return TOML.parsefile(toml_path)["camera"], toml_path
end

function camera_metadata(camera_params)
    return Dict(
        "numerical aperture" => camera_params["numerical_aperture"],
        "refractive index" => camera_params["refractive_index"],
        "wavelength" => camera_params["wavelength"],
        "pixel size" => camera_params["pixel_size"],
        "period" => camera_params["period"],
    )
end

function maybe_load_chain(dir::AbstractString, batchsize::Int)
    if !isdir(dir)
        return nothing
    end

    path = joinpath(dir, "chain_$(batchsize).jld2")
    if isfile(path)
        return load(path, "chain")
    end
    return nothing
end

function available_batchsizes(dir::AbstractString)
    return first.(load_chains_from_dir(dir))
end

function choose_batchsize(dir::AbstractString, preferred::Int; fallback::Symbol = :largest)
    batchsizes = available_batchsizes(dir)
    preferred in batchsizes && return preferred
    isempty(batchsizes) && return nothing
    return fallback == :smallest ? first(batchsizes) : last(batchsizes)
end

function load_tracks_for_panel(inf_dir::AbstractString, sim_dir::AbstractString, batchsize::Int; burn_in::Int)
    chain = maybe_load_chain(inf_dir, batchsize)
    if chain !== nothing
        track_samples = tracks(chain, burn_in = burn_in)
        return mean(track_samples, dims = 3), true
    end

    gt_path = joinpath(sim_dir, "groundtruth.jld2")
    if isfile(gt_path)
        gt_tracks = load(gt_path, "tracks")
        return gt_tracks, false
    end

    return nothing, false
end

function maybe_scatter_simulation_results!(ax_loc, ax_diff, Dsim, metadata, color)
    inf_dir = inference_dir(Dsim)
    chains = load_chains_from_dir(inf_dir)
    isempty(chains) && return Int[]

    local batchsizes_seen = Int[]
    println("\nD=$Dsim")
    for (batchsize, chain) in chains
        push!(batchsizes_seen, batchsize)
        d_vals = chain.msds[burn_in+1:end] ./ (2 * batchsize * metadata["period"])
        quantiles = quantile(d_vals, 0.5 .+ 0.34134474606854304 .* [-1, 1])

        localization_errors = zeros(size(chain.samples[1].tracks, 1))
        for k = burn_in+1:length(chain)
            localization_errors .+= sqrt.(vec(sum((chain.samples[k].tracks .- chain.samples[1].tracks).^2, dims = 2)))
        end
        localization_errors ./= length(chain) - burn_in
        println("\tBatchsize=$batchsize, loc err = $( mean(localization_errors) * 2)")
        scatter!(ax_loc, batchsize * metadata["period"], mean(localization_errors) * 2, markersize = 10, color = color)
        scatter!(ax_diff, batchsize * metadata["period"], quantiles[2] - quantiles[1], markersize = 10, color = color)
    end

    return batchsizes_seen
end

# =========================
# Load metadata + PSF model
# =========================

camera_params, camera_params_path = load_camera_params(simulation_dir(0.1))
metadata = camera_metadata(camera_params)

psf = CircularGaussian{Float64}(
    numerical_aperture   = metadata["numerical aperture"],
    refractive_index     = metadata["refractive index"],
    emission_wavelength  = metadata["wavelength"],
    pixel_size           = metadata["pixel size"],
)

brightness = 1e4 * psf.A

# =========================
# Figure and axes layout
# =========================

inch = 96
pt = 4 / 3

fig = Figure(size = (6inch, 6inch), fontsize = 7pt, font = "Arial")
# fig = Figure(size = (6inch, 7.5inch), fontsize = 7pt, font = "Arial")

# --- Image/trajectory panels (8 axes total; 4 pairs: full + zoom) ---
# Row 1 (top): a,b image pairs (unchanged)
ax_a_full = Axis(fig[1, 1], aspect = DataAspect())
ax_a_zoom = Axis(fig[1, 2], aspect = DataAspect())
ax_b_full = Axis(fig[1, 3], aspect = DataAspect())
ax_b_zoom = Axis(fig[1, 4], aspect = DataAspect())

# Row 2: exposure-time panels c,d (unchanged)
ax_c = Axis(
    fig[2, 1:2],
    xlabel = "Exposure time (s)",
    ylabel = "Dynamic localization error (μm)",
    xscale = log10,
    yscale = log10,
)
ax_d = Axis(
    fig[2, 3:4],
    xlabel = "Exposure time (s)",
    ylabel = "Diffusion coefficient error (μm²/s)",
    xscale = log10,
    yscale = log10,
)

# Row 4: image panels e,f (moved down by 1)
ax_e_full = Axis(fig[3, 1], aspect = DataAspect())
ax_e_zoom = Axis(fig[3, 2], aspect = DataAspect())
ax_f_full = Axis(fig[3, 3], aspect = DataAspect())
ax_f_zoom = Axis(fig[3, 4], aspect = DataAspect())

# Row 5 (bottom): exposure-time panels g,h (moved down by 1)
ax_g = Axis(
    fig[4, 1:2],
    xlabel = "Exposure time (s)",
    ylabel = "Dynamic localization error (μm)",
    xscale = log10,
    yscale = log10,
)
ax_h = Axis(
    fig[4, 3:4],
    xlabel = "Exposure time (s)",
    ylabel = "Diffusion coefficient error (μm²/s)",
    xscale = log10,
    yscale = log10,
)

# Hide decorations on image axes
img_axes = (ax_a_full, ax_a_zoom, ax_b_full, ax_b_zoom, ax_e_full, ax_e_zoom, ax_f_full, ax_f_zoom)
hidedecorations!.(img_axes)
hidespines!.(img_axes)

# Layout tuning: make the exposure-time rows and image rows have reasonable height
rowsize!(fig.layout, 2, 70)   # keep row 2 taller (exposure-time)
rowsize!(fig.layout, 4, 70)   # keep row 4 taller (exposure-time)
# rowsize!(fig.layout, 5, 70)   # bottom D histogram row
rowgap!(fig.layout, 5)
colgap!(fig.layout, 15)

# =========================
# Legends and labels
# =========================

colors = [
    ColorSchemes.tab10[4],
    ColorSchemes.tab10[3],
    ColorSchemes.tab10[1],
    ColorSchemes.tab10[2],
]

group_diffusion = [
    PolyElement(color = colors[1], strokecolor = :transparent),
    PolyElement(color = colors[2], strokecolor = :transparent),
    PolyElement(color = colors[3], strokecolor = :transparent),
    PolyElement(color = colors[4], strokecolor = :transparent),
]
group_method = [MarkerElement(color = :black, marker = :circle), LineElement(color = :black)]

elemtraj = LineElement(color = ColorSchemes.tab10[10], points = Point2f[(0, 0.5), (1, 0.5)])
elemerror = PolyElement(color = ColorSchemes.tab20[8], alpha = 0.5)

Legend(
    fig[0, 1:2],
    [elemtraj, elemerror],
    ["Tracks", "Localization error"],
    orientation = :horizontal,
    patchsize = (15, 15),
    rowgap = 1,
    colgap = 3,
    titlegap = 1,
    patchlabelgap = 1,
)

legend_group = Legend(
    fig,
    [group_method, group_diffusion],
    [["QTrack", "CRLB"], ["0.1 μm²/s", "1.0 μm²/s", "10 μm²/s", "Experiment"]],
    ["Method", "Data"],
    tellheight = true,
    orientation = :horizontal,
    patchsize = (15, 15),
    nbanks = 2,
    rowgap = 1,
    colgap = 3,
    titlegap = 1,
    patchlabelgap = 1,
)
fig[0, 3:4] = legend_group

# Panel labels (a–h) 
for (label, layout) in zip(
    ["a", "b", "c", "d", "e", "f", "g", "h"],
    [fig[1, 1], fig[1, 3], fig[2, 1], fig[2, 3], fig[3, 1], fig[3, 3], fig[4, 1], fig[4, 3]], #, fig[5, 1], fig[5, 3]],
)
    Label(
        layout[1, 1, TopLeft()],
        label,
        fontsize = 8pt,
        font = "Arial Bold",
        halign = :right,
    )
end

# =========================
# Exposure-time curves: simulation (ax_c, ax_d)
# =========================

Ds = [0.1, 1.0, 10.0] 
all_batchsizes = Int[]
for (i, Dsim) in enumerate(Ds)
    batchsizes_seen = maybe_scatter_simulation_results!(ax_c, ax_d, Dsim, metadata, colors[i])
    if i == 1
        append!(all_batchsizes, batchsizes_seen)
    end
end

# Theory lines overlaid for simulation Ds
for (c, Dsim) in zip(colors, Ds)
    batchsizes = logrange(1, 3000, length = 1001)
    texp = metadata["period"] .* batchsizes

    R  = pre_eq5(texp, texp) # motion blur coefficient
    σ₀ = pre_eq14(psf.σ, brightness, texp) # static localization error
    σ  = pre_eq1(σ₀, Dsim, texp, psf.σ) # dynamic localization error

    x = pre_eq13(σ, Dsim, texp, R) # approx dynamic localization error
    S = pre_eq12(2, 6000 ./ batchsizes, x) # diffusion coefficient error

    lines!(ax_c, texp, 2 .* σ, color = c)
    lines!(ax_d, texp, 2 .* S .* Dsim, color = c)
end

# Calc again to just print for right batchsizes
println("Batchsizes: $all_batchsizes")
if !isempty(all_batchsizes)
    for (c, Dsim) in zip(colors, Ds)
        println("\nD=$Dsim")
        texp = metadata["period"] .* all_batchsizes

        R  = pre_eq5(texp, texp) # motion blur coefficient
        σ₀ = pre_eq14(psf.σ, brightness, texp) # static localization error
        σ  = pre_eq1(σ₀, Dsim, texp, psf.σ) # dynamic localization error

        x = pre_eq13(σ, Dsim, texp, R) # approx dynamic localization error
        S = pre_eq12(2, 6000 ./ all_batchsizes, x) # diffusion coefficient error
        println("CRLB Localization error: $(2 .* σ)")
        println("CRLB diff coeff err: $(2 .* S .* Dsim)")
    end
end

xlims!(ax_c, 8e-6, 3.8e-2)
ylims!(ax_c, 2 * 10^-2.2, 2 * 1)
xlims!(ax_d, 8e-6, 3.8e-2)
ylims!(ax_d, 10^-1.7 / 2, 1e2 / 2)

# =========================
# Exposure-time curves: experiment (ax_g, ax_h)
# =========================

chains_exp = load_chains_from_dir(EXP_ROOT)
exp_camera_params = TOML.parsefile(joinpath(EXP_ROOT, "exp_camera_params.toml"))["camera"]
exp_metadata = camera_metadata(exp_camera_params)

for (batchsize, chain) in chains_exp
    msds = chain.msds[burn_in+1:end] ./ (2 * batchsize * exp_metadata["period"])
    quantiles = quantile(msds, 0.5 .+ 0.34134474606854304 .* [-1, 1])

    localization_errors = localization_error(chain, burn_in = burn_in) * 2 
    # multiply by 2 to cancel out random divide by 2 in the function

    # CHANGED: multiply by sqrt(2) instead of 2  because 2D localization error is already sqrt(2) 
    # times the 1D error (assuming isotropic errors in x and y). This yields correct 2*sigma width.
    # scatter!(ax_g, batchsize * 50e-6, localization_errors .* 2, markersize = 10, color = colors[4])
    scatter!(ax_g, batchsize * exp_metadata["period"], localization_errors .* sqrt(2), markersize = 10, color = colors[4])
    scatter!(ax_h, batchsize * exp_metadata["period"], (quantiles[2] - quantiles[1]), markersize = 10, color = colors[4])
end

for Dexp in [0.2556]
    batchsizes = logrange(1, 3000, length = 1001)
    texp = exp_metadata["period"] .* batchsizes

    R  = pre_eq5(texp, texp)
    σ₀ = pre_eq14(psf.σ, 1.5e3, texp)
    σ  = pre_eq1(σ₀, Dexp, texp, psf.σ)

    x = pre_eq13(σ, Dexp, texp, R)
    S = pre_eq12(2, 6800 ./ batchsizes, x)

    lines!(ax_g, texp, 2 .* σ, color = colors[4])
    lines!(ax_h, texp, 2 .* S .* Dexp, color = colors[4])
end

xlims!(ax_g, 4e-5, 0.21)
ylims!(ax_g, 2 * 10^-2.2, 2 * 1)
xlims!(ax_h, 4e-5, 0.21)
ylims!(ax_h, 10^-1.7 / 2, 1e2 / 2)

# =========================
# Image panels: simulation example (a,b)
# =========================

sim_img_dir = simulation_dir(10.0)
sim_inf_dir = inference_dir(10.0)

frames1 = load(joinpath(sim_img_dir, "frames.jld2"), "frames")
sumframes1 = sum(frames1, dims = 3)
W, H, _ = size(sumframes1)

batchsize_a = choose_batchsize(sim_inf_dir, 1000, fallback = :largest)
batchsize_a_for_tracks = something(batchsize_a, 1000)
meantracks1000, has_inference_a = load_tracks_for_panel(sim_inf_dir, sim_img_dir, batchsize_a_for_tracks; burn_in = burn_in)

heatmap!(ax_a_full, (0:W) .* metadata["pixel size"], (0:H) .* metadata["pixel size"], view(sumframes1, :, :, 1), colormap = :grays)
if meantracks1000 !== nothing
    lines!(ax_a_full, view(meantracks1000, :, 1, 1), view(meantracks1000, :, 2, 1), color = ColorSchemes.tab10[10])
end

heatmap!(ax_a_zoom, (0:W) .* metadata["pixel size"], (0:H) .* metadata["pixel size"], view(sumframes1, :, :, 1), colormap = :grays)

batchsize_a_for_sigma = batchsize_a_for_tracks
R  = pre_eq5(metadata["period"] * batchsize_a_for_sigma, metadata["period"] * batchsize_a_for_sigma)
σ₀ = pre_eq14(psf.σ, brightness, metadata["period"] * batchsize_a_for_sigma)
σ  = pre_eq1(σ₀, 10, metadata["period"] * batchsize_a_for_sigma, psf.σ)

if has_inference_a && meantracks1000 !== nothing
    for r in eachslice(meantracks1000, dims = 1)
        arc!(ax_a_zoom, Point2f(r[1], r[2]), σ, -π, π, color = ColorSchemes.tab20[8], alpha = 0.5)
    end
end
if meantracks1000 !== nothing
    lines!(ax_a_zoom, view(meantracks1000, :, 1, 1), view(meantracks1000, :, 2, 1), color = ColorSchemes.tab10[10])
end

# bounds_ab = simulation_bounds_ab(metadata)
bounds_ab = figure_cfg.bounds_ab .* metadata["pixel size"]
linewidth_ab = 0.02

p_ab = Polygon(
    Point2f[
        (bounds_ab[1] - linewidth_ab / 2, bounds_ab[3] - linewidth_ab / 2),
        (bounds_ab[2] + linewidth_ab / 2, bounds_ab[3] - linewidth_ab / 2),
        (bounds_ab[2] + linewidth_ab / 2, bounds_ab[4] + linewidth_ab / 2),
        (bounds_ab[1] - linewidth_ab / 2, bounds_ab[4] + linewidth_ab / 2),
    ],
    [
        Point2f[
            (bounds_ab[1] + linewidth_ab / 2, bounds_ab[3] + linewidth_ab / 2),
            (bounds_ab[2] - linewidth_ab / 2, bounds_ab[3] + linewidth_ab / 2),
            (bounds_ab[2] - linewidth_ab / 2, bounds_ab[4] - linewidth_ab / 2),
            (bounds_ab[1] + linewidth_ab / 2, bounds_ab[4] - linewidth_ab / 2),
        ],
    ],
)

poly!(ax_a_full, p_ab, color = :gray70)
limits!(ax_a_zoom, bounds_ab...)

pts1 = [posFig(ax_a_full, bounds_ab[2], bounds_ab[3]), posFig(ax_a_zoom, bounds_ab[1], bounds_ab[3])]
pts2 = [posFig(ax_a_full, bounds_ab[2], bounds_ab[4]), posFig(ax_a_zoom, bounds_ab[1], bounds_ab[4])]

translate!(lines!(fig.scene, getindex.(pts1, 1), getindex.(pts1, 2), color = :gray70, linewidth = 0.7), (0, 0, 1))
translate!(lines!(fig.scene, getindex.(pts2, 1), getindex.(pts2, 2), color = :gray70, linewidth = 0.7), (0, 0, 1))

meantracks1_sim, _ = load_tracks_for_panel(sim_inf_dir, sim_img_dir, 1; burn_in = burn_in)

heatmap!(ax_b_full, (0:W) .* metadata["pixel size"], (0:H) .* metadata["pixel size"], view(sumframes1, :, :, 1), colormap = :grays)
if meantracks1_sim !== nothing
    lines!(ax_b_full, view(meantracks1_sim, :, 1, 1), view(meantracks1_sim, :, 2, 1), color = ColorSchemes.tab10[10])
end
poly!(ax_b_full, p_ab, color = :gray70)

heatmap!(ax_b_zoom, (0:W) .* metadata["pixel size"], (0:H) .* metadata["pixel size"], view(sumframes1, :, :, 1), colormap = :grays)
if meantracks1_sim !== nothing
    lines!(ax_b_zoom, view(meantracks1_sim, :, 1, 1), view(meantracks1_sim, :, 2, 1),
          alpha = 0.5, color = ColorSchemes.tab20[8], linewidth = 15.0)
    lines!(ax_b_zoom, view(meantracks1_sim, :, 1, 1), view(meantracks1_sim, :, 2, 1), color = ColorSchemes.tab10[10])
end

limits!(ax_b_zoom, bounds_ab...)

pts1 = [posFig(ax_b_full, bounds_ab[2], bounds_ab[3]), posFig(ax_b_zoom, bounds_ab[1], bounds_ab[3])]
pts2 = [posFig(ax_b_full, bounds_ab[2], bounds_ab[4]), posFig(ax_b_zoom, bounds_ab[1], bounds_ab[4])]

translate!(lines!(fig.scene, getindex.(pts1, 1), getindex.(pts1, 2), color = :gray70, linewidth = 0.7), (0, 0, 1))
translate!(lines!(fig.scene, getindex.(pts2, 1), getindex.(pts2, 2), color = :gray70, linewidth = 0.7), (0, 0, 1))

# =========================
# Image panels: experimental example (e,f) from EXP_ROOT
# =========================

frames1_exp = load(joinpath(EXP_DATA_ROOT, "frames1.jld2"), "frames")
sumframes1_exp = sum(frames1_exp, dims = 3)
W, H, _ = size(sumframes1_exp)

# Panel e (prefer batchsize 200, otherwise use the largest available)
batchsize_e = choose_batchsize(EXP_ROOT, 200, fallback = :largest)
meantracks200 = batchsize_e === nothing ? nothing : begin
    chain = maybe_load_chain(EXP_ROOT, batchsize_e)
    chain === nothing ? nothing : mean(tracks(chain, burn_in = burn_in), dims = 3)
end

heatmap!(ax_e_full, (0:W) .* exp_metadata["pixel size"], (0:H) .* exp_metadata["pixel size"], view(sumframes1_exp, :, :, 1), colormap = :grays)
if meantracks200 !== nothing
    lines!(ax_e_full, view(meantracks200, :, 1, 1), view(meantracks200, :, 2, 1), color = ColorSchemes.tab10[10])
end

heatmap!(ax_e_zoom, (0:W) .* exp_metadata["pixel size"], (0:H) .* exp_metadata["pixel size"], view(sumframes1_exp, :, :, 1), colormap = :grays)

batchsize_e_for_sigma = something(batchsize_e, 200)
R  = pre_eq5(exp_metadata["period"] * batchsize_e_for_sigma, exp_metadata["period"] * batchsize_e_for_sigma)
σ₀ = pre_eq14(psf.σ, brightness, exp_metadata["period"] * batchsize_e_for_sigma)
σ  = pre_eq1(σ₀, 10, exp_metadata["period"] * batchsize_e_for_sigma, psf.σ)

if meantracks200 !== nothing
    for r in eachslice(meantracks200, dims = 1)
        arc!(ax_e_zoom, Point2f(r[1], r[2]), σ, -π, π, color = ColorSchemes.tab20[8], alpha = 0.5)
    end
    lines!(ax_e_zoom, view(meantracks200, :, 1, 1), view(meantracks200, :, 2, 1), color = ColorSchemes.tab10[10])
end

bounds_ef = (0.3, 0.6, 0.5, 0.8)
linewidth_ef = 0.01

p_ef = Polygon(
    Point2f[
        (bounds_ef[1] - linewidth_ef / 2, bounds_ef[3] - linewidth_ef / 2),
        (bounds_ef[2] + linewidth_ef / 2, bounds_ef[3] - linewidth_ef / 2),
        (bounds_ef[2] + linewidth_ef / 2, bounds_ef[4] + linewidth_ef / 2),
        (bounds_ef[1] - linewidth_ef / 2, bounds_ef[4] + linewidth_ef / 2),
    ],
    [
        Point2f[
            (bounds_ef[1] + linewidth_ef / 2, bounds_ef[3] + linewidth_ef / 2),
            (bounds_ef[2] - linewidth_ef / 2, bounds_ef[3] + linewidth_ef / 2),
            (bounds_ef[2] - linewidth_ef / 2, bounds_ef[4] - linewidth_ef / 2),
            (bounds_ef[1] + linewidth_ef / 2, bounds_ef[4] - linewidth_ef / 2),
        ],
    ],
)

poly!(ax_e_full, p_ef, color = :gray70)
limits!(ax_e_zoom, bounds_ef...)

pts1 = [posFig(ax_e_full, bounds_ef[2], bounds_ef[3]), posFig(ax_e_zoom, bounds_ef[1], bounds_ef[3])]
pts2 = [posFig(ax_e_full, bounds_ef[2], bounds_ef[4]), posFig(ax_e_zoom, bounds_ef[1], bounds_ef[4])]

translate!(lines!(fig.scene, getindex.(pts1, 1), getindex.(pts1, 2), color = :gray70, linewidth = 0.7), (0, 0, 1))
translate!(lines!(fig.scene, getindex.(pts2, 1), getindex.(pts2, 2), color = :gray70, linewidth = 0.7), (0, 0, 1))

# Panel f (chain1)
meantracks1_exp = begin
    chain = maybe_load_chain(EXP_ROOT, 1)
    chain === nothing ? nothing : mean(tracks(chain, burn_in = burn_in), dims = 3)
end

heatmap!(ax_f_full, (0:W) .* exp_metadata["pixel size"], (0:H) .* exp_metadata["pixel size"], view(sumframes1_exp, :, :, 1), colormap = :grays)
if meantracks1_exp !== nothing
    lines!(ax_f_full, view(meantracks1_exp, :, 1, 1), view(meantracks1_exp, :, 2, 1), color = ColorSchemes.tab10[10])
end
poly!(ax_f_full, p_ef, color = :gray70)

heatmap!(ax_f_zoom, (0:W) .* exp_metadata["pixel size"], (0:H) .* exp_metadata["pixel size"], view(sumframes1_exp, :, :, 1), colormap = :grays)
if meantracks1_exp !== nothing
    lines!(ax_f_zoom, view(meantracks1_exp, :, 1, 1), view(meantracks1_exp, :, 2, 1),
            alpha = 0.5, color = ColorSchemes.tab20[8], linewidth = 16.0)
    lines!(ax_f_zoom, view(meantracks1_exp, :, 1, 1), view(meantracks1_exp, :, 2, 1), color = ColorSchemes.tab10[10])
end

limits!(ax_f_zoom, bounds_ef...)

pts1 = [posFig(ax_f_full, bounds_ef[2], bounds_ef[3]), posFig(ax_f_zoom, bounds_ef[1], bounds_ef[3])]
pts2 = [posFig(ax_f_full, bounds_ef[2], bounds_ef[4]), posFig(ax_f_zoom, bounds_ef[1], bounds_ef[4])]

translate!(lines!(fig.scene, getindex.(pts1, 1), getindex.(pts1, 2), color = :gray70, linewidth = 0.7), (0, 0, 1))
translate!(lines!(fig.scene, getindex.(pts2, 1), getindex.(pts2, 2), color = :gray70, linewidth = 0.7), (0, 0, 1))

# =========================
# Save output
# =========================
mkpath(SAVE_DIR)
outpath = joinpath(SAVE_DIR, figure_cfg.output_name)
save(outpath, fig)
println("Saved figure to $outpath")
