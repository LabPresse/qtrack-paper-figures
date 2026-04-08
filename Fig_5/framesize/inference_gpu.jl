using SP2T
using JLD2
using Distributions
using CUDA

dir = "./benchmarks/framesize"

metadata = load(joinpath(dir, "metadata.jld2"), "metadata")

FloatType = Float32

for framesize in [16, 32, 64, 128, 256, 512, 1024]
    gttracks = load(joinpath(dir, "groundtruth_$framesize.jld2"), "tracks")
    gtmsd = load(joinpath(dir, "groundtruth_$framesize.jld2"), "msd")
    gtbrightness = load(joinpath(dir, "groundtruth_$framesize.jld2"), "brightness")
    detector = EMCCD{FloatType}(
        period = metadata["period"],
        pixel_size = metadata["pixel size"],
        darkcounts = CUDA.zeros(framesize, framesize) .+ eps(),
        cutoffs = (0, Inf),
        readouts = CuArray(load(joinpath(dir, "frames_$framesize.jld2"), "frames")),
        offset = 100,
        gain = 100,
        variance = 2,
    )

    psf = CircularGaussian{FloatType}(
        numerical_aperture = metadata["numerical aperture"],
        refractive_index = metadata["refractive index"],
        emission_wavelength = metadata["wavelength"],
        pixel_size = metadata["pixel size"],
    )

    msd = MeanSquaredDisplacement{FloatType}(guess = gtmsd, prior = InverseGamma(2, 1e-5))

    brightness = Brightness{FloatType}(
        guess = gtbrightness,
        prior = Gamma(1, 10),
        proposalparam = 10,
    )

    nframes = size(detector.readouts, 3)
    tracks = Tracks{FloatType}(
        guess = CuArray(gttracks),
        prior = DNormal{FloatType}(
            CuArray(collect(detector.framecenter)),
            CuArray{FloatType}([metadata["pixel size"] * 10, metadata["pixel size"] * 10]),
        ),
        max_ntracks = 10,
        perturbsize = CUDA.fill(√msd.value, 2),
        logonprob = -3,
    )

    @time chain = runMCMC(
        tracks = tracks,
        msd = msd,
        brightness = brightness,
        detector = detector,
        psf = psf,
        niters = 2000,
        sizelimit = 1000,
    )
end

# 6.311231 seconds (28.51 M allocations: 990.896 MiB, 3.64% gc time)
# 6.595078 seconds (28.54 M allocations: 991.225 MiB, 3.17% gc time)
# 10.332345 seconds (28.53 M allocations: 991.038 MiB, 2.01% gc time)
# 26.258859 seconds (28.60 M allocations: 992.063 MiB, 0.84% gc time, 11 lock conflicts)
# 81.828142 seconds (28.63 M allocations: 992.752 MiB, 0.26% gc time, 9 lock conflicts)
# 302.311302 seconds (29.21 M allocations: 1002.314 MiB, 0.08% gc time, 13 lock conflicts)
# 1141.116050 seconds (29.25 M allocations: 1005.526 MiB, 0.04% gc time, 3 lock conflicts)

# runMCMC!(chain, tracks, msd, brightness, detector, psf, 1000, true);

# jldsave(joinpath(dir, "chain_gpu.jld2"); chain)