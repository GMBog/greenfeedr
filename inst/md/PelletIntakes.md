
#### Calculating pellet intakes with greenfeedr

The following examples illustrate how to calculate pellet intakes in greenfeedr.

**1. Downloading feedtimes and calculating pellet intakes**

```R
 library(greenfeedr)
 pellin(user = "GF_USER",
        pass = "GF_PASS",
        unit = c(300,301),
        gcup = c(34,35,40,41), #Dual-hopper
        start_date = "2025-02-02",
        end_date = "2025-03-06",
        save_dir = "/Users/Downloads/"#,
        #rfid_file = "/Users/EXP1/EXP1_EID.xlsx"
        )
```

**2. Calculating pellet intakes from downloaded feedtimes**

```R
 library(greenfeedr)
 pellin(unit = "596,597",
        gcup = 43,
        start_date = "2025-02-02",
        end_date = "2025-02-06",
        save_dir = "/Users/Downloads/",
        rfid_file = "/Users/EXP2/EXP2_EID.xlsx",
        file_path = "/Users/Downloads/EXP2_feedtimes.csv"
        )
```

