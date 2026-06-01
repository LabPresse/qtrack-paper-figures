using SP2T
using JLD2
using Distributions

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
        darkcounts = zeros(128, 128) .+ eps(),
        cutoffs = (0, Inf),
        readouts = load(joinpath(dir, "frames_$M.jld2"), "frames"),
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
        guess = gttracks[:, :, 1:M],
        prior = DNormal{FloatType}(
            collect(detector.framecenter),
            convert(FloatType, metadata["pixel size"]) * 10 .* [1, 1],
        ),
        max_ntracks = 200,
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
    @time runMCMC!(chain, tracks, msd, brightness, detector, psf, 1000, true)
end

#  90.129906 seconds (8.60 M allocations: 19.613 GiB, 1.77% gc time)
#  47.955936 seconds (157.53 k allocations: 13.423 GiB, 1.65% gc time)
#  62.076980 seconds (8.59 M allocations: 11.943 GiB, 1.74% gc time)
#  26.080078 seconds (156.24 k allocations: 6.716 GiB, 2.62% gc time)
#  48.111907 seconds (8.59 M allocations: 8.107 GiB, 1.57% gc time)
#  15.561161 seconds (155.52 k allocations: 3.363 GiB, 1.39% gc time)
#  38.806874 seconds (8.59 M allocations: 5.806 GiB, 1.63% gc time)
#   7.346578 seconds (154.56 k allocations: 1.351 GiB, 1.20% gc time)
#  35.881798 seconds (8.59 M allocations: 5.039 GiB, 1.55% gc time)
#   4.736035 seconds (154.34 k allocations: 696.778 MiB, 0.98% gc time)
#  34.783449 seconds (8.59 M allocations: 4.655 GiB, 1.49% gc time)
#   3.330434 seconds (154.31 k allocations: 353.414 MiB, 0.77% gc time)
#  34.564337 seconds (8.59 M allocations: 4.425 GiB, 1.80% gc time)
#   2.496373 seconds (154.23 k allocations: 147.331 MiB, 0.55% gc time)
#  32.485655 seconds (8.59 M allocations: 4.348 GiB, 1.80% gc time)
#   2.158859 seconds (154.23 k allocations: 78.484 MiB, 0.47% gc time)