using SP2T
using Random
using JLD2

dir = "./benchmarks/framesize"

Random.seed!(9)
FloatType = Float64

metadata = Dict{String,Any}(
    "units" => ("μm", "s"),
    "numerical aperture" => 1.45,
    "refractive index" => 1.515,
    "wavelength" => 0.665,
    "period" => 3.3e-2,
    "pixel size" => 0.133,
    "description" => "example run",
)

psf = CircularGaussian{FloatType}(
    numerical_aperture = metadata["numerical aperture"],
    refractive_index = metadata["refractive index"],
    emission_wavelength = metadata["wavelength"],
    pixel_size = metadata["pixel size"],
)

detector = []
for framesize in [16, 32, 64, 128, 256, 512, 1024]
    detector = EMCCD{FloatType}(
        period = metadata["period"],
        pixel_size = metadata["pixel size"],
        darkcounts = zeros(framesize, framesize),
        cutoffs = (0, Inf),
        readouts = zeros(UInt16, framesize, framesize, 100),
        offset = 100,
        gain = 100,
        variance = 2,
    )

    msd = 2 * 0.05 * metadata["period"]
    ntracks = 2
    tracks = simulate!(
        Array{FloatType}(undef, 100, 2, ntracks),
        metadata["pixel size"] ./ 2 .* collect(size(detector)),
        [0.3, 0.3],
        msd,
    )
    tracks[:, 1, :] .-= 0.3
    tracks[:, 2, :] .-= 0.1
    brightness = 20 * metadata["period"]
    SP2T.simulate_readouts!(
        detector,
        SP2T.getincident(tracks, brightness, detector.darkcounts, detector.pxbounds, psf),
    )

    jldsave(joinpath(dir, "frames_$framesize.jld2"); frames = detector.readouts)
    jldsave(
        joinpath(dir, "groundtruth_$framesize.jld2");
        tracks = tracks,
        msd = msd,
        brightness = brightness,
    )
end
jldsave(joinpath(dir, "metadata.jld2"); metadata = metadata)