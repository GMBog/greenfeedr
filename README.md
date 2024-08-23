
<!-- README.md is generated from README.Rmd. Please edit that file -->

# greenfeedr <img src="man/figures/GFSticker.png" align="right" width="10%"/>

<!-- badges: start -->

[![R-CMD-check](https://github.com/GMBog/greenfeedr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/GMBog/greenfeedr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of greenfeedr is to provide functions for downloading,
processing, and reporting GreenFeed data

## Installation

You can install the development version of greenfeedr from
[GitHub](https://github.com/GMBog/greenfeedr) with:

``` r
# install.packages("pak")
pak::pak("GMBog/greenfeedr")
```

## Example

``` r
library(greenfeedr)
library(ggplot2)
library(dplyr)
```

This is a basic example which shows you how to work with GreenFeed
files:

``` r
# Define file paths for example data
## Example data contains 62 dairy cows from a study using one GreenFeed unit
file1 <- system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr")

# Here you can evaluate the use of different parameters to process the data
# let's check the number of cows we retain when we use param2 = 3 or 4 and min_time = 2 or 3

# Run the function process_gfdata() and create two objects data11 and data12:
data32 <- process_gfdata(file1,
  input_type = "daily",
  start_date = "2024-05-13",
  end_date = "2024-05-25",
  param1 = 2,
  param2 = 3,
  min_time = 2
)
#> [1] "CH4: 387.24 +- 67.37"
#> [1] "CH4 CV = 17.4%"
#> [1] "CO2: 11198.47 +- 1427.23"
#> [1] "CO2 CV = 12.7%"
#> [1] "O2: 7578.41 +- 917.46"
#> [1] "O2 CV = 12.1%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"

data43 <- process_gfdata(file1,
  input_type = "daily",
  start_date = "2024-05-13",
  end_date = "2024-05-25",
  param1 = 2,
  param2 = 4,
  min_time = 3
)
#> [1] "CH4: 392.33 +- 121.81"
#> [1] "CH4 CV = 31%"
#> [1] "CO2: 10994.11 +- 2714.04"
#> [1] "CO2 CV = 24.7%"
#> [1] "O2: 7436.6 +- 1442.16"
#> [1] "O2 CV = 19.4%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"

# Then check the number of cows from each returned data sets:
cat("If we use 3 days with records per week (=param2) and a minimum time of 2 minutes (=min_time), we keep: ", nrow(data32$daily_data), "in data")
#> If we use 3 days with records per week (=param2) and a minimum time of 2 minutes (=min_time), we keep:  62 in data
cat("Otherwise, if we use 4 days with records per week (=param2) and a minimum time of 3 minutes (=min_time), we keep: ", nrow(data43$daily_data), "in data")
#> Otherwise, if we use 4 days with records per week (=param2) and a minimum time of 3 minutes (=min_time), we keep:  35 in data
cat("Ohhh that means we remove half of the cows in the study, due to the parameters defined in data processing")
#> Ohhh that means we remove half of the cows in the study, due to the parameters defined in data processing


# Now, let's check the difference between process daily and final data.
## First note that here we defined the End_Date because we want to process all data from a completed study for which received the final report from C-Lock.

## Example data contains the final report from the same 62 dairy cows from a study using one GreenFeed unit
file2 <- system.file("extdata", "StudyName_FinalReport.xlsx", package = "greenfeedr")

# Run the function process_gfdata() and create one object finaldata:
finaldata <- process_gfdata(file2,
  input_type = "final",
  start_date = "2024-05-13",
  end_date = "2024-05-25",
  param1 = 2,
  param2 = 3,
  min_time = 2
)
#> [1] "CH4: 391.91 +- 58.87"
#> [1] "CH4 CV = 15%"
#> [1] "CO2: 11587.14 +- 1421.59"
#> [1] "CO2 CV = 12.3%"
#> [1] "O2: 7833.91 +- 877.7"
#> [1] "O2 CV = 11.2%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"

head(finaldata)
#> $daily_data
#> # A tibble: 115 × 8
#>    RFID           week     n minutes CH4GramsPerDay CO2GramsPerDay O2GramsPerDay
#>    <chr>         <dbl> <int>   <dbl>          <dbl>          <dbl>         <dbl>
#>  1 840003234513…     1     3    410.           269.          8608.         5690.
#>  2 840003234513…     1     4    436.           422.         11723.         7573.
#>  3 840003234513…     1     2    208.           429.         13552.         8868.
#>  4 840003234513…     2     2    207.           333.         10756.         7803.
#>  5 840003234513…     1     6    972.           410.         11449.         7801.
#>  6 840003234513…     1     5    864.           229.          7370.         5008.
#>  7 840003234513…     1     5    899.           440.         11472.         7198.
#>  8 840003234513…     1     2    304.           404.         13632.         9279.
#>  9 840003234513…     2     3    564.           415.         13117.         8453.
#> 10 840003234513…     2     2    183.           278.         10094.         7279.
#> # ℹ 105 more rows
#> # ℹ 1 more variable: H2GramsPerDay <dbl>
#> 
#> $weekly_data
#> # A tibble: 22 × 9
#>    RFID             week nDays nRecords TotalMin CH4GramsPerDay CO2GramsPerDay
#>    <chr>           <dbl> <int>    <int>    <dbl>          <dbl>          <dbl>
#>  1 840003234513937     1     3        9    1053.           364.         10874.
#>  2 840003234513944     1     4       18    3039.           367.         10514.
#>  3 840003250681645     2     6       27    4660.           402.         13387.
#>  4 840003250681648     2     4       25    4814.           336.         11106.
#>  5 840003250681660     1     4       12    1966.           437.         11944.
#>  6 840003250681660     2     3        7     846.           521.         15100.
#>  7 840003250681661     1     3       14    2735.           368.         11316.
#>  8 840003250681661     2     6       23    4287.           375.         12314.
#>  9 840003250681680     1     3        9    1644.           452.         12286.
#> 10 840003250681680     2     4       13    2214.           500.         13436.
#> # ℹ 12 more rows
#> # ℹ 2 more variables: O2GramsPerDay <dbl>, H2GramsPerDay <dbl>
```
