[![DOI](https://zenodo.org/badge/133016249.svg)](https://zenodo.org/badge/latestdoi/133016249)

# Procedural Terrain Generator - NetLogo
Procedural generation of maps (terrain, climate, biomes) using [NetLogo](https://ccl.northwestern.edu/netlogo/).
<PENDING TO DEVELOP INFO>

## Terrain

**terrainGenerator_v01_simple** 

The initial, quite simple approach. First, randomly assign patches to be land or water, according to `landPercentage`. Then, repeat a procedure of aggregation of land (`land = 1`) and sea (`land = -1`) patches according to `continentality`. Set elevation using 'land' and normal noise (`meanElevation`, `sdElevation`) limited by `minElevation` and `maxElevation`. Last, smooth patch elevations according to `elevationSmoothStep`.

![terrain01](screenshots/terrainGenerator_v01_simple_interface.png?raw=true "terrain v0")

**terrainGenerator_v1_twoAlgorithms**

This version presents two cleaner and more complete algorithms. NetLogo-style uses patch and turtle calls while C#-style is my attempt of a more lower-level object-based language). I refer to C# because I was actually prototyping these algorithms to use them in [Unity](https://unity3d.com).

![terrain02](screenshots/terrainGenerator_v1_twoAlgorithms_interface.png?raw=true "terrain v1")

**terrainGenerator_v2_withFlows**

This version creates a network of water flows over the terrain generated by v1 algorithms and derives the soil moisture of patches from the amount of water from streams/rivers and areas below sea level. 

After the base terrain is generated, the procedure `set-valleySlope` forces the terrain to become a valley, if `par_valleySlope > 0`, which will generally have a N-S orientation (`par_valleyAxisInclination` > 0 will lean this valley towards the NE-SW diagonal). If `par_valleySlope < 0`, the terrain will be forced into a ridge instead. 

The lower patch at either the North or South edges (whichever has the highest average elevation) is selected as the patch with an entering river. This patch is assign a inward `flowDirection` and given a `flowAccumulation` value of `par_riverFlowAccumulationAtStart`.

In the next step, the so-called 'sinks' or depressions are filled following an algorithm based on:

>Huang P C and Lee K T (2015) A simple depression-filling method for raster and irregular elevation datasets, J. Earth Syst. Sci. 124 1653–65.

The `fill-sinks` procedure is optional and, if not applied, the terrain may have multiple closed basins.

Every patch is then assigned a `flowDirection` pointing towards the neighboring patch with the largest drop (least elevation accounting for horizontal distance). 

A unit of `flowAccumulation` is assigned to every patch not receiving a flow (ridges) and passed downwards until the edge of the map. The algorithms in charge of calculating flow directions and accumulation are based on: 

>Jenson, S. K., & Domingue, J. O. (1988). Extracting topographic structure from digital elevation data for geographic information system analysis. Photogrammetric engineering and remote sensing, 54(11), 1593-1600.

Each patch `flowAccumulation` is converted into units of `water` while patches below sea level have `water` units proportional to their depth. The amount of `water` of patches is converted to units of `moisture` and then moisture is distributed to other 'dry' patches using NetLogo's primitive `diffuse` (NOTE: not ideal because it does not account for the difference in elevation nor soil type). 

![terrain02](screenshots/terrainGenerator_v2_withFlows_interface.png?raw=true "terrain v2")

![terrain02|20%](screenshots/terrainGenerator_v2_withFlows_view1.png?raw=true&v=4&s=200 "terrain v2-only terrain")
![terrain02](screenshots/terrainGenerator_v2_withFlows_view2.png?raw=true "terrain v2-terrain with flows")
![terrain02](screenshots/terrainGenerator_v2_withFlows_view3.png?raw=true "terrain v2-soil moisture")

## Climate
**terrainGenerator-withClimate_v01**

Using the C#-style terrain, this is an initial approach to defining patch temperatures and wind directions to be integrated into a climate simulation. Temperature is dependent only on latitude, elevation, and slope (both elevation and slope are average values for a given patch). Wind direction is dependent on latitude (latitude regions are defined according to Coriolis effect). Still no atmoshperic dynamics in this version.

![climate01](screenshots/terrainGenerator-withClimate_v01_interface.png?raw=true "climate v0")
