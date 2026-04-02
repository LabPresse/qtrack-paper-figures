#!/usr/bin/env bash
set -euo pipefail

#-------------------- Simulation --------------------#
echo "Simulating data for Fig 2, S1, S5, and S6..."
### Simulate data for Fig 2
# julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S5_S6/tomls/sim_params_Fig_2_D0.1.toml
# julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S5_S6/tomls/sim_params_Fig_2_D1.0.toml
# julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S5_S6/tomls/sim_params_Fig_2_D10.0.toml

### Simulate data for Fig S1 and S5
# julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S5_S6/tomls/sim_params_Fig_S1_S5_D0.1.toml
# julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S5_S6/tomls/sim_params_Fig_S1_S5_D1.0.toml
# julia --project=. ./simulation_with_toml.jl ./Fig_2_S1_S5_S6/tomls/sim_params_Fig_S1_S5_D10.0.toml

#-------------------- Inference & Plotting --------------------#
echo "Fig S6 (experimental data) inference and plotting..."
### Experimental inference 
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S5_S6/tomls/inf_params_exp.toml

### Fig S6
julia --project=. ./Fig_2_S1_S5_S6/Fig_S6_script.jl ./Fig_2_S1_S5_S6/tomls 

echo "Fig 2 inference and plotting..."
### Do inference for Fig 2
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S5_S6/tomls/inf_params_Fig_2_D10.0.toml
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S5_S6/tomls/inf_params_Fig_2_D1.0.toml
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S5_S6/tomls/inf_params_Fig_2_D0.1.toml

### Fig 2
julia --project=. ./Fig_2_S1_S5_S6/Fig_2_S1_script.jl Fig_2

echo "Fig S1 and S5 inference and plotting..."
### Do inference for Fig S1 and S5
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S5_S6/tomls/inf_params_Fig_S1_S5_D10.0.toml
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S5_S6/tomls/inf_params_Fig_S1_S5_D1.0.toml
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S5_S6/tomls/inf_params_Fig_S1_S5_D0.1.toml

### Fig S1
julia --project=. ./Fig_2_S1_S5_S6/Fig_2_S1_script.jl Fig_S1

### Fig S5
julia --project=. ./Fig_2_S1_S5_S6/Fig_S5_script.jl ./Fig_2_S1_S5_S6/tomls
