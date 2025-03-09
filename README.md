
<!-- README.md is generated from README.Rmd. Please edit that file -->

# greenfeedr <img src="man/figures/GFSticker.png" align="right" width="15.2%"/>

<!-- badges: start -->

[![CRAN
Status](https://www.r-pkg.org/badges/version/greenfeedr)](https://CRAN.R-project.org/package=greenfeedr)
![CRAN
Downloads](https://cranlogs.r-pkg.org/badges/grand-total/greenfeedr)
![CRAN
Downloads](https://cranlogs.r-pkg.org/badges/last-month/greenfeedr)
<!-- badges: end -->

## Overview

**greenfeedr** provides a set of functions that help you work with
GreenFeed data:

- `get_gfdata()` downloads GreenFeed data via API.
- `report_gfdata()` downloads and generates markdown reports of
  preliminary and finalized GreenFeed data.
- `compare_gfdata()` compare preliminary and finalized GreenFeed data.
- `process_gfdata()` processes and averages preliminary or finalized
  GreenFeed data.
- `pellin()` processes pellet intakes from GreenFeed units.
- `viseat()` processes GreenFeed visits.

## Citation

More information about how to use greenfeedr can be found in
[Martinez-Boggio et al. (2024)](https://doi.org/10.3168/jdsc.2024-0662).

## Cheat Sheet

<a href="https://github.com/GMBog/greenfeedr/raw/main/man/figures/Cheatsheet.pdf"><img src="https://github.com/GMBog/greenfeedr/raw/main/man/figures/Cheatsheet.png" width="480" height="360"/></a>

## Installation

To install the latest stable release of `greenfeedr` from
[CRAN](https://CRAN.R-project.org/package=greenfeedr), use:

``` r
install.packages("greenfeedr")
```

For the development version with the latest updates, install it from
GitHub:

``` r
install.packages("remotes")
remotes::install_github("GMBog/greenfeedr")
```

## Usage

### Example: Using `process_gfdata()`:

``` r
library(greenfeedr)
```

You can process either preliminary data obtained via the API using
`get_gfdata()` or finalized data downloaded from the [GreenFeed web
interface](https://ext.c-lockinc.com/greenfeed/data.php).

Before diving into the analysis, let’s examine the dataset structure.
Below are the first five column names:

<table style="font-size: 12px;">
<thead>
<tr>
<th style="text-align:left;">
Column.Name
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
RFID
</td>
</tr>
<tr>
<td style="text-align:left;">
Farm Name
</td>
</tr>
<tr>
<td style="text-align:left;">
FID
</td>
</tr>
<tr>
<td style="text-align:left;">
Start Time
</td>
</tr>
<tr>
<td style="text-align:left;">
End Time
</td>
</tr>
<tr>
<td style="text-align:left;">
Good Data Duration
</td>
</tr>
<tr>
<td style="text-align:left;">
Hour Of Day
</td>
</tr>
<tr>
<td style="text-align:left;">
CO2 Massflow (g/d)
</td>
</tr>
<tr>
<td style="text-align:left;">
CH4 Massflow (g/d)
</td>
</tr>
<tr>
<td style="text-align:left;">
O2 Massflow (g/d)
</td>
</tr>
<tr>
<td style="text-align:left;">
H2 Massflow (g/d)
</td>
</tr>
<tr>
<td style="text-align:left;">
H2S Massflow (g/d)
</td>
</tr>
<tr>
<td style="text-align:left;">
Average Airflow (L/s)
</td>
</tr>
<tr>
<td style="text-align:left;">
Airflow CF
</td>
</tr>
<tr>
<td style="text-align:left;">
Average Wind Speed (m/s)
</td>
</tr>
<tr>
<td style="text-align:left;">
Average Wind Direction (deg)
</td>
</tr>
<tr>
<td style="text-align:left;">
Wind CF
</td>
</tr>
<tr>
<td style="text-align:left;">
Was Interrupted
</td>
</tr>
<tr>
<td style="text-align:left;">
Interrupting Tags
</td>
</tr>
<tr>
<td style="text-align:left;">
Midpoint Since Last
</td>
</tr>
<tr>
<td style="text-align:left;">
Midpoint Until Next
</td>
</tr>
<tr>
<td style="text-align:left;">
Standard Deviation of CH4 Baseline
</td>
</tr>
<tr>
<td style="text-align:left;">
Pipe Temperature (deg C)
</td>
</tr>
<tr>
<td style="text-align:left;">
Gas Temperature (deg C)
</td>
</tr>
<tr>
<td style="text-align:left;">
RID
</td>
</tr>
</tbody>
</table>

Before proceeding with analysis, it’s useful to summarize key aspects of
the dataset:

- Total number of records
- Records per day
- Days with records per week
- Weeks with records

This helps in understanding data distribution and completeness before
processing. 🚀

To do this we will use the `process_gfdata()`!!! Note that the function
includes :

- **`param1`** is the number of records per day.
  - This parameter controls the minimum number of records that must be
    present for each day in the dataset to be considered valid.
- **`param2`** is the number of days with records per week.
  - This parameter ensures that a minimum number of days within a week
    have valid records to be included in the analysis.
- **`min_time`** is the minimum duration of a record.
  - This parameter specifies the minimum time threshold for each record
    to be considered valid.

To evaluate the parameters that “best” fit for our data we will use an
extra function `eval_param()`.

``` r
# Define the parameter space for param1 (i), param2 (j), and min_time (k):
i <- seq(1, 6)
j <- seq(1, 7)
k <- seq(2, 6)

# Generate all combinations of i, j, and k
param_combinations <- expand.grid(param1 = i, param2 = j, min_time = k)
```

Interestingly, we have 210 combinations of our 3 parameters (param1,
param2, and min_time).

The next step, is to evaluate the function `process_gfdata()` with the
defined set of parameters. Note that the function can handle as argument
a file path to the data files or the data as data frame.

``` r
data <- eval_gfparam(data = finaldata,
                   start_date = "2024-05-13",
                   end_date = "2024-05-25")
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
1
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
185
</td>
<td style="text-align:right;">
25
</td>
<td style="text-align:right;">
381.6
</td>
<td style="text-align:right;">
113.1
</td>
<td style="text-align:right;">
0.30
</td>
<td style="text-align:right;">
11452.4
</td>
<td style="text-align:right;">
2574.3
</td>
<td style="text-align:right;">
0.22
</td>
<td style="text-align:right;">
45
</td>
<td style="text-align:right;">
25
</td>
<td style="text-align:right;">
385.0
</td>
<td style="text-align:right;">
65.2
</td>
<td style="text-align:right;">
0.17
</td>
<td style="text-align:right;">
11491.8
</td>
<td style="text-align:right;">
1596.0
</td>
<td style="text-align:right;">
0.14
</td>
</tr>
<tr>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
1
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
384.9
</td>
<td style="text-align:right;">
88.5
</td>
<td style="text-align:right;">
0.23
</td>
<td style="text-align:right;">
11546.1
</td>
<td style="text-align:right;">
2098.8
</td>
<td style="text-align:right;">
0.18
</td>
<td style="text-align:right;">
36
</td>
<td style="text-align:right;">
20
</td>
<td style="text-align:right;">
380.7
</td>
<td style="text-align:right;">
64.6
</td>
<td style="text-align:right;">
0.17
</td>
<td style="text-align:right;">
11407.0
</td>
<td style="text-align:right;">
1597.9
</td>
<td style="text-align:right;">
0.14
</td>
</tr>
<tr>
<td style="text-align:right;">
3
</td>
<td style="text-align:right;">
1
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
75
</td>
<td style="text-align:right;">
18
</td>
<td style="text-align:right;">
376.4
</td>
<td style="text-align:right;">
93.8
</td>
<td style="text-align:right;">
0.25
</td>
<td style="text-align:right;">
11457.5
</td>
<td style="text-align:right;">
2291.4
</td>
<td style="text-align:right;">
0.20
</td>
<td style="text-align:right;">
30
</td>
<td style="text-align:right;">
18
</td>
<td style="text-align:right;">
381.8
</td>
<td style="text-align:right;">
75.3
</td>
<td style="text-align:right;">
0.20
</td>
<td style="text-align:right;">
11547.9
</td>
<td style="text-align:right;">
1954.9
</td>
<td style="text-align:right;">
0.17
</td>
</tr>
<tr>
<td style="text-align:right;">
4
</td>
<td style="text-align:right;">
1
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
38
</td>
<td style="text-align:right;">
14
</td>
<td style="text-align:right;">
368.3
</td>
<td style="text-align:right;">
89.7
</td>
<td style="text-align:right;">
0.24
</td>
<td style="text-align:right;">
11196.9
</td>
<td style="text-align:right;">
2330.0
</td>
<td style="text-align:right;">
0.21
</td>
<td style="text-align:right;">
20
</td>
<td style="text-align:right;">
14
</td>
<td style="text-align:right;">
384.1
</td>
<td style="text-align:right;">
87.6
</td>
<td style="text-align:right;">
0.23
</td>
<td style="text-align:right;">
11401.3
</td>
<td style="text-align:right;">
2135.6
</td>
<td style="text-align:right;">
0.19
</td>
</tr>
<tr>
<td style="text-align:right;">
5
</td>
<td style="text-align:right;">
1
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
23
</td>
<td style="text-align:right;">
11
</td>
<td style="text-align:right;">
353.2
</td>
<td style="text-align:right;">
82.4
</td>
<td style="text-align:right;">
0.23
</td>
<td style="text-align:right;">
10945.1
</td>
<td style="text-align:right;">
2193.3
</td>
<td style="text-align:right;">
0.20
</td>
<td style="text-align:right;">
14
</td>
<td style="text-align:right;">
11
</td>
<td style="text-align:right;">
352.2
</td>
<td style="text-align:right;">
87.7
</td>
<td style="text-align:right;">
0.25
</td>
<td style="text-align:right;">
10866.3
</td>
<td style="text-align:right;">
2180.4
</td>
<td style="text-align:right;">
0.20
</td>
</tr>
<tr>
<td style="text-align:right;">
6
</td>
<td style="text-align:right;">
1
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
14
</td>
<td style="text-align:right;">
9
</td>
<td style="text-align:right;">
368.1
</td>
<td style="text-align:right;">
82.6
</td>
<td style="text-align:right;">
0.22
</td>
<td style="text-align:right;">
11476.1
</td>
<td style="text-align:right;">
2143.1
</td>
<td style="text-align:right;">
0.19
</td>
<td style="text-align:right;">
11
</td>
<td style="text-align:right;">
9
</td>
<td style="text-align:right;">
370.6
</td>
<td style="text-align:right;">
83.6
</td>
<td style="text-align:right;">
0.23
</td>
<td style="text-align:right;">
11465.1
</td>
<td style="text-align:right;">
2051.3
</td>
<td style="text-align:right;">
0.18
</td>
</tr>
<tr>
<td style="text-align:right;">
1
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
185
</td>
<td style="text-align:right;">
25
</td>
<td style="text-align:right;">
381.6
</td>
<td style="text-align:right;">
113.1
</td>
<td style="text-align:right;">
0.30
</td>
<td style="text-align:right;">
11452.4
</td>
<td style="text-align:right;">
2574.3
</td>
<td style="text-align:right;">
0.22
</td>
<td style="text-align:right;">
43
</td>
<td style="text-align:right;">
24
</td>
<td style="text-align:right;">
381.9
</td>
<td style="text-align:right;">
63.5
</td>
<td style="text-align:right;">
0.17
</td>
<td style="text-align:right;">
11469.1
</td>
<td style="text-align:right;">
1628.7
</td>
<td style="text-align:right;">
0.14
</td>
</tr>
<tr>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
2
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
384.9
</td>
<td style="text-align:right;">
88.5
</td>
<td style="text-align:right;">
0.23
</td>
<td style="text-align:right;">
11546.1
</td>
<td style="text-align:right;">
2098.8
</td>
<td style="text-align:right;">
0.18
</td>
<td style="text-align:right;">
27
</td>
<td style="text-align:right;">
16
</td>
<td style="text-align:right;">
389.8
</td>
<td style="text-align:right;">
63.0
</td>
<td style="text-align:right;">
0.16
</td>
<td style="text-align:right;">
11648.9
</td>
<td style="text-align:right;">
1514.2
</td>
<td style="text-align:right;">
0.13
</td>
</tr>
<tr>
<td style="text-align:right;">
3
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
75
</td>
<td style="text-align:right;">
18
</td>
<td style="text-align:right;">
376.4
</td>
<td style="text-align:right;">
93.8
</td>
<td style="text-align:right;">
0.25
</td>
<td style="text-align:right;">
11457.5
</td>
<td style="text-align:right;">
2291.4
</td>
<td style="text-align:right;">
0.20
</td>
<td style="text-align:right;">
21
</td>
<td style="text-align:right;">
16
</td>
<td style="text-align:right;">
376.7
</td>
<td style="text-align:right;">
68.3
</td>
<td style="text-align:right;">
0.18
</td>
<td style="text-align:right;">
11365.9
</td>
<td style="text-align:right;">
1613.0
</td>
<td style="text-align:right;">
0.14
</td>
</tr>
<tr>
<td style="text-align:right;">
4
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
2
</td>
<td style="text-align:right;">
38
</td>
<td style="text-align:right;">
14
</td>
<td style="text-align:right;">
368.3
</td>
<td style="text-align:right;">
89.7
</td>
<td style="text-align:right;">
0.24
</td>
<td style="text-align:right;">
11196.9
</td>
<td style="text-align:right;">
2330.0
</td>
<td style="text-align:right;">
0.21
</td>
<td style="text-align:right;">
10
</td>
<td style="text-align:right;">
8
</td>
<td style="text-align:right;">
354.8
</td>
<td style="text-align:right;">
61.3
</td>
<td style="text-align:right;">
0.17
</td>
<td style="text-align:right;">
10972.7
</td>
<td style="text-align:right;">
1776.5
</td>
<td style="text-align:right;">
0.16
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

## Premium Version

A **premium version** is available, specifically designed for
**commercial setup**. It includes advanced features optimized for
**large-scale data processing, enhanced analytics, and dedicated
support**.

For more details, please contact [Guillermo
Martinez-Boggio](guillermo.martinezboggio@wisc.edu).
