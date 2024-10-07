extensions [csv]

patches-own [seasonal-productivity attempts successes initiations duration-successful build-duration start-day end-day duration-interval first-egg-day active-day previous-attempt-outcome build-day chicks-fledged egg-dsp chick-dsp dsp-logit-holder hatchlings-logit-holder fledglings-logit-holder chicks-fledged-holder]
globals [renesting-probability-vector renesting-probability observed-nest-initiations-per-day-vector observed-nest-initiations]; cumdist cumdist2] ; chicks-fledged taken from here

to setup
  clear-all
  file-close-all

  file-open renesting-probability-file
  set renesting-probability-vector csv:from-file renesting-probability-file
  file-open observed-nest-initiations-per-day
  if include-observed-nest-initiations? [
    set observed-nest-initiations-per-day-vector csv:from-file observed-nest-initiations-per-day]

  setup-patches
  select-build-duration
  ;inspect patch 1 1 ; THIS CAN BE SWITCHED ON TO VIEW THE PARAMETERS FOR A INDIVIDUAL NEST AND HOW THEY CHANGE OVER THE SEASON
  reset-ticks
end

to go
  if ticks = 365 [stop]
  if ticks = 364 [output-files]
  reset-first-egg-day
  set renesting-probability first item ticks renesting-probability-vector ;
  start-season?
  build
  survive-day-eggs?
  hatch?
  survive-day-chicks?
  fledge?
  interval-after-attempt
  renest?
  tick
end

to reset-first-egg-day
  ask patches [set first-egg-day 0]
end

to setup-patches
  ask patches [set pcolor black set active-day 0]
  ask patches [set start-day round (random-normal season-start-mean season-start-sd)]

end

to select-build-duration
  ask patches [set build-duration (build-duration-min + random ((build-duration-max + 1) - build-duration-min))]
end

to start-season?
  ask patches with [start-day = ticks + build-duration] [set pcolor orange set build-day 1]
end

to build
  ask patches with [pcolor = orange] [ifelse build-day >= build-duration
   [set pcolor blue set active-day 1 set first-egg-day 1 set build-day 0 set initiations initiations + 1]
   [set build-day build-day + 1]]
end

to survive-day-eggs?
   ask patches [ifelse probability-mode = "logit-scale"
   [set dsp-logit-holder (random-normal egg-dsp-mean egg-dsp-sd) set egg-dsp ((exp dsp-logit-holder / (1 + exp dsp-logit-holder)))]
   [set egg-dsp (random-normal egg-dsp-mean egg-dsp-sd)]]
   ask patches with [pcolor = blue] [ifelse random 9999 < (egg-dsp * 10000)
   [set duration-successful duration-successful + 1 set active-day 1]
   [set pcolor yellow set duration-successful 0 set attempts attempts + 1 set active-day 0 set previous-attempt-outcome "F"]]  ; the female converts to post attempt phase and duration-interval is reset to 0
end

to hatch?
   ask patches with [duration-successful >= (egg-duration)] [set pcolor green]
end

to survive-day-chicks?
   ask patches [ifelse probability-mode = "logit-scale"
   [set dsp-logit-holder (random-normal chick-dsp-mean chick-dsp-sd) set chick-dsp ((exp dsp-logit-holder / (1 + exp dsp-logit-holder)))]
   [set chick-dsp (random-normal chick-dsp-mean chick-dsp-sd)]]
   ask patches with [pcolor = green] [ifelse random 9999 < (chick-dsp * 10000)
   [set duration-successful duration-successful + 1 set active-day 1]
   [set pcolor yellow set duration-successful 0 set attempts attempts + 1 set active-day 0 set previous-attempt-outcome "F"]]  ; the female converts to post attempt phase and duration-interval is reset to 0
end

