
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

**greenfeedr** is an R package to easily download, report, and process
GreenFeed data.

The package provides tools for:

- `get_gfdata()` downloads GreenFeed data via API.
- `report_gfdata()` generates reports of GreenFeed data.
- `compare_gfdata()` compares preliminary and finalized GreenFeed data.
- `process_gfdata()` processes and averages GreenFeed data.
- `pellin()` processes pellet intakes from GreenFeed units.
- `viseat()` processes GreenFeed visits.

## Citation

More information about how to use greenfeedr can be found in
[Martinez-Boggio et al. (2024)](https://doi.org/10.3168/jdsc.2024-0662).

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

``` r
library(greenfeedr)
```

## ShinyApp

The greenfeedr ShinyApp is hosted on shinyapps.io here:
<https://gmbog.shinyapps.io/shinyapp/>

When using RStudio you can also run the **greenfeedr** app directly on
your computer with:

``` r
greenfeedr::run_gfapp()
```

## Tutorials

Learn how to use greenfeedr in different workflows:

- [1. Downloading
  Data](https://github.com/GMBog/greenfeedr/tree/main/inst/md/DownloadData.md)

- [2. Reporting
  Data](https://github.com/GMBog/greenfeedr/tree/main/inst/md/ReportData.md)

- [3. Processing
  Data](https://github.com/GMBog/greenfeedr/tree/main/inst/md/ProcessData.md)

- [4. Calculating Pellet
  Intakes](https://github.com/GMBog/greenfeedr/tree/main/inst/md/PelletIntakes.md)

- [5. Checking
  Visitation](https://github.com/GMBog/greenfeedr/tree/main/inst/md/Visitation.md)

## Cheat Sheet

<a href="https://github.com/GMBog/greenfeedr/raw/main/man/figures/Cheatsheet.pdf"><img src="https://github.com/GMBog/greenfeedr/raw/main/man/figures/Cheatsheet.png" width="480" height="360"/></a>

## Getting help

If you encounter a clear bug, please file an issue with a minimal
reproducible example on [GitHub](https://github.com/GMBog/greenfeedr).

For more details, please contact [Guillermo
Martinez-Boggio](mailto:guillermo.martinezboggio@wisc.edu).
