#!/usr/bin/env bash
set -euo pipefail

#-------------------- Simulation --------------------#
echo "Simulating data for Fig 2 new..."
### Simulate data for Fig 2
julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S5_S6/tomls/sim_params_Fig_2_newest_D0.1.toml
# julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S5_S6/tomls/sim_params_Fig_2_new_D1.0.toml
# julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S5_S6/tomls/sim_params_Fig_2_new_D10.0.toml

# echo "Fig 2 new inference and plotting..."
# ### Do inference for Fig 2
# julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S5_S6/tomls/inf_params_Fig_2_new_D10.0.toml
# julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S5_S6/tomls/inf_params_Fig_2_new_D1.0.toml
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S5_S6/tomls/inf_params_Fig_2_newest_D0.1.toml

### Fig 2
# julia --project=. ./Fig_2_S1_S5_S6/Fig_2_S1_script.jl Fig_2