to fledge?
  if clutch-mode = "Poisson" [
  ask patches [ifelse probability-mode = "logit-scale"
  [set hatchlings-logit-holder (random-normal hatchlings-per-egg-mean hatchlings-per-egg-sd) set fledglings-logit-holder (random-normal fledglings-per-hatchling-mean fledglings-per-hatchling-sd)
        set chicks-fledged ((exp (random-normal clutch-mean clutch-sd)) * (exp hatchlings-logit-holder / (1 + exp hatchlings-logit-holder)) * (exp fledglings-logit-holder / (1 + exp fledglings-logit-holder)))]
  [set chicks-fledged ((exp (random-normal clutch-mean clutch-sd)) * hatchlings-per-egg-mean * fledglings-per-hatchling-mean)]]]
  if clutch-mode = "real" [
  ask patches [ifelse probability-mode = "logit-scale"
  [set hatchlings-logit-holder (random-normal hatchlings-per-egg-mean hatchlings-per-egg-sd) set fledglings-logit-holder (random-normal fledglings-per-hatchling-mean fledglings-per-hatchling-sd)
        set chicks-fledged ((random-normal clutch-mean clutch-sd) * (exp hatchlings-logit-holder / (1 + exp hatchlings-logit-holder)) * (exp fledglings-logit-holder / (1 + exp fledglings-logit-holder)))]
  [set chicks-fledged ((random-normal clutch-mean clutch-sd) * hatchlings-per-egg-mean * fledglings-per-hatchling-mean)]]]

  ask patches [set chicks-fledged-holder (chicks-fledged - floor chicks-fledged)]

  ask patches with [duration-successful >= (chick-duration + egg-duration)] [ifelse random 9999 > (chicks-fledged-holder * 10000)
  [set pcolor yellow set duration-successful 0 set attempts attempts + 1 set successes successes + 1 set active-day 0 set seasonal-productivity seasonal-productivity + (floor chicks-fledged) set previous-attempt-outcome "S"]
  [set pcolor yellow set duration-successful 0 set attempts attempts + 1 set successes successes + 1 set active-day 0 set seasonal-productivity seasonal-productivity + (ceiling chicks-fledged) set previous-attempt-outcome "S"]]
end

to interval-after-attempt
  ask patches with [pcolor = yellow] [set duration-interval duration-interval + 1 set active-day 0]
end

to renest?
  ask patches with [pcolor = yellow and (duration-interval = fail-inter-attempt-interval) and (previous-attempt-outcome = "F")] [ifelse random 9999 < (renesting-probability * 10000)
    [set pcolor orange set duration-interval 0]   ; the female reverts to nesting state and duration-interval is reset to 0
    [set pcolor brown set end-day ticks]]
  ask patches with [pcolor = yellow and (duration-interval = success-inter-attempt-interval) and (previous-attempt-outcome = "S")] [ifelse random 9999 < (renesting-probability * 10000)
    [set pcolor orange set duration-interval 0]
    [set pcolor brown set end-day ticks]]
end


to output-files
  csv:to-file "NETLOGO OUTPUTS/attempts.csv" (list [attempts] of patches)
  export-plot "Simulated nest initiations per day - combined" "NETLOGO OUTPUTS/Simulated nest initiations per day - combined.csv"
  export-plot "Simulated nest initiations per day - by attempt" "NETLOGO OUTPUTS/Simulated nest initiations per day - by attempt.csv"
  export-plot "Observed nest initiations - combined" "NETLOGO OUTPUTS/Observed nest initiations - combined.csv"
  export-plot "Observed nest initiations - by attempt" "NETLOGO OUTPUTS/Observed nest initiations - by attempt.csv"
  export-world "NETLOGO OUTPUTS/world.csv"
end
@#$#@#$#@
GRAPHICS-WINDOW
0
10
1008
1019
-1
-1
10.0
1
10
1
1
1
0
1
1
1
0
99
0
99
1
1
1
ticks
30.0

BUTTON
534
338
608
372
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
453
338
536
372
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
790
245
950
290
range attempts
word min [attempts] of patches \" to \" max [attempts] of patches
17
1
11

INPUTBOX
8
608
164
668
chick-dsp-mean
0.987
1
0
Number

INPUTBOX
5
369
161
429
fail-inter-attempt-interval
9.0
1
0
Number

PLOT
950
249
1495
377
Simulated nest initiations per day - combined
Julian day
Frequency
0.0
365.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum [first-egg-day] of patches"

PLOT
950
623
1552
743
Seasonal history of female [1,1]
NIL
NIL
0.0
365.0
0.0
2.0
true
true
"" ""
PENS
"first egg" 1.0 0 -16777216 true "" "plot [first-egg-day] of patch 1 1"
"active" 1.0 0 -13210332 true "" "plot [active-day] of patch 1 1"

