;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GNU GENERAL PUBLIC LICENSE ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;  Terrain Generator model v.2
;;  Copyright (C) 2018 Andreas Angourakis (andros.spica@gmail.com)
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.
;;
;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.

breed [ transectLines transectLine ]
breed [ flowHolders flowHolder ]

globals
[
  patchArea
  maxDist

  ;;; parameters (copies) ===============================================================
  numContinents
  numOceans
  numRanges
  rangeLength
  numRifts
  riftLength
  seaLevel
  elevationSmoothStep
  smoothingNeighborhood

  xSlope
  ySlope

  flowWaterVolume

  moistureDiffusionSteps
  moistureTransferenceRate

  ;;; variables ===============================================================
  landOceanRatio
  elevationDistribution
  minElevation
  sdElevation
  maxElevation
]

patches-own
[
  elevation
  flowDirection
  receivesFlow flowAccumulationState
  flowAccumulation
  watershedID
  pourPointWithWatershed
  isLowestPourPoint
  ;downstreamPatch
  streamLevel
  water
  moisture
  tempMoisture
]

breed [ mapSetters mapSetter ]

mapSetters-own [ points ]

to setup

  clear-all

  set patchArea 10000 ; 10,000 m^2 = 1 hectare
  set maxDist (sqrt (( (max-pxcor - min-pxcor) ^ 2) + ((max-pycor - min-pycor) ^ 2)) / 2)

  set numContinents par_numContinents
  set numOceans par_numOceans

  set numRanges par_numRanges
  set rangeLength round ( par_rangeLength * maxDist)
  set maxElevation par_maxElevation
  set numRifts par_numRifts
  set riftLength round ( par_riftLength * maxDist)
  set minElevation par_minElevation

  set xSlope par_xSlope
  set ySlope par_ySlope

  set flowWaterVolume par_flowWaterVolume
  set moistureDiffusionSteps par_moistureDiffusionSteps
  set moistureTransferenceRate par_moistureTransferenceRate

  ;set continentality (par_continentality * (count patches / 2))

  set seaLevel par_seaLevel
  set elevationSmoothStep par_elevationSmoothStep
  set smoothingNeighborhood par_smoothingNeighborhood * maxDist

  random-seed randomSeed

  reset-timer

  ifelse (algorithm-style = "NetLogo")
  [
    set-landform-NetLogo
  ]
  [
    set-landform-Csharp
  ]

  print (word "set-landform computing time: " timer)

  reset-timer

  set-xySlopes

  print (word "set-xySlopes computing time: " timer)

  reset-timer

  fill-sinks

  print (word "fill-sinks computing time: " timer)

  reset-timer

  set-flow-accumulations

  print (word "set-flow-accumulations computing time: " timer)

  reset-timer

  diffuse-moisture

  print (word "diffuse-moisture computing time: " timer)

  set landOceanRatio count patches with [elevation > seaLevel] / count patches
  set elevationDistribution [elevation] of patches
  set minElevation min [elevation] of patches
  set maxElevation max [elevation] of patches
  set sdElevation standard-deviation [elevation] of patches

  paint-patches

  setup-patch-coordinates-labels "bottom" "left"

  setup-transect

  update-transects

  update-plots

end

to set-landform-NetLogo ;[ minElevation maxElevation numRanges rangeLength numRifts riftLength par_continentality smoothingNeighborhood elevationSmoothStep]

  ; Netlogo-like code
  ask n-of numRanges patches [ sprout-mapSetters 1 [ set points random rangeLength ] ]
  ask n-of numRifts patches with [any? turtles-here = false] [ sprout-mapSetters 1 [ set points (random riftLength) * -1 ] ]

  let steps sum [ abs points ] of mapSetters
  repeat steps
  [
    ask one-of mapSetters
    [
      let sign 1
      let scale maxElevation
      if ( points < 0 ) [ set sign -1 set scale minElevation ]
      ask patch-here [ set elevation scale ]
      set points points - sign
      if (points = 0) [die]
      rt (random-exponential par_featureAngleRange) * (1 - random-float 2)
      forward 1
    ]
  ]

  smooth-elevation-all

  let continentality par_continentality * count patches
  let underWaterPatches patches with [elevation < 0]
  let aboveWaterPatches patches with [elevation > 0]

  repeat continentality
  [
    if (any? underWaterPatches AND any? aboveWaterPatches)
    [
      let p_ocean max-one-of underWaterPatches [ count neighbors with [elevation > 0] ]
      let p_land  max-one-of aboveWaterPatches [ count neighbors with [elevation < 0] ]
      let temp [elevation] of p_ocean
      ask p_ocean [ set elevation [elevation] of p_land ]
      ask p_land [ set elevation temp ]
      set underWaterPatches underWaterPatches with [pxcor != [pxcor] of p_ocean AND pycor != [pycor] of p_ocean]
      set aboveWaterPatches aboveWaterPatches with [pxcor != [pxcor] of p_land AND pycor != [pycor] of p_land]
    ]
  ]

  smooth-elevation-all

end

to set-landform-Csharp ;[ minElevation maxElevation par_sdElevation numContinents numRanges rangeLength par_rangeAggregation numOceans numRifts riftLength par_riftAggregation smoothingNeighborhood elevationSmoothStep]

  ; C#-like code
  let p1 0
  let sign 0
  let len 0
  let elev 0

  let continents n-of numContinents patches
  let oceans n-of numOceans patches

  let maxDistBetweenRanges (1.1 - par_rangeAggregation) * maxDist
  let maxDistBetweenRifts (1.1 - par_riftAggregation) * maxDist

  repeat (numRanges + numRifts)
  [
    set sign -1 + 2 * (random 2)
    if (numRanges = 0) [ set sign -1 ]
    if (numRifts = 0) [ set sign 1 ]

    ifelse (sign = -1)
    [
      set numRifts numRifts - 1
      set len riftLength - 2
      set elev minElevation
      ;ifelse (any? patches with [elevation < 0]) [set p0 one-of patches with [elevation < 0]] [set p0 one-of patches]
      set p1 one-of patches with [ distance one-of oceans < maxDistBetweenRifts ]
    ]
    [
      set numRanges numRanges - 1
      set len rangeLength - 2
      set elev maxElevation
      set p1 one-of patches with [ distance one-of continents < maxDistBetweenRanges ]
    ]

    draw-elevation-pattern p1 len elev
  ]

  smooth-elevation-all

  ask patches with [elevation = 0]
  [
    set elevation random-normal 0 par_sdElevation
  ]

  smooth-elevation-all

end

