#!/usr/bin/env bash
set -euo pipefail

#-------------------- Simulation --------------------#
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

#-------------------- Inference & Plotting --------------------#
echo "Fig S8 (experimental data) inference and plotting..."
### Experimental inference 
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_exp.toml

### Fig S8
julia --project=. ./Fig_2_S1_S2_S7_S8/Fig_S8_script.jl ./Fig_2_S1_S2_S7_S8/tomls 

echo "Fig 2 inference and plotting..."
### Do inference for Fig 2 (and S2 and S7)
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_2_D10.0.toml
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_2_D1.0.toml
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_2_D0.1.toml

### Fig 2
julia --project=. ./Fig_2_S1_S2_S7_S8/Fig_2_S1_script.jl Fig_2

echo "Fig S1 inference and plotting..."
### Do inference for Fig S1 (and S2)
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_S1_D10.0.toml
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_S1_D1.0.toml
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_S1_D0.1.toml

### Fig S1
julia --project=. ./Fig_2_S1_S2_S7_S8/Fig_2_S1_script.jl Fig_S1

### Fig S7
julia --project=. ./Fig_2_S1_S2_S7_S8/Fig_S7_script.jl 

echo "Fig S2 inference and plotting..."
### Do inference for Fig S2
julia --project=. ./inference_with_toml.jl ./Fig_2_S1_S2_S7_S8/tomls/inf_params_Fig_S2_D0.1.toml

### Fig S2
julia --project=. ./Fig_2_S1_S2_S7_S8/Fig_S2_script.jl