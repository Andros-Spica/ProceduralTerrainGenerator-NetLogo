;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GNU GENERAL PUBLIC LICENSE ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;  Terrain Generator with Climate model v.0.1
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

globals
[
  patchArea
  maxDist

  ;;; parameters (copies) ===============================================================

  ;;;; elevation
  numContinents
  numOceans

  numRanges
  rangeLength
  rangeElevation
  rangeAggregation

  numRifts
  riftLength
  riftElevation
  riftAggregation

  featureAngleRange
  continentality
  elevationNoise
  seaLevel
  elevationSmoothStep
  smoothingNeighborhood

  ;;;; flow accumulation and moisture
  flowAccumulationPerPatch
  flowWaterVolume

  moistureDiffusionSteps
  moistureTransferenceRate

  ;;;; slope
  meanSlope
  stdDevSlope

  ;;;; latitude
  axisGridInDegrees
  yearLenghtInDays
  initialDayInYear

  ;;;; temperature
  polarLatitude
  tropicLatitude
  minTemperatureAtSeaLevel
  maxTemperatureAtSeaLevel
  temperatureDecreaseByElevation
  temperatureDecreaseBySlope

  ;;; variables ===============================================================
  landOceanRatio
  elevationDistribution
  minElevation
  sdElevation
  maxElevation

  currentYear
  currentDayInYear
  sunDeclination
  minTemperature
  maxTemperature
]

patches-own
[
  elevation
  flowDirection
  receivesFlow flowAccumulationState
  flowAccumulation
  water
  moisture
  tempMoisture
  slope
  latitude latitudeRegion
  windDirection sunAngle temperature
]

breed [ mapSetters mapSetter ]

breed [ flowHolders flowHolder ]

breed [ windIndicators windIndicator ]

mapSetters-own [ points ]

to create-terrain

  clear-all

  print (word "=====RUN " date-and-time "=================================================")

  set-parameters

  reset-timer

  ifelse (algorithm-style = "NetLogo")
  [
    set-landform-NetLogo
  ]
  [
    set-landform-Csharp
  ]

  print (word "Terrain computing time: " timer)

  set-flow-directions

  print (word "set-flow-directions computing time: " timer)

  reset-timer

  set-flow-accumulations

  print (word "set-flow-accumulations computing time: " timer)

  reset-timer

  diffuse-moisture

  print (word "diffuse-moisture computing time: " timer)

  reset-timer

  setup-latitude-and-windDirections
  update-climate

  print (word "Temperature computing time: " timer)

  set landOceanRatio count patches with [elevation > seaLevel] / count patches
  set elevationDistribution [elevation] of patches
  set minElevation min [elevation] of patches
  set maxElevation max [elevation] of patches
  set sdElevation standard-deviation [elevation] of patches

  set minTemperature min [temperature] of patches
  set maxTemperature max [temperature] of patches

  paint-patches

end