to draw-elevation-pattern [ p1 len elev ]

  let p2 0
  let x-direction 0
  let y-direction 0
  let directionAngle 0

  ask p1 [ set elevation elev set p2 one-of neighbors ]
  set x-direction ([pxcor] of p2) - ([pxcor] of p1)
  set y-direction ([pycor] of p2) - ([pycor] of p1)
  ifelse (x-direction = 1 AND y-direction = 0) [ set directionAngle 0 ]
  [ ifelse (x-direction = 1 AND y-direction = 1) [ set directionAngle 45 ]
    [ ifelse (x-direction = 0 AND y-direction = 1) [ set directionAngle 90 ]
      [ ifelse (x-direction = -1 AND y-direction = 1) [ set directionAngle 135 ]
        [ ifelse (x-direction = -1 AND y-direction = 0) [ set directionAngle 180 ]
          [ ifelse (x-direction = -1 AND y-direction = -1) [ set directionAngle 225 ]
            [ ifelse (x-direction = 0 AND y-direction = -1) [ set directionAngle 270 ]
              [ ifelse (x-direction = 1 AND y-direction = -1) [ set directionAngle 315 ]
                [ if (x-direction = 1 AND y-direction = 0) [ set directionAngle 360 ] ]
              ]
            ]
          ]
        ]
      ]
    ]
  ]

  repeat len
  [
    set directionAngle directionAngle + (random-exponential par_featureAngleRange) * (1 - random-float 2)
    set directionAngle directionAngle mod 360

    set p1 p2
    ask p2
    [
      set elevation elev
      if (patch-at-heading-and-distance directionAngle 1 != nobody) [ set p2 patch-at-heading-and-distance directionAngle 1 ]
    ]
  ]

end

to smooth-elevation-all

  ask patches
  [
    smooth-elevation
  ]

end

to smooth-elevation

  let smoothedElevation mean [elevation] of patches in-radius smoothingNeighborhood
  set elevation elevation + (smoothedElevation - elevation) * elevationSmoothStep

end

to set-xySlopes

  ask patches
  [
    ifelse (pxcor < (world-height / 2))
    [
      set elevation elevation - (xSlope * (elevation - minElevation) * ((world-width / 2) - pxcor))
    ]
    [
      set elevation elevation + (xSlope * (maxElevation - elevation) * (pxcor - (world-width / 2)))
    ]
    ifelse (pycor < (world-width / 2))
    [
      set elevation elevation - (ySlope * (elevation - minElevation) * ((world-height / 2) - pycor))
    ]
    [
      set elevation elevation + (ySlope * (maxElevation - elevation) * (pycor - (world-height / 2)))
    ]
  ]

end

;=======================================================================================================
;;; START of algorithms based on:
;;; Huang P C and Lee K T 2015
;;; A simple depression-filling method for raster and irregular elevation datasets
;;; J. Earth Syst. Sci. 124 1653–65
;=======================================================================================================

to fill-sinks

  while [ count patches with [is-sink] > 0 ]
  [
    ask patches with [is-sink]
    [
      ;print (word "before: " elevation)
      set elevation [elevation] of min-one-of neighbors [elevation] + 1E-1
      ; the scale of this "small number" (1E-1) regulates how fast will be the calculation
      ; and how distorted will be the depressless DEM
      ;print (word "after: " elevation)
    ]
  ]

  ask patches
  [
    let thisPatch self

    let downstreamPatch max-one-of neighbors [get-drop-from thisPatch]
    set flowDirection get-flow-direction-encoding ([pxcor] of downstreamPatch - pxcor) ([pycor] of downstreamPatch - pycor)
  ]

end

to-report is-sink ; ego = patch

  let thisPatch self

  report (not is-at-edge) and (count neighbors with [elevation < [elevation] of thisPatch] = 0)

end

;=======================================================================================================
;;; END of algorithms based on:
;;; Huang P C and Lee K T 2015
;;; A simple depression-filling method for raster and irregular elevation datasets
;;; J. Earth Syst. Sci. 124 1653–65
;=======================================================================================================

;=======================================================================================================
;;; START of algorithms based on:
;;; Jenson, S. K., & Domingue, J. O. (1988).
;;; Extracting topographic structure from digital elevation data for geographic information system analysis.
;;; Photogrammetric engineering and remote sensing, 54(11), 1593-1600.
;;; ***NOTE: the original text is copied in code comments
;;; ***NOTE: INCOMPLETE !!!! NOT ABLE TO UNDERSTAND THE ALGORITHM DESCRIPTION ON STEPS 6-7 (correct-watershed-paths) !!!!!!!!!!!!!!!!!!!!!!!!!!
;=======================================================================================================

