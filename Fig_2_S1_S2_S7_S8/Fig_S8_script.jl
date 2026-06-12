using JLD2
using SP2T
using CairoMakie
using Statistics
using TOML
using ColorSchemes
orange = ColorSchemes.tab10.colors[2]

################################# Code to plot experimental histogram ######################
# toml_dir = length(ARGS) >= 1 ? ARGS[1] : "."
# base_dir = abspath(joinpath(toml_dir, ".."))
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
const SAVE_DIR = joinpath(SCRIPT_DIR, "..", "figures")
EXP_ROOT = joinpath(SCRIPT_DIR, "experimental_data")
INF_ROOT = joinpath(SCRIPT_DIR, inf_dir_name, "inf_exp_data")
period = 50e-6
burn_in = 100

tracks = load(joinpath(EXP_ROOT, "tracks1.jld2"), "tracks")
# --- infer batchsize from filename (e.g. chain1000.jld2 → 1000)
chain1 = load(joinpath(INF_ROOT, "chain_1.jld2"), "chain")
chain2 = load(joinpath(INF_ROOT, "chain_2.jld2"), "chain")
dvals1 = chain1.msds[burn_in+1:end] ./ (2 * period) # Diffusion coefficient samples
# MSD from SP2T is the 1D MSD, so you get D by dividing by 2*period
dvals2 = chain2.msds[burn_in+1:end] ./ (2 * period * 2); # Diffusion coefficient samples

inch = 96
pt = 4 / 3

fig = Figure(size = (12inch, 6inch), fontsize = 18pt, font = "Arial")
# fig = Figure(size=(600, 300))

ax = Axis(fig[1,1],
        xlabel=rich("Diffusion coefficient (μm", superscript("2"), "/s)"),
        ylabel="Probability",
        yticklabelsvisible=false
        )

bins = range(0.15, 0.43, length = 50)
hist!(ax, dvals1, 
    bins = bins,
    color = orange, 
    strokewidth = 1, 
    strokecolor = :white,
    normalization=:pdf,
    label = "Batch size = 1",
)

hist!(ax, dvals2, 
    bins = bins,
    color = :transparent, 
    strokewidth = 1, 
    strokecolor = :black,
    normalization=:pdf,
    label = "Batch size = 2" 
)
# hideydecorations!(ax, grid=false)
axislegend(ax, position=:rt)
mkpath(SAVE_DIR)
save(joinpath(SAVE_DIR, "Fig_S8.pdf"), fig)
