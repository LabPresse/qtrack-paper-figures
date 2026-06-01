#!/usr/bin/env bash
set -euo pipefail

### Do simulations and inference for Figures S3 and S4
echo "Running simulations..."
julia --project=. ./simulation_with_toml.jl ./Fig_S4_S5/tomls/sim_params_no_blink.toml
julia --project=. ./simulation_with_toml.jl ./Fig_S4_S5/tomls/sim_params_blink_45perc.toml
julia --project=. ./simulation_with_toml.jl ./Fig_S4_S5/tomls/sim_params_blink_55perc.toml
julia --project=. ./simulation_with_toml.jl ./Fig_S4_S5/tomls/sim_params_blink_79perc.toml

### Make Fig S4
echo "Making Fig S4..."
julia --project=. ./Fig_S4_S5/Fig_S4_script.jl ./Fig_S4_S5/tomls

### Do inference for Fig S5
echo "Running inference..."
julia --project=. ./inference_with_toml.jl ./Fig_S4_S5/tomls/inference_params_no_blink.toml
julia --project=. ./inference_with_toml.jl ./Fig_S4_S5/tomls/inference_params_45perc.toml
julia --project=. ./inference_with_toml.jl ./Fig_S4_S5/tomls/inference_params_55perc.toml
julia --project=. ./inference_with_toml.jl ./Fig_S4_S5/tomls/inference_params_79perc.toml

### Make Fig S5
echo "Making Fig S5..."
julia --project=. ./Fig_S4_S5/Fig_S5_script.jl ./Fig_S4_S5/tomls
