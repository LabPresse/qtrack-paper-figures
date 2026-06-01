using SP2T
using JLD2
using Distributions

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
        darkcounts = zeros(framesize, framesize) .+ eps(),
        cutoffs = (0, Inf),
        readouts = load(joinpath(dir, "frames_$framesize.jld2"), "frames"),
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
        guess = copy(gttracks),
        prior = DNormal{FloatType}(
            collect(detector.framecenter),
            convert(FloatType, metadata["pixel size"]) * 10 .* [1, 1],
        ),
        max_ntracks = 10,
        perturbsize = fill(√msd.value, 2),
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

# 8.748255 seconds (1.19 M allocations: 962.712 MiB, 1.11% gc time)
# 21.756765 seconds (1.19 M allocations: 1.765 GiB, 0.68% gc time)
# 38.175688 seconds (1.19 M allocations: 3.432 GiB, 0.65% gc time)
# 108.681775 seconds (1.20 M allocations: 6.784 GiB, 0.39% gc time)
# 372.529724 seconds (1.22 M allocations: 13.517 GiB, 0.23% gc time)
# 1370.256918 seconds (1.25 M allocations: 27.090 GiB, 0.07% gc time)
# 5523.995111 seconds (1.31 M allocations: 54.676 GiB, 0.01% gc time)

# runMCMC!(chain, tracks, msd, brightness, detector, psf, 1000, true);

# jldsave(joinpath(dir, "chain_cpu.jld2"); chain)