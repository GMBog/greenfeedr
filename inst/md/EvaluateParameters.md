#### Evaluating Parameters for GreenFeed Data Processing with greenfeedr

The following examples illustrate how to evaluate and select filtering parameters for GreenFeed data in greenfeedr.

GreenFeed units record gas emissions during voluntary animal visits. The parameters `param1` (minimum records per day) and `param2` (minimum days with records per week) control a two-level aggregation hierarchy that ensures daily and weekly emission averages are based on enough observations to reliably represent each animal's true emission pattern. `eval_gfparam()` evaluates all parameter combinations and recommends the set that maximizes the repeatability (ICC) of weekly estimates.

**1. Evaluating parameters**

```R
library(greenfeedr)

YourData <- readr::read_csv("/Users/EXP1/EXP1_GFdata.csv")

# Evaluate all combinations of param1, param2, and min_time
# Returns a table sorted by repeatability (ICC) and prints the suggested parameters
evaluation <- eval_gfparam(data       = YourData,
                           start_date = "2025-01-17",
                           end_date   = "2025-03-07",
                           gas        = "CH4"
                          )
```

**2. Evaluating parameters — faster with a reduced grid**

```R
# Use quick = TRUE to evaluate 80 combinations instead of 140
# Useful for large datasets or initial exploration
evaluation <- eval_gfparam(data       = YourData,
                           start_date = "2025-01-17",
                           end_date   = "2025-03-07",
                           gas        = "CH4",
                           quick      = TRUE
                          )
```

**3. Adjusting the animal retention threshold**

```R
# By default, combinations retaining < 80% of animals are excluded
# Use min_retention to tighten or relax this threshold
evaluation <- eval_gfparam(data          = YourData,
                           start_date    = "2025-01-17",
                           end_date      = "2025-03-07",
                           gas           = "CH4",
                           min_retention = 0.90   # require at least 90% of animals
                          )
```

**4. Extracting results**

```R
# The returned data frame is sorted from highest to lowest repeatability (ICC)
# The top row is the recommended parameter combination

head(evaluation)

#   param1 param2 min_time records  N  mean   SD    CV repeatability
# 1      2      3        2     163 33 434.5 51.1 12.01        0.7812
# 2      1      3        2     238 33 435.3 51.5 12.01        0.7798
# 3      2      4        2     128 29 427.5 45.8 10.89        0.7754

# param1       : minimum records per day
# param2       : minimum days with records per week
# min_time     : minimum visit duration (minutes)
# records      : total weekly animal-records retained
# N            : number of unique animals retained
# CV           : mean within-animal coefficient of variation (%) — informational
# repeatability: intraclass correlation coefficient (ICC) — selection criterion
```

**5. Processing data with the suggested parameters**

```R
# Use the param1, param2, and min_time values from the top row of evaluation
# Gases expressed in g/d:
results <- process_gfdata(data       = YourData,
                          start_date = "2025-01-17",
                          end_date   = "2025-03-07",
                          param1     = 2,
                          param2     = 3,
                          min_time   = 2
                         )

# Gases expressed in L/d:
results <- process_gfdata(data       = YourData,
                          start_date = "2025-01-17",
                          end_date   = "2025-03-07",
                          param1     = 2,
                          param2     = 3,
                          min_time   = 2,
                          transform  = TRUE
                         )

# Extracting results
raw_data              <- results$filtered_data
daily_data            <- results$daily_data
weekly_gases_per_cow  <- results$weekly_data
```

**6. Reporting in your manuscript**

When you run `eval_gfparam()`, it automatically prints a ready-to-use methods sentence that includes the package citation. Copy and paste it directly into your manuscript. Example output:

```
-- Suggested methods text (copy/paste into your paper) --
GreenFeed filtering parameters were selected using eval_gfparam from the
greenfeedr R package (Martínez-Boggio et al., 2024, doi:10.3168/jdsc.2024-0662).
Individual visit records were averaged into daily means requiring a minimum of
2 record(s) per day (param1), and daily means were averaged into weekly estimates
requiring a minimum of 3 day(s) with records per week (param2); visits shorter
than 2 min were excluded (min_time). This combination maximized the repeatability
of weekly CH4 estimates (ICC = 0.78) while retaining 97% of study animals.
```
