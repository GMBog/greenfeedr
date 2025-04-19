
#### Checking GreenFeed visitation with greenfeedr

The following examples illustrate how to check visitation in greenfeedr.

**1. Checking GreenFeed visitation**

```R
 library(greenfeedr)
 data <- viseat(user = "GF_USER",
                pass = "GF_PASS",
                unit = c(579,600),
                start_date = "2025-04-06",
                end_date = "2025-04-08",
                rfid_file = "/Users/EXP2/EXP2_EID.xlsx"
                )

```