;to fill-sinks-JD
;
;  set-flow-directions
;
;  ;;; Table 1
;
;  ; Step 1: "Fill single-cell depressions by raising each cell’s elevation to the
;  ; elevation of its lowest elevation neighbor if that neighbor is higher in
;  ; elevation than the cell. This is a simple case and filling them reduces the
;  ; number of depressions that must be dealt with."
;  ask patches with [flowDirection < 0]
;  [ set elevation [elevation] of min-one-of neighbors [elevation] ]
;
;  ; Step 2: "Compute flow directions (Table 3)" (see set-flow-directions)
;  set-flow-directions
;
;  ; Step 3: For every spatially connected group of cells that has undefined flow directions
;  ; because it would have required an uphill flow,
;  ; find the group’s uniquely labeled watershed from the flow directions.
;  set-flow-accumulations
;  set-watershed-labels
;
;  ; Step 4: Build a table of pour point elevations between all pairs of watersheds that share a boundary (Table 6).
;  set-pour-points
;
;  ; Step 5: For each watershed, mark the pour point that is lowest in elevation as that watershed’s “lowest pour point.”
;  ; If there are duplicate lowest pour points, select one arbitrarily.
;  set-lowest-pour-points
;
;  ; Step 6: For each watershed, follow the path of lowest pour points until either the data set edge is reached (go to step 7)
;  ; or the path loops back on itself (go to step 6a).
;  ; Step 6a: 6a. Fix paths that loop back on themselves by aggregating the watersheds which comprised the loop,
;  ; deleting pour points between group members from the table, recomputing “lowest pour point” for the new aggregated watershed,
;  ; and resume following the path of lowest pour points.
;  ; Step 7: In each watershed’s path of lowest pour points, find the one that is highest in elevation.
;  ; This is the threshold value for the watershed.
;  ; Raise all cells in the watershed that are less than the threshold value to the threshold value.
;  correct-watershed-paths
;
;end
;
;to set-flow-directions
;
;  ;;; Table 2
;  ;;; Notice that this code do not use the cell encoding conventions used by the original reference.
;  ;;; Instead, it represents flow direction as a two-item list holding relative coordinates in x and y.
;
;  ; reset flowDirection
;  ask patches [ set flowDirection 0 ]
;
;  ; Step 1: "For all cells adjacent to the data set edge or the study area amsk,
;  ; assign the flow direction to flow to the edge or the mask. This
;  ; action is taken under the assumption that the study area is interior
;  ; to the data set."
;  ask patches with [ pxcor = min-pxcor ]
;  [ set flowDirection 32 ];[ -1 0 ] ]
;  ask patches with [ pxcor = max-pxcor ]
;  [ set flowDirection 2 ];[ 1 0 ] ]
;  ask patches with [ pycor = min-pycor ]
;  [ set flowDirection 8 ];[ 0 -1 ] ]
;  ask patches with [ pycor = max-pycor ]
;  [ set flowDirection 128 ];[ 0 1 ] ]
;
;  ; Step 2: "For each cell not assigned a flow direction in step 1, ...
;  ask patches with [ flowDirection = 0 ]
;  [
;    let thisPatch self
;
;    ; compute the distance-weighted drop in elevation to each of the cell’s eight neighbors."
;    ; Step 3: Examine the drop value to determine the neighbor(s) with the largest drop ...
;    let downstreamPatch max-one-of neighbors [get-drop-from thisPatch]
;    let downstreamCandidates neighbors with [ elevation = [elevation] of downstreamPatch ]
;    let largestDrop [get-drop-from thisPatch] of downstreamPatch
;    ; and perform one of the following:
;    ; 3a. If the largest drop is less than zero, ...
;    ifelse (largestDrop < 0)
;    [
;      ; assign a negative flow direction to indicate undefined.
;      ; This situation does not occur for a depressionless DEM
;      set flowDirection largestDrop;[ 0 0 ] ; (here, "sinks" are coded as [ 0 0 ])
;    ]
;    [
;      ; 3b. If the largest drop is greater than or equal to zero ...
;      ifelse (count downstreamCandidates = 1)
;      [
;        ; and occurs at only one neighbor, assign the flow direction to that neighbor.
;        ;set flowDirection [ (pxcor - [pxcor] of flowDirection) (pycor - [pycor] of flowDirection) ]
;        set flowDirection get-flow-direction-encoding ([pxcor] of downstreamPatch - pxcor) ([pycor] of downstreamPatch - pycor)
;      ]
;      [
;        ifelse (largestDrop > 0)
;        [
;          ; 3c. If the largest drop is <greater than and not> equal to zero and occurs at more than one neighbor,
;          ; assign the flow direction logically according to a table loop-up.
;          ; ***Notice that here I am assuming that the text in the original paper (Table 3) actually meant <greater than and not> equal to zero,
;          ; which seems to fit the "condition 3" example given in Table 4 in Jenson & Domingue (1988)
;          ; ***Not sure what "table loop-up" stands for in this context and there is no further detail on how to handle this condition.
;          ; Here, the chosen solution is to check which neighbor candidate has the larger drop accounting their own flow direction.
;          ;print "3c"
;          ask downstreamCandidates
;          [
;            let thisCandidate self
;            let nextDownstreamPatch get-patch-in-flow-direction flowDirection
;            let nextDrop get-drop-from thisPatch
;            if (nextDownstreamPatch != nobody)
;            [ set nextDrop nextDrop + [get-drop-from thisCandidate] of nextDownstreamPatch ]
;
;            if (largestDrop < nextDrop )
;            [
;              set largestDrop nextDrop
;              set downstreamPatch thisCandidate
;            ]
;          ]
;
;          set flowDirection get-flow-direction-encoding ([pxcor] of downstreamPatch - pxcor) ([pycor] of downstreamPatch - pycor)
;        ]
;        [
;          ; 3d. If the largest drop is equal to zero and occurs at more than one neighbor,
;          ; encode the locations of those neighbors by summing their neighbor location codes. Neighbor location codes are:
;          ; 64 128 1
;          ; 32 x 2
;          ; 16 8 4
;          ; for any cell x. If all neighbor elevations were equal to the center cell, the center would receive a value of 255.
;          ;(NOTE: this scenario is actually very rare when using float point numbers)
;          ;print "3d"
;          ask downstreamCandidates
;          [
;            set flowDirection flowDirection + get-flow-direction-encoding (pxcor - [pxcor] of thisPatch) (pycor - [pycor] of thisPatch)
;          ]
;        ]
;      ]
;    ]
;  ]
;
;  ; Step 4: For each cell not already encoded as negative, 0, 1, 2, 4, 8, 16, 32,
;  ; 64, or 128, ...
;  ;(NOTE: this scenario is actually very rare when using float point numbers)
;  let patchesStillToProcess patches with [check-flow-direction-still-missing]
;  let maxIterations 10000 ; just as a safety measure, to avoid infinite loop
;  while [ any? patchesStillToProcess and maxIterations > 0 ]
;  [
;    ask patchesStillToProcess
;    [
;      let thisPatch self
;
;      ; ... examine the neighbor cells with the largest drop.
;      let downstreamPatch max-one-of neighbors [get-drop-from thisPatch]
;
;      ; If a neighbor is encountered that as a flow direction of 1, 2, 4, 8, 16,
;      ; 32, 64, or 128, and the neighbor does not flow to the center cell, ...
;      let downstreamCandidates neighbors with [
;        elevation = [elevation] of downstreamPatch and has-flow-direction-code and not flow-direction-is thisPatch
;      ]
;
;      ; ... assign the center cell a flow direction which flows to this neighbor.
;      if (any? downstreamCandidates)
;      [
;        set downstreamPatch one-of downstreamCandidates
;        set flowDirection get-flow-direction-encoding ([pxcor] of downstreamPatch - pxcor) ([pycor] of downstreamPatch - pycor)
;      ]
;    ]
;
;    set patchesStillToProcess patches with [check-flow-direction-still-missing]
;    set maxIterations maxIterations - 1
;    ; Step 5: Repeat step 4 until no more cells can be assigned a flow direction.
;  ]
;
;  ; Step 6: Make the flow direction value negative for cells that are not equal to
;  ; 1, 2, 4, 8, 16, 32, 64, or 128. This situation will not occur for a depressionless DEM.
;  ask patches with [not has-flow-direction-code]
;  [ set flowDirection -1 ]
;
;end

