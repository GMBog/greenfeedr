
#### Downloading Data with greenfeedr

The following examples illustrate how to download GreenFeed data in greenfeedr.

**1. Downloading raw data (feed, commands, and rfids)**

```R
 library(greenfeedr)
 get_gfdata(user = "GF_USER",
           pass = "GF_PASS",
           d = "feed", #"rfid", #"cmds"
           exp = "EXP1",
           unit = c(500,501),
           start_date = "2025-02-02",
           end_date = "2025-02-06",
           save_dir = "/Users/Downloads/")

```

**2. Downloading preliminary emissions data**

```R
 library(greenfeedr)
 get_gfdata(user = "GF_USER",
           pass = "GF_PASS",
           d = "visits",
           type = 2,
           exp = "EXP1",
           unit = c(300,301),
           start_date = "2025-01-01",
           end_date = "2025-03-01",
           save_dir = "/Users/Downloads/")
```

**3. Downloading finalized emissions data**

```R
 library(greenfeedr)
 get_gfdata(user = "GF_USER",
           pass = "GF_PASS",
           d = "visits",
           type = 1,
           exp = "EXP1",
           unit = c(300,301),
           start_date = "2025-01-01",
           end_date = "2025-03-14",
           save_dir = "/Users/Downloads/")
```