to set-parameters

  random-seed randomSeed

  set patchArea 1E6 ; 1,000,000 m^2 = 1 km^2
  set maxDist (sqrt (( (max-pxcor - min-pxcor) ^ 2) + ((max-pycor - min-pycor) ^ 2)) / 2)

  ;parameters-check-1

  if (type-of-experiment = "user-defined")
  [
    ;;; load parameters from user interface
    set numContinents par_numContinents ; 3
    set numOceans par_numOceans ; 10

    set numRanges par_numRanges ; 50
    set rangeLength round ( par_rangeLength * maxDist) ; 0.2
    set rangeElevation par_rangeElevation ; 5000 m
    set rangeAggregation par_rangeAggregation

    set numRifts par_numRifts ; 50
    set riftLength round ( par_riftLength * maxDist) ; 0.5
    set riftElevation par_riftElevation ; -5000 m
    set riftAggregation par_riftAggregation

    set elevationNoise par_elevationNoise ; 800 m

    set featureAngleRange par_featureAngleRange

    set continentality par_continentality * count patches

    set elevationSmoothStep par_elevationSmoothStep ; 1
    set smoothingNeighborhood par_smoothingNeighborhood * maxDist ; 0.03 (3% of maxDist)

    set seaLevel par_seaLevel

    set flowAccumulationPerPatch par_flowAccumulationPerPatch
    set flowWaterVolume par_flowWaterVolume
    set moistureDiffusionSteps par_moistureDiffusionSteps
    set moistureTransferenceRate par_moistureTransferenceRate

    set meanSlope par_meanSlope
    set stdDevSlope par_stdDevSlope

    set axisGridInDegrees par_axisGridInDegrees
    set yearLenghtInDays par_yearLenghtInDays
    set initialDayInYear par_initialDayInYear
    set polarLatitude par_polarLatitude
    set tropicLatitude par_tropicLatitude

    set minTemperatureAtSeaLevel par_minTemperatureAtSeaLevel
    set maxTemperatureAtSeaLevel par_maxTemperatureAtSeaLevel
    set temperatureDecreaseByElevation par_temperatureDecreaseByElevation
    set temperatureDecreaseBySlope par_temperatureDecreaseBySlope
  ]

  if (type-of-experiment = "random") ; TODO
  [
    ;;; get random values within an arbitrary (reasonable) range of values
    ;;; this depends on what type and scale of terrain you want
    ;;; Here, our aim is to create a global-scale terrain (horizontal wrap or cylinder)
    set numContinents 1 + random 10
    set numOceans 1 + random 10

    set numRanges 1 + random 100
    set rangeLength round ( (random-float 1) * maxDist)
    set rangeElevation random-float 5000
    set rangeAggregation random-float 0.5

    set numRifts 1 + random 100
    set riftLength round ( (random-float 1) * maxDist)
    set riftElevation -1 * random-float 5000
    set riftAggregation random-float 0.5

    set elevationNoise random-float 1

    set featureAngleRange random-float 30

    set continentality (random-float 2) * count patches

    set elevationSmoothStep 1 ; not randomised
    set smoothingNeighborhood 0.03 * maxDist ; not randomised

    set seaLevel 0 ; riftElevation + (random-float (rangeElevation - riftElevation))

    set flowAccumulationPerPatch 1 ; not randomised
    set flowWaterVolume 1 ; not randomised
    set moistureDiffusionSteps random-float 1
    set moistureTransferenceRate random-float 1

    set meanSlope random-float 20
    set stdDevSlope random-float 5

    set axisGridInDegrees random-float 30
    set yearLenghtInDays 150 + random 400
    set initialDayInYear random yearLenghtInDays

    set tropicLatitude random-float 45
    set polarLatitude tropicLatitude + random-float (90 - tropicLatitude)

    set minTemperatureAtSeaLevel -1 * (random-float 50)
    set maxTemperatureAtSeaLevel random-float 50
    set temperatureDecreaseByElevation random-float 0.1
    set temperatureDecreaseBySlope random-float 0.1
  ]
  if (type-of-experiment = "defined by experiment-number")
  [
    ;load-experiment
  ]

  set currentDayInYear initialDayInYear

end

to parameters-check-1

  ;;; check if values were reset to 0 (comment out lines if 0 is a valid value)
  ;;; and set default values

  if (par_rangeElevation = 0)                     [ set par_rangeElevation                   15 ]
  if (par_riftElevation = 0)                     [ set par_riftElevation                    0 ]
  if (par_elevationNoise = 0)                      [ set par_elevationNoise                     1 ]

  if (par_numContinents = 0)                    [ set par_numContinents                   1 ]
  if (par_numOceans = 0)                        [ set par_numOceans                       1 ]

  if (par_continentality = 0)                   [ set par_continentality                  5 ]

  if (par_numRanges = 0)                        [ set par_numRanges                       1 ]
  if (par_rangeLength = 0)                      [ set par_rangeLength                   100 ]
  if (par_rangeAggregation = 0)                 [ set par_rangeAggregation                0.75 ]

  if (par_numRifts = 0)                         [ set par_numRifts                        1 ]
  if (par_riftLength = 0)                       [ set par_riftLength                    100 ]
  if (par_riftAggregation = 0)                  [ set par_riftAggregation                 0.9 ]

  if (par_seaLevel = 0)                         [ set par_seaLevel                        0 ]
  if (par_elevationSmoothStep = 0)              [ set par_elevationSmoothStep             1 ]
  if (par_smoothingNeighborhood = 0)            [ set par_smoothingNeighborhood           0.1 ]

  if (par_flowAccumulationPerPatch = 0)         [ set par_flowAccumulationPerPatch        1 ]
  if (par_flowWaterVolume = 0)                  [ set par_flowWaterVolume                 1 ]

  if (par_moistureDiffusionSteps = 0)           [ set par_moistureDiffusionSteps        100 ]
  if (par_moistureTransferenceRate = 0)         [ set par_moistureTransferenceRate        0.2 ]

