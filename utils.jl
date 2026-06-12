using CairoMakie
using Dates
using StatsBase
# several of these functions are copied from the SP2TExtra repository]

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
