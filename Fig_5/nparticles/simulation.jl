using SP2T
using Random
using JLD2

dir = "./benchmarks/nparticles"

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

detector = EMCCD{FloatType}(
    period = metadata["period"],
    pixel_size = metadata["pixel size"],
    darkcounts = zeros(128, 128),
    cutoffs = (0, Inf),
    readouts = zeros(UInt16, 128, 128, 10),
    offset = 100,
    gain = 100,
    variance = 2,
)

msd = 2 * 0.1 * metadata["period"]
ntracks = 200
tracks = simulate!(
    Array{FloatType}(undef, 10, 2, ntracks),
    metadata["pixel size"] ./ 2 .* collect(size(detector)),
    [2.5, 2.5],
    msd,
)

brightness = 20 * metadata["period"]

for M in [1, 2, 5, 10, 20, 50, 100, 200]
    SP2T.simulate_readouts!(
        detector,
        SP2T.getincident(
            tracks[:, :, 1:M],
            brightness,
            detector.darkcounts,
            detector.pxbounds,
            psf,
        ),
    )
    jldsave(joinpath(dir, "frames_$M.jld2"); frames = detector.readouts)
end
jldsave(joinpath(dir, "metadata.jld2"); metadata = metadata)
jldsave(
    joinpath(dir, "groundtruth.jld2");
    tracks = tracks,
    msd = msd,
    brightness = brightness,
)