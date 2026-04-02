using SP2T
using Random
using JLD2
using TOML
using Dates
include("utils.jl")

FloatType = Float64

resolve_path(path::AbstractString, base_dir::AbstractString) =
    isabspath(path) ? normpath(path) : normpath(joinpath(base_dir, path))

# Load parameters from TOML file
toml_file = length(ARGS) >= 1 ? ARGS[1] : "sim_params.toml"
toml_path = abspath(toml_file)
toml_dir = dirname(toml_path)
params = TOML.parsefile(toml_path)

# Extract parameters from sections
camera_params = params["camera"]
sim_params = params["simulation"]
saving_params = params["saving"]

# Create PSF with optical parameters
psf = CircularGaussian{FloatType}(
    numerical_aperture = camera_params["numerical_aperture"],
    refractive_index = camera_params["refractive_index"],
    emission_wavelength = camera_params["wavelength"],
    pixel_size = camera_params["pixel_size"],
)

# Handle darkcounts: load from file or create zeros (base template)
darkcounts_param = camera_params["darkcounts"]
detector_size = camera_params["detector_size"]
if darkcounts_param === false
    base_darkcounts = zeros(FloatType, detector_size, detector_size)
elseif darkcounts_param isa Number
    base_darkcounts = fill(FloatType(darkcounts_param), detector_size, detector_size)
else
    darkcounts_path = resolve_path(darkcounts_param, toml_dir)
    base_darkcounts = FloatType.(load(darkcounts_path, "darkcounts"))
end

# --- Execution ---
dir_name = "sim_$(saving_params["save_name"])"
save_location = resolve_path(saving_params["save_location"], toml_dir)
save_unique = get(saving_params, "save_unique", true)
if save_unique
    data_dir = get_unique_datadir(save_location, dir_name)
else
    data_dir = joinpath(save_location, dir_name)
end
println("Saving in $data_dir")
mkpath(data_dir)

random_seed = get(sim_params, "random_seed", false)
init_width = get(sim_params, "init_width", 10)
init_bounds_pixels = get(sim_params, "init_bounds_pixels", nothing)
throw_out_of_bounds = get(sim_params, "throw_out_of_bounds", true)
shift = get(sim_params, "shift", false)
detector_type = get(sim_params, "detector_type", "spad")

# Seed the simulation reproducibly when requested
if random_seed !== false
    Random.seed!(random_seed)
end

# Create a fresh detector
darkcounts = copy(base_darkcounts)
if detector_type == "spad"
    detector = SPAD{FloatType}(
        period = camera_params["period"],
        pixel_size = camera_params["pixel_size"],
        darkcounts = darkcounts,
        cutoffs = (0, Inf),
        readouts = zeros(UInt16, size(darkcounts)..., sim_params["n_frames"]),
    )
elseif detector_type == "emccd"
    detector = EMCCD{FloatType}(
        period = camera_params["period"],
        pixel_size = camera_params["pixel_size"],
        darkcounts = darkcounts,
        cutoffs = (0, Inf),
        readouts = zeros(UInt16, size(darkcounts)..., sim_params["n_frames"]),
        offset = 0,
        gain = 5,
        variance=0
    )
else
    error("Detector type $detector_type not implemented, try 'spad' or 'emccd'.")
end

# Simulate tracks
msd = 2 * sim_params["diffusion_coefficient"] * camera_params["period"]
n_particles = sim_params["n_particles"]
n_frames = sim_params["n_frames"]

tracks = Array{FloatType}(undef, n_frames, 2, n_particles)
if init_bounds_pixels !== nothing
    length(init_bounds_pixels) == 4 || error(
        "init_bounds_pixels must contain [xmin, xmax, ymin, ymax] in detector pixels.",
    )
    xmin, xmax, ymin, ymax = FloatType.(init_bounds_pixels)
    xmax >= xmin || error("init_bounds_pixels requires xmax >= xmin.")
    ymax >= ymin || error("init_bounds_pixels requires ymax >= ymin.")
    bounds = ((xmin, xmax), (ymin, ymax))
    for i in 1:n_particles
        for d in 1:2
            lo, hi = bounds[d]
            tracks[1, d, i] = (lo + rand(FloatType) * (hi - lo)) * camera_params["pixel_size"]
        end
    end
else
    @views rand!(tracks[1, :, :]) .*= init_width .* camera_params["pixel_size"]
    offset = (camera_params["detector_size"] - init_width) * camera_params["pixel_size"] / 2
    tracks[1, :, :] .+= offset
end

simulate!(tracks, msd)
if shift === true
    # If tracks leave FOV, shift starting position to be more central
    for i in 1:n_particles
        for d in 1:2
            if minimum(tracks[:, d, i]) < 0
                shift_val = minimum(tracks[:, d, i])*1.5
                tracks[:, d, i] .-= shift_val
                println("Shifting")
            elseif maximum(tracks[:, d, i]) > size(detector, d) .* camera_params["pixel_size"]
                shift_val = (maximum(tracks[:, d, i]) .- size(detector, d) .* camera_params["pixel_size"]).*1.5
                tracks[:, d, i] .-= shift_val
                println("Shifting")
            end
        end
    end
elseif shift isa Array
    # Shift all tracks by specified amount in pixels
    size_shift = size(shift)
    if size_shift == (2,)
        tracks .+= reshape(shift .* camera_params["pixel_size"], 1, 2, 1)
    else
        error("Shift parameter has size $(size_shift)), but should be of size (2,).")
    end
end

# check again if tracks are out of bounds, if so, throw error
for i in 1:n_particles
    for d in 1:2
        if (minimum(tracks[:, d, i]) < 0) || (maximum(tracks[:, d, i]) > size(detector, d) .* camera_params["pixel_size"])
            if throw_out_of_bounds
                error("Track $i is out of bounds after shifting. Check parameters.")
            else
                println("WARNING: Track $i is out of bounds after shifting.")
            end
        end
    end
end

# Save groundtruth track
gt_fname = joinpath(data_dir, "groundtruth.jld2")
jldsave(gt_fname; tracks = tracks, msd = msd)

# Photoblinking tracks
if haskey(params, "blinking")
    println("Simulating photoblinking trajectory")
    on_rate = 1/params["blinking"]["on_rate_period"]
    off_rate = 1/params["blinking"]["off_rate_period"]
    seed_val = params["blinking"]["states_seed"]
    state_trace, _ = simulate_blinking_trajectory(
        n_frames * camera_params["period"],
        on_rate, off_rate,
        seed_val,
        camera_params["period"]
        )
    states_fname = joinpath(data_dir, "states.jld2")
    jldsave(states_fname; states=state_trace)

    # For frames where state is off (0), set track position to NaN
    for d in 1:2
        @views tracks[:, d, 1] .= ifelse.(state_trace .== 1, tracks[:, d, 1], NaN)
    end

    # Save blinking tracks
    gt_fname = joinpath(data_dir, "groundtruth_blinking.jld2")
    jldsave(gt_fname; tracks = tracks, msd = msd)
end

# Simulate readouts
brightness = sim_params["brightness_multiplier"] * camera_params["period"] * psf.A
SP2T.simulate_readouts!(
    detector,
    SP2T.getincident(tracks, brightness, detector.darkcounts, detector.pxbounds, psf),
)
frames_fname = joinpath(data_dir, "frames.jld2")
jldsave(frames_fname; frames = detector.readouts)

# Copy toml file to directory for reference
toml_fname_new = joinpath(data_dir, basename(toml_path))
cp(toml_path, toml_fname_new, force=!save_unique)