;to set-watershed-labels
;
;  ; From Jenson, S. K., & Domingue, J. O. (1988), p. 1598
;  ; "SPECIFIC WATERSHED DELINEATION
;  ; Delineation of watersheds requires both a flow direction data set and another “starter” data set.
;  ; The starter data set consists of background values of –1 inch which “start” cells or groups of cells
;  ; have been inserted at the outflow points of the desired watersheds, with each start cell or group
;  ; of cells having its own unique positive values. In creating the starter data set, it is useful to
;  ; have a raster image processing system to display color-coded flow direction and flow accumulation
;  ; data sets. A cursor is used to identify the line and sample coordinates of the outflow points when
;  ; watersheds are to be delineated with respect to the locations of hydrologic stations or the locations
;  ; where samples are collected for water or stream sediment chemistry. If a watershed is to be delineated
;  ; for a broad feature such as a dam, a block of cells should be inserted to represent the feature.
;  ; If a watershed is to be delineated for a depression such as a pothole, the cells isolated by the
;  ; depression-filling procedure would be used as a “start” group. The flow direction data set is then
;  ; used in the watershed generation procedure to iteratively reassign background cells to the value of
;  ; the “start” cell to which they flow."
;
;  ; set up "start" data set
;  let nextWatershedID 1
;  let watershedColor 5
;  let patchesWithFlow patches with [has-flow-direction-code and not flow-direction-is-loop and not is-at-edge]
;  ask patchesWithFlow [ set watershedID -1 ]
;  ;ask patchesWithFlow [ set pcolor yellow ]
;  set patchesWithFlow patchesWithFlow with [get-patch-in-flow-direction flowDirection != nobody]
;  ;ask patchesWithFlow [ set pcolor red ]
;
;  while [count patchesWithFlow with [watershedID < 1] > 0]
;  [
;    ask one-of patches with [watershedID = 0] [ set watershedID nextWatershedID ]
;
;    let nextBasinPatches patchesWithFlow with [[watershedID] of get-patch-in-flow-direction flowDirection = nextWatershedID]
;
;    while [count nextBasinPatches > 0]
;    [
;      ask nextBasinPatches [ set watershedID nextWatershedID ]
;
;      set nextBasinPatches patchesWithFlow with [watershedID = -1 and [watershedID] of get-patch-in-flow-direction flowDirection = nextWatershedID]
;    ]
;
;    set nextWatershedID nextWatershedID + 1
;    set watershedColor watershedColor + 10
;  ]
;
;end
;
;to set-pour-points
;
;  ; Table 6, p. 1598
;
;  ; Step 1: Compare each cell in a watershed data set to its eight neighbors. When a cell and its neighbor have different watershed labels, proceed to steps 2 through 5.
;  ask patches with [ any? neighbors-in-another-watershed ]
;  [
;    ; Step 2: Compare the elevation values of the cell and its neighbor.
;    ; The larger of the two elevation values is the elevation of the possible pour point they represent,
;    ; and the line and sample of the cell with the larger elevation is the pour point location.
;    ; ***NOTE: here, location and elevation are stored in the patch while we mark the pouring points with a variable holding the watershedID of the neighbor
;
;    ; ***NOTE: here, there is the additional criterium of selecting the neighbors with the least elevation, in case there are more than one
;    let neighbor min-one-of neighbors-in-another-watershed [elevation]
;
;    ; ***NOTE: here, the criterium is greater than -OR EQUAL TO- the neighbor elevation
;    ; (this avoids ignoring the lowest pour points because of the first step of filling sinks, which are the patches involved in loops)
;    if (elevation >= [elevation] of neighbor)
;    [
;      let currentPourPoint get-pour-point-between watershedID [watershedID] of neighbor
;      ifelse (currentPourPoint = nobody)
;      [
;        ; Step 3: If this pair of watershed labels is not yet in the table of pour points, make a new table entry by recording the pair of watershed labels and the location and elevation of the pour point.
;        set pourPointWithWatershed [watershedID] of neighbor
;      ]
;      [
;        ; Step 4: If this pair of watershed labels is already in the pour point table, compare the elevation in the table to the elevation for the possible pour point being examined.
;        ; If the new elevation is lower, replace the old pour point lines, sample, and elevation with the new ones.
;        if (elevation < [elevation] of currentPourPoint)
;        [
;          set pourPointWithWatershed [watershedID] of neighbor ; mark this patch as a pour point
;          ask currentPourPoint [ set pourPointWithWatershed 0 ] ; erase the other patch as a pour point
;        ]
;      ]
;    ]
;    ; Step 5: Repeat the procedure for all cells.
;  ]
;
;end
;
;to set-lowest-pour-points
;
;  ; Step 5: For each watershed, mark the pour point that is lowest in elevation as that watershed’s “lowest pour point.”
;  ; If there are duplicate lowest pour points, select one arbitrarily.
;
;  ; ***NOTE: ignoring single cells watesheds (at the edges).
;  let validPatches get-valid-watershed-patches
;
;  ; ***NOTE: not valid cells will remain with isLowestPourPoint = 0
;  ask validPatches [ set isLowestPourPoint false ]
;
;  foreach remove-duplicates [watershedID] of validPatches
;  [
;    aWatershedID ->
;
;    let lowestPourPoint get-lowest-pour-point-in aWatershedID
;
;    ask lowestPourPoint
;    [
;      set isLowestPourPoint true
;      set flowDirection get-flow-direction-in-pour-point
;    ]
;
;    ;print (word "watershed " aWathershedID ", lowestPourPoint count = " (count patches with [watershedID = aWathershedID and isLowestPourPoint = true]))
;  ]
;
;end
;
;to correct-watershed-paths
;
;  ; Step 6 (Table 1)
;
;  ; ***NOTE: ignoring single cells watesheds (at the edges).
;  let validPatches get-valid-watershed-patches
;
;  ; For each watershed, ...
;  foreach sort remove-duplicates [watershedID] of validPatches
;  [
;    aWatershedID ->
;
;    ; ***NOTE: since watersheds can be aggreagated during this process, we need to check if the watershed is still valid
;    if (any? validPatches with [watershedID = aWatershedID])
;    [
;      let comprisedWatershedsIDs (list)
;print aWatershedID
;      let currentPathPoint one-of validPatches with [watershedID = aWatershedID and isLowestPourPoint = true ]
;      let lastPathPoint [get-patch-flowing-in] of currentPathPoint
;      let nextPathPoint nobody
;
;      ; ... follow the path of lowest pour points until either the data set edge is reached (go to step 7)
;      while [not [is-at-edge ] of currentPathPoint ] ; or flow-direction-is-loop
;      [
;        set comprisedWatershedsIDs remove-duplicates lput ([watershedID] of currentPathPoint) comprisedWatershedsIDs
;
;        ask currentPathPoint [ set nextPathPoint get-patch-in-flow-direction [flowDirection] of currentPathPoint ];set pcolor red]
;
;        ; ... or the path loops back on itself (go to step 6a).
;        ifelse (nextPathPoint = lastPathPoint)
;        [
;          ; Step 6a: 6a. Fix paths that loop back on themselves by aggregating the watersheds which comprised the loop, ...
;          foreach remove aWatershedID comprisedWatershedsIDs ; iterate for all comprised watersheds that are not aWatershedID
;          [
;            comprisedWathershedID ->
;
;            ask patches with [ watershedID = comprisedWathershedID ]
;            [
;              set watershedID aWatershedID
;              ; ***NOTE: the current watershed ID overwrites the others
;
;              ; ... deleting pour points between group members from the table,
;              ; ***NOTE: deleting pour points from those originally in the former "comprisedWatershedsIDs" to the original "watershedID"
;              if (pourPointWithWatershed = aWatershedID) [ set pourPointWithWatershed 0 ]
;            ]
;
;            ; ***NOTE: pour points to the former "comprisedWatershedsIDs" are overwritten
;            ask patches with [pourPointWithWatershed = comprisedWathershedID] [ set pourPointWithWatershed aWatershedID ]
;          ]
;          ; ***NOTE: pour points in the watershed still pouring into itself are deleted
;          ask patches with [ watershedID = aWatershedID and pourPointWithWatershed = aWatershedID ] [ set pourPointWithWatershed 0 ]
;
;          ; ... recomputing “lowest pour point” for the new aggregated watershed,
;          ask patches with [watershedID = aWatershedID and isLowestPourPoint = true] [ set isLowestPourPoint false ] ; reset
;          ; set new lowest point
;          set currentPathPoint get-lowest-pour-point-in aWatershedID
;          ask currentPathPoint [ set isLowestPourPoint true ] ;set flowDirection get-flow-direction-in-pour-point
;          set lastPathPoint [get-patch-flowing-in] of currentPathPoint
;
;          ; and resume following the path of lowest pour points.
;        ]
;        [
;          set lastPathPoint currentPathPoint
;          ask lastPathPoint [ set pcolor black ]
;
;          set currentPathPoint nextPathPoint
;          ask currentPathPoint [ set pcolor green ]
;        ]
;      ]
;
;      ; Step 7: In each watershed’s path of lowest pour points, find the one that is highest in elevation.
;      ; This is the threshold value for the watershed.
;      ; Raise all cells in the watershed that are less than the threshold value to the threshold value.
;      raise-watershed-minimun-elevation
;
;    ]
;  ]
;
;end
;
;to raise-watershed-minimun-elevation
;
;  ; Step 7 (Table 1)
;
;  ; In each watershed’s path of lowest pour points, find the one that is highest in elevation.
;  ; This is the threshold value for the watershed.
;  ; Raise all cells in the watershed that are less than the threshold value to the threshold value.
;
;  ; INCOMPLETE!!!!!!!!!!!!!!!!
;
;end
;
;to-report get-patch-flowing-in ; ego = patch
;
;  let me self
;
;  report one-of neighbors with [flowDirection = get-flow-direction-encoding ([pxcor] of me - pxcor) ([pycor] of me - pycor)]
;
;end
;
;to-report check-flow-direction-still-missing ; ego = patch
;
;  if (flowDirection <= 0 or has-flow-direction-code) [ report false ]
;
;  report true
;
;end
;
;to-report get-valid-watershed-patches
;
;  report patches with [ member? watershedID [watershedID] of neighbors ]
;
;end
;
;to-report neighbors-in-another-watershed ; ego = patch
;
;  let myWatershedID watershedID
;
;  report neighbors with [watershedID != myWatershedID]
;
;end
;
;to-report get-pour-point-between [ watershedID1 watershedID2 ] ; ego = patch
;
;  report one-of patches with [ watershedID = watershedID1 and pourPointWithWatershed = watershedID2 ]
;
;end
;
;to-report get-lowest-pour-point-in [ aWathershedID ]
;
;  let lowestPourPoint nobody
;
;  ask get-valid-watershed-patches with [watershedID = aWathershedID and pourPointWithWatershed > 0]
;  [
;    ifelse (lowestPourPoint = nobody)
;    [ set lowestPourPoint self ]
;    [
;      if (elevation < [elevation] of lowestPourPoint)
;      [ set lowestPourPoint self ]
;    ]
;  ]
;
;  report lowestPourPoint
;
;end
;
;to-report get-flow-direction-in-pour-point ; ego = patch
;
;  let otherWatershed pourPointWithWatershed
;  let neighbourInAnotherWatershed min-one-of neighbors with [watershedID = otherWatershed] [elevation] ; using the same criterium from set-pour-points
;
;  report get-flow-direction-encoding ([pxcor] of neighbourInAnotherWatershed - pxcor) ([pycor] of neighbourInAnotherWatershed - pycor)
;
;end

