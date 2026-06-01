using SP2T
using JLD2
using Distributions

dir = "./benchmarks/nframes"

metadata = load(joinpath(dir, "metadata.jld2"), "metadata")
gttracks = load(joinpath(dir, "groundtruth.jld2"), "tracks")
gtmsd = load(joinpath(dir, "groundtruth.jld2"), "msd")
gtbrightness = load(joinpath(dir, "groundtruth.jld2"), "brightness")

FloatType = Float32

for N in [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000]
    detector = EMCCD{FloatType}(
        period = metadata["period"],
        pixel_size = metadata["pixel size"],
        darkcounts = zeros(50, 50) .+ eps(),
        cutoffs = (0, Inf),
        readouts = load(joinpath(dir, "frames.jld2"), "frames")[:, :, 1:N],
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
        guess = gttracks[1:N, :, :],
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

# 0.447546 seconds (1.08 M allocations: 87.965 MiB, 4.10% gc time)
# 0.763726 seconds (1.08 M allocations: 117.321 MiB, 1.93% gc time)
# 2.005623 seconds (1.25 M allocations: 207.442 MiB, 1.45% gc time, 14.71% compilation time)
# 3.298759 seconds (1.15 M allocations: 332.014 MiB, 1.57% gc time)
# 6.404777 seconds (1.19 M allocations: 603.644 MiB, 1.13% gc time)
# 15.588880 seconds (1.19 M allocations: 1.383 GiB, 0.76% gc time)
# 30.844945 seconds (1.19 M allocations: 2.702 GiB, 0.62% gc time)
# 67.182005 seconds (1.20 M allocations: 5.341 GiB, 0.56% gc time)
# 173.621677 seconds (1.21 M allocations: 13.257 GiB, 0.53% gc time)
# 323.893421 seconds (1.21 M allocations: 26.450 GiB, 0.51% gc time)

# runMCMC!(chain, tracks, msd, brightness, detector, psf, 1000, true);

# jldsave(joinpath(dir, "chain_cpu.jld2"); chain)