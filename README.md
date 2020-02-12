# LeWoS <br/> 
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3516856.svg)](https://doi.org/10.5281/zenodo.3516856) <br/>

Unsupervised tree leaf-wood classification from point cloud data <br/> 

# Usage<br/> 
There are many ways to use this tool.<br/> 

**(a) if you have Matlab installed:**<br/>
Option 1. Call the entry level funtion "RecursiveSegmentation_release.m" as:<br/> 
“[BiLabel, BiLabel_Regu] = RecursiveSegmentation_release(points, ft_threshold, paral, plot);”<br/> 
Inputs:<br/> 
% points: this is your nx3 data matrix.<br/> 
% ft_threshold: feature threshold. suggest using 0.125 or so <br/> 
% paral: if shut down parallel pool after segmentation (1 or other). <br/> 
% plot: if plot results in the end (1 or other)<br/> 
Outputs:<br/> 
% BiLabel: point label without regularization<br/> 
% BiLabel_Regu: point label with regularization<br/> 

Option 2. Type "LeWoS_RS" in Matlab workspace. This will open up an interface by calling the classdef "LeWoS_RS.m". This classdef file defines the interface.<br/> 

Option 3. Drag "LeWoS.mlappinstall" into Matlab workspace. This will install a Matlab App for you. <br/> 

**(b) if you don't have Matlab installed, and don't want to install it:**<br/>
Run "LeWoS_installer.exe" for win64. If you need an excutable for other systems (Linux and Mac), please contact me.<br/> (PS: Matlab Runtime 2019b (freely available at https://se.mathworks.com/products/compiler/matlab-runtime.html) is required. You can either install it in advance or do it during the installation of LeWoS.)

--------------------------<br/>
*Note that if you load an ascii point cloud with the interface, only space delimiter is supported (without header). Currently, these formats are supported: .las; .laz; .mat; .xyz; .txt; .ply; .pcd (recommend to use more generic formats for point clouds, such as las, ply, and pcd) <br/> 
*This method does not implement any post-processing filters. Users can design and apply post-processing steps to [potentially] further improve the results.

# Examples
![example 1](plot.png)
Plot-level separation<br/>
![example 2](crown.png)
Inside a crown
![example 3](e3.png)
Very thin branches are difficult to detect

# Acknowledgement
This repo contains code from Loic Landrieu's repo on point-cloud-regularization (https://github.com/loicland/point-cloud-regularization), and Inverse Tampere's repo on TreeQSM (https://github.com/InverseTampere/TreeQSM).

# Bibtex
@article{xxx,<br/>
author = {Wang, Di and Momo Takoudjou, Stéphane and Casella, Eric},<br/>
title = {LeWoS: A Universal Leaf-wood Classification Method to Facilitate the 3D Modelling of Large Tropical Trees Using Terrestrial LiDAR},<br/>
journal = {Methods in Ecology and Evolution},<br/>
volume = {n/a},<br/>
number = {n/a},<br/>
pages = {},<br/>
doi = {10.1111/2041-210X.13342},<br/>
url = { https://besjournals.onlinelibrary.wiley.com/doi/abs/10.1111/2041-210X.13342 }<br/>
}<br/>
(Current code is a slightly updated version of the one used in publication. With current one, the results are further improved a bit. e.g., 0.925 ± 0.035 vs 0.91 ± 0.03 in the paper.)

# Contact
Di Wang<br/> 
di.wang@aalto.fi