MONITOR
972
638
1034
683
attempts
[attempts] of patch 1 1
17
1
11

MONITOR
1033
638
1095
683
successes
[successes] of patch 1 1
17
1
11

MONITOR
790
155
950
200
mean attempts
mean [attempts] of patches
2
1
11

MONITOR
1002
683
1064
728
fledged
[seasonal-productivity] of patch 1 1
17
1
11

MONITOR
789
11
949
56
mean seasonal productivity
mean [seasonal-productivity] of patches
2
1
11

MONITOR
789
56
949
101
sd seasonal productivity
standard-deviation [seasonal-productivity] of patches
2
1
11

INPUTBOX
5
249
160
309
egg-duration
16.0
1
0
Number

INPUTBOX
5
488
161
548
egg-dsp-mean
0.976
1
0
Number

INPUTBOX
5
428
161
488
success-inter-attempt-interval
12.0
1
0
Number

INPUTBOX
5
133
160
193
build-duration-min
3.0
1
0
Number

INPUTBOX
5
14
160
74
season-start-mean
150.98
1
0
Number

INPUTBOX
5
74
160
134
season-start-sd
5.65
1
0
Number

INPUTBOX
5
309
160
369
chick-duration
13.0
1
0
Number

TEXTBOX
30
707
197
727
MODEL INPUTS
11
0.0
1

TEXTBOX
345
250
512
270
 brown = post-season
11
34.0
0

TEXTBOX
345
175
512
195
 orange = nest building
11
25.0
0

TEXTBOX
345
155
512
175
 black = pre-season
11
0.0
0

TEXTBOX
345
195
512
215
 blue = egg(s) in nest
11
94.0
0

TEXTBOX
345
210
512
230
 green = chicks in nest
11
55.0
0

TEXTBOX
345
230
512
250
 yellow = inter-attempt
11
43.0
0

TEXTBOX
345
95
512
151
 MODEL VISUALISATION\n Each square is one nest, with colour corresponding to its current status:\n
11
0.0
0

MONITOR
789
454
948
499
mean season length
mean [end-day - start-day] of patches
0
1
11

MONITOR
789
544
948
589
range season length
word min [end-day - start-day] of patches \" to \" max [end-day - start-day] of patches
0
1
11

CHOOSER
160
368
316
413
probability-mode
probability-mode
"logit-scale" "probability-scale"
1

CHOOSER
160
413
315
458
clutch-mode
clutch-mode
"Poisson" "real"
1

INPUTBOX
158
13
314
73
clutch-mean
4.13
1
0
Number

INPUTBOX
158
72
314
132
clutch-sd
0.85
1
0
Number

INPUTBOX
158
130
314
190
hatchlings-per-egg-mean
0.812
1
0
Number

INPUTBOX
158
248
314
308
fledglings-per-hatchling-mean
0.809
1
0
Number

INPUTBOX
6
548
162
608
egg-dsp-sd
0.0
1
0
Number

INPUTBOX
8
668
164
728
chick-dsp-sd
0.0
1
0
Number

INPUTBOX
160
190
316
250
hatchlings-per-egg-sd
0.0
1
0
Number

INPUTBOX
160
308
316
368
fledglings-per-hatchling-sd
0.0
1
0
Number

MONITOR
790
200
950
245
sd attempts
standard-deviation [attempts] of patches
2
1
11

MONITOR
789
101
948
146
range seasonal productivity
word min [seasonal-productivity] of patches \" to \" max [seasonal-productivity] of patches
17
1
11

MONITOR
789
500
949
545
sd season length
standard-deviation [end-day - start-day] of patches
0
1
11

MONITOR
791
303
948
348
mean successes
mean [successes] of patches
2
1
11

MONITOR
791
348
948
393
sd successes
standard-deviation [successes] of patches
2
1
11

MONITOR
790
394
948
439
range successes
word min [successes] of patches \" to \" max [successes] of patches
17
1
11

INPUTBOX
159
458
601
518
renesting-probability-file
SPOTTED FLYCATCHER HIGH STEP RE-NESTING PROBABABILITY.csv
1
0
String

