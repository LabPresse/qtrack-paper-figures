using JLD2
using CairoMakie
using SP2T
using Statistics
using Colors
using SP2TExtra
# using XMLDict

include(joinpath(@__DIR__, "..", "utils.jl"))
if length(ARGS) >= 1
    if ARGS[1] == "precomputed"
        inf_dir_name = "precomputed_inference_results"
    elseif ARGS[1] == "test"
        inf_dir_name = "test_inference_results"
    else
        inf_dir_name = "inference_results"
    end
else
    inf_dir_name = "inference_results"
end

const SCRIPT_DIR = @__DIR__
const INF_DIR = joinpath(SCRIPT_DIR, inf_dir_name, "inf_beads")

function rgb_confidence_image(c1, c2, c3; scale)
    img = Matrix{RGBA{Float32}}(undef, size(c1)...)

    @inbounds for j in axes(c1, 2), i in axes(c1, 1)
        r = c1[i, j] / scale
        g = c2[i, j] / scale
        b = c3[i, j] / scale
        img[i, j] = RGBA(clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1), 1.0)
    end

    return img
end

# _xmlnodes(x) = x isa AbstractVector ? x : [x]

# function xml2spots(xmlfile::AbstractString)
#     txt = read(xmlfile, String)
#     i = findfirst(==('<'), txt)
#     i === nothing && error("No XML content found")

#     x = parse_xml(txt[i:end])

#     # XMLDict uses string keys for child elements and symbol keys for attributes.
#     sf = _xmlnodes(x["Model"]["AllSpots"]["SpotsInFrame"])

#     sf = sort(sf; by = s -> parse(Int, s[:frame]))

#     return [
#         [
#             (parse(Float64, spot[:POSITION_X]),
#              parse(Float64, spot[:POSITION_Y]))
#             for spot in _xmlnodes(s["Spot"])
#         ]
#         for s in sf
#     ]
# end

