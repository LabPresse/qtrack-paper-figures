using SP2T
using JLD2
using Distributions
using CUDA

dir = "./examples/background"

metadata = load(joinpath(dir, "metadata.jld2"), "metadata")

FloatType = Float32

factor = 10.0

# for factor in [10.0]
detector = SP2T.EMCCDGamma{FloatType}(
    period = metadata["period"],
    pixel_size = metadata["pixel size"],
    darkcounts = CUDA.fill(1e5 * metadata["period"] * metadata["pixel size"]^2, 128, 128) .* factor,
    cutoffs = (0, Inf),
    readouts = CuArray(load(joinpath(dir, "frames_$factor.jld2"), "frames")),
    gain = 0.3,
)

psf = CircularGaussian{FloatType}(
    numerical_aperture = metadata["numerical aperture"],
    refractive_index = metadata["refractive index"],
    emission_wavelength = metadata["wavelength"],
    pixel_size = metadata["pixel size"],
)

msd = MeanSquaredDisplacement{FloatType}(
    guess = 2 * 0.2 * metadata["period"],
    priorparams = (2, 1e-5),
)

brightness = Brightness{FloatType}(
    guess = 1e4 * metadata["period"] * psf.A,
    priorparams = (1, 10),
    proposalparams = (10, 1),
)

nframes = size(detector.readouts, 3)
tracks = Tracks{FloatType}(
    guess = CUDA.zeros(nframes, 2, 1),
    prior = DNormal{FloatType}(
        CuArray(collect(detector.framecenter)),
        CuArray{FloatType}(
            convert(FloatType, metadata["pixel size"]) .*
            [size(detector.readouts, 1), size(detector.readouts, 2)] ./ 2,
        ),
    ),
    max_ntracks = 20,
    scaling = √msd.value, 2Z,
    logonprob = -5,
)

chain = runMCMC(
    tracks = tracks,
    msd = msd,
    brightness = brightness,
    detector = detector,
    psf = psf,
    niters = 1000000,
    sizelimit = 1000,
)

# runMCMC!(chain, tracks, msd, brightness, detector, psf, 1000, true);

jldsave("./examples/EMCCD Gamma2/chain_$factor.jld2"; chain)
# end

# 0.5 1:01:13 10/10
# 1.0 1:01:18 10/10
# 2.0 0:59:08 10/10
# 5.0 1:03:10 10/10
# 10.0 1:55:33 / 2 10/10