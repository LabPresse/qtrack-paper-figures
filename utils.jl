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

function sumbin!(binned::AbstractArray{T,3}, tobin::AbstractArray{T,3}, batchsize::Integer) where {T<:Real}
    @views for i in axes(binned, 3)
        sum!(
            binned[:, :, i],
            tobin[:, :, (i-1)*batchsize+1:i*batchsize],
        )
    end
    return binned
end

function binframes(frames1bit::AbstractArray{<:Integer,3}, batchsize::Integer)
    binned = similar(
        frames1bit,
        size(frames1bit, 1),
        size(frames1bit, 2),
        size(frames1bit, 3) ÷ batchsize,
    )
    sumbin!(binned, frames1bit, batchsize)
    return binned
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

repeattracks(tracks::AbstractArray{<:Real,3}, batchsize::Integer) = repeat(tracks, inner=(batchsize, 1, 1))

function writetiff(path::String, frames::AbstractArray{UInt16,3}; px_size::Real=1, unit::AbstractString="μm", period::Real=1)
    tiff = TiffImages.DenseTaggedImage(reinterpret(Gray{N0f16}, frames))
    ifdvec = ifds(tiff)
    nframes = size(frames, 3)
    for ifd in ifdvec
        res = Rational{UInt32}(round(1 / px_size, digits=3))
        ifd[TiffImages.XRESOLUTION] = res
        ifd[TiffImages.YRESOLUTION] = res
        ifd[TiffImages.RESOLUTIONUNIT] = oneunit(UInt8)
    end
    unit == "μm" && (unit = "um")
    ifdvec[1][TiffImages.IMAGEDESCRIPTION] = "unit=$unit\nfinterval=$period"
    TiffImages.save(path, tiff)
end

function tracks_from_chain(chain::Chain{T}; burn_in::Integer=0) where {T<:Real}
    N = sum(chain.emittercounts[burn_in+1:end])
    t = chain.samples[1].tracks
    x = Array{T}(undef, size(t, 1), size(t, 2), N)
    i = 1
    for s in chain.samples[burn_in+1:end]
        n = size(s.tracks, 3)
        copyto!(view(x, :, :, i:i+n-1), s.tracks)
        i += n
    end
    return x
end

#! Only works when one particle is present
function localization_error(chain::Chain{T}; burn_in::Integer=0) where {T<:Real}
    x = tracks_from_chain(chain; burn_in=burn_in)
    mean(sqrt.(sum(var(x, dims=3), dims=2))) / 2
end