using SP2T
using JLD2
using Distributions

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
        darkcounts = zeros(128, 128) .+ eps(),
        cutoffs = (0, Inf),
        readouts = load(joinpath(dir, "frames.jld2"), "frames"),
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
        guess = gttracks,
        prior = DNormal{FloatType}(
            collect(detector.framecenter),
            convert(FloatType, metadata["pixel size"]) * 10 .* [1, 1],
        ),
        max_ntracks = M,
        perturbsize = fill(√msd.value, 2),
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

# 33.019432 seconds (7.39 M allocations: 2.421 GiB, 1.20% gc time)
#  18.049709 seconds (3.79 M allocations: 1.259 GiB, 1.09% gc time)
#  10.079853 seconds (1.99 M allocations: 694.540 MiB, 1.04% gc time)
#   5.541876 seconds (911.43 k allocations: 337.674 MiB, 1.04% gc time)
#   3.972533 seconds (551.32 k allocations: 218.738 MiB, 0.84% gc time)
#   3.237083 seconds (371.30 k allocations: 159.244 MiB, 0.66% gc time)
#   2.761136 seconds (263.24 k allocations: 123.580 MiB, 0.73% gc time)
#   2.613482 seconds (227.26 k allocations: 111.663 MiB, 0.47% gc time)