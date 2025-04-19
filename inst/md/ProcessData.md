
#### Processing Data with greenfeedr

The following examples illustrate how to process GreenFeed data in greenfeedr.

**1. Processing GreenFeed data**

```R
 library(greenfeedr)
 data1 <- readr::read_csv("/Users/EXP1/EXP1_GFdata.csv")
 #Evaluating parameters to filter data
 eval <- eval_gfparam(data = data1,
                   start_date = "2025-01-17",
                   end_date = "2025-03-07")
 #Processing data using the selected parameters
 result <- process_gfdata(data = data1,
                          start_date = "2025-01-17",
                          end_date = "2025-03-07",
                          param1 = 2,
                          param2 = 1,
                          min_time = 2)
 #Extracting results
 raw_data <- result$filtered_data
 daily_data <- result$daily_data
 weekly_gases_per_cow <- result$weekly_data
```
