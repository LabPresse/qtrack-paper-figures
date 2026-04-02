using SP2T
using SP2TExtra
using JLD2
using CUDA

FloatType = Float32

# cd("./data/D vs bits/5035")
dir = joinpath("./data/experimental")
cd(dir)

metadata = Dict{String,Any}(
    "dataset" => "DOPC-GM1-SM-Chol-BigDomains i9_540nm_p100_fll4_exp50_bd10_binary_good",
    "units" => ("μm", "s"),
    "dye" => "Cy3",
    "numerical aperture" => 1.49,
    "refractive index" => 1.52,
    "wavelength" => 0.571,
    "period" => 50e-6,
    "pixel size" => 0.1,
)

# roisheet = XLSX.readxlsx("ganglioside.xlsx")["200to20"][:]
# rois = roisheet[3:3, 8:end]
# ids = roisheet[3:3, 1]
frames_1bit = load("frames1.jld2", "frames")
tracks_1bit = load("tracks1.jld2", "tracks")
darkcounts = load("./bigdomainDC.jld2", "darkcounts")[295:304,411:420]

# for batchsize in [1, 200]
for batchsize in [1, 2, 5, 10, 20, 50, 100, 200, 400, 850, 1700, 3400]
    frames = CuArray(binframes(frames_1bit, batchsize))
    detector = SPAD{FloatType}(
        period = metadata["period"],
        pixel_size = metadata["pixel size"],
        darkcounts = CuArray(darkcounts),
        cutoffs = (0, Inf),
        readouts = frames,
        batchsize = batchsize,
    )

    psf = CircularGaussian{FloatType}(
        numerical_aperture = metadata["numerical aperture"],
        refractive_index = metadata["refractive index"],
        emission_wavelength = metadata["wavelength"],
        pixel_size = metadata["pixel size"],
    )

    msd = MeanSquaredDisplacement{FloatType}(
        guess = 2 * 1 * metadata["period"] * batchsize,
        priorparams = (2, 1e-5),
    )

    brightness = Brightness{FloatType}(
        guess = 1.5e3 * metadata["period"],
        priorparams = (1, 1),
        proposalparams = (10, 1),
    )

    nframes = size(detector.readouts, 3)
    tracks = Tracks{FloatType}(
        guess = CuArray(bintracks(tracks_1bit, batchsize)),
        prior = DNormal{FloatType}(
            CuArray(collect(detector.framecenter)),
            CuArray{FloatType}([metadata["pixel size"] * 10, metadata["pixel size"] * 10]),
        ),
        max_ntracks = 5,
        scaling = √msd.value,
        logonprob = -10,
    )

    chain = runMCMC(
        tracks = tracks,
        msd = msd,
        brightness = brightness,
        detector = detector,
        psf = psf,
        niters = 1000 * 1024,
        sizelimit = 1001,
        parametric = true,
    )

    jldsave("./chain$(batchsize).jld2"; chain, tracks, msd, brightness, detector, psf)
end

cd("../../..")