function make_fig()
    ############################## SETUP AND LOAD DATA ##############################
    chain = load(joinpath(INF_DIR, "chain_15.jld2"), "chain")
    track = chain.samples[end].tracks
    frames = load(joinpath(SCRIPT_DIR, "frames.jld2"), "frames")

    # spots_by_frame = xml2spots(joinpath(SCRIPT_DIR, "frames15_median.xml"))
    # median_frames, metadata = readtiff(joinpath(SCRIPT_DIR, "frames15_median.tif"))

    batchsize = 15
    frames15 = binframes(frames, batchsize)

    period = 20e-6
    pixel_size = 0.1
    burn_in = 750
    detector_size = 55
    dt = period * batchsize
    n_frames = 750
    t = 0:dt:(n_frames - 1) * dt
    # frame_idxs = [1, 200, 400, 600]
    frame_idxs = [5, 270, 365, 730] #1, 273, 34, 24, 41, 44, 750, 5, 223, 365, 583, 288, 271, 730
    edges = range(-0.18, 0.18, length=400)
    max_photon_count = 8
    colors = [:red, :lime, :blue]
    # arrow_offset = 0.35
    xshift = 0.025
    yshift = 0.045

    mean_track = zeros(n_frames, 2, 3) # frames x (x,y) x particles
    for i in burn_in:length(chain.samples)
        mean_track .+= chain.samples[i].tracks
    end
    mean_track ./= (length(chain.samples) - burn_in + 1);

    crediblex1, credibley1 = @views credible1D(chain.samples[burn_in + 1:end], 1, edges, edges, factor=1, xshift=-mean(mean_track[:, 1, 1]) + xshift, yshift=-mean(mean_track[:, 2, 1]) + yshift)
    crediblex2, credibley2 = @views credible1D(chain.samples[burn_in + 1:end], 2, edges, edges, factor=1, xshift=-mean(mean_track[:, 1, 2]) + xshift, yshift=-mean(mean_track[:, 2, 2]) + yshift)
    crediblex3, credibley3 = @views credible1D(chain.samples[burn_in + 1:end], 3, edges, edges, factor=1, xshift=-mean(mean_track[:, 1, 3]) + xshift, yshift=-mean(mean_track[:, 2, 3]) + yshift)

    vel_mean_x = zeros(n_frames - 1, 3)
    vel_mean_y = zeros(n_frames - 1, 3)

    for j in burn_in:length(chain.samples)
        track_j = chain.samples[j].tracks
        for idx in 1:3
            displacements = diff(track_j[:, :, idx], dims=1)
            vel_mean_x[:, idx] .+= displacements[:, 1] ./ dt
            vel_mean_y[:, idx] .+= displacements[:, 2] ./ dt
        end
    end

    vel_mean_x ./= (length(chain.samples) - burn_in + 1)
    vel_mean_y ./= (length(chain.samples) - burn_in + 1)

    x = (0:detector_size - 1) .* pixel_size .+ pixel_size / 2
    y = (0:detector_size - 1) .* pixel_size .+ pixel_size / 2

    scale = maximum((
        maximum(crediblex1), maximum(crediblex2), maximum(crediblex3),
        maximum(credibley1), maximum(credibley2), maximum(credibley3),
    ))
    scale = scale == 0 ? 1.0 : scale

    ############################## MAKE FIGURE ##############################
    inch = 96
    pt = 4 / 3

    fig = Figure(size = (12inch, 8inch), fontsize = 14pt, font = "Arial")
    # fig = Figure(size = (1100, 700), colgap = 0, rowgap = 0)
    # fig = Figure(size = (1100, 940), colgap = 0, rowgap = 0)

    ############################## SUBPANEL A: HEATMAPS WITH TRACKS ##############################
    hm_axes = [Axis(fig[1, i], aspect = DataAspect()) for i in 1:4]
    hm = nothing
    for (i, frame_idx) in enumerate(frame_idxs)
        hm = heatmap!(hm_axes[i], x, y, frames15[:, :, frame_idx],
                      colormap = :grays, colorrange = (0, max_photon_count))
    end

    for (i, frame_idx) in enumerate(frame_idxs)
        for j in 1:3
            arc!(hm_axes[i], Point2f(track[frame_idx, 1, j], track[frame_idx, 2, j]), 0.185, -π, π, color = colors[j], alpha=0.6, linewidth=3)
            # scatter!(hm_axes[i],
            #          track[frame_idx, 1, j],
            #          track[frame_idx, 2, j] - arrow_offset,
            #          marker = :utriangle,
            #          markersize = 15,
            #          color = colors[j])
        end
    end

    scalebar_length = 1.0
    scalebar_start_x = 0.2
    scalebar_start_y = 0.2
    lines!(hm_axes[1],
           [scalebar_start_x, scalebar_start_x + scalebar_length],
           [scalebar_start_y, scalebar_start_y],
           color = :white, linewidth = 4)
    text!(hm_axes[1],
          scalebar_start_x + scalebar_length / 2,
          scalebar_start_y + 0.08,
          text = "1 μm",
          align = (:center, :bottom),
          color = :white)

    for ax in hm_axes
        hidespines!(ax)
        hidedecorations!(ax)
    end

    Colorbar(fig[1, 5], hm, label = "# of photons")

    ############################### SUBPANELS B AND C: MAP ESTIMATE WITH CREDIBLE INTERVALS ##############################
    ax_x_pos = Axis(fig[2, 1:2], title = "x-trajectory",
                    backgroundcolor = :black, ylabel = "Position (μm)")
    ax_y_pos = Axis(fig[2, 3:4], title = "y-trajectory",
                    backgroundcolor = :black)
    hideydecorations!(ax_y_pos)
    hidexdecorations!(ax_y_pos)
    hidexdecorations!(ax_x_pos)

    img_x = rgb_confidence_image(crediblex1, crediblex2, crediblex3; scale = scale)
    img_y = rgb_confidence_image(credibley1, credibley2, credibley3; scale = scale)

    image!(ax_x_pos, t[1] .. t[end], edges[1] .. edges[end], img_x)
    image!(ax_y_pos, t[1] .. t[end], edges[1] .. edges[end], img_y)

    # hlines!(ax_x_pos, 0, color = :white, linestyle = :dash)
    # hlines!(ax_y_pos, 0, color = :white, linestyle = :dash)

    xlims!(ax_x_pos, t[1], t[end])
    xlims!(ax_y_pos, t[1], t[end])
    ylims!(ax_x_pos, edges[1], edges[end])
    ylims!(ax_y_pos, edges[1], edges[end])

    ############################### SUBPANELS D AND E: VELOCITY ESTIMATES ##############################
    ax_x_vel = Axis(fig[3, 1:2], ylabel = "Velocity (μm/s)", xlabel = "Time (s)")
    ax_y_vel = Axis(fig[3, 3:4], xlabel = "Time (s)")
    # println("x-max velocity: ", maximum(abs.(vel_mean_x)))
    # println("y-max velocity: ", maximum(abs.(vel_mean_y)))

    for j in 1:3
        lines!(ax_x_vel, t[1:end-1], vel_mean_x[:, j], color = colors[j])
        lines!(ax_y_vel, t[1:end-1], vel_mean_y[:, j], color = colors[j])
    end

    # vlines!(ax_x_pos, 0.1355, color = :red, linestyle = :dash)
    # vlines!(ax_x_pos, 0.1475, color = :red, linestyle = :dash)
    # vlines!(ax_x_vel, 0.1355, color = :red, linestyle = :dash)
    # vlines!(ax_x_vel, 0.1475, color = :red, linestyle = :dash)

    # vlines!(ax_y_pos, 0.018, color = :red, linestyle = :dash)
    # vlines!(ax_y_pos, 0.038, color = :red, linestyle = :dash)
    # vlines!(ax_y_vel, 0.018, color = :red, linestyle = :dash)
    # vlines!(ax_y_vel, 0.038, color = :red, linestyle = :dash)

    xlims!(ax_x_vel, t[1], t[end])
    xlims!(ax_y_vel, t[1], t[end])
    ylims!(ax_x_vel, -22, 22)
    ylims!(ax_y_vel, -22, 22)
    hideydecorations!(ax_y_vel, grid = false)

    # ###################################### Row 4 ################################
    # hm_axes_row4 = [Axis(fig[4, i], aspect = DataAspect()) for i in 1:4]
    # hm = nothing
    # for (i, frame_idx) in enumerate(frame_idxs)
    #     hm = heatmap!(hm_axes_row4[i], x, y, median_frames[:, :, frame_idx],
    #                   colormap = :grays, colorrange = (0, 2))
    # end

    # colors_trackmate = [[1, 2, 3], [1, 2, 3], [1, 1, 2, 2, 3], [1, 2]]
    # for (i, frame_idx) in enumerate(frame_idxs)
    #     n_spots = length(spots_by_frame[frame_idx])
    #     println("$n_spots at frame $frame_idx")
    #     for j in 1:n_spots
    #         color_idx = colors_trackmate[i][j]
    #         arc!(hm_axes_row4[i], Point2f(spots_by_frame[frame_idx][j][2], spots_by_frame[frame_idx][j][1]), 
    #             0.3/sqrt(2), -π, π, color=colors[color_idx], alpha=0.6, linewidth=3, linestyle=(:dot, :dense))
    #     end
    #     # for j in 1:3
    #     #     arc!(hm_axes_row4[i], Point2f(track[frame_idx, 1, j], track[frame_idx, 2, j]), 0.185, -π, π, color = colors[j])
    #     # end
    # end

    # lines!(hm_axes_row4[1],
    #        [scalebar_start_x, scalebar_start_x + scalebar_length],
    #        [scalebar_start_y, scalebar_start_y],
    #        color = :white, linewidth = 4)
    # text!(hm_axes_row4[1],
    #       scalebar_start_x + scalebar_length / 2,
    #       scalebar_start_y + 0.08,
    #       text = "1 μm",
    #       align = (:center, :bottom),
    #       color = :white)

    # for ax in hm_axes_row4
    #     hidespines!(ax)
    #     hidedecorations!(ax)
    # end

    # Colorbar(fig[4, 5], hm, label = "# of photons", ticks=[0,1,2])

    ###################################### ADJUST LAYOUT ################################
    rowsize!(fig.layout, 1, Fixed(220))
    rowsize!(fig.layout, 2, Fixed(150))
    rowsize!(fig.layout, 3, Fixed(150))
    # rowsize!(fig.layout, 4, Fixed(220))


    # for (label, layout) in zip(["a", "b", "c", "d", "e", "f"], [fig[1, :], fig[2, 1:2], fig[2, 3:4], fig[3, 1:2], fig[3, 3:4], fig[4, :]])
    for (label, layout) in zip(["a", "b", "c", "d", "e"], [fig[1, :], fig[2, 1:2], fig[2, 3:4], fig[3, 1:2], fig[3, 3:4]])
        Label(layout[1, 1, TopLeft()],
              label,
              fontsize = 16pt,
              font = "Arial Bold",
              halign = :right)
    end
    return fig
end

function main()
    fig = make_fig()
    save(joinpath(@__DIR__, "..", "figures", "Fig_3.pdf"), fig)
    # display(fig)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end