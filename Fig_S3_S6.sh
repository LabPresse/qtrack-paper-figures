#!/usr/bin/env bash
set -euo pipefail

### Fig S3
echo "Making Fig S3..."
julia --project=. ./simulation_with_toml.jl ./Fig_S3/sim_params_emccd.toml

julia --project=. ./Fig_S3/Fig_S3_script.jl ./Fig_S3

### Fig S6
echo "Making Fig S6..."
julia --project=. ./Fig_S6/Fig_S6_script.jl