PLOT
950
503
1529
623
Simulated nest initiations per day - by attempt
Julian day
NIL
0.0
365.0
0.0
10.0
true
true
"" ""
PENS
"1st" 1.0 2 -2674135 true "" "plot sum [first-egg-day] of patches with [attempts = 0]"
"2nd" 1.0 0 -16777216 true "" "plot sum [first-egg-day] of patches with [attempts = 1]"
"3rd" 1.0 0 -10899396 true "" "plot sum [first-egg-day] of patches with [attempts = 2]"
"4th" 1.0 0 -13345367 true "" "plot sum [first-egg-day] of patches with [attempts = 3]"
"5th" 1.0 0 -955883 true "" "plot sum [first-egg-day] of patches with [attempts = 4]"
"6th" 1.0 0 -2064490 true "" "plot sum [first-egg-day] of patches with [attempts = 5]"

PLOT
950
10
1498
130
Re-nesting probability function
NIL
NIL
0.0
365.0
0.0
1.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot renesting-probability"

INPUTBOX
160
517
602
577
observed-nest-initiations-per-day
SPOTTED FLYCATCHER OBSERVED NEST INITIATIONSallDEVON.csv
1
0
String

PLOT
950
130
1495
250
Observed nest initiations - combined
Julian day
NIL
0.0
365.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot item 0 item ticks observed-nest-initiations-per-day-vector"

MONITOR
740
200
790
245
cv
(standard-deviation [attempts] of patches) / (mean [attempts] of patches)
2
1
11

MONITOR
737
55
792
100
cv
(standard-deviation [seasonal-productivity] of patches)/(mean [seasonal-productivity] of patches)
2
1
11

MONITOR
735
350
792
395
cv
(standard-deviation [successes] of patches) / (mean [successes] of patches)
2
1
11

MONITOR
740
500
790
545
cv
(standard-deviation [end-day - start-day] of patches) / (mean [end-day - start-day] of patches)
2
1
11

MONITOR
650
45
715
90
1 attempt
count patches with [attempts = 1] / count patches
2
1
11

MONITOR
650
90
715
135
2 attempts
count patches with [attempts = 2] / count patches
2
1
11

MONITOR
650
135
715
180
3 attempts
count patches with [attempts = 3] / count patches
2
1
11

MONITOR
650
180
715
225
>3 attempts
count patches with [attempts > 3] / count patches
2
1
11

MONITOR
735
100
792
145
mode
modes [seasonal-productivity] of patches
2
1
11

INPUTBOX
5
192
162
252
build-duration-max
7.0
1
0
Number

SWITCH
160
575
397
608
include-observed-nest-initiations?
include-observed-nest-initiations?
0
1
-1000

SWITCH
450
370
612
403
produce-R-outputs?
produce-R-outputs?
0
1
-1000

PLOT
950
375
1530
503
Observed nest initiations - by attempt
Julian day
Frequency
0.0
365.0
0.0
10.0
true
true
"" ""
PENS
"1st" 1.0 1 -2674135 true "" "plot item 1 item ticks observed-nest-initiations-per-day-vector"
"2nd" 1.0 1 -4539718 true "" "plot item 2 item ticks observed-nest-initiations-per-day-vector"
"3rd" 1.0 1 -13345367 true "" "plot item 3 item ticks observed-nest-initiations-per-day-vector"

@#$#@#$#@
# INDIVIDUAL-BASED STOCHASTIC BREEDING SEASON SIMULATION MODEL

## MODEL DESCRIPTION

The basic model structure follows previous individual-based models (e.g. Beintama & Muskens 1987; Powell et al. 1999), following a female on a “random walk” through a season. The progress and outcome of the season of any one modelled female depends on three broad categories of input parameter: (1) seasonal limit parameters, initial 1st egg date and a re-nesting probability <i>?R</i>, which determine the dates of commencement and cessation of nesting activity for any one female, (2) temporal duration constants (nest construction duration, egg period, nestling period, interval after failure and interval after success), which determine the duration (or maximum duration) of each stage in the nest cycle, and (3) breeding parameters which together determine the fate and output of each attempt and are selected randomly from empirically measured distributions.

