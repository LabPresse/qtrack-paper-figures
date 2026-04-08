using SP2T
using JLD2
using Distributions
using CUDA

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
        darkcounts = CUDA.zeros(50, 50) .+ eps(),
        cutoffs = (0, Inf),
        readouts = CuArray(load(joinpath(dir, "frames.jld2"), "frames")[:, :, 1:N]),
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
        guess = CuArray(gttracks[1:N, :, :]),
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

# 5.659603 seconds (24.37 M allocations: 845.898 MiB, 3.11% gc time)
# 7.178892 seconds (28.58 M allocations: 1.006 GiB, 2.90% gc time, 11.36% compilation time)
# 6.353883 seconds (27.75 M allocations: 973.966 MiB, 2.69% gc time)
# 6.534477 seconds (27.87 M allocations: 976.015 MiB, 3.34% gc time)
# 6.513216 seconds (28.25 M allocations: 982.360 MiB, 2.72% gc time)
# 6.983892 seconds (28.45 M allocations: 986.900 MiB, 3.23% gc time)
# 9.095428 seconds (28.64 M allocations: 998.328 MiB, 2.23% gc time, 0.12% compilation time)
# 12.796379 seconds (28.66 M allocations: 997.463 MiB, 1.79% gc time)
# 25.110002 seconds (28.84 M allocations: 1014.613 MiB, 0.87% gc time, 15 lock conflicts)
# 43.667029 seconds (29.18 M allocations: 1.018 GiB, 0.59% gc time, 17 lock conflicts)

# runMCMC!(chain, tracks, msd, brightness, detector, psf, 1000, true);

# jldsave(joinpath(dir, "chain_gpu.jld2"); chain)