;=======================================================================================================
;;; END of algorithms based on:
;;; Jenson, S. K., & Domingue, J. O. (1988).
;;; Extracting topographic structure from digital elevation data for geographic information system analysis.
;;; Photogrammetric engineering and remote sensing, 54(11), 1593-1600.
;=======================================================================================================

;=======================================================================================================
;;; START of algorithms based on:
;;; Jenson, S. K., & Domingue, J. O. (1988).
;;; Extracting topographic structure from digital elevation data for geographic information system analysis.
;;; Photogrammetric engineering and remote sensing, 54(11), 1593-1600.
;;; ===BUT used elsewhere, such as in the algorithms based on:
;;; Huang P C and Lee K T 2015
;;; A simple depression-filling method for raster and irregular elevation datasets
;;; J. Earth Syst. Sci. 124 1653–65
;=======================================================================================================

to-report get-drop-from [ aPatch ] ; ego = patch

  ; "Distance- weighted drop is calculated by subtracting the neighbor’s value from the center cell’s value
  ; and dividing by the distance from the center cell, √2 for a corner cell and one for a noncorner cell." (p. 1594)

  report ([elevation] of aPatch - elevation) / (distance aPatch)

end

to-report is-at-edge ; ego = patch

  report (pxcor = min-pxcor or pxcor = max-pxcor or pycor = min-pycor or pycor = max-pycor)

end

to-report has-flow-direction-code ; ego = patch

  if (member? flowDirection [ 1 2 4 8 16 32 64 128 ]) [ report true ]

  report false

