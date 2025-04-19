
#### Reporting Data with greenfeedr

The following examples illustrate how to report GreenFeed data in greenfeedr.

**1. Reporting preliminary data**

```R
 library(greenfeedr)
 report_gfdata(user = "GF_USER",
              pass = "GF_PASS",
              exp = "EXP1",
              unit = 716,
              start_date = "2025-01-17",
              #end_date = Sys.Date(),
              input_type = "prelim",
              save_dir = "/Users/Downloads/",
              plot_opt = "All",
              rfid_file = "/Users/EXP1/EXP1_EID.xlsx")
```

**2. Reporting finalized data**

```R
 library(greenfeedr)
 report_gfdata(user = "GF_USER",
              pass = "GF_PASS",
              exp = "EXP2",
              unit = c(300,301),
              start_date = "2025-01-01",
              end_date = "2025-03-14",
              input_type = "final",
              save_dir = "/Users/Downloads/",
              plot_opt = "All",
              rfid_file = "/Users/EXP2/EXP2_EID.xlsx")
```

