
<!-- README.md is generated from README.Rmd. Please edit that file -->

# greenfeedr <img src="man/figures/GFSticker.png" align="right" width="15.2%"/>

<!-- badges: start -->

[![CRAN
Status](https://www.r-pkg.org/badges/version/greenfeedr)](https://CRAN.R-project.org/package=greenfeedr)
[![R-CMD-check](https://github.com/GMBog/greenfeedr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/GMBog/greenfeedr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

## Overview

**greenfeedr** provides a set of functions that help you work with
GreenFeed data:

- `get_gfdata()` downloads GreenFeed data via API.
- `report_gfdata()` downloads and generates markdown reports of daily
  and final GreenFeed data.
- `process_gfdata()` processes and averages daily or final GreenFeed
  data.
- `pellin()` processes pellet intakes from GreenFeed units.
- `viseat()` processes GreenFeed visits.

Most of these use the same daily and final data from GreenFeed system.

## Citation

More complete information about how to use greenfeedr can be found in:

## Cheat Sheet

<a href="https://github.com/GMBog/greenfeedr/raw/main/man/figures/Cheatsheet.pdf"><img src="https://github.com/GMBog/greenfeedr/raw/main/man/figures/Cheatsheet.png" width="480" height="360"/></a>

## Installation

You can install the released version of `greenfeedr` from
[CRAN](https://CRAN.R-project.org/package=greenfeedr) with:

``` r
install.packages("greenfeedr")
```

## Usage

Here we present an example of how to use `process_gfdata()`:

``` r
library(greenfeedr)
```

Note that we received the finalized data (or Summarized Data) for our
study using GreenFeed from C-Lock Inc. So, now we need to process all
the daily records obtained.

The data looks like (first 5 cols):

<table style="font-size: 12px;">
<thead>
<tr>
<th style="text-align:left;">
RFID
</th>
<th style="text-align:right;">
FID
</th>
<th style="text-align:left;">
Start Time
</th>
<th style="text-align:left;">
End Time
</th>
<th style="text-align:left;">
Good Data Duration
</th>
<th style="text-align:right;">
Hour Of Day
</th>
<th style="text-align:right;">
CO2 Massflow (g/d)
</th>
<th style="text-align:right;">
CH4 Massflow (g/d)
</th>
<th style="text-align:right;">
O2 Massflow (g/d)
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
840003250681664
</td>
<td style="text-align:right;">
1
</td>
<td style="text-align:left;">
2024-05-13 09:33:24
</td>
<td style="text-align:left;">
2024-05-13 09:36:31
</td>
<td style="text-align:left;">
1899-12-31 00:02:31
</td>
<td style="text-align:right;">
9.556666
</td>
<td style="text-align:right;">
10541.00
</td>
<td style="text-align:right;">
466.9185
</td>
<td style="text-align:right;">
6821.710
</td>
</tr>
<tr>
<td style="text-align:left;">
840003250681664
</td>
<td style="text-align:right;">
1
</td>
<td style="text-align:left;">
2024-05-13 10:25:44
</td>
<td style="text-align:left;">
2024-05-13 10:32:40
</td>
<td style="text-align:left;">
1899-12-31 00:06:09
</td>
<td style="text-align:right;">
10.428889
</td>
<td style="text-align:right;">
14079.59
</td>
<td style="text-align:right;">
579.3398
</td>
<td style="text-align:right;">
8829.182
</td>
</tr>
<tr>
<td style="text-align:left;">
840003250681799
</td>
<td style="text-align:right;">
1
</td>
<td style="text-align:left;">
2024-05-13 12:29:02
</td>
<td style="text-align:left;">
2024-05-13 12:45:19
</td>
<td style="text-align:left;">
1899-12-31 00:10:21
</td>
<td style="text-align:right;">
12.483889
</td>
<td style="text-align:right;">
9273.30
</td>
<td style="text-align:right;">
302.3902
</td>
<td style="text-align:right;">
6193.614
</td>
</tr>
<tr>
<td style="text-align:left;">
840003250681664
</td>
<td style="text-align:right;">
1
</td>
<td style="text-align:left;">
2024-05-13 13:06:20
</td>
<td style="text-align:left;">
2024-05-13 13:12:14
</td>
<td style="text-align:left;">
1899-12-31 00:04:00
</td>
<td style="text-align:right;">
13.105555
</td>
<td style="text-align:right;">
14831.44
</td>
<td style="text-align:right;">
501.0839
</td>
<td style="text-align:right;">
10705.166
</td>
</tr>
<tr>
<td style="text-align:left;">
840003250681664
</td>
<td style="text-align:right;">
1
</td>
<td style="text-align:left;">
2024-05-13 14:34:58
</td>
<td style="text-align:left;">
2024-05-13 14:41:52
</td>
<td style="text-align:left;">
1899-12-31 00:04:55
</td>
<td style="text-align:right;">
14.582778
</td>
<td style="text-align:right;">
20187.44
</td>
<td style="text-align:right;">
759.9457
</td>
<td style="text-align:right;">
11080.463
</td>
</tr>
<tr>
<td style="text-align:left;">
840003234513955
</td>
<td style="text-align:right;">
1
</td>
<td style="text-align:left;">
2024-05-13 14:59:14
</td>
<td style="text-align:left;">
2024-05-13 15:11:50
</td>
<td style="text-align:left;">
1899-12-31 00:03:42
</td>
<td style="text-align:right;">
14.987223
</td>
<td style="text-align:right;">
13994.72
</td>
<td style="text-align:right;">
472.2763
</td>
<td style="text-align:right;">
8997.816
</td>
</tr>
</tbody>
</table>

The first step is to investigate the total number of records, records
per day, and days with records per week we have in our GreenFeed data.

To do this we will use the `process_gfdata()` function and test
threshold values that will define the records we will retain for further
analysis. Note that the function includes :

- **`param1`** is the number of records per day.
  - This parameter controls the minimum number of records that must be
    present for each day in the dataset to be considered valid.
- **`param2`** is the number of days with records per week.
  - This parameter ensures that a minimum number of days within a week
    have valid records to be included in the analysis.
- **`min_time`** is the minimum duration of a record.
  - This parameter specifies the minimum time threshold for each record
    to be considered valid.

We can make an iterative process evaluating all possible combinations of
parameters. Then, we define the parameters as follows:

``` r
# Define the parameter space for param1 (i), param2 (j), and min_time (k):
i <- seq(1, 3)
j <- seq(3, 7)
k <- seq(2, 5)

# Generate all combinations of i, j, and k
param_combinations <- expand.grid(param1 = i, param2 = j, min_time = k)
```

Interestingly, we have 60 combinations of our 3 parameters (param1,
param2, and min_time).

The next step, is to evaluate the function `process_gfdata()` with the
defined set of parameters. Note that the function can handle as argument
a file path to the data files or the data as data frame.

``` r
# Helper function to call process_gfdata and extract relevant information
process_and_summarize <- function(param1, param2, min_time) {
  data <- process_gfdata(
    data = finaldata,
    start_date = "2024-05-13",
    end_date = "2024-05-25",
    param1 = param1,
    param2 = param2,
    min_time = min_time
  )

  # Extract daily_data and weekly_data
  daily_data <- data$daily_data
  weekly_data <- data$weekly_data

  # Calculate the required metrics
  records_d <- nrow(daily_data)
  cows_d <- length(unique(daily_data$RFID))

  mean_dCH4 <- mean(daily_data$CH4GramsPerDay, na.rm = TRUE)
  sd_dCH4 <- sd(daily_data$CH4GramsPerDay, na.rm = TRUE)
  CV_dCH4 <- sd(daily_data$CH4GramsPerDay, na.rm = TRUE) / mean(daily_data$CH4GramsPerDay, na.rm = TRUE)
  mean_dCO2 <- mean(daily_data$CO2GramsPerDay, na.rm = TRUE)
  sd_dCO2 <- sd(daily_data$CO2GramsPerDay, na.rm = TRUE)
  CV_dCO2 <- sd(daily_data$CO2GramsPerDay, na.rm = TRUE) / mean(daily_data$CO2GramsPerDay, na.rm = TRUE)

  records_w <- nrow(weekly_data)
  cows_w <- length(unique(weekly_data$RFID))

  mean_wCH4 <- mean(weekly_data$CH4GramsPerDay, na.rm = TRUE)
  sd_wCH4 <- sd(weekly_data$CH4GramsPerDay, na.rm = TRUE)
  CV_wCH4 <- sd(weekly_data$CH4GramsPerDay, na.rm = TRUE) / mean(weekly_data$CH4GramsPerDay, na.rm = TRUE)
  mean_wCO2 <- mean(weekly_data$CO2GramsPerDay, na.rm = TRUE)
  sd_wCO2 <- sd(weekly_data$CO2GramsPerDay, na.rm = TRUE)
  CV_wCO2 <- sd(weekly_data$CO2GramsPerDay, na.rm = TRUE) / mean(weekly_data$CO2GramsPerDay, na.rm = TRUE)

  # Return a summary row
  return(data.frame(
    param1 = param1,
    param2 = param2,
    min_time = min_time,
    records_d = records_d,
    cows_d = cows_d,
    mean_dCH4 = round(mean_dCH4, 1),
    sd_dCH4 = round(sd_dCH4, 1),
    CV_dCH4 = round(CV_dCH4, 2),
    mean_dCO2 = round(mean_dCO2, 1),
    sd_dCO2 = round(sd_dCO2, 1),
    CV_dCO2 = round(CV_dCO2, 2),
    records_w = records_w,
    cows_w = cows_w,
    mean_wCH4 = round(mean_wCH4, 1),
    sd_wCH4 = round(sd_wCH4, 1),
    CV_wCH4 = round(CV_wCH4, 2),
    mean_wCO2 = round(mean_wCO2, 1),
    sd_wCO2 = round(sd_wCO2, 1),
    CV_wCO2 = round(CV_wCO2, 2)
  ))
}

# Apply helper function to all combinations and combine results into a data frame
data <- param_combinations %>%
  purrr::pmap_dfr(process_and_summarize)
```

Finally, the results from our function will be placed in a data frame
with the following structure:

<table style="font-size: 12px;">
<thead>
<tr>
<th style="text-align:right;">
param1
</th>
<th style="text-align:right;">
param2
</th>
<th style="text-align:right;">
min_time
</th>
<th style="text-align:right;">
records_d
</th>
<th style="text-align:right;">
cows_d
</th>
<th style="text-align:right;">
mean_dCH4
</th>
<th style="text-align:right;">
sd_dCH4
</th>
<th style="text-align:right;">
CV_dCH4
</th>
<th style="text-align:right;">
mean_dCO2
</th>
<th style="text-align:right;">
sd_dCO2
</th>
<th style="text-align:right;">
CV_dCO2
</th>
<th style="text-align:right;">
records_w
</th>
<th style="text-align:right;">
cows_w
</th>
<th style="text-align:right;">
mean_wCH4
</th>
<th style="text-align:right;">
sd_wCH4
</th>
<th style="text-align:right;">
CV_wCH4
</th>
<th style="text-align:right;">
mean_wCO2
</th>
<th style="text-align:right;">
sd_wCO2
</th>
<th style="text-align:right;">
CV_wCO2
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:right;">
1
</td>
<td style="text-align:right;">
3
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
184
</td>
<td style="text-align:right;">
25
</td>
<td style="text-align:right;">
380.2
</td>
<td style="text-align:right;">
110.5
</td>
<td style="text-align:right;">
0.29
</td>
<td style="text-align:right;">
11429.1
</td>
<td style="text-align:right;">
2531.7
</td>
<td style="text-align:right;">
0.22
</td>
<td style="text-align:right;">
33
</td>
<td style="text-align:right;">
19
</td>
<td style="text-align:right;">
382.4
</td>
<td style="text-align:right;">
54.8
</td>
<td style="text-align:right;">
0.14
</td>
<td style="text-align:right;">
11488.1
</td>
<td style="text-align:right;">
1428.0
</td>
<td style="text-align:right;">
0.12
</td>
</tr>
<tr>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
3
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
116
</td>
<td style="text-align:right;">
20
</td>
<td style="text-align:right;">
380.8
</td>
<td style="text-align:right;">
84.9
</td>
<td style="text-align:right;">
0.22
</td>
<td style="text-align:right;">
11450.6
</td>
<td style="text-align:right;">
2076.6
</td>
<td style="text-align:right;">
0.18
</td>
<td style="text-align:right;">
22
</td>
<td style="text-align:right;">
15
</td>
<td style="text-align:right;">
392.7
</td>
<td style="text-align:right;">
58.7
</td>
<td style="text-align:right;">
0.15
</td>
<td style="text-align:right;">
11630.5
</td>
<td style="text-align:right;">
1421.7
</td>
<td style="text-align:right;">
0.12
</td>
</tr>
<tr>
<td style="text-align:right;">
3
</td>
<td style="text-align:right;">
3
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
75
</td>
<td style="text-align:right;">
19
</td>
<td style="text-align:right;">
373.1
</td>
<td style="text-align:right;">
86.7
</td>
<td style="text-align:right;">
0.23
</td>
<td style="text-align:right;">
11394.2
</td>
<td style="text-align:right;">
2185.9
</td>
<td style="text-align:right;">
0.19
</td>
<td style="text-align:right;">
12
</td>
<td style="text-align:right;">
10
</td>
<td style="text-align:right;">
377.1
</td>
<td style="text-align:right;">
62.1
</td>
<td style="text-align:right;">
0.16
</td>
<td style="text-align:right;">
11458.8
</td>
<td style="text-align:right;">
1429.4
</td>
<td style="text-align:right;">
0.12
</td>
</tr>
<tr>
<td style="text-align:right;">
1
</td>
<td style="text-align:right;">
4
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
184
</td>
<td style="text-align:right;">
25
</td>
<td style="text-align:right;">
380.2
</td>
<td style="text-align:right;">
110.5
</td>
<td style="text-align:right;">
0.29
</td>
<td style="text-align:right;">
11429.1
</td>
<td style="text-align:right;">
2531.7
</td>
<td style="text-align:right;">
0.22
</td>
<td style="text-align:right;">
25
</td>
<td style="text-align:right;">
15
</td>
<td style="text-align:right;">
389.9
</td>
<td style="text-align:right;">
50.4
</td>
<td style="text-align:right;">
0.13
</td>
<td style="text-align:right;">
11685.1
</td>
<td style="text-align:right;">
1266.2
</td>
<td style="text-align:right;">
0.11
</td>
</tr>
<tr>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
4
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
116
</td>
<td style="text-align:right;">
20
</td>
<td style="text-align:right;">
380.8
</td>
<td style="text-align:right;">
84.9
</td>
<td style="text-align:right;">
0.22
</td>
<td style="text-align:right;">
11450.6
</td>
<td style="text-align:right;">
2076.6
</td>
<td style="text-align:right;">
0.18
</td>
<td style="text-align:right;">
17
</td>
<td style="text-align:right;">
14
</td>
<td style="text-align:right;">
380.5
</td>
<td style="text-align:right;">
51.6
</td>
<td style="text-align:right;">
0.14
</td>
<td style="text-align:right;">
11367.5
</td>
<td style="text-align:right;">
1264.2
</td>
<td style="text-align:right;">
0.11
</td>
</tr>
<tr>
<td style="text-align:right;">
3
</td>
<td style="text-align:right;">
4
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
75
</td>
<td style="text-align:right;">
19
</td>
<td style="text-align:right;">
373.1
</td>
<td style="text-align:right;">
86.7
</td>
<td style="text-align:right;">
0.23
</td>
<td style="text-align:right;">
11394.2
</td>
<td style="text-align:right;">
2185.9
</td>
<td style="text-align:right;">
0.19
</td>
<td style="text-align:right;">
6
</td>
<td style="text-align:right;">
5
</td>
<td style="text-align:right;">
359.4
</td>
<td style="text-align:right;">
41.9
</td>
<td style="text-align:right;">
0.12
</td>
<td style="text-align:right;">
11310.2
</td>
<td style="text-align:right;">
1595.7
</td>
<td style="text-align:right;">
0.14
</td>
</tr>
<tr>
<td style="text-align:right;">
1
</td>
<td style="text-align:right;">
5
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
184
</td>
<td style="text-align:right;">
25
</td>
<td style="text-align:right;">
380.2
</td>
<td style="text-align:right;">
110.5
</td>
<td style="text-align:right;">
0.29
</td>
<td style="text-align:right;">
11429.1
</td>
<td style="text-align:right;">
2531.7
</td>
<td style="text-align:right;">
0.22
</td>
<td style="text-align:right;">
21
</td>
<td style="text-align:right;">
15
</td>
<td style="text-align:right;">
380.2
</td>
<td style="text-align:right;">
48.1
</td>
<td style="text-align:right;">
0.13
</td>
<td style="text-align:right;">
11444.3
</td>
<td style="text-align:right;">
1182.3
</td>
<td style="text-align:right;">
0.10
</td>
</tr>
<tr>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
5
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
116
</td>
<td style="text-align:right;">
20
</td>
<td style="text-align:right;">
380.8
</td>
<td style="text-align:right;">
84.9
</td>
<td style="text-align:right;">
0.22
</td>
<td style="text-align:right;">
11450.6
</td>
<td style="text-align:right;">
2076.6
</td>
<td style="text-align:right;">
0.18
</td>
<td style="text-align:right;">
8
</td>
<td style="text-align:right;">
7
</td>
<td style="text-align:right;">
361.5
</td>
<td style="text-align:right;">
38.8
</td>
<td style="text-align:right;">
0.11
</td>
<td style="text-align:right;">
11247.0
</td>
<td style="text-align:right;">
1250.1
</td>
<td style="text-align:right;">
0.11
</td>
</tr>
<tr>
<td style="text-align:right;">
3
</td>
<td style="text-align:right;">
5
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
75
</td>
<td style="text-align:right;">
19
</td>
<td style="text-align:right;">
373.1
</td>
<td style="text-align:right;">
86.7
</td>
<td style="text-align:right;">
0.23
</td>
<td style="text-align:right;">
11394.2
</td>
<td style="text-align:right;">
2185.9
</td>
<td style="text-align:right;">
0.19
</td>
<td style="text-align:right;">
4
</td>
<td style="text-align:right;">
3
</td>
<td style="text-align:right;">
360.3
</td>
<td style="text-align:right;">
50.0
</td>
<td style="text-align:right;">
0.14
</td>
<td style="text-align:right;">
11555.9
</td>
<td style="text-align:right;">
2000.6
</td>
<td style="text-align:right;">
0.17
</td>
</tr>
<tr>
<td style="text-align:right;">
1
</td>
<td style="text-align:right;">
6
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
184
</td>
<td style="text-align:right;">
25
</td>
<td style="text-align:right;">
380.2
</td>
<td style="text-align:right;">
110.5
</td>
<td style="text-align:right;">
0.29
</td>
<td style="text-align:right;">
11429.1
</td>
<td style="text-align:right;">
2531.7
</td>
<td style="text-align:right;">
0.22
</td>
<td style="text-align:right;">
14
</td>
<td style="text-align:right;">
11
</td>
<td style="text-align:right;">
378.1
</td>
<td style="text-align:right;">
50.6
</td>
<td style="text-align:right;">
0.13
</td>
<td style="text-align:right;">
11208.1
</td>
<td style="text-align:right;">
1316.1
</td>
<td style="text-align:right;">
0.12
</td>
</tr>
</tbody>
</table>

That gives the user an idea of what are the pros and cons of being more
or less conservative when processing GreenFeed data for analysis. In
general, the more conservative the parameters are, the fewer records are
retained in the data.

## Getting help

If you encounter a clear bug, please file an issue with a minimal
reproducible example on [GitHub](https://github.com/GMBog/greenfeedr).
