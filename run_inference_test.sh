#!/usr/bin/env bash
set -euo pipefail

# To do full inference, remove the "test" command line argument from these Julia script calls

echo "Inference for Fig 2, Fig S1, and Fig S8 (experimental data)..."
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_exp.toml test

echo "Inference for Fig 2 and S2 and S7..."
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_2_D10.0.toml test
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_2_D1.0.toml test
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_2_D0.1.toml test
# Full inference takes ~13 hours for these three cases combined

echo "Inference for Fig S1 (and S2) inference and plotting..."
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_S1_D10.0.toml test
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_S1_D1.0.toml test
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_S1_D0.1.toml test
# Full inference takes ~13 hours for these three cases combined

echo "Inference for Fig S2..."
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_S2_D0.1.toml test

echo "Inference for Fig 3 (experimental data)..."
julia --project=. ./Fig_3/inference_for_beads.jl ./Fig_3/inf_params_exp.toml test

echo "Inference for Fig S5..."
julia --project=. ./inference_with_toml.jl ./Fig_S4_S5/tomls/inference_params_no_blink.toml test
julia --project=. ./inference_with_toml.jl ./Fig_S4_S5/tomls/inference_params_45perc.toml test
julia --project=. ./inference_with_toml.jl ./Fig_S4_S5/tomls/inference_params_55perc.toml test
julia --project=. ./inference_with_toml.jl ./Fig_S4_S5/tomls/inference_params_79perc.toml test