end

to set-landform-NetLogo ;[ numRanges rangeLength rangeElevation numRifts riftLength riftElevation continentality smoothingNeighborhood elevationSmoothStep]

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
      rt (random-exponential featureAngleRange) * (1 - random-float 2)
      forward 1
    ]
  ]

  smooth-elevation-all

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

to set-landform-Csharp ;[ elevationNoise numContinents numRanges rangeLength rangeElevation rangeAggregation numOceans numRifts riftLength riftElevation riftAggregation smoothingNeighborhood elevationSmoothStep]

  ; C#-like code
  let p1 0
  let sign 0
  let len 0
  let elev 0

  let continents n-of numContinents patches
  let oceans n-of numOceans patches

  let maxDistBetweenRanges (1.1 - rangeAggregation) * maxDist
  let maxDistBetweenRifts (1.1 - riftAggregation) * maxDist

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
    set elevation random-normal 0 elevationNoise
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
    set directionAngle directionAngle + (random-exponential featureAngleRange) * (1 - random-float 2)
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

  report (;pxcor = min-pxcor or pxcor = max-pxcor or ; the world wraps horizontally
    pycor = min-pycor or pycor = max-pycor)

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

  ; exceptions for wraping horizontal edges
  if (x = world-width - 1)
  [
    if (y = -1) [ report 16 ]
    if (y = 0) [ report 32 ]
    if (y = 1) [ report 64 ]
  ]
  if (x = -1 * (world-width - 1))
  [
    if (y = -1) [ report 4 ]
    if (y = 0) [ report 2 ]
    if (y = 1) [ report 1 ]
  ]

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

to set-flow-directions

  ask patches with [ flowDirection = 0 ]
  [
    ifelse (is-at-edge)
    [
      ;if ( pxcor = min-pxcor ) [ set flowDirection 32 ] ; west
      ;if ( pxcor = max-pxcor ) [ set flowDirection 2 ] ; east
      if ( pycor = min-pycor ) [ set flowDirection 8 ] ; south
      if ( pycor = max-pycor ) [ set flowDirection 128 ] ; north
    ]
    [
      set-flow-direction
    ]
  ]

end

