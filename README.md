# ProceduralMap-NetLogo
Procedural generation of maps (terrain, climate, biomes) using [NetLogo](https://ccl.northwestern.edu/netlogo/).
<PENDING TO DEVELOP INFO>

## Terrain

**terrainAltitude_v0_simple**: the initial, quite simple approach.
![terrain01](screenshots/terrainAltitude_v0_simple_interface.png?raw=true "terrain v0")

**terrainAltitude_v1_twoAlgorithms**: this version presents two cleaner and more complete algorithms. NetLogo-style uses patch and turtle calls while C#-style is my attempt of a more lower-level object-based language). I refer to C# because I was actually prototyping these algorithms to use them in [Unity](https://unity3d.com).
![terrain02](screenshots/terrainAltitude_v1_twoAlgorithms_interface.png?raw=true "terrain v1")

## Climate
**terrainAltitudeAndClimate_v0**: using the C#-style terrain, this is an initial approach to defining patch temperatures and wind directions to be integrated into a climate simulation. Temperature is dependent only on latitude, altitude, and slope (both altitude and slope are average values for a given patch). Wind direction is dependent on latitude (latitude regions are defined according to Coriolis effect). Still no atmoshperic dynamics in this version.
![climate01](screenshots/terrainAltitudeAndClimate_v0_interface.png?raw=true "climate v0")
