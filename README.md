
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
library(greenfeedr)

Exp <- "StudyName"
Unit <- "1"
Start_Date <- "2023-10-23"
End_Date <- "2024-01-12"
Final_report <- system.file("extdata", "StudyName_FinalReport.xlsx", package = "greenfeedr")

finalrep(Exp, Unit, Start_Date, End_Date, Final_report, Plot_opt = "All")
#> Warning: Expecting numeric in U14 / R14C21: got 'TRUE'
#> Warning: Expecting numeric in U15 / R15C21: got 'TRUE'
#> Warning: Expecting numeric in U16 / R16C21: got 'TRUE'
#> Warning: Expecting numeric in T17 / R17C20: got 'TRUE'
#> Warning: Expecting numeric in T18 / R18C20: got 'TRUE'
#> Warning: Expecting numeric in T19 / R19C20: got 'TRUE'
#> Warning: Expecting numeric in U61 / R61C21: got 'TRUE'
#> Warning: Expecting numeric in T62 / R62C20: got 'TRUE'
#> Warning: Expecting numeric in U63 / R63C21: got 'TRUE'
#> Warning: Expecting numeric in U131 / R131C21: got 'TRUE'
#> Warning: Expecting numeric in T161 / R161C20: got 'TRUE'
#> Warning: Expecting numeric in U221 / R221C21: got 'TRUE'
#> Warning: Expecting numeric in T284 / R284C20: got 'TRUE'
#> Warning: Expecting numeric in U380 / R380C21: got 'TRUE'
#> Warning: Expecting numeric in T383 / R383C20: got 'TRUE'
#> Warning: Expecting numeric in T384 / R384C20: got 'TRUE'
#> Warning: Expecting numeric in U419 / R419C21: got 'TRUE'
#> Warning: Expecting numeric in U424 / R424C21: got 'TRUE'
#> Warning: Expecting numeric in U425 / R425C21: got 'TRUE'
#> Warning: Expecting numeric in U426 / R426C21: got 'TRUE'
#> Warning: Expecting numeric in U427 / R427C21: got 'TRUE'
#> Warning: Expecting numeric in U428 / R428C21: got 'TRUE'
#> Warning: Expecting numeric in T429 / R429C20: got 'TRUE'
#> Warning: Expecting numeric in U429 / R429C21: got 'TRUE'
#> Warning: Expecting numeric in T430 / R430C20: got 'TRUE'
#> Warning: Expecting numeric in T431 / R431C20: got 'TRUE'
#> Warning: Expecting numeric in U435 / R435C21: got 'After Last Baseline'
#> Warning: Expecting numeric in U446 / R446C21: got 'TRUE'
#> Warning: Expecting numeric in T448 / R448C20: got 'TRUE'
#> Warning: Expecting numeric in T449 / R449C20: got 'TRUE'
#> Warning: Expecting numeric in U456 / R456C21: got 'TRUE'
#> Warning: Expecting numeric in U457 / R457C21: got 'TRUE'
#> Warning: Expecting numeric in U458 / R458C21: got 'TRUE'
#> Warning: Expecting numeric in T461 / R461C20: got 'TRUE'
#> Warning: Expecting numeric in U466 / R466C21: got 'TRUE'
#> Warning: Expecting numeric in T467 / R467C20: got 'TRUE'
#> processing file: FinalReportsGF.Rmd
#> output file: FinalReportsGF.knit.md
#> /Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools/aarch64/pandoc +RTS -K512m -RTS FinalReportsGF.knit.md --to latex --from markdown+autolink_bare_uris+tex_math_single_backslash --output /private/var/folders/8n/lmf4l1hs7jz2m86j5g16k21c0000gn/T/RtmpRKIwIB/temp_libpath685266620bf/greenfeedr/Report_StudyName.tex --lua-filter /Library/Frameworks/R.framework/Versions/4.4-arm64/Resources/library/rmarkdown/rmarkdown/lua/pagebreak.lua --lua-filter /Library/Frameworks/R.framework/Versions/4.4-arm64/Resources/library/rmarkdown/rmarkdown/lua/latex-div.lua --embed-resources --standalone --highlight-style tango --pdf-engine pdflatex --variable graphics --variable 'geometry:margin=1in' --include-in-header /var/folders/8n/lmf4l1hs7jz2m86j5g16k21c0000gn/T//RtmpzdLj07/rmarkdown-str98f2fb1cd8d.html
#> 
#> Output created: /private/var/folders/8n/lmf4l1hs7jz2m86j5g16k21c0000gn/T/RtmpRKIwIB/temp_libpath685266620bf/greenfeedr/Report_StudyName.pdf
```