to set-flow-direction ; ego = patch

  let thisPatch self

  let downstreamPatch max-one-of neighbors [get-drop-from thisPatch]

  set flowDirection get-flow-direction-encoding ([pxcor] of downstreamPatch - pxcor) ([pycor] of downstreamPatch - pycor)

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
  while [count patches with [flowAccumulationState = "pending" and not flow-direction-is-loop] > 0 and maxIterations > 0 and count patches with [flowAccumulationState = "start"] > 0 ]
  [
    ask one-of patches with [flowAccumulationState = "start"]
    [
      let downstreamPatch get-patch-in-flow-direction flowDirection
      let nextFlowAccumulation flowAccumulation + flowAccumulationPerPatch

      set flowAccumulationState "done"
      ;set pcolor orange

      if (downstreamPatch != nobody)
      [
        ask downstreamPatch
        [
          set flowAccumulation flowAccumulation + nextFlowAccumulation
          if (count neighbors with [
            get-patch-in-flow-direction flowDirection = downstreamPatch and
            (flowAccumulationState = "pending" or flowAccumulationState = "start")
            ] = 0
          )
          [
            set flowAccumulationState "start"
            ;set pcolor red
          ]
        ]
      ]
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

  ask patches [ set water 0 set moisture 0 ]

  ; assign water volume per patch under sea/inundation level
  ask patches with [ elevation < seaLevel ] [ set water (seaLevel - elevation) * patchArea ]

  ; assign water volume per patch according to flowAccumulation
  ask patches with [ elevation >= seaLevel and flowAccumulation > 0 ] [ set water flowWaterVolume * flowAccumulation ]

  ; calculate moisture from water volumes
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

to setup-latitude-and-windDirections

  ; set latitude and wind direction
  ask patches
  [
    set latitude 90 * (pycor - (max-pycor / 2)) / (max-pycor / 2)

    let windDirectionX pxcor
    let windDirectionY pycor
    ; south polar
    if (latitude < (- 1) * polarLatitude )
    [
      set latitudeRegion "South polar"
      set windDirectionX windDirectionX - 1
      set windDirectionY windDirectionY + 1
      ;set pcolor blue
    ]
    ; south polar to tropical
    if (latitude < (- 1) * tropicLatitude AND latitude > (- 1) * polarLatitude )
    [
      set latitudeRegion "South polar to tropical"
      set windDirectionX windDirectionX + 1
      set windDirectionY windDirectionY - 1
      ;set pcolor green
    ]
    ; south tropical to equator
    if (latitude < 0 AND latitude > (- 1) * tropicLatitude )
    [
      set latitudeRegion "South tropical to equatorial"
      set windDirectionX windDirectionX - 1
      set windDirectionY windDirectionY + 1
      ;set pcolor red
    ]
    ; north tropical to equator
    if (latitude > 0 AND latitude < tropicLatitude )
    [
      set latitudeRegion "North tropical to equatorial"
      set windDirectionX windDirectionX - 1
      set windDirectionY windDirectionY - 1
      ;set pcolor yellow
    ]
    ; north tropical to polar
    if (latitude > tropicLatitude AND latitude < polarLatitude )
    [
      set latitudeRegion "North polar to tropical"
      set windDirectionX windDirectionX + 1
      set windDirectionY windDirectionY + 1
      ;set pcolor brown
    ]
    ; north polar
    if (latitude > polarLatitude )
    [
      set latitudeRegion "North polar"
      set windDirectionX windDirectionX - 1
      set windDirectionY windDirectionY - 1
      ;set pcolor violet
    ]

    ; wrap horizontally
    if (windDirectionX < 0) [ set windDirectionX max-pxcor ]
    if (windDirectionX > max-pxcor) [ set windDirectionX 0 ]

    set windDirection patch windDirectionX windDirectionY
  ]

end

to update-climate

  ; set sun declination
  set sunDeclination (- 1) * axisGridInDegrees * cos (360 * currentDayInYear / yearLenghtInDays)

  ; set sun angle and temperature
  ask patches
  [
    ; Set sun angle
    set sunAngle  90 - abs (latitude - sunDeclination)

    ; Set temperature
    ;; according to sun angle
    set temperature (abs sunAngle / 90) * (maxTemperatureAtSeaLevel - minTemperatureAtSeaLevel) + minTemperatureAtSeaLevel
    ;; according to elevation and slope
    if (elevation > seaLevel)
    [
      set temperature temperature - (elevation - seaLevel) * temperatureDecreaseByElevation
      set temperature temperature - slope * temperatureDecreaseBySlope;
    ]
    ;; TO DO: diffuse temperature according to wind direction
  ]

end

to go

  set currentDayInYear currentDayInYear + 1
  if (currentDayInYear > yearLenghtInDays)
  [
    set currentYear currentYear + 1
    set currentDayInYear currentDayInYear mod yearLenghtInDays
  ]

  update-climate

  set minTemperature min [temperature] of patches
  set maxTemperature max [temperature] of patches

  paint-patches

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
      set pcolor 92 + (7 * 1E100 ^ (1 - moisture / (max [moisture] of patches)) / 1E100)
    ]
    if (display-mode = "sun angle at noon")
    [
      set pcolor rgb (255 * (sunAngle / 90)) 0 0
    ]
    if (display-mode = "temperature")
    [
      set pcolor rgb (255 * (abs (minTemperature - temperature) / abs (maxTemperature - minTemperature))) 0 0
    ]

    display-windDirections
  ]

  display-flows

end

