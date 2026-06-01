using SP2T
using CairoMakie
using Statistics
using StatsBase
using Random
using ColorSchemes
blue = ColorSchemes.tab10[1]

const SCRIPT_DIR = @__DIR__
const SAVE_DIR = abspath(joinpath(SCRIPT_DIR, "../figures"))

function calculate_msds(trajectories)
    distances = diff(trajectories, dims=1)
    squared_displacements = sum(distances .^ 2, dims=2) # x^2 + y^2
    msd = mean(squared_displacements, dims=1)
    return dropdims(msd, dims=(1,2))
end

function calculate_D_apparent(trajectories, dt)
    msds = calculate_msds(trajectories)
    return msds ./ (4*dt)
end


function meanbin!(binned::AbstractArray{T,3}, tobin::AbstractArray{T,3}, batchsize::Integer) where {T<:AbstractFloat}
    @views for i in axes(binned, 1)
        mean!(
            binned[i:i, :, :],
            tobin[(i-1)*batchsize+1:i*batchsize, :, :],
            weights(ones(T, batchsize)),
            dims=1,
        )
    end
    return binned
end

function bintracks(tracks1bit::AbstractArray{<:AbstractFloat,3}, batchsize::Integer)
    binned = similar(
        tracks1bit,
        size(tracks1bit, 1) ÷ batchsize,
        size(tracks1bit, 2),
        size(tracks1bit, 3),
    )
    meanbin!(binned, tracks1bit, batchsize)
    return binned
end

n_simulations = 50000
n_frames = 6000 
period = 1e-5
diffusion_coefficient = 0.1

# for sim_idx in 1:n_simulations
#     # per-simulation seeding for reproducible but distinct runs
#     Random.seed!(random_seed + sim_idx - 1)

trajectories = Array{Float64}(undef, n_frames, 2, n_simulations)
trajectories[1,:,:] = zeros(2, n_simulations)
msd = 2 * diffusion_coefficient * period
simulate!(trajectories, msd)
println(size(trajectories))
binned = bintracks(trajectories, 100)
println(size(binned))
## Look at apparent diffusion coefficients
batchsizes = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 3000]
# D_apparent = calculate_D_apparent(trajectories, period)
# println(D_apparent)

d_samples = []
max_val = 0
max_idx = 0
min_val = 100
min_idx = 0
for batchsize in batchsizes
    println("Batchsize: $batchsize")
    binned = bintracks(trajectories, batchsize)
    d_app_bs = calculate_D_apparent(binned, period*batchsize)
    push!(d_samples, d_app_bs)
    if maximum(d_app_bs) > max_val
        max_val, max_idx = findmax(d_app_bs)
    end
    if minimum(d_app_bs) < min_val
        min_val, min_idx = findmin(d_app_bs)
    end
end
println("(min, max) = ($min_val, $max_val)")
n_bins = 150
max_val = 0.2
step_val = max_val / n_bins
bins=0:step_val:max_val
hist_scale_factor = 0.7

fig = Figure(size=(1000,500))
ax = Axis(fig[1,1],
    xlabel="Batchsize",
    ylabel="Apparent diffusion coefficient",
    xticks=(
        1:length(batchsizes),
        string.(batchsizes)
    )
)
hlines!(diffusion_coefficient, color=:black, linestyle=:dash)
for i in 1:length(batchsizes)
    d_apparent = d_samples[i]
    hist!(ax, 
        d_apparent,
        bins=bins,
        offset=i, 
        direction=:x, 
        color=blue, 
        normalization=:pdf, 
        scale_to=hist_scale_factor
    )
end
save("$SAVE_DIR/Fig_S6.pdf", fig)
display(fig)