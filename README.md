
<!-- README.md is generated from README.Rmd. Please edit that file -->

# greenfeedr

<!-- badges: start -->
<!-- badges: end -->

The goal of greenfeedr is to provide convenient functions to process
GreenFeed files

## Installation

You can install the development version of greenfeedr from
[GitHub](https://github.com/GMBog/greenfeedr) with:

``` r
# install.packages("pak")
pak::pak("GMBog/greenfeedr")
```

## Example

This is a basic example which shows you how to solve a common problem:

``` r
library(greenfeedr)

Exp <- "StudyName"
Unit <- "1"
Start_Date <- "2023-10-23"
End_Date <- "2024-01-12"
Final_report <- system.file("extdata", "StudyName_FinalReport.xlsx", package = "greenfeedr")

#finalrep(Exp, Unit, Start_Date, End_Date, Final_report, Plot_opt = "All")
```
