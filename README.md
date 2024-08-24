
<!-- README.md is generated from README.Rmd. Please edit that file -->

# greenfeedr <img src="man/figures/GFSticker.png" align="right" width="10%"/>

<!-- badges: start -->

[![R-CMD-check](https://github.com/GMBog/greenfeedr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/GMBog/greenfeedr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of greenfeedr is to provide functions for downloading,
processing, and reporting GreenFeed data

More complete information about how to use greenfeedr can be found in:
…, but here you’ll find a brief overview of the functions and some
examples to know how to process your data:

## Installation

You can install the development version of greenfeedr from
[GitHub](https://github.com/GMBog/greenfeedr) with:

``` r
# install.packages("pak")
pak::pak("GMBog/greenfeedr")
```

``` r
library(greenfeedr)
```

## Example

Here we have an example data with 32 dairy cows from one study (45
days).

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

Note that we have 60 combinations of our 3 parameters.

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

We computed the Pearson correlations between parameters and records,
mean and CV of CH4.

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
