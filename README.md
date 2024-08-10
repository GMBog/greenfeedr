
<!-- README.md is generated from README.Rmd. Please edit that file -->

# greenfeedR

<!-- badges: start -->
<!-- badges: end -->

The goal of greenfeedR is to provide convenient functions to process
GreenFeed files

## Installation

You can install the development version of greenfeedR from
[GitHub](https://github.com/GMBog/greenfeedR) with:

``` r
# install.packages("pak")
pak::pak("GMBog/greenfeedR")
```

## Example

This is a basic example which shows you how to solve a common problem:

``` r
library(greenfeedR)
User = "your_username"
Pass = "your_password"

Exp = "Test"
Unit = "212"
Start_Date = "2024-07-15"
End_Date = Sys.Date()
Dir = "/Users/Downloads"
RFID_file = "/Users/Test_RFID.csv"


#dailyrep(User, Pass, Exp, Unit, Start_Date, End_Date, Dir, RFID_file)
```

What is special about using `README.Rmd` instead of just `README.md`?
You can include R chunks like so:

``` r
summary(cars)
#>      speed           dist       
#>  Min.   : 4.0   Min.   :  2.00  
#>  1st Qu.:12.0   1st Qu.: 26.00  
#>  Median :15.0   Median : 36.00  
#>  Mean   :15.4   Mean   : 42.98  
#>  3rd Qu.:19.0   3rd Qu.: 56.00  
#>  Max.   :25.0   Max.   :120.00
```

You’ll still need to render `README.Rmd` regularly, to keep `README.md`
up-to-date. `devtools::build_readme()` is handy for this.

You can also embed plots, for example:

<img src="man/figures/README-pressure-1.png" width="100%" />

In that case, don’t forget to commit and push the resulting figure
files, so they display on GitHub and CRAN.