end

to-report flow-direction-is [ centralPatch ]

  if (flowDirection = get-flow-direction-encoding ([pxcor] of centralPatch - pxcor) ([pycor] of centralPatch - pycor))
  [ report true ]

  report false

end

to-report get-flow-direction-encoding [ x y ]

  if (x = -1 and y = -1) [ report 16 ]
  if (x = -1 and y = 0) [ report 32 ]
  if (x = -1 and y = 1) [ report 64 ]

  if (x = 0 and y = -1) [ report 8 ]
  if (x = 0 and y = 1) [ report 128 ]

  if (x = 1 and y = -1) [ report 4 ]
  if (x = 1 and y = 0) [ report 2 ]
  if (x = 1 and y = 1) [ report 1 ]

end

to-report get-patch-in-flow-direction [ neighborEncoding ] ; ego = patch

  ; 64 128 1
  ; 32  x  2
  ; 16  8  4

  if (neighborEncoding = 16) [ report patch (pxcor - 1) (pycor - 1) ]
  if (neighborEncoding = 32) [ report patch (pxcor - 1) (pycor) ]
  if (neighborEncoding = 64) [ report patch (pxcor - 1) (pycor + 1) ]

  if (neighborEncoding = 8) [ report patch (pxcor) (pycor - 1) ]
  if (neighborEncoding = 128) [ report patch (pxcor) (pycor + 1) ]

  if (neighborEncoding = 4) [ report patch (pxcor + 1) (pycor - 1) ]
  if (neighborEncoding = 2) [ report patch (pxcor + 1) (pycor) ]
  if (neighborEncoding = 1) [ report patch (pxcor + 1) (pycor + 1) ]

  report nobody

end

to-report flow-direction-is-loop ; ego = patch

  let thisPatch self
  let dowstreamPatch get-patch-in-flow-direction flowDirection
  ;print (word "thisPatch: " thisPatch "dowstreamPatch: " dowstreamPatch)

  if (dowstreamPatch != nobody)
  [ report [flow-direction-is thisPatch] of dowstreamPatch ]

  report false

end

to set-flow-accumulations

  ; From Jenson, S. K., & Domingue, J. O. (1988), p. 1594
  ; "FLOW ACCUMULATION DATA SET
  ; The third procedure of the conditioning phase makes use of the flow direction data set to create the flow accumulation data set,
  ; where each cell is assigned a value equal to the number of cells that flow to it (O’Callaghan and Mark, 1984).
  ; Cells having a flow accumulation value of zero (to which no other cells flow) generally correspond to the pattern of ridges.
  ; Because all cells in a depressionless DEM have a path to the data set edge, the pattern formed by highlighting cells
  ; with values higher than some threshold delineates a fully connected drainage network. As the threshold value is increased,
  ; the density of the drainage network decreases. The flow accumulation data set that was calculated for the numeric example
  ; is shown in Table 2d, and the visual example is shown in Plate 1c."

  ; identify patches that receive flow and those that do not (this makes the next step much easier)
  ask patches
  [
    set receivesFlow false
    set flowAccumulationState "start"
    ;set pcolor red
  ]

  ask patches with [has-flow-direction-code]
  [
    let patchInFlowDirection get-patch-in-flow-direction flowDirection
    if (patchInFlowDirection != nobody)
    [
      ask patchInFlowDirection
      [
        set receivesFlow true
        set flowAccumulationState "pending"
        ;set pcolor yellow
      ]
    ]
  ]

  let maxIterations 100000 ; just as a safety measure, to avoid infinite loop
  while [count patches with [flowAccumulationState = "pending" and not flow-direction-is-loop] > 0 and maxIterations > 0 ]
  [
    ask one-of patches with [flowAccumulationState = "start"]
    [
      let downstreamPatch get-patch-in-flow-direction flowDirection
      let nextFlowAccumulation flowAccumulation + 1

      if (downstreamPatch != nobody)
      [
        ask downstreamPatch
        [
          set flowAccumulation flowAccumulation + nextFlowAccumulation
          if (count neighbors with [get-patch-in-flow-direction flowDirection = downstreamPatch and flowAccumulationState = "pending"] = 0)
          [
            set flowAccumulationState "start"
            ;set pcolor red
          ]
        ]
      ]

      set flowAccumulationState "done"
      ;set pcolor orange
    ]

    set maxIterations maxIterations - 1
  ]

end

;=======================================================================================================
;;; END of algorithms based on:
;;; Jenson, S. K., & Domingue, J. O. (1988).
;;; Extracting topographic structure from digital elevation data for geographic information system analysis.
;;; Photogrammetric engineering and remote sensing, 54(11), 1593-1600.
;;; ===BUT used in the algorithms based on:
;;; Huang P C and Lee K T 2015
;;; A simple depression-filling method for raster and irregular elevation datasets
;;; J. Earth Syst. Sci. 124 1653–65
;=======================================================================================================

to diffuse-moisture

  ask patches [ set moisture 0 ]

  ; assign water volume per patch under sealevel
  ask patches with [ elevation < seaLevel ] [ set water (seaLevel - elevation) * patchArea ]

  ; assign water volume per patch according to streamLevel
  ask patches with [ elevation >= seaLevel and flowAccumulation > 0 ] [ set water flowWaterVolume * flowAccumulation ]

  ; calculate moisture from water volumes (including rivers)
  ask patches with [ water > 0 ] [ set moisture water ]

  repeat moistureDiffusionSteps
  [
    ;diffuse moisture moistureTransferenceRate ; diffuse does not work here because it decreases the moisture of patches with water
    ask patches with [ moisture = 0 ]
    [
      ;;; !!! TO DO: weight the moisture transmission with the difference in elevation
      let myElevation elevation
      set tempMoisture moistureTransferenceRate * mean [
        moisture
        ;* (max (list 0 (min (list 1 ((elevation - myElevation) / 100))))) ;;; this weighting function assumes maximum transmission with 45º favorable inclination between patches centres
      ] of neighbors
    ]

    ask patches with [ moisture = 0 ]
    [
      set moisture tempMoisture
    ]
  ]

end

