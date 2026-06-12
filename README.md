# Data and source code for figure generation in the QTrack manuscript

This directory contains the data, analysis scripts, and figure-generation code associated with the QTrack manuscript. It is intended to provide a clean, reproducible, and accessible set of materials for regenerating the figures presented in the paper.

The source code for QTrack is available on Github at <https://github.com/LabPresse/SP2T.jl>, and on Zenodo at <10.5281/zenodo.20656382>.

## Overview

This repository contains the code and data required to regenerate the figures for which reproducible materials are provided here. These can be primarily run from shell scrips in the main directory, or you can run individual lines from these scripts which will produce individual figures or results. All figures produced will be saved to  a `figures/` directory. 

Because some figures are substantially more computing time (including Fig. 2 and related figures), the first shell script `generate_figures_precomputed.sh` uses previously calculated inference results and simulations to produce the paper figures. While not all precomputed results are available on the Github repository due to space constraints, the Zenodo repository should have all required results. The code to calculate the simulations and inference are provided however. The shell script `run_simulations.sh` will run all figure simulations. The shell script `run_inference_test.sh` contains example code for running inference results, with a "test" flag activated so each case only runs for 1000 iterations, to allow you to test your environment and ability to run all inference cases. If you want to run results fully from scratch, you can use the julia script calls in this shell script without the "test" flag for the cases you wish to reproduce. 

The simulation scripts were written using fixed random-number seeds, and should reproduce trajectories exactly. Inference scripts are not necessarily run with a fixed seed, but should produce qualitatively very similar results. The simulation and inference scripts for Figures 4 through 7 are not included in these shell scripts; refer to the individual inference and simulation scripts within those directories. Unless otherwise noted, the naming conventions used in this repository are as follows:

- `simulation.jl` generates synthetic data;
- `inference_cpu.jl` performs inference on the CPU;
- `inference_gpu.jl` performs inference on the GPU;
- `simulation_from_toml.jl` runs simulation based on parameters specified in a toml file (main directory);
- `inference_from_toml.jl` runs inference based on parameters from a toml file (main directory);
- `Fig_x_script.jl` generates the corresponding figure.

A working Julia environment is provided through `Project.toml` and `Manifest.toml`. This environment specifies `CUDA.jl` version `5.9.6`. Although this exact version is not strictly required in every setup, it is the version used and tested for the present repository.

## Figure guide

### Figure 1

**Figure 1** is a conceptual figure. For this reason, only the complete SVG file is provided here. Code used to generate individual components of the figure can be made available upon reasonable request.

### Figure 2, Figure S1, Figure S2, Figure S6, Figure S7, and Figure S8

These figures are grouped together because they rely on related simulations and inference procedures.

- **Figure 2** presents the main benchmark results in the manuscript.
- **Figure S1** provides a complementary robustness analysis based on an alternative parameter setting related to Fig. 2.
- **Figure S2** provides a closer look at the "plateau" behavior observed for the localization error in Fig. 2, discussing the factors that affect the plateau value.
- **Figure S6** shows how time averaging Brownian trajectories (as with motion blur in longer exposures) can yield apparent diffusion coefficients that underestimate the ensemble diffusion coefficient.
- **Figure S7** shows diffusion-coefficient posteriors together with ensemble diffusion coefficients and apparent diffusion coefficients across exposure times, providing an additional robustness check.
- **Figure S7** validates the experimental diffusion-coefficient posterior by showing consistency between inference performed with batch size 1 and batch size 2.

Because inference for these figures (except for Fig. S6) can be time-consuming, users may wish to generate figures from precomputed results.

### Figure 3 and S9

- **Figure 3** analyzes experimental data of fluorescent beads fixed to a piezo stage with low photon counts as a way to validate trajectory inference by comparing multiple bead trajectories. 
- **Figure S9** provides a comparison to Trackmate, showing the advantage gained by QTrack in the low-photon regime.

### Figures 4–7

Simulation, inference, and plotting scripts for **Figures 4-7** are provided in their corresponding folders.

### Figure S2

**Figure S3** illustrates how motion blur arises as exposure time increases.

### Figure S4 and Figure S5

- **Figure S3** shows three realizations of the same baseline Brownian trajectory, each paired with a different ON/OFF state trace.
- **Figure S4** shows the localization error for blinking and non-blinking trajectories in the corresponding three cases.

## Notes

- The shell scripts in the main directory are intended to automate the workflow from simulation and inference to plotting.
- Runtime varies substantially across figures, especially for those involving large-scale inference.
- The included Julia environment is provided to maximize reproducibility.
- As the QTrack API may evolve over time, some scripts in this repository may require minor updates to remain compatible with the latest version. If you encounter such an issue, please feel free to contact us.
