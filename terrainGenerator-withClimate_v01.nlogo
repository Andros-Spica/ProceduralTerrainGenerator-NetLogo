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
  maxDist

  ;;; parameters (copies) ===============================================================

  ;;;; elevation
  numContinents
  numOceans
  numRanges
  rangeLength
  numRifts
  riftLength
  seaLevel
  elevationSmoothStep
  smoothingNeighborhood

  ;;;; slope
  meanSlope
  stdDevSlope

  ;;;; latitude
  axisGridInDegrees
  yearLenghtInDays

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
  slope
  latitude latitudeRegion
  windDirection sunAngle temperature
]

breed [ mapSetters mapSetter ]

breed [ windIndicators windIndicator ]

mapSetters-own [ points ]

to setup

  clear-all

  set maxDist (sqrt (( (max-pxcor - min-pxcor) ^ 2) + ((max-pycor - min-pycor) ^ 2)) / 2)

  set numContinents par_numContinents ; 3
  set numOceans par_numOceans ; 10

  set numRanges par_numRanges ; 50
  set rangeLength round ( par_rangeLength * maxDist) ; 0.2
  set maxElevation par_maxElevation ; 5000 m
  set numRifts par_numRifts ; 50
  set riftLength round ( par_riftLength * maxDist) ; 0.5
  set minElevation par_minElevation ; -5000 m
  set seaLevel par_seaLevel ; 0 m
  set SdElevation par_SdElevation ; 800 m
  set elevationSmoothStep par_elevationSmoothStep ; 1
  set smoothingNeighborhood par_smoothingNeighborhood * maxDist ; 0.03 (3% of maxDist)

  set meanSlope par_meanSlope
  set stdDevSlope par_stdDevSlope
  set axisGridInDegrees par_axisGridInDegrees
  set currentDayInYear par_initialDayInYear
  set yearLenghtInDays par_yearLenghtInDays
  set polarLatitude par_polarLatitude
  set tropicLatitude par_tropicLatitude
  set minTemperatureAtSeaLevel par_minTemperatureAtSeaLevel
  set maxTemperatureAtSeaLevel par_maxTemperatureAtSeaLevel
  set temperatureDecreaseByElevation par_temperatureDecreaseByElevation
  set temperatureDecreaseBySlope par_temperatureDecreaseBySlope

  random-seed randomSeed

  reset-timer

  ifelse (algorithm-style = "NetLogo")
  [
    set-landform-NetLogo
  ]
  [
    set-landform-Csharp
  ]

  print (word "Terrain computing time: " timer)

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

  smooth-elevation

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

  smooth-elevation

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

  smooth-elevation

  ask patches with [elevation = 0]
  [
    set elevation random-normal 0 par_sdElevation
  ]

  smooth-elevation

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

to smooth-elevation ;[ smoothingNeighborhood elevationSmoothStep ]

    ask patches
  [
    let smoothedElevation mean [elevation] of patches in-radius smoothingNeighborhood
    set elevation elevation + (smoothedElevation - elevation) * elevationSmoothStep
  ]

end

to refresh-after-seaLevel-change

  set seaLevel par_seaLevel

  update-plots

  paint-patches

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
    ifelse (PaintMode = "terrain")
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
    [
      ifelse (PaintMode = "sun angle at noon")
      [
        set pcolor rgb (255 * (sunAngle / 90)) 0 0
      ]
      [
        if (PaintMode = "temperature")
        [
          set pcolor rgb (255 * (abs (minTemperature - temperature) / abs (maxTemperature - minTemperature))) 0 0
        ]
      ]
    ]
    ifelse (displayWindDirections)
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
  ]

end

to refresh

  set seaLevel par_seaLevel
  set currentDayInYear par_initialDayInYear
  update-climate

  paint-patches

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
68
57
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
330
513
431
558
NIL
landOceanRatio
4
1
11

SLIDER
3
306
175
339
par_seaLevel
par_seaLevel
min (list minElevation par_minElevation)
min (list maxElevation par_maxElevation)
0.0
1
1
m
HORIZONTAL

SLIDER
3
207
175
240
par_sdElevation
par_sdElevation
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
431
514
529
559
oneSdElevation
precision sdElevation 4
4
1
11

MONITOR
531
514
613
559
minElevation
precision minElevation 4
4
1
11

MONITOR
609
514
688
559
maxElevation
precision maxElevation 4
4
1
11

INPUTBOX
4
345
92
405
par_numRanges
50.0
1
0
Number

INPUTBOX
91
345
183
405
par_rangeLength
0.2
1
0
Number

INPUTBOX
4
405
91
465
par_numRifts
50.0
1
0
Number

INPUTBOX
91
405
183
465
par_riftLength
0.5
1
0
Number

SLIDER
3
141
175
174
par_minElevation
par_minElevation
-5000
0
-5000.0
100
1
m
HORIZONTAL

BUTTON
424
21
657
54
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
175
207
par_maxElevation
par_maxElevation
0
5000
5000.0
100
1
m
HORIZONTAL

MONITOR
176
513
258
558
NIL
count patches
0
1
11

SLIDER
9
531
163
564
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
9
564
163
597
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
7
598
114
658
par_numContinents
3.0
1
0
Number

INPUTBOX
114
598
206
658
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
259
513
324
558
maxDist
precision maxDist 4
4
1
11

SLIDER
204
294
392
327
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
331
407
364
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
132
402
165
par_axisGridInDegrees
par_axisGridInDegrees
0
90
23.5
0.1
1
degrees
HORIZONTAL

INPUTBOX
466
150
579
210
par_initialDayInYear
1.0
1
0
Number

SLIDER
198
166
402
199
par_yearLenghtInDays
par_yearLenghtInDays
1
600
365.0
1
1
days
HORIZONTAL

BUTTON
357
61
470
94
NIL
update-climate
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
582
413
675
458
NIL
sunDeclination
4
1
11

SLIDER
198
200
402
233
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
234
402
267
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
426
119
485
152
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
416
241
652
274
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
416
277
651
310
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
416
312
687
345
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
417
349
682
382
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
392
413
494
458
NIL
currentDayInYear
0
1
11

CHOOSER
156
13
295
58
PaintMode
PaintMode
"terrain" "sun angle at noon" "temperature"
2

MONITOR
437
463
531
508
NIL
minTemperature
4
1
11

MONITOR
535
463
629
508
NIL
maxTemperature
4
1
11

MONITOR
499
413
578
458
NIL
currentYear
0
1
11

BUTTON
485
119
546
152
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
113
354
131
Latitude
14
0.0
1

BUTTON
304
21
417
54
refresh display
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
156
60
306
93
displayWindDirections
displayWindDirections
0
1
-1000

TEXTBOX
472
215
622
233
Temperature
14
0.0
1

TEXTBOX
276
274
317
292
Slope
14
0.0
1

TEXTBOX
516
99
552
117
Time
14
0.0
1

BUTTON
546
119
651
152
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
466
197
499
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
11
515
175
543
used when algorithm-style = C#
11
0.0
1

TEXTBOX
205
395
389
423
used when algorithm-style = Netlogo
11
0.0
1

INPUTBOX
215
414
370
474
par_continentality
0.5
1
0
Number

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

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