An attempt is demarcated as the period between 1st egg date (laying of the first egg) and last active day of that attempt. The date of commencement of breeding activity by each female is determined by random selection from an initial 1st egg date normal distribution; the start of the season is back-dated to the initial 1st egg date minus the nest construction duration. All females make at least one attempt, so averaged outputs represent only the breeding population (estimates could be post-adjusted if the proportion of non-breeding females is estimated/know). The date of cessation of breeding activity is determined by a Bernoulli trial after each attempt, where the probability of success (female makes another attempt) is taken from an indexed vector of <i>?R</i> (3dp) with a value for each Julian day. Bernoulli trials are achieved through the selection of a random number x from a uniform distribution 0 ? x ? 1. If x > <i>?R</i> the trial is a failure and the female halts breeding - the date of cessation is taken as the last active day of the last attempt. If x ? <i>?R</i> the trial is a deemed a success and another attempt is made - the duration of the inter-attempt interval is determined by adding the re-nesting interval (interval after failure or interval after success depending on outcome of last attempt) to the nest construction duration.

The fate of an attempt is determined with reference to daily survival probability estimates. For each female, a random estimate of daily survival at the egg stage (DSPE) and daily survival at the nestling stage (DSPN) are selected from a normal distribution on the logit scale, which is logit-converted to a probability, or else from a normal distribution on the probability scale (see DROP-DOWN SETTINGS, below). Each day within the attempt is treated as a Bernoulli trial (method as with ?R, above) with probability of success (survival) equal to DSPE for the egg period and DSPN for the nestling period. If the nest survives to the maximum duration of the egg period it is considered to have hatched, and if it then survives to the maximum duration of the nestling period it is considered to have fledged. The model assumes hatching and fledging of all eggs and chicks occur on the same day and thus does not take into account hatching or fledging asynchronicity. In the case of a successful attempt, reproductive output is calculated independently as the product of the clutch size, hatchlings/egg and fledglings/hatchling, rounded to the nearest integer. A value for each of these parameters is selected randomly from given distributions for each attempt. A value for clutch size is selected randomly from a normal distribution, which can either be on the log scale and then log-converted to a real value, or on the original scale (see DROP-DOWN SETTINGS, below). The result is rounded to the nearest integer. Hatchlings/egg and fledglings/hatchling are selected randomly either from normal distributions on the logit scale, and then logit-converted to proportions, or from a normal distribution on the probability scale (see DROP-DOWN SETTINGS, below).

## VARIABLE DEFINITIONS

#### GLOBAL VARIABLES SET BY USER ON INTERFACE [TURQUOISE BOXES]

