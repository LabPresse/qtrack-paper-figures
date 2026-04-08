using SP2T
using JLD2
using Distributions

dir = "./examples/background"

metadata = load(joinpath(dir, "metadata.jld2"), "metadata")

FloatType = Float32

detector = SP2T.EMCCDGamma{FloatType}(
    period = metadata["period"],
    pixel_size = metadata["pixel size"],
    darkcounts = fill(1e5 * metadata["period"] * metadata["pixel size"]^2, 128, 128) .* 5.0,
    cutoffs = (0, Inf),
    readouts = load(joinpath(dir, "frames_5.0.jld2"), "frames"),
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

gt = load(joinpath(dir, "groundtruth.jld2"), "tracks")

nframes = size(detector.readouts, 3)
tracks = Tracks{FloatType}(
    guess = zeros(nframes, 2, 1),
    prior = DNormal{FloatType}(
        collect(detector.framecenter),
        convert(FloatType, metadata["pixel size"]) .*
        [size(detector.readouts, 1), size(detector.readouts, 2)] ./ 2,
    ),
    max_ntracks = 20,
    scaling = √msd.value,
    logonprob = -10,
)

chain = runMCMC(
    tracks = tracks,
    msd = msd,
    brightness = brightness,
    detector = detector,
    psf = psf,
    niters = 5000,
    sizelimit = 1000,
    # annealing = PolynomialAnnealing{FloatType}(1000, 1000, 2),
);

runMCMC!(chain, tracks, msd, brightness, detector, psf, 1000, true);

jldsave("./examples/EMCCD Gamma2/chain_cpu.jld2"; chain)