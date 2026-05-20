#!/usr/bin/env bash
set -euo pipefail

echo "Making Fig 3..."
julia --project=. ./Fig_3/Fig_3_script.jl

echo "Making Fig 4..."
julia --project=. ./Fig_4/Fig_4_script.jl

echo "Making Fig 5..."
julia --project=. ./Fig_5/Fig_5_script.jl

echo "Making Fig 6..."
julia --project=. ./Fig_6/Fig_6_script.jl