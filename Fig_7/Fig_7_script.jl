using SP2T
using CairoMakie
using JLD2

dir = joinpath(pwd(), "Fig_7")
include(joinpath(dir, "..", "utils.jl"))

# metadata = load(joinpath(dir, "metadata.jld2"), "metadata")

factors = [0.1, 0.2, 0.5, 1.0, 2.0]

inch = 96
pt = 4 / 3
cm = inch / 2.54

fig = Figure(; size=(6inch, 4inch), fontsize=7pt, font="Arial")
axis_nparticles = Axis(
    fig[1, 1],
    xlabel="Number of emitting particles",
    ylabel="Time per iteration (s)",
    yscale=log10,
    xscale=log10,
)
nparticles = [1, 2, 5, 10, 20, 50, 100, 200]
cpu_nonparametric = reverse([
    90.129906,
    62.076980,
    48.111907,
    38.806874,
    35.881798,
    34.783449,
    34.564337,
    32.485655,
]) ./ 1000
gpu_nonparametric = reverse([
    40.907088,
    38.889104,
    36.968032,
    36.686156,
    36.926828,
    37.427132,
    36.653276,
    36.849085,
]) ./ 1000
cpu_parametric = reverse([
    47.955936
    26.080078
    15.561161
    7.346578
    4.736035
    3.330434
    2.496373
    2.158859
]) ./ 1000
gpu_parametric = reverse([
    2.355861
    1.875202
    1.482047
    1.331378
    1.342027
    1.414631
    1.353960
    1.335353
]) ./ 1000
l1 = scatterlines!(axis_nparticles, nparticles, cpu_nonparametric)
l2 = scatterlines!(axis_nparticles, nparticles, gpu_nonparametric)
l3 = scatterlines!(axis_nparticles, nparticles, cpu_parametric)
l4 = scatterlines!(axis_nparticles, nparticles, gpu_parametric)

write_source_csv("Fig_7", "a_time_vs_nparticles",
    ["n_particles", "cpu_nonparametric_s", "gpu_nonparametric_s", "cpu_parametric_s", "gpu_parametric_s"],
    nparticles, cpu_nonparametric, gpu_nonparametric, cpu_parametric, gpu_parametric)

Legend(
    fig[0, :],
    [l1, l2, l3, l4],
    ["CPU nonparametric", "GPU nonparametric", "CPU parametric", "GPU parametric"],
    orientation=:horizontal,
    framevisible=false,
)
mkpath(joinpath(dir, "../figures"))
save(joinpath(dir, "../figures/Fig_7.pdf"), fig)