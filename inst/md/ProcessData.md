
#### Processing Data with greenfeedr

The following examples illustrate how to process GreenFeed data in greenfeedr.

**1. Processing GreenFeed data**

```R
 library(greenfeedr)
 
 YourData <- readr::read_csv("/Users/EXP1/EXP1_GFdata.csv")
 
 #Evaluating parameters to filter data
 evaluation <- eval_gfparam(data = YourData,
                            start_date = "2025-01-17",
                            end_date = "2025-03-07"
                           )
                                 
 #Processing data using the selected parameters
 #Gases expressed in g/d:
 results <- process_gfdata(data = YourData,
                           start_date = "2025-01-17",
                           end_date = "2025-03-07",
                           param1 = 2,
                           param2 = 1,
                           min_time = 2
                          )
 
 #Gases expressed in L/d:
 results <- process_gfdata(data = YourData,
                           start_date = "2025-01-17",
                           end_date = "2025-03-07",
                           param1 = 2,
                           param2 = 1,
                           min_time = 2,
                           transform = TRUE
                          )
 
 #Extracting results
 raw_data <- results$filtered_data
 daily_data <- results$daily_data
 weekly_gases_per_cow <- results$weekly_data
```
