# LeWoS <br/> 
[![DOI](https://zenodo.org/badge/202789309.svg)](https://zenodo.org/badge/latestdoi/202789309) <br/> 
Tree leaf-wood classification from point cloud data <br/> 

# Usage<br/> 
There are many ways to use this tool.<br/> 
**(a) if you have Matlab installed:**<br/>
Option 1. Call the entry level funtion "RecursiveSegmentation_release.m".<br/> 
Option 2. Type "LeWoS_RS" in Matlab workspace. This will open up an interface by calling the classdef "LeWoS_RS.m". This classdef file defines the interface.<br/> 
Option 3. Drag "LeWoS.mlappinstall" into Matlab workspace. This will install a Matlab App for you. <br/> 
**(b) if you don't have Matlab installed, and don't want to install it:**<br/>
Run "LeWoS_installer.exe" for win64. If you need an excutable for other systems, please contact me.<br/> (PS: Matlab Runtime 2019b is required. You can either install it in advance or do it during the installation of LeWoS.)

*Note that if you load an ascii point cloud with the interface, only space delimiter is supported. (Recommend to use las files)

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

# Contact
Di Wang<br/> 
di.wang@aalto.fi
