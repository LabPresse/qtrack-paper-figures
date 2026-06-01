using SP2T
using JLD2
using Distributions
using CUDA

dir = "./benchmarks/nparticles"

metadata = load(joinpath(dir, "metadata.jld2"), "metadata")
gttracks = load(joinpath(dir, "groundtruth.jld2"), "tracks")
gtmsd = load(joinpath(dir, "groundtruth.jld2"), "msd")
gtbrightness = load(joinpath(dir, "groundtruth.jld2"), "brightness")

FloatType = Float32
chain = []

for M in [200, 100, 50, 20, 10, 5, 2, 1]
    detector = EMCCD{FloatType}(
        period = metadata["period"],
        pixel_size = metadata["pixel size"],
        darkcounts = CUDA.zeros(128, 128) .+ eps(),
        cutoffs = (0, Inf),
        readouts = CuArray(load(joinpath(dir, "frames_$M.jld2"), "frames")),
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
        guess = CuArray(gttracks[:, :, 1:M]),
        prior = DNormal{FloatType}(
            CuArray(collect(detector.framecenter)),
            CuArray{FloatType}([metadata["pixel size"] * 10, metadata["pixel size"] * 10]),
        ),
        max_ntracks = 200,
        perturbsize = CUDA.fill(√msd.value, 2),
        logonprob = -3,
    )

    @time chain = runMCMC(
        tracks = tracks,
        msd = msd,
        brightness = brightness,
        detector = detector,
        psf = psf,
        niters = 1000,
        sizelimit = 1000,
    )
    @time runMCMC!(chain, tracks, msd, brightness, detector, psf, 1000, true)
end

#  40.907088 seconds (156.60 M allocations: 5.270 GiB, 3.28% gc time, 9 lock conflicts)
#   2.355861 seconds (6.42 M allocations: 232.338 MiB, 2.97% gc time)
#  38.889104 seconds (153.49 M allocations: 5.227 GiB, 3.17% gc time, 1.24% compilation time)
#   1.875202 seconds (6.41 M allocations: 224.528 MiB, 6.02% gc time)
#  36.968032 seconds (150.47 M allocations: 5.133 GiB, 3.74% gc time, 0.02% compilation time)
#   1.482047 seconds (6.31 M allocations: 218.763 MiB, 3.11% gc time)
#  36.686156 seconds (149.17 M allocations: 5.104 GiB, 3.17% gc time)
#   1.331378 seconds (6.27 M allocations: 215.771 MiB, 3.47% gc time)
#  36.926828 seconds (148.75 M allocations: 5.094 GiB, 3.15% gc time)
#   1.342027 seconds (6.27 M allocations: 215.069 MiB, 3.43% gc time)
#  37.427132 seconds (148.54 M allocations: 5.089 GiB, 3.09% gc time)
#   1.414631 seconds (6.27 M allocations: 214.643 MiB, 3.55% gc time)
#  36.653276 seconds (148.34 M allocations: 5.085 GiB, 3.16% gc time)
#   1.353960 seconds (6.26 M allocations: 214.184 MiB, 3.61% gc time)
#  36.849085 seconds (148.28 M allocations: 5.084 GiB, 3.25% gc time)
#   1.335353 seconds (6.26 M allocations: 214.108 MiB, 3.40% gc time)