<b>NUMERICAL INPUTS</b>
<b>season-start-mean</b> - Julian days. The mean of a normal distribution of season start dates or, if season-start-sd is set at zero or blank, the season start day for all females.
<b>season-start-sd</b> - Julian days. The standard deviation of a normal distribution of season start dates. Set to zero or blank if all females to start on season-start-mean.
<b>build-duration-min</b> - Days. The minimum number of days a female can spend building the nest. The building duration for any one female is then drawn from a uniform duration between <i>build-duration-min</i> and <i>build-duration-max</i>. For a fixed building duration, set both of these variables equal to that duration.
<b>build-duration-max</b> - Days. The maximum number of days a female can spend building the nest. The building duration for any one female is then drawn from a uniform duration between <i>build-duration-min</i> and <i>build-duration-max</i>. For a fixed building duration, set both of these variables equal to that duration.
<b>egg-duration</b> - Days. The number of days eggs will be in the nest before hatching, assuming survival to that point. This includes both the laying and incubation period combined.
<b>egg-duration</b> - Days. The number of days eggs will be in the nest before hatching, assuming survival to that point. This includes both the laying and incubation period combined.
<b>chick-duration</b> - Days. The number of days chicks will be in the nest before fledging, assuming survival to that point.
<b>fail-inter-attempt-interval</b> - Days. The number of days between the end of a failed nest and initiation of a new nest, assuming female doesn't end breeding season at that point.
<b>success-inter-attempt-interval</b> - Days. The number of days between a the end of a successful nest and initiation of a new nest, assuming female doesn't end breeding season at that point.
<b>egg-dsp-mean</b> Logit- or probability-scale. The mean of a normal distribution of daily survival probability values during the egg stage or, if egg-dsp-sd is set at zero or blank, the fixed daily survival probability during the egg stage. This can be entered on the logit- or probability-scale depending on the setting for probability-mode.
<b>egg-dsp-sd</b> Logit- or probability-scale. The standard deviation of a normal distribution of daily survival probability values during the egg stage. Set to zero or blank if using a fixed daily survival probability during the egg stage. This can be entered on the logit- or probability-scale depending on the setting for probability-mode.
<b>chick-dsp-mean</b> Logit- or probability-scale. The mean of a normal distribution of daily survival probability values during the chick stage or, if chick-dsp-sd is set at zero or blank, the fixed daily survival probability during the chick stage. This can be entered on the logit- or probability-scale depending on the setting for probability-mode.
<b>chick-dsp-sd</b> Logit- or probability-scale. The standard deviation of a normal distribution of daily survival probability values during the chick stage. Set to zero or blank if using a fixed daily survival probability during the chick stage. This can be entered on the logit- or probability-scale depending on the setting for probability-mode.
<b>clutch-mean</b> Natural-logarithm- or integer-scale. The mean of a normal distribution of clutch sizes or, if clutch-sd is set at zero or blank, the fixed clutch size for all nests initiated. This can be entered on the natural-logaritm- or integer-scale depending on the setting for clutch-mode.
<b>clutch-sd</b> Natural-logarithm- or integer-scale. The standard deviation of a normal distribution of clutch sizes. Set at zero or blank if using a fixed clutch size for all nests initiated.
<b>hatchlings-per-egg-mean</b> Logit- or probability-scale. The mean of a normal distribution of number of hatchlings hatched per egg laid or, if hatchlings-per-egg-sd is set at zero or blank, the fixed number of hatchlings hatched per egg laid. This can be entered on the logit- or probability-scale depending on the setting for probability-mode.
<b>hatchlings-per-egg-sd</b> Logit- or probability-scale. The standard deviation of a normal distribution of number of hatchlings hatched per egg laid. Set to zero or blank if using a fixed number of hatchlings hatched per egg laid. This can be entered on the logit- or probability-scale depending on the setting for probability-mode.
<b>fledglings-per-hatchling-mean</b> Logit- or probability-scale. The mean of a normal distribution of number of fledglings fledged per hatchling hatched or, if fledglings-per-egg-sd is set at zero or blank, the fixed number of fledglings fledged per hatchling hatched. This can be entered on the logit- or probability-scale depending on the setting for
<b>fledglings-per-hatchling-sd</b> Logit- or probability-scale. The standard deviation of a normal distribution of number of fledglings fledged per hatchling hatched. Set to zero or blank if using a fixed number of fledglings fledged per hatchling hatched. This can be entered on the logit- or probability-scale depending on the setting for probability-mode.

<b>DROP-DOWN SELECTIONS</b>
<b>probability-mode</b> Tells the model whether distributions (or fixed values) of probability/proportion inputs are given in the logit- or probability-scale. 
<b>clutch-mode</b> Tells the model whether distributions (or fixed values) of clutch size are given on the natural-logarithm- or integer-scale. The former would be appropriate if the values are derived from a Poisson distribution. 

<b>SWITCHES</b>
<b>include-observed-nest-initiations</b> Determines whether observed-nest-initiations-per-day needs to be included (on) or not (off). The model can show an observed distribution of frequency of nest initiations per Julian day for visual comparison to the simulated distribution of frequency of nest initiations per Julian day. This can be useful for validating the model against an observed population. 

<b>TEXT INPUTS</b>
Note that for ease of programming, February 29th is ignored, and all years are assumed to contain 365 days. 
<b>renesting-probability-file</b> File name in the simple format filename.csv of the .csv file containing the re-nesting probability distribution. This .csv file should contain 365 values (one per Julian day) in a single column, with no headers. Each value should be the re-nesting probability (however derived) for that Julian day, where 1 = female is certain to re-nest if previous attemt ends on that day and 0 = female is certain not to renest that day. Any decimal value inbetween can be used. 
<b>observed-nest-initiations-per-day</b> File name in the simple format filename.csv of the .csv file containing the observed distribution of frequency of nest initiations per Julian day. This .csv file should contain 365 values (one per Julian day) in a single column, with no headers. Each value should be the frequency of nests initiated (across the population) for that Julian day. However, these values could also be provided as relative frequencies if, for example, derived from data collected at a different temporal scale (e.g. per week rather than per day). 

#### OUTPUTS ON INTERFACE [YELLOW BOXES]

<b>(1) NUMERICAL OUTPUTS</b>