to paint-patches

  ask patches
  [

    if (display-mode = "terrain")
    [
      let elevationGradient 0
      ifelse (elevation < seaLevel)
      [
        let normSubElevation (-1) * (seaLevel - elevation)
        let normSubMinElevation (-1) * (seaLevel - minElevation)
        set elevationGradient 20 + (200 * (1 - normSubElevation / normSubMinElevation))
        set pcolor rgb 0 0 elevationGradient
      ]
      [
        let normSupElevation elevation - seaLevel
        let normSupMaxElevation maxElevation - seaLevel
        set elevationGradient 100 + (155 * (normSupElevation / normSupMaxElevation))
        set pcolor rgb (elevationGradient - 100) elevationGradient 0
      ]
    ]
    if (display-mode = "moisture")
    [
      set pcolor 92 + (7 * 1E20 ^ (1 - moisture / (max [moisture] of patches)) / 1E20)
    ]
;    if (display-mode = "watersheds")
;    [
;      set pcolor 2 + round 137 * watershedID / (max [watershedID] of patches)
;      while [remainder pcolor 10 = 0] [ set pcolor pcolor - 1 ]
;    ]
  ]

  if (show-flows) [ display-flows ]

end

to display-flows

  if (not any? flowHolders)
  [
    ask patches [ sprout-flowHolders 1 [ set hidden? true ] ]
  ]

  ask patches ;with [ has-flow-direction-code ]
  [
    let flowDirectionHere flowDirection
    let nextPatchInFlow get-patch-in-flow-direction flowDirection
    let flowAccumulationHere flowAccumulation

    ask one-of flowHolders-here
    [
      if (link-with one-of [flowHolders-here] of nextPatchInFlow = nobody)
      [ create-link-with one-of [flowHolders-here] of nextPatchInFlow ]

      ask link-with one-of [flowHolders-here] of nextPatchInFlow
      [
        let multiplier 1E20 ^ (1 - flowAccumulationHere / (max [flowAccumulation] of patches)) / 1E20
        set color 92 + (6 * multiplier)
        set thickness 0.4 * ( 1 - ((color - 92) / 6))
      ]
    ]
  ]

end

to-report get-angle-in-flow-direction [ neighborEncoding ]

  ; 64 128 1
  ; 32  x  2
  ; 16  8  4

  if (neighborEncoding = 16) [ report 225 ]
  if (neighborEncoding = 32) [ report 270 ]
  if (neighborEncoding = 64) [ report 315 ]

  if (neighborEncoding = 8) [ report 180 ]
  if (neighborEncoding = 128) [ report 0 ]

  if (neighborEncoding = 4) [ report 135 ]
  if (neighborEncoding = 2) [ report 90 ]
  if (neighborEncoding = 1) [ report 45 ]

  report nobody

end

to refresh-view

  update-plots

  paint-patches

end

to refresh-view-after-seaLevel-change

  set seaLevel par_seaLevel

  diffuse-moisture

  update-plots

  paint-patches

end

to setup-patch-coordinates-labels [ XcoordPosition YcoordPosition ]

  let xspacing floor (world-width / patch-size)
  let yspacing floor (world-height / patch-size)

  ifelse (XcoordPosition = "bottom")
  [
    ask patches with [ pycor = min-pycor + 1 ]
    [
      if (pxcor mod xspacing = 0)
      [ set plabel (word pxcor) ]
    ]
  ]
  [
    ask patches with [ pycor = max-pycor - 1 ]
    [
      if (pxcor mod xspacing = 0)
      [ set plabel (word pxcor) ]
    ]
  ]

  ifelse (YcoordPosition = "left")
  [
    ask patches with [ pxcor = min-pxcor + 1 ]
    [
      if (pycor mod yspacing = 0)
      [ set plabel (word pycor) ]
    ]
  ]
  [
    ask patches with [ pycor = max-pycor - 1 ]
    [
      if (pycor mod yspacing = 0)
      [ set plabel (word pycor) ]
    ]
  ]

end

to setup-transect

  ask patches with [ pxcor = xTransect ]
  [
    sprout-transectLines 1 [ set shape "line" set heading 0 set color white ]
  ]

  ask patches with [ pycor = yTransect ]
  [
    sprout-transectLines 1 [ set shape "line" set heading 90 set color white ]
  ]

  if (not show-transects)
  [
    ask transectLines [ set hidden? true ]
  ]

end

to update-transects

  if (show-transects)
  [
    ask transectLines
    [
      ifelse (heading = 0) [ set xcor xTransect ] [ set ycor yTransect ]
      set hidden? false
    ]
  ]

end

to plot-horizontal-transect

  foreach (n-values world-width [ j -> min-pxcor + j ])
  [
    x ->
    plotxy x ([elevation] of patch x yTransect)
  ]
  plot-pen-up

end

to plot-sea-level-horizontal-transect

  foreach (n-values world-width [ j -> min-pxcor + j ])
  [
    x ->
    plotxy x seaLevel
  ]
  plot-pen-up

end

to plot-vertical-transect

  foreach (n-values world-height [ j -> min-pycor + j ])
  [
    y ->
    plotxy ([elevation] of patch xTransect y) y
  ]
  plot-pen-up

end

to plot-sea-level-vertical-transect

  foreach (n-values world-height [ j -> min-pycor + j ])
  [
    y ->
    plotxy seaLevel y
  ]
  plot-pen-up

end
@#$#@#$#@
GRAPHICS-WINDOW
728
43
1204
520
-1
-1
9.36
1
10
1
1
1
0
0
0
1
0
49
0
49
0
0
1
ticks
30.0

BUTTON
9
10
68
57
NIL
setup
NIL
1
T
OBSERVER
NIL
1
NIL
NIL
1

MONITOR
560
490
661
535
NIL
landOceanRatio
4
1
11

SLIDER
470
14
665
47
par_seaLevel
par_seaLevel
round min (list minElevation par_minElevation)
round max (list maxElevation par_maxElevation)
0.0
1
1
m
HORIZONTAL

SLIDER
5
151
177
184
par_sdElevation
par_sdElevation
0
(par_maxElevation - par_minElevation) / 2
5.0
1
1
m
HORIZONTAL

SLIDER
186
118
368
151
par_elevationSmoothStep
par_elevationSmoothStep
0
1
1.0
0.01
1
NIL
HORIZONTAL

INPUTBOX
78
10
154
70
randomSeed
5.0
1
0
Number

INPUTBOX
43
405
144
465
par_continentality
0.0
1
0
Number

MONITOR
398
547
496
592
sdElevation
precision sdElevation 4
4
1
11

MONITOR
495
547
577
592
minElevation
precision minElevation 4
4
1
11

MONITOR
571
547
658
592
maxElevation
precision maxElevation 4
4
1
11

INPUTBOX
8
188
96
248
par_numRanges
3.0
1
0
Number

INPUTBOX
95
188
187
248
par_rangeLength
100.0
1
0
Number

INPUTBOX
8
248
95
308
par_numRifts
2.0
1
0
Number

