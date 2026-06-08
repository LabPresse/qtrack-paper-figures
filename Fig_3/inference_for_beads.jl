using SP2T
# using SP2TExtra
using JLD2
using CUDA
using TOML
include("../utils.jl")

FloatType = Float32

resolve_path(path::AbstractString, base_dir::AbstractString) =
    isabspath(path) ? normpath(path) : normpath(joinpath(base_dir, path))

toml_file = length(ARGS) >= 1 ? ARGS[1] : "inference_params.toml"
toml_path = abspath(toml_file)
toml_dir = dirname(toml_path)
inference_params_toml = TOML.parsefile(toml_path)

test = false
println(ARGS)
if length(ARGS) >= 2
    if ARGS[2] == "test"
        println("Test inference runs for 1000 iterations")
        test = true
    end
end

frames_path = resolve_path(inference_params_toml["frames_path"], toml_dir)
camera_params_path = resolve_path(inference_params_toml["camera_params_path"], toml_dir)
camera_params = TOML.parsefile(camera_params_path)["camera"]
camera_base_dir = dirname(camera_params_path)

inference_params = inference_params_toml["inference"]
priors = inference_params_toml["priors"]
saving_params = get(inference_params_toml, "saving", inference_params_toml)

chain_output_dir = resolve_path(saving_params["chain_output_dir"], toml_dir)
if test
    clean = rstrip(chain_output_dir, '/')
    parent_dir, last_dir = splitdir(clean)
    chain_output_dir = joinpath(parent_dir, "test_$(last_dir)")
end
save_name = saving_params["save_name"]
save_unique = get(saving_params, "save_unique", true)
also_save = get(saving_params, "also_save", String[])
batchsizes = inference_params["batchsizes"]

dir_name = "inf_$(save_name)"
save_dir = save_unique ? get_unique_datadir(chain_output_dir, dir_name) : joinpath(chain_output_dir, dir_name)
println("Saving in $save_dir")
mkpath(save_dir)

frames_1bit = load(frames_path, "frames")
tracks_guess_path = resolve_path(priors["tracks_guess_path"], toml_dir)
tracks_1bit = load(tracks_guess_path, "tracks")

n_input_frames = size(frames_1bit, 3)
println("Loaded $n_input_frames input frames from $frames_path")

# psf = CircularGaussian{FloatType}(
#     numerical_aperture = camera_params["numerical_aperture"],
#     refractive_index = camera_params["refractive_index"],
#     emission_wavelength = camera_params["wavelength"],
#     pixel_size = camera_params["pixel_size"],
# )

psf = CircularGaussian{FloatType}(camera_params["psf_std"], camera_params["pixel_size"])


if camera_params["darkcounts"] isa Number
    darkcounts = fill(FloatType(camera_params["darkcounts"]), camera_params["detector_size"], camera_params["detector_size"])
else
    darkcounts = FloatType.(load(resolve_path(camera_params["darkcounts"], camera_base_dir), "darkcounts"))
end

for batchsize in batchsizes
    println("Running inference with batchsize = $batchsize")
    frames = CuArray(binframes(frames_1bit, batchsize))

    detector = SPAD{FloatType}(
        period = camera_params["period"],
        pixel_size = camera_params["pixel_size"],
        darkcounts = CuArray(darkcounts),
        cutoffs = (0, Inf),
        readouts = frames,
        batchsize = batchsize,
    )

    msd = MeanSquaredDisplacement{FloatType}(
        guess = 2 * priors["diffusion_coeff_guess"] * camera_params["period"] * batchsize,
        priorparams = tuple(priors["msd_prior"]...),
    )

    brightness = Brightness{FloatType}(
        guess = priors["brightness_guess"] * camera_params["period"] * psf.A,
        priorparams = tuple(priors["brightness_prior"]...),
        proposalparams = tuple(priors["brightness_proposal"]...),
    )

    tracks = Tracks{FloatType}(
        guess = CuArray(bintracks(tracks_1bit, batchsize)),
        prior = DNormal{FloatType}(
            CuArray(collect(detector.framecenter)),
            CuArray{FloatType}([
                camera_params["pixel_size"] * priors["track_prior_scale"],
                camera_params["pixel_size"] * priors["track_prior_scale"],
            ]),
        ),
        max_ntracks = inference_params["max_n_tracks"],
        scaling = √msd.value,
        logonprob = priors["track_logonprob"],
    )

    n_iters = test ? 1000 : inference_params["n_iters"]
    chain = runMCMC(
        tracks = tracks,
        msd = msd,
        brightness = brightness,
        detector = detector,
        psf = psf,
        niters = n_iters,
        sizelimit = inference_params["size_limit"],
        parametric = inference_params["parametric"],
    )

    chain_fname = joinpath(save_dir, "chain_$(batchsize).jld2")
    jldsave(chain_fname; chain = chain, tracks = tracks, msd = msd, brightness = brightness, detector = detector, psf = psf)
end

cp(toml_path, joinpath(save_dir, basename(toml_path)), force=!save_unique)
cp(camera_params_path, joinpath(save_dir, basename(camera_params_path)), force=!save_unique)
cp(tracks_guess_path, joinpath(save_dir, basename(tracks_guess_path)), force=!save_unique)

frames_dir = dirname(frames_path)
for extra_file in also_save
    extra_path = resolve_path(extra_file, frames_dir)
    cp(extra_path, joinpath(save_dir, basename(extra_path)), force=!save_unique)
end