<b>mean seasonal productivity</b> The mean number of chicks fledged per female for the whole simulated season.
<b>sd seasonal productivity</b> The standard deviation of number of chicks fledged per female for the whole simulated season.
<b>range seasonal productivity</b> The minimum and maximum number of chicks fledged per female for the whole simulated season.
Also provided are the <b>CV</b> coefficient of variation and <b>mode</b> modal average.

<b>mean attemps</b> The mean number of nesting attempts (i.e. at least 1 egg laid) per female for the whole simulated season.
<b>sd attemps</b> The standard deviation of number of nesting attempts (i.e. at least 1 egg laid) per female for the whole simulated season.
<b>range attemps</b> The minimum and maximum number of nesting attempts (i.e. at least 1 egg laid) per female for the whole simulated season.
Also provided are the <b>CV</b> coefficient of variation and <b>mode</b> modal average.

<b>mean successes</b> The mean number of successful nests (i.e. at least 1 chick fledged) per female for the whole simulated season.
<b>sd successes</b> The standard deviation of number of successful nests (i.e. at least 1 chick fledged) per female for the whole simulated season.
<b>range successes</b> The minimum and maximum number of successful nests (i.e. at least 1 chick fledged) per female for the whole simulated season.
Also provided are the <b>CV</b> coefficient of variation and <b>mode</b> modal average.

<b>1 attempt</b> The proportion of females who made exactly 1 attempt.
<b>2 attempt</b> The proportion of females who made exactly 2 attempts.
<b>3 attempt</b> The proportion of females who made exactly 3 attempts.
<b>>3 attempts</b> The proportion of females who made more than 3 attempts.

<b> (2) VISUAL OUTPUTS</b>

<b>Re-nesting probability function</b> A visualisation of the re-nesting probability function entered via the <b>renesting-probability-file</b>, with Julian day on the x-axis and re-nesting probability on the y-axis.
<b>Observed nest initiations - combined</b> A visualisation of the observed nest initiatians entered via the <b>observed-nest-initiations-per-day</b> with Julian day on the x-axis and frquency on the y-axis. These are all nest inititiations combined, regardless of attempt
<b>Simulated nest initiations per day - combined</b> A visualisation of the simulated nest initiatians for all nests of all females in the simulated population, with Julian day on the x-axis and frequency on the y-axis. These are all nest inititiations combined, regardless of attempt.
<b>Observed nest initiations - by attempt</b> A visualisation of the observed nest initiatians entered via the <b>observed-nest-initiations-per-day</b> with Julian day on the x-axis and frquency on the y-axis. If the observed data allow you to determine what is a first, attempt, second attempt, thrd attempt etc. (for example through a detailed study of a colour-ringed population) then these are shown, colour-coded, here. Note, if these data are not available, this plot can be ignored.
<b>Simulated nest initiations per day - by attempt</b> A visualisation of the simulated nest initiatians for all nests of all females in the simulated population, distinguished by whether it is a female's first, second, third etc. attempt, with Julian day on the x-axis and frequency on the y-axis. Because the simulation can track whether each nest initiation is a first attempt, second attempt, third attempt etc., this plot will always display, even if comparable observed data are not available. 

