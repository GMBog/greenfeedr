
<!-- README.md is generated from README.Rmd. Please edit that file -->

# greenfeedr <img src="man/figures/GFSticker.png" align="right" width="15.2%"/>

<!-- badges: start -->

[![R-CMD-check](https://github.com/GMBog/greenfeedr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/GMBog/greenfeedr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

## Overview

greenfeedr provides a set of functions that help you work with GreenFeed
data:

- `get_api_data()` downloads GreenFeed data using API.
- `report_gfdata()` downloads and generates markdown reports of daily
  and final GreenFeed data.
- `process_gfdata()` processes and averages daily or final GreenFeed
  data.
- `pellin()` process pellet intakes from GreenFeed units.
- `viseat()` process GreenFeed visits.

Most of these use the same daily and final data from GreenFeed system.

## Citation

More complete information about how to use greenfeedr can be found in: …

## Installation

You can install the development version of greenfeedr from
[GitHub](https://github.com/GMBog/greenfeedr) with:

``` r
# install.packages("pak")
pak::pak("GMBog/greenfeedr")
```

## Usage

``` r
library(greenfeedr)
```

Here we present an example of how to use `process_gfdata()`:

Note that with the finalized data (or Summarized Data) from GreenFeed
system for our study, we need to process all daily records.

First, we need to explore the number of records we have in our dataset.
To that we use the function `process_gfdata()` and we can test different
threshold values. The function includes 3 parameters: - param1 -
param2 - min_time

We can make an iterative process evaluating all possible combinations of
parameters. Then, we define the parameters:

``` r
# Define the parameter space for param1 (i), param2 (j), and min_time (k):
i <- seq(1, 3)
j <- seq(3, 7)
k <- seq(2, 5)

#Generate all combinations of i, j, and k
param_combinations <- expand.grid(param1 = i, param2 = j, min_time = k)
```

Note that we have 60 combinations of the 3 parameters (param1, param2,
and min_time).

The next step, is to evaluate the function `process_gfdata()` with the
set of parameters defined before.

``` r
# Helper function to call process_gfdata and extract relevant information
process_and_summarize <- function(param1, param2, min_time) {
  data <- process_gfdata(
    file = system.file("extdata", "StudyName_FinalReport.xlsx", package = "greenfeedr"), 
    input_type = "final",
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
```

The results are place in a data frame with the following structure:

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
