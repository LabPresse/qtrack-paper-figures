using SP2T
using JLD2
using Distributions
using CUDA

dir = "./benchmarks/weaklim"

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
        readouts = CuArray(load(joinpath(dir, "frames.jld2"), "frames")),
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
        max_ntracks = M,
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
end

# 37.521583 seconds (144.31 M allocations: 4.918 GiB, 2.47% gc time, 2 lock conflicts)
#  20.038792 seconds (75.90 M allocations: 2.584 GiB, 2.35% gc time, 2 lock conflicts)
#  11.028439 seconds (41.66 M allocations: 1.416 GiB, 2.52% gc time)
#   5.389633 seconds (21.12 M allocations: 732.865 MiB, 2.40% gc time)
#   3.673720 seconds (14.28 M allocations: 493.876 MiB, 2.79% gc time)
#   2.682955 seconds (10.86 M allocations: 374.352 MiB, 2.53% gc time)
#   2.075929 seconds (8.80 M allocations: 302.672 MiB, 1.68% gc time)
#   1.852915 seconds (7.87 M allocations: 269.388 MiB, 1.89% gc time, 0.60% compilation time)