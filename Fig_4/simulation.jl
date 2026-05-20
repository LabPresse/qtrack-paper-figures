using SP2T
# using SP2TExtra
using Random
using JLD2

dir = "./examples/brightness"

Random.seed!(9)
FloatType = Float64

metadata = Dict{String,Any}(
    "units" => ("μm", "s"),
    "numerical aperture" => 1.45,
    "refractive index" => 1.515,
    "wavelength" => 0.665,
    "period" => 3.3e-2,
    "pixel size" => 0.133,
    "batchsize" => 1,
    "description" => "example run",
)

psf = CircularGaussian{FloatType}(
    numerical_aperture = metadata["numerical aperture"],
    refractive_index = metadata["refractive index"],
    emission_wavelength = metadata["wavelength"],
    pixel_size = metadata["pixel size"],
)

detector = SP2T.EMCCDGamma{FloatType}(
    period = metadata["period"],
    pixel_size = metadata["pixel size"],
    darkcounts = fill(1e5 * metadata["period"] * metadata["pixel size"]^2, 128, 128),
    cutoffs = (0, Inf),
    readouts = ones(UInt16, 128, 128, 10),
    gain = 0.3,
)

msd = 2 * 0.1 * metadata["period"]
ntracks = 10
tracks = simulate!(
    Array{FloatType}(undef, 10, 2, ntracks),
    metadata["pixel size"] ./ 2 .* collect(size(detector)),
    [3.0, 3.0],
    msd,
)

brightness = 1e4 * metadata["period"] * psf.A

for factor in [0.1, 0.2, 0.5, 1, 2, 5]
    SP2T.simulate_readouts!(
        detector,
        SP2T.getincident(
            tracks,
            brightness * factor,
            detector.darkcounts,
            detector.pxbounds,
            psf,
        ),
    )
    writetiff(
        joinpath(dir, "frames_$(factor).tiff"),
        detector.readouts;
        px_size = metadata["pixel size"],
        unit = metadata["units"][1],
        period = metadata["period"],
    )
    jldsave(joinpath(dir, "frames_$(factor).jld2"); frames = detector.readouts)
    # matwrite(joinpath(dir, "DCR_$(factor).mat"), Dict("frames" => detector.readouts))
end

jldsave(joinpath(dir, "metadata.jld2"); metadata = metadata)
# jldsave(joinpath("frames.jld2"); frames = detector.readouts)
jldsave(joinpath(dir, "groundtruth.jld2"); tracks = tracks, msd = msd)