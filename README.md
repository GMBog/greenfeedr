
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

``` r
library(greenfeedr)
```

You can process either preliminary data obtained via the API using
`get_gfdata()` or finalized data downloaded from the [GreenFeed web
interface](https://ext.c-lockinc.com/greenfeed/data.php).

## Examples

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

## Getting help

If you encounter a clear bug, please file an issue with a minimal
reproducible example on [GitHub](https://github.com/GMBog/greenfeedr).

A **premium version** is available, specifically designed for
**commercial setup**. It includes advanced features optimized for
**large-scale data processing, enhanced analytics, and dedicated
support**.

For more details, please contact [Guillermo
Martinez-Boggio](mailto:guillermo.martinezboggio@wisc.edu).
