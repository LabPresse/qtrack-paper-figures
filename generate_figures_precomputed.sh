#!/usr/bin/env bash
set -euo pipefail

# #-------------------- Main Figures --------------------#
# echo "Figure 2..."
# julia --project=. ./Fig_2_S1_S2_S7_S8/Fig_2_S1_script.jl Fig_2 precomputed

# echo "Figure 3..."
# julia --project=. ./Fig_3/Fig_3_script.jl precomputed

# echo "Figure 4..."
# julia --project=. ./Fig_4/Fig_4_script.jl

# echo "Figure 5..."
# julia --project=. ./Fig_5/Fig_5_script.jl

# echo "Figure 6..."
# julia --project=. ./Fig_6/Fig_6_script.jl

# echo "Figure 7..."
# julia --project=. ./Fig_7/Fig_7_script.jl

# #-------------------- SI Figures --------------------#
# echo "Figure S1..."
# julia --project=. ./Fig_2_S1_S2_S7_S8/Fig_2_S1_script.jl Fig_S1 precomputed

# echo "Figure S2..."
# julia --project=. ./Fig_2_S1_S2_S7_S8/Fig_S2_script.jl precomputed

echo "Figure S3..."
julia --project=. ./Fig_S3/Fig_S3_script.jl precomputed

echo "Figure S4..."
julia --project=. ./Fig_S4_S5/Fig_S4_script.jl precomputed

echo "Figure S5..."
julia --project=. ./Fig_S4_S5/Fig_S5_script.jl precomputed

# echo "Figure S7..."
# julia --project=. ./Fig_2_S1_S2_S7_S8/Fig_S7_script.jl precomputed

# echo "Figure S8..."
# julia --project=. ./Fig_2_S1_S2_S7_S8/Fig_S8_script.jl precomputed

# echo "Figure S6..."
# julia --project=. ./Fig_S6/Fig_S6_script.jl
