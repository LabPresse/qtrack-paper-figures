#!/usr/bin/env bash
set -euo pipefail

### Fig S2
julia --project=. ./simulation_with_toml.jl ./Fig_S2/sim_params_emccd.toml

julia --project=. ./Fig_S2/Fig_S2_script.jl ./Fig_S2