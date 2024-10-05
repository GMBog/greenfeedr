
<!-- README.md is generated from README.Rmd. Please edit that file -->

# greenfeedr <img src="man/figures/GFSticker.png" align="right" width="15.2%"/>

<!-- badges: start -->

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

You can install the development version of greenfeedr from
[GitHub](https://github.com/GMBog/greenfeedr) with:

``` r
# install.packages("pak")
pak::pak("GMBog/greenfeedr")
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

|         RFID |    Farm Name | FID | Start Time          | End Time            |
|-------------:|-------------:|----:|:--------------------|:--------------------|
| 8.400033e+14 | 8.400033e+14 |   1 | 2024-05-13 09:33:24 | 2024-05-13 09:36:31 |
| 8.400033e+14 | 8.400033e+14 |   1 | 2024-05-13 10:25:44 | 2024-05-13 10:32:40 |
| 8.400033e+14 | 8.400033e+14 |   1 | 2024-05-13 12:29:02 | 2024-05-13 12:45:19 |
| 8.400033e+14 | 8.400033e+14 |   1 | 2024-05-13 13:06:20 | 2024-05-13 13:12:14 |
| 8.400033e+14 | 8.400033e+14 |   1 | 2024-05-13 14:34:58 | 2024-05-13 14:41:52 |

The first step is to investigate the total number of records, records
per day, and days with records per week we have in our GreenFeed data.

To do this we will use the `process_gfdata()` function and test 3
threshold values that will define the records we will retain for further
analysis. Note that the function includes 3 parameters:

- **`param1`** is the number of records per day. ➡ This parameter
  controls the minimum number of records that must be present for each
  day in the dataset to be considered valid.

- **`param2`** is the number of days with records per week. ➡ This
  parameter ensures that a minimum number of days within a week have
  valid records to be included in the analysis.

- **`min_time`** is the minimum duration of a record. ➡ This parameter
  specifies the minimum time threshold for each record to be considered
  valid.

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

    #> Using param1 = 1 , param2 = 3 , min_time = 2
    #> [1] "CH4: 382.44 +- 54.8"
    #> [1] "CH4 CV = 14.3%"
    #> [1] "CO2: 11488.13 +- 1427.95"
    #> [1] "CO2 CV = 12.4%"
    #> [1] "O2: 7820.78 +- 949.21"
    #> [1] "O2 CV = 12.1%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 3 , min_time = 2
    #> [1] "CH4: 392.67 +- 58.74"
    #> [1] "CH4 CV = 15%"
    #> [1] "CO2: 11630.54 +- 1421.75"
    #> [1] "CO2 CV = 12.2%"
    #> [1] "O2: 7869.98 +- 878.89"
    #> [1] "O2 CV = 11.2%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 3 , min_time = 2
    #> [1] "CH4: 377.13 +- 62.13"
    #> [1] "CH4 CV = 16.5%"
    #> [1] "CO2: 11458.76 +- 1429.37"
    #> [1] "CO2 CV = 12.5%"
    #> [1] "O2: 7801.62 +- 874.1"
    #> [1] "O2 CV = 11.2%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 4 , min_time = 2
    #> [1] "CH4: 389.85 +- 50.42"
    #> [1] "CH4 CV = 12.9%"
    #> [1] "CO2: 11685.06 +- 1266.23"
    #> [1] "CO2 CV = 10.8%"
    #> [1] "O2: 7914.98 +- 838.47"
    #> [1] "O2 CV = 10.6%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 4 , min_time = 2
    #> [1] "CH4: 380.53 +- 51.64"
    #> [1] "CH4 CV = 13.6%"
    #> [1] "CO2: 11367.53 +- 1264.22"
    #> [1] "CO2 CV = 11.1%"
    #> [1] "O2: 7726.48 +- 805.83"
    #> [1] "O2 CV = 10.4%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 4 , min_time = 2
    #> [1] "CH4: 359.4 +- 41.9"
    #> [1] "CH4 CV = 11.7%"
    #> [1] "CO2: 11310.19 +- 1595.71"
    #> [1] "CO2 CV = 14.1%"
    #> [1] "O2: 7779.78 +- 1006.5"
    #> [1] "O2 CV = 12.9%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 5 , min_time = 2
    #> [1] "CH4: 380.23 +- 48.14"
    #> [1] "CH4 CV = 12.7%"
    #> [1] "CO2: 11444.3 +- 1182.29"
    #> [1] "CO2 CV = 10.3%"
    #> [1] "O2: 7760.33 +- 757.29"
    #> [1] "O2 CV = 9.8%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 5 , min_time = 2
    #> [1] "CH4: 361.48 +- 38.81"
    #> [1] "CH4 CV = 10.7%"
    #> [1] "CO2: 11247.01 +- 1250.15"
    #> [1] "CO2 CV = 11.1%"
    #> [1] "O2: 7705.37 +- 802.44"
    #> [1] "O2 CV = 10.4%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 5 , min_time = 2
    #> [1] "CH4: 360.33 +- 49.96"
    #> [1] "CH4 CV = 13.9%"
    #> [1] "CO2: 11555.85 +- 2000.59"
    #> [1] "CO2 CV = 17.3%"
    #> [1] "O2: 7946.87 +- 1245.56"
    #> [1] "O2 CV = 15.7%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 6 , min_time = 2
    #> [1] "CH4: 378.08 +- 50.57"
    #> [1] "CH4 CV = 13.4%"
    #> [1] "CO2: 11208.12 +- 1316.05"
    #> [1] "CO2 CV = 11.7%"
    #> [1] "O2: 7612.4 +- 850.62"
    #> [1] "O2 CV = 11.2%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 6 , min_time = 2
    #> [1] "CH4: 365.64 +- 47.81"
    #> [1] "CH4 CV = 13.1%"
    #> [1] "CO2: 11420.48 +- 1616.94"
    #> [1] "CO2 CV = 14.2%"
    #> [1] "O2: 7872.97 +- 1003.77"
    #> [1] "O2 CV = 12.7%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 6 , min_time = 2
    #> [1] "CH4: 306.12 +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: 9447.76 +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: 6635.55 +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 7 , min_time = 2
    #> [1] "CH4: 356.37 +- 73.21"
    #> [1] "CH4 CV = 20.5%"
    #> [1] "CO2: 10402.26 +- 1729.21"
    #> [1] "CO2 CV = 16.6%"
    #> [1] "O2: 7081.97 +- 1117.26"
    #> [1] "O2 CV = 15.8%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 7 , min_time = 2
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 7 , min_time = 2
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 3 , min_time = 3
    #> [1] "CH4: 395.07 +- 56.73"
    #> [1] "CH4 CV = 14.4%"
    #> [1] "CO2: 11691.91 +- 1465.52"
    #> [1] "CO2 CV = 12.5%"
    #> [1] "O2: 7943.64 +- 990.06"
    #> [1] "O2 CV = 12.5%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 3 , min_time = 3
    #> [1] "CH4: 374.58 +- 62.24"
    #> [1] "CH4 CV = 16.6%"
    #> [1] "CO2: 11058.44 +- 1673.46"
    #> [1] "CO2 CV = 15.1%"
    #> [1] "O2: 7508.69 +- 1052.61"
    #> [1] "O2 CV = 14%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 3 , min_time = 3
    #> [1] "CH4: 343.85 +- 80.13"
    #> [1] "CH4 CV = 23.3%"
    #> [1] "CO2: 11019.55 +- 2857.03"
    #> [1] "CO2 CV = 25.9%"
    #> [1] "O2: 7739.68 +- 1717.18"
    #> [1] "O2 CV = 22.2%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 4 , min_time = 3
    #> [1] "CH4: 390.76 +- 59.83"
    #> [1] "CH4 CV = 15.3%"
    #> [1] "CO2: 11512.5 +- 1500.04"
    #> [1] "CO2 CV = 13%"
    #> [1] "O2: 7825.07 +- 980.17"
    #> [1] "O2 CV = 12.5%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 4 , min_time = 3
    #> [1] "CH4: 407.91 +- 13.63"
    #> [1] "CH4 CV = 3.3%"
    #> [1] "CO2: 12166.19 +- 1058.25"
    #> [1] "CO2 CV = 8.7%"
    #> [1] "O2: 8209.07 +- 725.73"
    #> [1] "O2 CV = 8.8%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 4 , min_time = 3
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 5 , min_time = 3
    #> [1] "CH4: 379.25 +- 68.57"
    #> [1] "CH4 CV = 18.1%"
    #> [1] "CO2: 11408.63 +- 1894.93"
    #> [1] "CO2 CV = 16.6%"
    #> [1] "O2: 7802.85 +- 1245.96"
    #> [1] "O2 CV = 16%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 5 , min_time = 3
    #> [1] "CH4: 403.48 +- 12.27"
    #> [1] "CH4 CV = 3%"
    #> [1] "CO2: 12587.04 +- 1232.48"
    #> [1] "CO2 CV = 9.8%"
    #> [1] "O2: 8524.65 +- 818.87"
    #> [1] "O2 CV = 9.6%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 5 , min_time = 3
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 6 , min_time = 3
    #> [1] "CH4: 405.07 +- 50.63"
    #> [1] "CH4 CV = 12.5%"
    #> [1] "CO2: 11974.23 +- 1494.78"
    #> [1] "CO2 CV = 12.5%"
    #> [1] "O2: 8112.64 +- 932.5"
    #> [1] "O2 CV = 11.5%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 6 , min_time = 3
    #> [1] "CH4: 413.83 +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: 13809.62 +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: 9367.71 +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 6 , min_time = 3
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 7 , min_time = 3
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 7 , min_time = 3
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 7 , min_time = 3
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 3 , min_time = 4
    #> [1] "CH4: 396.19 +- 64.49"
    #> [1] "CH4 CV = 16.3%"
    #> [1] "CO2: 11616.2 +- 1614.12"
    #> [1] "CO2 CV = 13.9%"
    #> [1] "O2: 7962.3 +- 1045.1"
    #> [1] "O2 CV = 13.1%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 3 , min_time = 4
    #> [1] "CH4: 372 +- 37.25"
    #> [1] "CH4 CV = 10%"
    #> [1] "CO2: 11963.47 +- 1569.29"
    #> [1] "CO2 CV = 13.1%"
    #> [1] "O2: 8288.51 +- 912.68"
    #> [1] "O2 CV = 11%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 3 , min_time = 4
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 4 , min_time = 4
    #> [1] "CH4: 406.19 +- 68.78"
    #> [1] "CH4 CV = 16.9%"
    #> [1] "CO2: 11940.27 +- 1764.71"
    #> [1] "CO2 CV = 14.8%"
    #> [1] "O2: 8109.57 +- 1127.25"
    #> [1] "O2 CV = 13.9%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 4 , min_time = 4
    #> [1] "CH4: 400.73 +- 4.08"
    #> [1] "CH4 CV = 1%"
    #> [1] "CO2: 13275.1 +- 548.69"
    #> [1] "CO2 CV = 4.1%"
    #> [1] "O2: 9040.81 +- 475.12"
    #> [1] "O2 CV = 5.3%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 4 , min_time = 4
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 5 , min_time = 4
    #> [1] "CH4: 396.51 +- 50.77"
    #> [1] "CH4 CV = 12.8%"
    #> [1] "CO2: 11968.31 +- 1816.15"
    #> [1] "CO2 CV = 15.2%"
    #> [1] "O2: 8149.18 +- 1198.12"
    #> [1] "O2 CV = 14.7%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 5 , min_time = 4
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 5 , min_time = 4
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 6 , min_time = 4
    #> [1] "CH4: 396.51 +- 50.77"
    #> [1] "CH4 CV = 12.8%"
    #> [1] "CO2: 11968.31 +- 1816.15"
    #> [1] "CO2 CV = 15.2%"
    #> [1] "O2: 8149.18 +- 1198.12"
    #> [1] "O2 CV = 14.7%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 6 , min_time = 4
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 6 , min_time = 4
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 7 , min_time = 4
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 7 , min_time = 4
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 7 , min_time = 4
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 3 , min_time = 5
    #> [1] "CH4: 396.26 +- 71.34"
    #> [1] "CH4 CV = 18%"
    #> [1] "CO2: 11943.45 +- 2006.88"
    #> [1] "CO2 CV = 16.8%"
    #> [1] "O2: 8132.21 +- 1267.87"
    #> [1] "O2 CV = 15.6%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 3 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 3 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 4 , min_time = 5
    #> [1] "CH4: 388.66 +- 17.43"
    #> [1] "CH4 CV = 4.5%"
    #> [1] "CO2: 12354.78 +- 1386"
    #> [1] "CO2 CV = 11.2%"
    #> [1] "O2: 8338.46 +- 1022.06"
    #> [1] "O2 CV = 12.3%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 4 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 4 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 5 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 5 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 5 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 6 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 6 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 6 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 1 , param2 = 7 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 2 , param2 = 7 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"
    #> Using param1 = 3 , param2 = 7 , min_time = 5
    #> [1] "CH4: NaN +- NA"
    #> [1] "CH4 CV = NA%"
    #> [1] "CO2: NaN +- NA"
    #> [1] "CO2 CV = NA%"
    #> [1] "O2: NaN +- NA"
    #> [1] "O2 CV = NA%"
    #> [1] "H2: NaN +- NA"
    #> [1] "H2 CV = NA%"

Finally, the results from our function will be placed in a data frame
with the following structure:

``` r
knitr::kable(data, format = "markdown")
```

| param1 | param2 | min_time | records_d | cows_d | mean_dCH4 | sd_dCH4 | CV_dCH4 | mean_dCO2 | sd_dCO2 | CV_dCO2 | records_w | cows_w | mean_wCH4 | sd_wCH4 | CV_wCH4 | mean_wCO2 | sd_wCO2 | CV_wCO2 |
|-------:|-------:|---------:|----------:|-------:|----------:|--------:|--------:|----------:|--------:|--------:|----------:|-------:|----------:|--------:|--------:|----------:|--------:|--------:|
|      1 |      3 |        2 |       184 |     25 |     380.2 |   110.5 |    0.29 |   11429.1 |  2531.7 |    0.22 |        33 |     19 |     382.4 |    54.8 |    0.14 |   11488.1 |  1428.0 |    0.12 |
|      2 |      3 |        2 |       116 |     20 |     380.8 |    84.9 |    0.22 |   11450.6 |  2076.6 |    0.18 |        22 |     15 |     392.7 |    58.7 |    0.15 |   11630.5 |  1421.7 |    0.12 |
|      3 |      3 |        2 |        75 |     19 |     373.1 |    86.7 |    0.23 |   11394.2 |  2185.9 |    0.19 |        12 |     10 |     377.1 |    62.1 |    0.16 |   11458.8 |  1429.4 |    0.12 |
|      1 |      4 |        2 |       184 |     25 |     380.2 |   110.5 |    0.29 |   11429.1 |  2531.7 |    0.22 |        25 |     15 |     389.9 |    50.4 |    0.13 |   11685.1 |  1266.2 |    0.11 |
|      2 |      4 |        2 |       116 |     20 |     380.8 |    84.9 |    0.22 |   11450.6 |  2076.6 |    0.18 |        17 |     14 |     380.5 |    51.6 |    0.14 |   11367.5 |  1264.2 |    0.11 |
|      3 |      4 |        2 |        75 |     19 |     373.1 |    86.7 |    0.23 |   11394.2 |  2185.9 |    0.19 |         6 |      5 |     359.4 |    41.9 |    0.12 |   11310.2 |  1595.7 |    0.14 |
|      1 |      5 |        2 |       184 |     25 |     380.2 |   110.5 |    0.29 |   11429.1 |  2531.7 |    0.22 |        21 |     15 |     380.2 |    48.1 |    0.13 |   11444.3 |  1182.3 |    0.10 |
|      2 |      5 |        2 |       116 |     20 |     380.8 |    84.9 |    0.22 |   11450.6 |  2076.6 |    0.18 |         8 |      7 |     361.5 |    38.8 |    0.11 |   11247.0 |  1250.1 |    0.11 |
|      3 |      5 |        2 |        75 |     19 |     373.1 |    86.7 |    0.23 |   11394.2 |  2185.9 |    0.19 |         4 |      3 |     360.3 |    50.0 |    0.14 |   11555.9 |  2000.6 |    0.17 |
|      1 |      6 |        2 |       184 |     25 |     380.2 |   110.5 |    0.29 |   11429.1 |  2531.7 |    0.22 |        14 |     11 |     378.1 |    50.6 |    0.13 |   11208.1 |  1316.1 |    0.12 |
|      2 |      6 |        2 |       116 |     20 |     380.8 |    84.9 |    0.22 |   11450.6 |  2076.6 |    0.18 |         5 |      4 |     365.6 |    47.8 |    0.13 |   11420.5 |  1616.9 |    0.14 |
|      3 |      6 |        2 |        75 |     19 |     373.1 |    86.7 |    0.23 |   11394.2 |  2185.9 |    0.19 |         1 |      1 |     306.1 |      NA |      NA |    9447.8 |      NA |      NA |
|      1 |      7 |        2 |       184 |     25 |     380.2 |   110.5 |    0.29 |   11429.1 |  2531.7 |    0.22 |         4 |      4 |     356.4 |    73.2 |    0.21 |   10402.3 |  1729.2 |    0.17 |
|      2 |      7 |        2 |       116 |     20 |     380.8 |    84.9 |    0.22 |   11450.6 |  2076.6 |    0.18 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      3 |      7 |        2 |        75 |     19 |     373.1 |    86.7 |    0.23 |   11394.2 |  2185.9 |    0.19 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      3 |        3 |       127 |     25 |     387.5 |   112.0 |    0.29 |   11533.3 |  2612.7 |    0.23 |        23 |     14 |     395.1 |    56.7 |    0.14 |   11691.9 |  1465.5 |    0.13 |
|      2 |      3 |        3 |        66 |     16 |     385.2 |   100.0 |    0.26 |   11491.6 |  2509.6 |    0.22 |        13 |     10 |     374.6 |    62.2 |    0.17 |   11058.4 |  1673.5 |    0.15 |
|      3 |      3 |        3 |        31 |     13 |     373.0 |    88.8 |    0.24 |   11316.4 |  2362.3 |    0.21 |         3 |      3 |     343.9 |    80.1 |    0.23 |   11019.5 |  2857.0 |    0.26 |
|      1 |      4 |        3 |       127 |     25 |     387.5 |   112.0 |    0.29 |   11533.3 |  2612.7 |    0.23 |        18 |     14 |     390.8 |    59.8 |    0.15 |   11512.5 |  1500.0 |    0.13 |
|      2 |      4 |        3 |        66 |     16 |     385.2 |   100.0 |    0.26 |   11491.6 |  2509.6 |    0.22 |         5 |      5 |     407.9 |    13.6 |    0.03 |   12166.2 |  1058.3 |    0.09 |
|      3 |      4 |        3 |        31 |     13 |     373.0 |    88.8 |    0.24 |   11316.4 |  2362.3 |    0.21 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      5 |        3 |       127 |     25 |     387.5 |   112.0 |    0.29 |   11533.3 |  2612.7 |    0.23 |         8 |      8 |     379.3 |    68.6 |    0.18 |   11408.6 |  1894.9 |    0.17 |
|      2 |      5 |        3 |        66 |     16 |     385.2 |   100.0 |    0.26 |   11491.6 |  2509.6 |    0.22 |         3 |      3 |     403.5 |    12.3 |    0.03 |   12587.0 |  1232.5 |    0.10 |
|      3 |      5 |        3 |        31 |     13 |     373.0 |    88.8 |    0.24 |   11316.4 |  2362.3 |    0.21 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      6 |        3 |       127 |     25 |     387.5 |   112.0 |    0.29 |   11533.3 |  2612.7 |    0.23 |         6 |      6 |     405.1 |    50.6 |    0.12 |   11974.2 |  1494.8 |    0.12 |
|      2 |      6 |        3 |        66 |     16 |     385.2 |   100.0 |    0.26 |   11491.6 |  2509.6 |    0.22 |         1 |      1 |     413.8 |      NA |      NA |   13809.6 |      NA |      NA |
|      3 |      6 |        3 |        31 |     13 |     373.0 |    88.8 |    0.24 |   11316.4 |  2362.3 |    0.21 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      7 |        3 |       127 |     25 |     387.5 |   112.0 |    0.29 |   11533.3 |  2612.7 |    0.23 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      2 |      7 |        3 |        66 |     16 |     385.2 |   100.0 |    0.26 |   11491.6 |  2509.6 |    0.22 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      3 |      7 |        3 |        31 |     13 |     373.0 |    88.8 |    0.24 |   11316.4 |  2362.3 |    0.21 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      3 |        4 |        83 |     21 |     397.0 |   122.4 |    0.31 |   11753.7 |  2904.9 |    0.25 |        13 |      9 |     396.2 |    64.5 |    0.16 |   11616.2 |  1614.1 |    0.14 |
|      2 |      3 |        4 |        30 |     13 |     381.6 |    71.3 |    0.19 |   11755.4 |  1843.6 |    0.16 |         4 |      3 |     372.0 |    37.3 |    0.10 |   11963.5 |  1569.3 |    0.13 |
|      3 |      3 |        4 |         7 |      4 |     351.2 |    46.9 |    0.13 |   11263.3 |  1874.0 |    0.17 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      4 |        4 |        83 |     21 |     397.0 |   122.4 |    0.31 |   11753.7 |  2904.9 |    0.25 |         9 |      8 |     406.2 |    68.8 |    0.17 |   11940.3 |  1764.7 |    0.15 |
|      2 |      4 |        4 |        30 |     13 |     381.6 |    71.3 |    0.19 |   11755.4 |  1843.6 |    0.16 |         2 |      2 |     400.7 |     4.1 |    0.01 |   13275.1 |   548.7 |    0.04 |
|      3 |      4 |        4 |         7 |      4 |     351.2 |    46.9 |    0.13 |   11263.3 |  1874.0 |    0.17 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      5 |        4 |        83 |     21 |     397.0 |   122.4 |    0.31 |   11753.7 |  2904.9 |    0.25 |         3 |      3 |     396.5 |    50.8 |    0.13 |   11968.3 |  1816.1 |    0.15 |
|      2 |      5 |        4 |        30 |     13 |     381.6 |    71.3 |    0.19 |   11755.4 |  1843.6 |    0.16 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      3 |      5 |        4 |         7 |      4 |     351.2 |    46.9 |    0.13 |   11263.3 |  1874.0 |    0.17 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      6 |        4 |        83 |     21 |     397.0 |   122.4 |    0.31 |   11753.7 |  2904.9 |    0.25 |         3 |      3 |     396.5 |    50.8 |    0.13 |   11968.3 |  1816.1 |    0.15 |
|      2 |      6 |        4 |        30 |     13 |     381.6 |    71.3 |    0.19 |   11755.4 |  1843.6 |    0.16 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      3 |      6 |        4 |         7 |      4 |     351.2 |    46.9 |    0.13 |   11263.3 |  1874.0 |    0.17 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      7 |        4 |        83 |     21 |     397.0 |   122.4 |    0.31 |   11753.7 |  2904.9 |    0.25 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      2 |      7 |        4 |        30 |     13 |     381.6 |    71.3 |    0.19 |   11755.4 |  1843.6 |    0.16 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      3 |      7 |        4 |         7 |      4 |     351.2 |    46.9 |    0.13 |   11263.3 |  1874.0 |    0.17 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      3 |        5 |        46 |     17 |     386.5 |   113.1 |    0.29 |   11502.5 |  2638.9 |    0.23 |         6 |      5 |     396.3 |    71.3 |    0.18 |   11943.5 |  2006.9 |    0.17 |
|      2 |      3 |        5 |        10 |      8 |     373.5 |    71.8 |    0.19 |   11401.1 |  2231.2 |    0.20 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      3 |      3 |        5 |         3 |      2 |     342.7 |    69.5 |    0.20 |   11594.7 |  2920.8 |    0.25 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      4 |        5 |        46 |     17 |     386.5 |   113.1 |    0.29 |   11502.5 |  2638.9 |    0.23 |         3 |      3 |     388.7 |    17.4 |    0.04 |   12354.8 |  1386.0 |    0.11 |
|      2 |      4 |        5 |        10 |      8 |     373.5 |    71.8 |    0.19 |   11401.1 |  2231.2 |    0.20 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      3 |      4 |        5 |         3 |      2 |     342.7 |    69.5 |    0.20 |   11594.7 |  2920.8 |    0.25 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      5 |        5 |        46 |     17 |     386.5 |   113.1 |    0.29 |   11502.5 |  2638.9 |    0.23 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      2 |      5 |        5 |        10 |      8 |     373.5 |    71.8 |    0.19 |   11401.1 |  2231.2 |    0.20 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      3 |      5 |        5 |         3 |      2 |     342.7 |    69.5 |    0.20 |   11594.7 |  2920.8 |    0.25 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      6 |        5 |        46 |     17 |     386.5 |   113.1 |    0.29 |   11502.5 |  2638.9 |    0.23 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      2 |      6 |        5 |        10 |      8 |     373.5 |    71.8 |    0.19 |   11401.1 |  2231.2 |    0.20 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      3 |      6 |        5 |         3 |      2 |     342.7 |    69.5 |    0.20 |   11594.7 |  2920.8 |    0.25 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      1 |      7 |        5 |        46 |     17 |     386.5 |   113.1 |    0.29 |   11502.5 |  2638.9 |    0.23 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      2 |      7 |        5 |        10 |      8 |     373.5 |    71.8 |    0.19 |   11401.1 |  2231.2 |    0.20 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |
|      3 |      7 |        5 |         3 |      2 |     342.7 |    69.5 |    0.20 |   11594.7 |  2920.8 |    0.25 |         0 |      0 |       NaN |      NA |      NA |       NaN |      NA |      NA |

Also, it is possible to compute Pearson correlations between the
different parameters and number of records, and/or the gas production
average.

    #> Daily data:
    #>           param1 param2 min_time records_d cows_d mean_dCH4 CV_dCH4
    #> param1      1.00      0     0.00     -0.62  -0.71     -0.77   -0.75
    #> param2      0.00      1     0.00      0.00   0.00      0.00    0.00
    #> min_time    0.00      0     1.00     -0.74  -0.65     -0.28   -0.25
    #> records_d  -0.62      0    -0.74      1.00   0.90      0.55    0.66
    #> cows_d     -0.71      0    -0.65      0.90   1.00      0.82    0.80
    #> mean_dCH4  -0.77      0    -0.28      0.55   0.82      1.00    0.75
    #> CV_dCH4    -0.75      0    -0.25      0.66   0.80      0.75    1.00

    #> Weekly data:
    #>           param1 param2 min_time records_w cows_w mean_wCH4 CV_wCH4
    #> param1      1.00  -0.25    -0.35     -0.30  -0.29     -0.53   -0.05
    #> param2     -0.25   1.00    -0.24     -0.37  -0.33     -0.10   -0.06
    #> min_time   -0.35  -0.24     1.00     -0.45  -0.47      0.49   -0.21
    #> records_w  -0.30  -0.37    -0.45      1.00   0.98      0.11    0.23
    #> cows_w     -0.29  -0.33    -0.47      0.98   1.00      0.12    0.26
    #> mean_wCH4  -0.53  -0.10     0.49      0.11   0.12      1.00   -0.46
    #> CV_wCH4    -0.05  -0.06    -0.21      0.23   0.26     -0.46    1.00

That gives the user an idea of what are the pros and cons of being more
or less conservative when processing GreenFeed data for analysis. In
general, the more conservative the parameters are, the fewer records are
retained in the data.

## Getting help

If you encounter a clear bug, please file an issue with a minimal
reproducible example on [GitHub](https://github.com/GMBog/greenfeedr).
