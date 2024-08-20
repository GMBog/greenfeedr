
<!-- README.md is generated from README.Rmd. Please edit that file -->

# greenfeedr <img src="man/figures/GFSticker.png" align="right" width="10%"/>

<!-- badges: start -->
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

This is a basic example which shows you how to work with GreenFeed
files:

``` r
library(greenfeedr)

# Lets use an example daily data from a study using dairy cows. 
file1 <- system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr")

# Run the function process_gfdata using the example data.
## Note that End_Date by default is today's data so we don't need to define
data11 <- process_gfdata(file1,
                        Start_Date = "2024-05-13",
                        input_type = "daily",
                        param1 = 2,
                        param2 = 3,
                        min_time = 2)
#> [1] "CH4: 387.24 +- 67.37"
#> [1] "CH4 CV = 17.4%"
#> [1] "CO2: 11198.47 +- 1427.23"
#> [1] "CO2 CV = 12.7%"
#> [1] "O2: 7578.41 +- 917.46"
#> [1] "O2 CV = 12.1%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"

data12 <- process_gfdata(file1,
                        Start_Date = "2024-05-13",
                        input_type = "daily",
                        param1 = 2,
                        param2 = 5,
                        min_time = 3)
#> [1] "CH4: 454.96 +- 78.38"
#> [1] "CH4 CV = 17.2%"
#> [1] "CO2: 12386.83 +- 1758.98"
#> [1] "CO2 CV = 14.2%"
#> [1] "O2: 8204.45 +- 788.7"
#> [1] "O2 CV = 9.6%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"

# The function returns a list with 2 dataset: daily_data and weekly_data
dim(data11$daily_data); dim(data12$daily_data)
#> [1] 62  8
#> [1] 35  8
dim(data11$weekly_data); dim(data12$weekly_data)
#> [1] 10  9
#> [1] 2 9



file2 <- system.file("extdata", "StudyName_FinalReport.xlsx", package = "greenfeedr")
data2 <- process_gfdata(file2,
                        Start_Date = "2024-05-13",
                        End_Date = "2024-05-25",
                        input_type = "final",
                        param1 = 2,
                        param2 = 3,
                        min_time = 2)
#> [1] "CH4: 392.54 +- 58.64"
#> [1] "CH4 CV = 14.9%"
#> [1] "CO2: 11615.04 +- 1415.68"
#> [1] "CO2 CV = 12.2%"
#> [1] "O2: 7856.83 +- 874.78"
#> [1] "O2 CV = 11.1%"
#> [1] "H2: 0 +- 0"
#> [1] "H2 CV = NaN%"

head(data2)
#> $daily_data
#> # A tibble: 116 × 8
#>    RFID           week     n minutes CH4GramsPerDay CO2GramsPerDay O2GramsPerDay
#>    <chr>         <dbl> <int>   <dbl>          <dbl>          <dbl>         <dbl>
#>  1 840003234513…     1     3    8.45           264.          8359.         5622.
#>  2 840003234513…     1     4   10.8            434.         11779.         7620.
#>  3 840003234513…     1     2    4.73           431.         13572.         8810.
#>  4 840003234513…     2     2    4.94           320.         10858.         8025.
#>  5 840003234513…     1     6   23.0            407.         11385.         7818.
#>  6 840003234513…     1     5   14.5            246.          7740.         5201.
#>  7 840003234513…     1     5   17.3            429.         11143.         6986.
#>  8 840003234513…     1     2    5.65           406.         13642.         9239.
#>  9 840003234513…     2     3   14.5            409.         12906.         8339.
#> 10 840003234513…     2     2    4.9            278.          9973.         7165.
#> # ℹ 106 more rows
#> # ℹ 1 more variable: H2GramsPerDay <dbl>
#> 
#> $weekly_data
#> # A tibble: 22 × 9
#>    RFID             week nDays nRecords TotalMin CH4GramsPerDay CO2GramsPerDay
#>    <chr>           <dbl> <int>    <int>    <dbl>          <dbl>          <dbl>
#>  1 840003234513937     1     3        9     24.0           374.         10929.
#>  2 840003234513944     1     4       18     60.4           375.         10651.
#>  3 840003250681645     2     6       27    104.            405.         13499.
#>  4 840003250681648     2     4       25    108.            335.         11047.
#>  5 840003250681660     1     4       12     43.2           440.         11983.
#>  6 840003250681660     2     3        7     21.4           524.         15047.
#>  7 840003250681661     1     3       14     59.3           357.         11035.
#>  8 840003250681661     2     6       23     86.3           377.         12326.
#>  9 840003250681680     1     3        9     33.1           448.         12350.
#> 10 840003250681680     2     4       13     52.2           496.         13313.
#> # ℹ 12 more rows
#> # ℹ 2 more variables: O2GramsPerDay <dbl>, H2GramsPerDay <dbl>
```
