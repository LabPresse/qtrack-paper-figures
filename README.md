All figure code contained here was developed separately (in a much messier way), but here contains cleaned up scripts to generate all figures.  The goal is that someone can, with the contents of this subfolder, generate every figure (that was added by Jay). This includes all SI figures S1-S6 and Fig 2. By running the three BASH files in the main directory, all simulations and inference will be performed and then plots made and placed in a "figures" directory. The inference results for Fig 2, S2, and S5 take a particularly long time, the rest can be run fairly quickly.

Also included is a functioning Julia environment with Project.toml and Manifest.toml. This specifies a specific version of CUDA.jl, 5.9.6, which is not strictly necessary, but it is what works for my setup.

## Fig S2
Fig S2 is demonstrating how motion blur arises with longer exposures. You can run `Fig_S2.sh` in the main directory to completely generate the figure.

## Fig S3 and S4

Fig S3 shows 3 realizations of the same baseline Brownian trajectory with 3 different ON/OFF state traces. Fig S4 shows localization error for blinking vs non-blinking trajectory for the 3 different cases. You can run `Fig_S3_S4.sh` to generate these figures.

## Fig 2, S1, S5, and S6
For revisions, we had to rerun the original Fig 2 with new parameters. The (mostly) original Fig 2 is now Fig S1, as a robustness test of the results in the figure. Fig S5 is a figure showing the diffusion coefficient posteriors compared to the ensemble diffusion coefficient and apparent diffusion coefficients for each exposure time, to show robustness. Fig S6 validates the diffusion coefficient posterior for the experimental by showing consistency between batchsize 1 and 2. You can run `Fig_2_S1_S5_S6.sh` to get the figures. Feel free to comment out code related to figures you don't need to generate, as the inference does take a very long time. 

## Fig 3 and 4
Here I just provide the updated plotting scripts that work in context of Weiqing's original code he made for these figures.