#### STATE VARIABLES SPECIFIC TO FEMALE
<b>pxcor</b> X-coordinate of female in grid. The model is not spatially explicit but for programming reasons females are identified as patches in a 2D grid. There are 100x100 squares = 10,000 females. A female is uniquely identifiable by her XY-coordinate.
<b>pycor</b> Y-coordinate of female in grid. The model is not spatially explicit but for programming reasons females are identified as patches in a 2D grid. There are 100x100 squares = 10,000 females. A female is uniquely identifiable by her XY-coordinate.
<b>pcolor</b> The colour of the patch at that day, numerically coded. This changes through the season according to the female's breeding status. The codes can be seen here: http://ccl.northwestern.edu/netlogo/docs/programming.html#colors, and the representation of breeding status by colour is described above. [NEED TO DO THIS]
<b>plabel</b> Not implemented.
<b>plabel-color</b> Not implemented.
<b>seasonal-productivity</b> Chicks. A running total of chicks fledged for that female within that season. Updates each time a female has a successful nesting attempt, adding on the number of chicks fledged. Will stay at 0 if not attempts are successful.
<b>attempts</b> Running total of nesting attempts made by that female within that season. Increases by 1 for each attempt, whether successful or failed. 
<b>successes</b> Running total of successful nesting attempts made by that female within that season. Increases by 1 for each successful attempt, with a successful attempt defined as any attempt that fledges at least one chick.  
<b>initiations</b>  Running total of initiated nesting attempts made by that female within that season. Increases by 1 for each initiated attempt. This differs from attempts in that it increases by 1 when an attempt is initiated rather than when the attempt is finished (successful or failed). Thus, during any attempt this will always have a value 1 more than <i>attempts</i>, while before the female's season starts, during any inter-attempt intervals, and after the female's season has ended, this will have a value equal to <i>attempts</i>.
<b>duration-successful</b> Days. Within any single attempt by that female, this tracks the number of days that attempt has been active (i.e. has eggs or chicks in the nest). Resets to 0 when the nest either fails or is successful. 
<b>build-duration</b> Days. The number of days that female will take to build a nest, selected based on <i>build-duration-min</i> and <i>build-duration-max</i> (see above). In the current implementation the value is selected per female, rather than per attempt, so will not change for a given female. 
<b>start-day</b> Julian days. The Julian day on which the female starts her first attempt. Selected from a normal distribution of possible start dates, parameterised by <i>season-start-mean</i> and <i>season-start-sd</i> (see above). 
<b>end-day</b> Julian days. The Julian day on which the female finsihed her final attempt (note all females in the model have at least 1 attempt as non-breeding females are not included). Only populated once the final attempt has finished.
<b>duration-interval</b> Days. During any inter-attempt interval, tracks the number of days since the last attempt. Maximum possible value is <i>fail-inter-attempt-interval</i> or <i>success-inter-attempt-interval</i> depending on outcome of previous attempt, after which another attempt is made. Value is 0 before the female starts the season, during any attempt, and after the female's season has ended.
<b>first-egg-day</b> Binary. Whether (1) or not (0) that specific Julian day is a first egg day (i.e. a day when the first egg of a new clutch is laid). Resets to 0 the following day. 
<b>active-day</b> Binary. Whether (1) or not (0) that specific Julian day is during any active attempt (e.g. female has eggs or chicks in the nest). Resets to 0 between attempts and at the end of the female's season. 
<b>previous-attempt-outcome</b> Indicates the outcome of the previous attempt by that female at that point in the season. Set at 0 if no attempts have yet been made, and thereafter "F" if previous attempt failed, or "S" if previous attempt was successful. 
<b>build-day</b> Days. Indicates the number of days spent building so far when the nest is being built. Maximum value is <i>build-duration</i>. Resets to zero once nest building for an attempt is finished.
<b>chicks-fledged</b> Chicks. Decimal calculation of the number of chicks that would be fledged if a female finished a successful attempt on that day. This will vary daily if either of <i>clutch-sd</i>, <i>hatchlings-per-egg-sd</i> or <i>fledglings-per-hatchlings-sd</i> are provided, and is a product of clutch size, hatchlings-per-egg and flegdlings-per-hatchling. In the case that an attempt is successful on a given day, the number of chicks fledged is taken as this value and rounded to the nearest integer. 
<b>egg-dsp</b> The daily survival probability that would occur at the egg stage if the female has eggs on that day. This will vary daily if <i>egg-dsp-sd</i> is provided.
<b>chick-dsp</b> The daily survival probability that would occur at the chick stage if the female has chicks on that day. This will vary daily if <i>chick-dsp-sd</i> is provided.

The model converts values on the logit scale (x) to a value on the probability scale (y), using the formula y=exp(x)/(1+exp(x)). The folloiwng four state variables are included to ensure that when x is selected randomly from a given distribution, that the two values of x in the equation are the same: 
<b>dsp-logit-holder</b> 
<b>hatchlings-logit-holder</b>
<b>fledglings-logit-holder</b>
<b>chicks-fledged-holder<b>

## References

Beintema, A.J. & Muskens, G.J.D.M. 1987. Nesting Success of Birds Breeding in Dutch Agricultural Grasslands. The Journal of Applied Ecology 24: 743.

Powell, L.A., Conroy, M.J., Krementz, D.G. & Lang, J.D. 1999b. A Model to Predict Breeding-Season Productivity for Multibrooded Songbirds. The Auk 116: 1001–1008.
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
NetLogo 6.3.0
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
1
@#$#@#$#@