INPUTBOX
95
248
187
308
par_riftLength
100.0
1
0
Number

SLIDER
5
85
177
118
par_minElevation
par_minElevation
-500
0
0.0
1
1
m
HORIZONTAL

BUTTON
464
52
672
85
refresh after changing sea level
refresh-view-after-seaLevel-change
NIL
1
T
OBSERVER
NIL
3
NIL
NIL
1

SLIDER
5
118
177
151
par_maxElevation
par_maxElevation
0
500
15.0
1
1
m
HORIZONTAL

MONITOR
398
490
483
535
NIL
count patches
0
1
11

SLIDER
208
391
362
424
par_rangeAggregation
par_rangeAggregation
0
1
0.73
0.01
1
NIL
HORIZONTAL

SLIDER
208
424
362
457
par_riftAggregation
par_riftAggregation
0
1
0.71
.01
1
NIL
HORIZONTAL

INPUTBOX
190
333
297
393
par_numContinents
1.0
1
0
Number

INPUTBOX
297
333
389
393
par_numOceans
1.0
1
0
Number

SLIDER
186
151
367
184
par_smoothingNeighborhood
par_smoothingNeighborhood
0
.1
0.1
.01
1
NIL
HORIZONTAL

MONITOR
488
490
553
535
maxDist
precision maxDist 4
4
1
11

MONITOR
222
184
319
221
neighborhood size
(word (count patches with [ distance patch 0 0 < smoothingNeighborhood ] - 1) \" patches\")
0
1
9

PLOT
21
469
377
589
Elevation per patch
m
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-plot-x-range (round min [elevation] of patches - 1) (round max [elevation] of patches + 1)"
PENS
"default" 1.0 1 -16777216 true "" "histogram [elevation] of patches"
"pen-1" 1.0 1 -2674135 true "" "histogram n-values plot-y-max [j -> seaLevel]"

CHOOSER
13
343
179
388
algorithm-style
algorithm-style
"NetLogo" "C#"
1

TEXTBOX
246
322
396
340
used when algorithm-style = C#
9
0.0
1

TEXTBOX
20
394
186
416
used when algorithm-style = Netlogo
9
0.0
1

SLIDER
7
308
187
341
par_featureAngleRange
par_featureAngleRange
0
360
30.0
1
1
º
HORIZONTAL

SLIDER
195
263
366
296
par_ySlope
par_ySlope
-0.1
0.1
0.01
0.01
1
NIL
HORIZONTAL

MONITOR
485
158
589
203
count river patches
count patches with [ water > 0 ]
0
1
11

SWITCH
305
10
425
43
show-flows
show-flows
0
1
-1000

CHOOSER
162
10
300
55
display-mode
display-mode
"terrain" "moisture"
1

SLIDER
196
229
366
262
par_xSlope
par_xSlope
-0.1
0.1
-0.01
0.01
1
NIL
HORIZONTAL

SLIDER
429
201
639
234
par_moistureDiffusionSteps
par_moistureDiffusionSteps
0
100
15.0
1
1
NIL
HORIZONTAL

BUTTON
323
46
395
79
refresh
refresh-view
NIL
1
T
OBSERVER
NIL
2
NIL
NIL
1

SLIDER
429
234
640
267
par_moistureTransferenceRate
par_moistureTransferenceRate
0
1
0.05
0.01
1
NIL
HORIZONTAL

MONITOR
464
439
582
484
total moisture
sum [moisture] of patches
2
1
11

TEXTBOX
194
95
265
120
ELEVATION
11
0.0
1

TEXTBOX
460
110
610
128
WATER & SOIL MOISTURE
11
0.0
1

PLOT
708
514
1204
634
Horizontal transect
pxcor
m
0.0
10.0
0.0
10.0
true
false
"" "clear-plot\nset-plot-x-range (min-pxcor - 1) (max-pxcor + 1)\nset-plot-y-range (round min [elevation] of patches - 1) (round max [elevation] of patches + 1)"
PENS
"default" 1.0 0 -16777216 true "" "plot-horizontal-transect"
"pen-1" 1.0 0 -13345367 true "" "plot-sea-level-horizontal-transect"
"pen-2" 1.0 0 -2674135 true "" "plotxy xTransect plot-y-max plotxy xTransect plot-y-min"

SLIDER
698
39
731
517
yTransect
yTransect
min-pycor
max-pycor
0.0
1
1
NIL
VERTICAL

SLIDER
725
12
1211
45
xTransect
xTransect
min-pxcor
max-pxcor
0.0
1
1
NIL
HORIZONTAL

PLOT
1203
36
1363
521
vertical transect
m
pycor
0.0
10.0
0.0
10.0
true
false
"" "clear-plot\nset-plot-y-range (min-pycor - 1) (max-pycor + 1)\nset-plot-x-range (round min [elevation] of patches - 1) (round max [elevation] of patches + 1)"
PENS
"default" 1.0 0 -16777216 true "" "plot-vertical-transect"
"pen-1" 1.0 0 -13345367 true "" "plot-sea-level-vertical-transect"
"pen-2" 1.0 0 -2674135 true "" "plotxy  plot-x-max yTransect plotxy plot-x-min yTransect"

BUTTON
1230
579
1330
612
update transects
update-transects\nupdate-plots
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
1220
545
1345
578
show-transects
show-transects
0
1
-1000

SLIDER
423
130
666
163
par_flowWaterVolume
par_flowWaterVolume
0
100
10.0
1
1
m^3 / patch
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

this version creates rivers over the terrain generated by v1 algorithms and derives the soil moisture of patches from rivers and meters below sea level. Rivers are formed by one or more streams which start at random patches and move from patch to patch towards the least elevation. There are two algorithms implementing the movement of streams: choosing only among neighbors (`river-algorithm = "least neighbor"`), favouring connections between basins, or neighbors *AND* the patch considered (`river-algorithm = "absolute downhill"`), producing 'stump' rivers more often. Every time a stream is formed, the elevation of the patches involved is depressed by a quantity (`par_waterDepression`) and then smoothed, together with that of neighboring patches. A passing stream will add 1 unit of `water` to a patch while patches below sea level have `water` units proportional to their depth. The amount of `water` of patches is converted to units of `moisture` and then moisture is distributed to other 'dry' patches using NetLogo's primitive `diffuse` (NOTE: not ideal because it does not account for the difference in elevation). 

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

line1
true
0
Line -7500403 true 150 0 150 300
Rectangle -7500403 true true 135 0 165 300

line2
true
0
Line -7500403 true 150 0 150 300
Rectangle -7500403 true true 120 0 180 300

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@