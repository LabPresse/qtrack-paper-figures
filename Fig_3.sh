#!/usr/bin/env bash
set -euo pipefail

### Fig 3
echo "Making Fig 3..."
julia --project=. ./Fig_3/inference_for_beads.jl ./Fig_3/inf_params_exp.toml

julia --project=. ./Fig_3/Fig_3_script.jl
