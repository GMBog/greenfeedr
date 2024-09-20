
<!-- README.md is generated from README.Rmd. Please edit that file -->

# greenfeedr <img src="man/figures/GFSticker.png" align="right" width="15.2%"/>

<!-- badges: start -->

[![R-CMD-check](https://github.com/GMBog/greenfeedr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/GMBog/greenfeedr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

## Overview

greenfeedr provides a set of functions that help you work with GreenFeed
data:

- `get_gfdata()` downloads GreenFeed data via API.
- `report_gfdata()` downloads and generates markdown reports of daily
  and final GreenFeed data.
- `process_gfdata()` processes and averages daily or final GreenFeed
  data.
- `pellin()` processes pellet intakes from GreenFeed units.
- `viseat()` processes GreenFeed visits.

Most of these use the same daily and final data from GreenFeed system.

## Citation

More complete information about how to use greenfeedr can be found in: …

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

The data looks like:

    #> # A tibble: 5 × 25
    #>      RFID `Farm Name`   FID `Start Time`        `End Time`         
    #>     <dbl>       <dbl> <dbl> <dttm>              <dttm>             
    #> 1 8.40e14     8.40e14     1 2024-05-13 09:33:24 2024-05-13 09:36:31
    #> 2 8.40e14     8.40e14     1 2024-05-13 10:25:44 2024-05-13 10:32:40
    #> 3 8.40e14     8.40e14     1 2024-05-13 12:29:02 2024-05-13 12:45:19
    #> 4 8.40e14     8.40e14     1 2024-05-13 13:06:20 2024-05-13 13:12:14
    #> 5 8.40e14     8.40e14     1 2024-05-13 14:34:58 2024-05-13 14:41:52
    #> # ℹ 20 more variables: `Good Data Duration` <dttm>, `Hour Of Day` <dbl>,
    #> #   `CO2 Massflow (g/d)` <dbl>, `CH4 Massflow (g/d)` <dbl>,
    #> #   `O2 Massflow (g/d)` <dbl>, `H2 Massflow (g/d)` <dbl>,
    #> #   `H2S Massflow (g/d)` <dbl>, `Average Airflow (L/s)` <dbl>,
    #> #   `Airflow CF` <dbl>, `Average Wind Speed (m/s)` <dbl>,
    #> #   `Average Wind Direction (deg)` <dbl>, `Wind CF` <dbl>,
    #> #   `Was Interrupted` <lgl>, `Interrupting Tags` <chr>, …

The first step is to investigate the total number of records, records
per day, and days with records per week we have in our GreenFeed data.

To do this we will use the `process_gfdata()` function and test 3
threshold values that will define the records we will retain for further
analysis. Note that the function includes 3 parameters: - **`param1`**:
The number of records per day. - This parameter controls the minimum
number of records that must be present for each day in the dataset to be
considered valid. - **`param2`**: The number of days with records per
week. - This parameter ensures that a minimum number of days within a
week have valid records to be included in the analysis. -
**`min_time`**: The minimum duration of a record. - This parameter
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
#> Using param1 = 1 , param2 = 3 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 382.39 +- 54.74"
#> [1] "CH4 CV = 14.3%"
#> [1] "CO2: 11480.18 +- 1422.09"
#> [1] "CO2 CV = 12.4%"
#> [1] "O2: 7814.07 +- 944.58"
#> [1] "O2 CV = 12.1%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 3 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 392.54 +- 58.64"
#> [1] "CH4 CV = 14.9%"
#> [1] "CO2: 11615.04 +- 1415.68"
#> [1] "CO2 CV = 12.2%"
#> [1] "O2: 7856.83 +- 874.78"
#> [1] "O2 CV = 11.1%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 3 , param2 = 3 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 377.11 +- 62.09"
#> [1] "CH4 CV = 16.5%"
#> [1] "CO2: 11428.8 +- 1392.8"
#> [1] "CO2 CV = 12.2%"
#> [1] "O2: 7774.5 +- 847.36"
#> [1] "O2 CV = 10.9%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 1 , param2 = 4 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 389.78 +- 50.33"
#> [1] "CH4 CV = 12.9%"
#> [1] "CO2: 11674.57 +- 1259.09"
#> [1] "CO2 CV = 10.8%"
#> [1] "O2: 7906.13 +- 832.51"
#> [1] "O2 CV = 10.5%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 4 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 380.38 +- 51.44"
#> [1] "CH4 CV = 13.5%"
#> [1] "CO2: 11347.47 +- 1250.74"
#> [1] "CO2 CV = 11%"
#> [1] "O2: 7709.47 +- 796.65"
#> [1] "O2 CV = 10.3%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 3 , param2 = 4 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 359.4 +- 41.9"
#> [1] "CH4 CV = 11.7%"
#> [1] "CO2: 11310.19 +- 1595.71"
#> [1] "CO2 CV = 14.1%"
#> [1] "O2: 7779.78 +- 1006.5"
#> [1] "O2 CV = 12.9%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 1 , param2 = 5 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 380.15 +- 48.01"
#> [1] "CH4 CV = 12.6%"
#> [1] "CO2: 11431.81 +- 1170.41"
#> [1] "CO2 CV = 10.2%"
#> [1] "O2: 7749.8 +- 747.06"
#> [1] "O2 CV = 9.6%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 5 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 361.48 +- 38.81"
#> [1] "CH4 CV = 10.7%"
#> [1] "CO2: 11247.01 +- 1250.15"
#> [1] "CO2 CV = 11.1%"
#> [1] "O2: 7705.37 +- 802.44"
#> [1] "O2 CV = 10.4%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 3 , param2 = 5 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 360.33 +- 49.96"
#> [1] "CH4 CV = 13.9%"
#> [1] "CO2: 11555.85 +- 2000.59"
#> [1] "CO2 CV = 17.3%"
#> [1] "O2: 7946.87 +- 1245.56"
#> [1] "O2 CV = 15.7%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 1 , param2 = 6 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 377.95 +- 50.37"
#> [1] "CH4 CV = 13.3%"
#> [1] "CO2: 11189.38 +- 1295.89"
#> [1] "CO2 CV = 11.6%"
#> [1] "O2: 7596.6 +- 833.51"
#> [1] "O2 CV = 11%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 6 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 365.64 +- 47.81"
#> [1] "CH4 CV = 13.1%"
#> [1] "CO2: 11420.48 +- 1616.94"
#> [1] "CO2 CV = 14.2%"
#> [1] "O2: 7872.97 +- 1003.77"
#> [1] "O2 CV = 12.7%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 3 , param2 = 6 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 306.12 +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: 9447.76 +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: 6635.55 +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: 0 +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 7 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 355.92 +- 72.44"
#> [1] "CH4 CV = 20.4%"
#> [1] "CO2: 10336.65 +- 1617.65"
#> [1] "CO2 CV = 15.6%"
#> [1] "O2: 7026.66 +- 1020.92"
#> [1] "O2 CV = 14.5%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 7 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 3 , param2 = 7 , min_time = 2
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 3 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 395.07 +- 56.73"
#> [1] "CH4 CV = 14.4%"
#> [1] "CO2: 11691.91 +- 1465.52"
#> [1] "CO2 CV = 12.5%"
#> [1] "O2: 7943.64 +- 990.06"
#> [1] "O2 CV = 12.5%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 3 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 374.58 +- 62.24"
#> [1] "CH4 CV = 16.6%"
#> [1] "CO2: 11058.44 +- 1673.46"
#> [1] "CO2 CV = 15.1%"
#> [1] "O2: 7508.69 +- 1052.61"
#> [1] "O2 CV = 14%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 3 , param2 = 3 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 343.85 +- 80.13"
#> [1] "CH4 CV = 23.3%"
#> [1] "CO2: 11019.55 +- 2857.03"
#> [1] "CO2 CV = 25.9%"
#> [1] "O2: 7739.68 +- 1717.18"
#> [1] "O2 CV = 22.2%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 1 , param2 = 4 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 390.76 +- 59.83"
#> [1] "CH4 CV = 15.3%"
#> [1] "CO2: 11512.5 +- 1500.04"
#> [1] "CO2 CV = 13%"
#> [1] "O2: 7825.07 +- 980.17"
#> [1] "O2 CV = 12.5%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 4 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 407.91 +- 13.63"
#> [1] "CH4 CV = 3.3%"
#> [1] "CO2: 12166.19 +- 1058.25"
#> [1] "CO2 CV = 8.7%"
#> [1] "O2: 8209.07 +- 725.73"
#> [1] "O2 CV = 8.8%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 3 , param2 = 4 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 5 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 379.25 +- 68.57"
#> [1] "CH4 CV = 18.1%"
#> [1] "CO2: 11408.63 +- 1894.93"
#> [1] "CO2 CV = 16.6%"
#> [1] "O2: 7802.85 +- 1245.96"
#> [1] "O2 CV = 16%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 5 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 403.48 +- 12.27"
#> [1] "CH4 CV = 3%"
#> [1] "CO2: 12587.04 +- 1232.48"
#> [1] "CO2 CV = 9.8%"
#> [1] "O2: 8524.65 +- 818.87"
#> [1] "O2 CV = 9.6%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 3 , param2 = 5 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 6 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 405.07 +- 50.63"
#> [1] "CH4 CV = 12.5%"
#> [1] "CO2: 11974.23 +- 1494.78"
#> [1] "CO2 CV = 12.5%"
#> [1] "O2: 8112.64 +- 932.5"
#> [1] "O2 CV = 11.5%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 6 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 413.83 +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: 13809.62 +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: 9367.71 +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: 0 +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 3 , param2 = 6 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 7 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 2 , param2 = 7 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 3 , param2 = 7 , min_time = 3
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 3 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 396.19 +- 64.49"
#> [1] "CH4 CV = 16.3%"
#> [1] "CO2: 11616.2 +- 1614.12"
#> [1] "CO2 CV = 13.9%"
#> [1] "O2: 7962.3 +- 1045.1"
#> [1] "O2 CV = 13.1%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 3 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 372 +- 37.25"
#> [1] "CH4 CV = 10%"
#> [1] "CO2: 11963.47 +- 1569.29"
#> [1] "CO2 CV = 13.1%"
#> [1] "O2: 8288.51 +- 912.68"
#> [1] "O2 CV = 11%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 3 , param2 = 3 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 4 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 406.19 +- 68.78"
#> [1] "CH4 CV = 16.9%"
#> [1] "CO2: 11940.27 +- 1764.71"
#> [1] "CO2 CV = 14.8%"
#> [1] "O2: 8109.57 +- 1127.25"
#> [1] "O2 CV = 13.9%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 4 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 400.73 +- 4.08"
#> [1] "CH4 CV = 1%"
#> [1] "CO2: 13275.1 +- 548.69"
#> [1] "CO2 CV = 4.1%"
#> [1] "O2: 9040.81 +- 475.12"
#> [1] "O2 CV = 5.3%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 3 , param2 = 4 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 5 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 396.51 +- 50.77"
#> [1] "CH4 CV = 12.8%"
#> [1] "CO2: 11968.31 +- 1816.15"
#> [1] "CO2 CV = 15.2%"
#> [1] "O2: 8149.18 +- 1198.12"
#> [1] "O2 CV = 14.7%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 5 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 3 , param2 = 5 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 6 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 396.51 +- 50.77"
#> [1] "CH4 CV = 12.8%"
#> [1] "CO2: 11968.31 +- 1816.15"
#> [1] "CO2 CV = 15.2%"
#> [1] "O2: 8149.18 +- 1198.12"
#> [1] "O2 CV = 14.7%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 6 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 3 , param2 = 6 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 7 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 2 , param2 = 7 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 3 , param2 = 7 , min_time = 4
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 3 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 396.26 +- 71.34"
#> [1] "CH4 CV = 18%"
#> [1] "CO2: 11943.45 +- 2006.88"
#> [1] "CO2 CV = 16.8%"
#> [1] "O2: 8132.21 +- 1267.87"
#> [1] "O2 CV = 15.6%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 3 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 3 , param2 = 3 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 4 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: 388.66 +- 17.43"
#> [1] "CH4 CV = 4.5%"
#> [1] "CO2: 12354.78 +- 1386"
#> [1] "CO2 CV = 11.2%"
#> [1] "O2: 8338.46 +- 1022.06"
#> [1] "O2 CV = 12.3%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"
#> Using param1 = 2 , param2 = 4 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 3 , param2 = 4 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 5 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 2 , param2 = 5 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 3 , param2 = 5 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 6 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 2 , param2 = 6 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 3 , param2 = 6 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 1 , param2 = 7 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 2 , param2 = 7 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
#> Using param1 = 3 , param2 = 7 , min_time = 5
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `GoodDataDuration = case_when(...)`.
#> Caused by warning:
#> ! NAs introduced by coercion
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> [1] "CH4: NaN +- NA"
#> [1] "CH4 CV = NA%"
#> [1] "CO2: NaN +- NA"
#> [1] "CO2 CV = NA%"
#> [1] "O2: NaN +- NA"
#> [1] "O2 CV = NA%"
#> [1] "H2: NaN +- NA"
#> [1] "H2 CV = NA%"
```

Finally, the results from our function will be placed in a data frame
with the following structure:

``` r
head(data)
#>   param1 param2 min_time records_d cows_d mean_dCH4 sd_dCH4 CV_dCH4 mean_dCO2
#> 1      1      3        2       184     25     380.3   110.5    0.29   11426.1
#> 2      2      3        2       116     20     380.9    85.0    0.22   11445.8
#> 3      3      3        2        75     19     373.3    87.0    0.23   11386.8
#> 4      1      4        2       184     25     380.3   110.5    0.29   11426.1
#> 5      2      4        2       116     20     380.9    85.0    0.22   11445.8
#> 6      3      4        2        75     19     373.3    87.0    0.23   11386.8
#>   sd_dCO2 CV_dCO2 records_w cows_w mean_wCH4 sd_wCH4 CV_wCH4 mean_wCO2 sd_wCO2
#> 1  2527.9    0.22        33     19     382.4    54.7    0.14   11480.2  1422.1
#> 2  2069.2    0.18        22     15     392.5    58.6    0.15   11615.0  1415.7
#> 3  2174.8    0.19        12     10     377.1    62.1    0.16   11428.8  1392.8
#> 4  2527.9    0.22        25     15     389.8    50.3    0.13   11674.6  1259.1
#> 5  2069.2    0.18        17     14     380.4    51.4    0.14   11347.5  1250.7
#> 6  2174.8    0.19         6      5     359.4    41.9    0.12   11310.2  1595.7
#>   CV_wCO2
#> 1    0.12
#> 2    0.12
#> 3    0.12
#> 4    0.11
#> 5    0.11
#> 6    0.14
```

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
    #> param2     -0.25   1.00    -0.24     -0.37  -0.33     -0.11   -0.08
    #> min_time   -0.35  -0.24     1.00     -0.45  -0.47      0.49   -0.21
    #> records_w  -0.30  -0.37    -0.45      1.00   0.98      0.11    0.23
    #> cows_w     -0.29  -0.33    -0.47      0.98   1.00      0.12    0.27
    #> mean_wCH4  -0.53  -0.11     0.49      0.11   0.12      1.00   -0.46
    #> CV_wCH4    -0.05  -0.08    -0.21      0.23   0.27     -0.46    1.00

That gives the user an idea of what are the pros and cons of being more
or less conservative when processing GreenFeed data for analysis. In
general, the more conservative the parameters are, the fewer records are
retained in the data.

## Getting help

If you encounter a clear bug, please file an issue with a minimal
reproducible example on [GitHub](https://github.com/GMBog/greenfeedr).
