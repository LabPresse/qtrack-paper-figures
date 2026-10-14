using CairoMakie
using ColorSchemes
using Dates
using StatsBase
# several of these functions are copied from the SP2TExtra repository]

# ---------------- Shared paper palette ----------------
# Wong colors (colorblind-safe; also Makie's default palette, so figures that
# rely on default color cycling match automatically). Reserved roles:
# `track` is used only for inferred-track overlays on images, and `locerror`
# only for localization-error shading.
const PAPER_COLORS = (
    blue       = Makie.wong_colors()[1],
    orange     = Makie.wong_colors()[2],
    green      = Makie.wong_colors()[3],
    pink       = Makie.wong_colors()[4],
    skyblue    = Makie.wong_colors()[5],
    vermillion = Makie.wong_colors()[6],
    yellow     = Makie.wong_colors()[7],
    track      = ColorSchemes.tab10[10],
    locerror   = ColorSchemes.tab20[8],
)

# ---------------- Source Data export ----------------
# Figure scripts dump the numerical values behind each plotted series to
# source_data/<figure>/<block>.csv; make_source_data.py assembles the
# journal's Source Data workbook from these files.

const SOURCE_DATA_ROOT = joinpath(@__DIR__, "source_data")

function source_data_path(figname::AbstractString, block::AbstractString)
    dir = joinpath(SOURCE_DATA_ROOT, figname)
    mkpath(dir)
    return joinpath(dir, block * ".csv")
end

function write_source_csv(figname::AbstractString, block::AbstractString, headers, cols...)
    columns = [vec(collect(c)) for c in cols]
    n = maximum(length.(columns))
    open(source_data_path(figname, block), "w") do io
        println(io, join(headers, ","))
        for i in 1:n
            println(io, join((i <= length(c) ? c[i] : "" for c in columns), ","))
        end
    end
    return nothing
end

function write_source_matrix(figname::AbstractString, block::AbstractString, M::AbstractMatrix;
                             x = axes(M, 1), y = axes(M, 2), xlabel = "x", ylabel = "y")
    # CSV rows run over y, columns over x, matching heatmap!(x, y, M) orientation
    open(source_data_path(figname, block), "w") do io
        println(io, join([string(ylabel, "\\", xlabel); string.(collect(x))], ","))
        for (j, yj) in enumerate(y)
            println(io, join([yj; vec(M[:, j])], ","))
        end
    end
    return nothing
end

# Bin `data` exactly as hist!(...; bins = edges, normalization = :pdf) does
function binned_pdf(data::AbstractVector{<:Real}, edges::AbstractRange)
    h = fit(Histogram, data, edges)
    density = h.weights ./ (sum(h.weights) * step(edges))
    centers = (edges[1:end-1] .+ edges[2:end]) ./ 2
    return collect(centers), density
end

function get_unique_datadir(base_path, dir_name)
    # 1. Create the initial date-prefixed name
    date_str = today()
    folder_name = "$(date_str)_$dir_name"
    target_path = joinpath(base_path, folder_name)
    
    # 2. If it doesn't exist, we are done!
    if !ispath(target_path)
        return target_path
    end
    
    # 3. If it does exist, find the next available ID
    id = 1
    while ispath("$(target_path)_$id")
        id += 1
    end
    
    return "$(target_path)_$id"
end

function sample_exp(rate, rng)
    u = rand(rng)
    h = -1/rate*log(u) # holding time
    return h
end

function simulate_blinking_trajectory(total_time, on_rate, off_rate, seed_val, dt)
    rng = Random.Xoshiro()
    Random.seed!(rng, seed_val)
    t_vals = collect(0:dt:(total_time-dt/2))
    n_frames = length(t_vals)
    state_trace = zeros(Int, length(t_vals))

    t = 0.0
    state = 1 # start in on state
    
    while t < total_time
        if state == 0
            h = sample_exp(on_rate, rng)
            new_state = 1
        else
            h = sample_exp(off_rate, rng)
            new_state = 0
        end
        # nsteps = minimum(ceil(Int, h/dt), ceil((total_time - t)/dt))
        state_trace[(t_vals .>= t) .& (t_vals .< t+h)] .= state
        state = new_state
        t += h
    end
    
    return state_trace, t_vals
end