to display-flows

  if (not any? flowHolders)
  [
    ask patches [ sprout-flowHolders 1 [ set hidden? true ] ]
  ]

  ifelse (show-flows)
  [
    ask patches with [ count neighbors with [elevation > seaLevel] > 0 ]
    [
      let flowDirectionHere flowDirection
      let nextPatchInFlow get-patch-in-flow-direction flowDirection
      let flowAccumulationHere flowAccumulation

      ask one-of flowHolders-here
      [
        ifelse (nextPatchInFlow != nobody)
        [
          if (link-with one-of [flowHolders-here] of nextPatchInFlow = nobody)
          [ create-link-with one-of [flowHolders-here] of nextPatchInFlow ]

          ask link-with one-of [flowHolders-here] of nextPatchInFlow
          [
            set hidden? false
            let multiplier 1E100 ^ (1 - flowAccumulationHere / (max [flowAccumulation] of patches)) / 1E100
            set color 92 + (5 * multiplier)
            set thickness 0.4 * ( 1 - ((color - 92) / 5))
          ]
        ]
        [
          set hidden? false
          let multiplier 1E100 ^ (1 - flowAccumulationHere / (max [flowAccumulation] of patches)) / 1E100
          set color 92 + (5 * multiplier)
          let dir get-angle-in-flow-direction flowDirection
          ifelse (dir != nobody)
          [
            if (color <= 97) [ set shape "line half" ]
            if (color < 95) [ set shape "line half 1" ]
            if (color < 93) [ set shape "line half 2" ]
            set heading dir
          ]
          [ set shape "circle" ] ; this is a drainage sink
        ]
      ]
    ]

    ask patches with [ count neighbors with [elevation > seaLevel] = 0 ]
    [
      ask one-of flowHolders-here
      [
        set hidden? true
        ask my-links [ set hidden? true ]
      ]
    ]
  ]
  [
    ask flowHolders
    [
      set hidden? true
      ask my-links [ set hidden? true ]
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

to display-windDirections

  ifelse (show-windDirections)
  [
    let thisPatch self
    ifelse (any? windIndicators-here)
    [
      ask one-of windIndicators-here [ set hidden? false face [windDirection] of thisPatch ]
    ]
    [
      sprout-windIndicators 1 [ set shape "wind" set color black set size 1.5 face [windDirection] of thisPatch ]
    ]
  ]
  [
    if (any? windIndicators-here)
    [
      ask one-of windIndicators-here [ set hidden? true ]
    ]
  ]

end

to refresh-view

  update-plots

  paint-patches

end

to refresh-after-seaLevel-change

  set seaLevel par_seaLevel

  update-plots

  paint-patches

end

to refresh

  refresh-after-seaLevel-change

  set currentDayInYear par_initialDayInYear

  update-climate

  paint-patches

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; FILE HANDLING ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to export-random-terrain

  set randomSeed randomSeed + 1 ; this allows for creating multiple terrains when executing this procedure continuosly

  create-terrain

  export-terrain

end

to export-terrain

  ;set show-transects false

  ;update-transects

  ;;; build a file name as unique to this setting as possible
  let filePath (word "terrains//terrainGenerator_withClimate_v01_" type-of-experiment "_w=" world-width "_h=" world-height "_a=" algorithm-style "_seed=" randomSeed)

  if (type-of-experiment = "user-defined") [ set filePath (word filePath "_" date-and-time) ]
  ;if (type-of-experiment = "defined by expNumber") [set filePath (word filePath "_" expNumber) ]

  ;print filePath print length filePath ; de-bug print

;;; check that filePath does not exceed 100 (not common in this context)
  if (length filePath > 100) [ print "WARNING: file path may be too long, depending on your current directory. Decrease length of file name or increase the limit." set filePath substring filePath 0 100 ]

  let filePathCSV (word filePath ".csv")

  let filePathPNG (word filePath ".png")

  export-view filePathPNG
  export-world filePathCSV

end

to import-terrain

  ;;; build a unique file name according to the user setting
  let filePath (word "terrains//terrainGenerator_withClimate_v01_" type-of-experiment "_w=" world-width "_h=" world-height "_a=" algorithm-style "_seed=" randomSeed)

  if (type-of-experiment = "user-defined") [ set filePath (word filePath "_" date-and-time) ]
  ;if (type-of-experiment = "defined by expNumber") [set filePath (word filePath "_" expNumber) ]

  ;;; check that filePath does not exceed 100 (not common in this context)
  if (length filePath > 100) [ print "WARNING: file path may be too long, depending on your current directory. Decrease length of file name or increase the limit." set filePath substring filePath 0 100 ]

  set filePath (word filePath ".csv")

  ifelse (file-exists? filePath)
  [ import-world filePath ]
  [ print (word "WARNING: could not find '" filePath "'") ]

end
@#$#@#$#@
GRAPHICS-WINDOW
692
10
1305
524
-1
-1
5.0
1
10
1
1
1
0
1
0
1
0
120
0
100
0
0
1
ticks
30.0

BUTTON
9
10
76
57
create
create-terrain
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
341
104
442
149
NIL
landOceanRatio
4
1
11

SLIDER
502
14
674
47
par_seaLevel
par_seaLevel
min (list minElevation par_riftElevation)
min (list maxElevation par_rangeElevation)
0.0
1
1
m
HORIZONTAL

SLIDER
3
207
183
240
par_elevationNoise
par_elevationNoise
1
5000
801.0
100
1
m
HORIZONTAL

SLIDER
3
239
184
272
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
75
10
151
70
randomSeed
0.0
1
0
Number

MONITOR
190
152
288
197
sdElevation
precision sdElevation 4
4
1
11

MONITOR
290
152
372
197
minElevation
precision minElevation 4
4
1
11

MONITOR
368
152
447
197
maxElevation
precision maxElevation 4
4
1
11

INPUTBOX
4
311
92
371
par_numRanges
50.0
1
0
Number

INPUTBOX
91
311
183
371
par_rangeLength
0.2
1
0
Number

INPUTBOX
4
371
91
431
par_numRifts
50.0
1
0
Number

INPUTBOX
91
371
183
431
par_riftLength
0.5
1
0
Number

SLIDER
3
141
181
174
par_riftElevation
par_riftElevation
-5000
0
-5000.0
100
1
m
HORIZONTAL

BUTTON
452
53
685
86
refresh after changing sea level or initial day
refresh
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
3
174
181
207
par_rangeElevation
par_rangeElevation
0
5000
5000.0
100
1
m
HORIZONTAL

MONITOR
187
104
269
149
NIL
count patches
0
1
11

SLIDER
11
497
165
530
par_rangeAggregation
par_rangeAggregation
0
1
0.75
0.01
1
NIL
HORIZONTAL

SLIDER
11
530
165
563
par_riftAggregation
par_riftAggregation
0
1
0.21
.01
1
NIL
HORIZONTAL

INPUTBOX
165
500
272
560
par_numContinents
3.0
1
0
Number

INPUTBOX
272
500
364
560
par_numOceans
10.0
1
0
Number

SLIDER
3
272
184
305
par_smoothingNeighborhood
par_smoothingNeighborhood
0
.1
0.03
.01
1
NIL
HORIZONTAL

MONITOR
270
104
335
149
maxDist
precision maxDist 4
4
1
11

SLIDER
204
390
407
423
par_meanSlope
par_meanSlope
0
80
25.0
0.1
1
degrees
HORIZONTAL

SLIDER
203
427
407
460
par_stdDevSlope
par_stdDevSlope
0
80
20.0
0.01
1
degrees
HORIZONTAL

SLIDER
198
228
402
261
par_axisGridInDegrees
par_axisGridInDegrees
0
90
20.0
0.1
1
degrees
HORIZONTAL

INPUTBOX
490
149
603
209
par_initialDayInYear
1.0
1
0
Number

SLIDER
198
262
402
295
par_yearLenghtInDays
par_yearLenghtInDays
1
600
365.0
1
1
days
HORIZONTAL

MONITOR
599
217
692
262
NIL
sunDeclination
4
1
11

SLIDER
198
296
402
329
par_polarLatitude
par_polarLatitude
par_tropicLatitude
90
66.5
0.1
1
degrees
HORIZONTAL

SLIDER
198
330
402
363
par_tropicLatitude
par_tropicLatitude
0
par_polarLatitude
23.5
0.1
1
degrees
HORIZONTAL

BUTTON
453
111
512
144
+1 day
repeat 1 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
415
292
682
325
par_minTemperatureAtSeaLevel
par_minTemperatureAtSeaLevel
-50
par_maxTemperatureAtSeaLevel
-40.0
1
1
Celsius
HORIZONTAL

SLIDER
415
328
682
361
par_maxTemperatureAtSeaLevel
par_maxTemperatureAtSeaLevel
par_minTemperatureAtSeaLevel
50
40.0
1
1
Celsius
HORIZONTAL

SLIDER
415
363
683
396
par_temperatureDecreaseByElevation
par_temperatureDecreaseByElevation
0
1
0.01
0.001
1
Celsius
HORIZONTAL

SLIDER
415
398
683
431
par_temperatureDecreaseBySlope
par_temperatureDecreaseBySlope
0
1
0.0
0.01
1
Celsius
HORIZONTAL

MONITOR
409
217
511
262
NIL
currentDayInYear
0
1
11

CHOOSER
278
12
417
57
display-mode
display-mode
"terrain" "moisture" "sun angle at noon" "temperature"
0

MONITOR
457
433
551
478
NIL
minTemperature
4
1
11

MONITOR
555
433
649
478
NIL
maxTemperature
4
1
11

MONITOR
516
217
595
262
NIL
currentYear
0
1
11

BUTTON
512
111
573
144
+30 days
repeat 30 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
52
78
109
112
Elevation
14
0.0
1

TEXTBOX
264
209
354
227
Latitude
14
0.0
1

BUTTON
431
13
494
46
refresh
paint-patches
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
263
61
410
94
show-windDirections
show-windDirections
1
1
-1000

TEXTBOX
473
271
623
289
Temperature
14
0.0
1

TEXTBOX
276
370
317
388
Slope
14
0.0
1

TEXTBOX
543
91
579
109
Time
14
0.0
1

BUTTON
573
111
678
144
advance time
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
4
432
197
465
par_featureAngleRange
par_featureAngleRange
0
360
30.0
1
1
º
HORIZONTAL

CHOOSER
15
97
146
142
algorithm-style
algorithm-style
"C#" "NetLogo"
0

TEXTBOX
13
481
177
509
used when algorithm-style = C#
11
0.0
1

TEXTBOX
371
481
555
509
used when algorithm-style = Netlogo
11
0.0
1

INPUTBOX
381
500
536
560
par_continentality
0.5
1
0
Number

SLIDER
14
588
257
621
par_flowAccumulationPerPatch
par_flowAccumulationPerPatch
0
2
1.0
0.001
1
NIL
HORIZONTAL

SLIDER
14
622
257
655
par_flowWaterVolume
par_flowWaterVolume
0
100
1.0
1
1
m^3 / patch
HORIZONTAL

SLIDER
264
588
486
621
par_moistureDiffusionSteps
par_moistureDiffusionSteps
0
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
263
621
486
654
par_moistureTransferenceRate
par_moistureTransferenceRate
0
1
0.2
0.01
1
NIL
HORIZONTAL

TEXTBOX
21
567
252
601
Flow accumulation & moisture
14
0.0
1

CHOOSER
152
12
278
57
type-of-experiment
type-of-experiment
"random" "user-defined" "defined by expNumber"
0

SWITCH
154
61
258
94
show-flows
show-flows
0
1
-1000

BUTTON
789
530
899
563
NIL
export-terrain
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
901
530
1009
563
NIL
import-terrain
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1013
530
1209
563
export-random-terrain (100x)
repeat 100 [ export-random-terrain ]
NIL
1
T
OBSERVER
NIL
9
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

using the C#-style terrain, this is an initial approach to defining patch temperatures and wind directions to be integrated into a climate simulation. Temperature is dependent only on latitude, elevation, and slope (both elevation and slope are average values for a given patch). Wind direction is dependent on latitude (latitude regions are defined according to Coriolis effect). Still no atmoshperic dynamics in this version.

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

line half 1
true
0
Line -7500403 true 150 0 150 300
Rectangle -7500403 true true 135 0 165 150

line half 2
true
0
Line -7500403 true 150 0 150 300
Rectangle -7500403 true true 120 0 180 150

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

wind
true
0
Line -7500403 true 150 0 150 150
Polygon -7500403 true true 120 75 150 0 180 75 120 75

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
