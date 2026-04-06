#!/usr/bin/env bash
set -euo pipefail

### Do simulations and inference for Figures S3 and S4
julia --project=. ./simulation_with_toml.jl ./Fig_S3_S4/tomls/sim_params_no_blink.toml
julia --project=. ./simulation_with_toml.jl ./Fig_S3_S4/tomls/sim_params_blink_45perc.toml
julia --project=. ./simulation_with_toml.jl ./Fig_S3_S4/tomls/sim_params_blink_55perc.toml
julia --project=. ./simulation_with_toml.jl ./Fig_S3_S4/tomls/sim_params_blink_79perc.toml

### Make Fig S3
julia --project=. ./Fig_S3_S4/Fig_S3_script.jl ./Fig_S3_S4/tomls

### Do inference for Fig S4
julia --project=. ./inference_with_toml.jl ./Fig_S3_S4/tomls/inference_params_no_blink.toml
julia --project=. ./inference_with_toml.jl ./Fig_S3_S4/tomls/inference_params_45perc.toml
julia --project=. ./inference_with_toml.jl ./Fig_S3_S4/tomls/inference_params_55perc.toml
julia --project=. ./inference_with_toml.jl ./Fig_S3_S4/tomls/inference_params_79perc.toml

### Make Fig S4
julia --project=. ./Fig_S3_S4/Fig_S4_script.jl ./Fig_S3_S4/tomls
