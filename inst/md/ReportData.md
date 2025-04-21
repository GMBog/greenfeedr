
#### Reporting Data with greenfeedr

**How to create the rfid_file?**

The rfid_file contains the list of animals enrolled in your study. 
It is highly recommended to use this file when running functions such as report_gfdata() and pellin().

The file must include the following structure:
- The first two columns should always be:
     VisualID: A name or identifier for the animal
     RFID: The animal's unique RFID tag

You may include any number of additional columns with extra information (e.g., treatment group, weight, breed, etc.).

```R
  VisualID <- c("Anim1", "Anim2", "Anim3", "Anim4")
  RFID <- c("840003234513780", "840003234523759", "840003234513770", "840003234513781")
  ExtraCol1 <- c(1, 2, 2, 1)
  ExtraCol2 <- c(54, 59, 89, 100)
  rfid_file <- data.frame(VisualID, RFID, ExtraCol1, ExtraCol2)
  openxlsx::write.xlsx(rfid_file, "~/Downloads/rfid_file.xlsx")
```

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
               rfid_file = "/Users/EXP1/EXP1_EID.xlsx"
               )
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
               rfid_file = "/Users/EXP2/EXP2_EID.xlsx"
               )
```

