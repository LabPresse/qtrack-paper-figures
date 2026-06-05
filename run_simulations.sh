#!/usr/bin/env bash
set -euo pipefail

echo "Simulating data for Fig 2, S1, S2, and S7..."
### Simulate data for Fig 2 (and S2 and S7)
julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/sim_params_Fig_2_D0.1.toml
julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/sim_params_Fig_2_D1.0.toml
julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/sim_params_Fig_2_D10.0.toml

### Simulate data for Fig S1 (and S2)
julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/sim_params_Fig_S1_D0.1.toml
julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/sim_params_Fig_S1_D1.0.toml
julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/sim_params_Fig_S1_D10.0.toml

### Simulate data for Fig S2
julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/sim_params_Fig_S2_D0.1.toml

echo "Simulating data for Fig S3..."
julia --project=. ./simulation_with_toml.jl ./Fig_S3/sim_params_emccd.toml

echo "Simulating data for Fig S4 and S5..."
julia --project=. ./simulation_with_toml.jl ./Fig_S4_S5/tomls/sim_params_no_blink.toml
julia --project=. ./simulation_with_toml.jl ./Fig_S4_S5/tomls/sim_params_blink_45perc.toml
julia --project=. ./simulation_with_toml.jl ./Fig_S4_S5/tomls/sim_params_blink_55perc.toml
julia --project=. ./simulation_with_toml.jl ./Fig_S4_S5/tomls/sim_params_blink_79perc.toml
