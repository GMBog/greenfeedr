.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "Thank you for using the greenfeedr package!\n",
    "Cite: Martinez-Boggio et al. (2025). greenfeedr: An R-package for processing and reporting GreenFeed data.\n",
    "Type '??greenfeedr' for summary information"
  )
}

#' @name has_credentials
#' @title Check for 'API' Credentials
#'
#' @description Check if necessary 'API' credentials are available in the environment.
#'
#' @return A logical value: `TRUE` if both `API_USER` and `API_PASS` environment variables are set (i.e., not `NA`); `FALSE` otherwise
#' @examples
#' # Example 1: When environment variables are set
#' Sys.setenv(API_USER = "my_username", API_PASS = "my_password")
#' has_credentials()
#' # Expected output: TRUE
#'
#' # Example 2: When one or both environment variables are not set
#' Sys.unsetenv("API_USER")
#' Sys.unsetenv("API_PASS")
#' has_credentials()
#' # Expected output: FALSE
#'
#' # Clean up by removing environment variables
#' Sys.unsetenv("API_USER")
#' Sys.unsetenv("API_PASS")
#'
#' @export
#' @keywords internal
has_credentials <- function() {
  !is.na(Sys.getenv("API_USER", unset = NA)) && !is.na(Sys.getenv("API_PASS", unset = NA))
}


#' @name download_data
#' @title Download data from 'API'
#'
#' @description Download all types of 'GreenFeed' from 'API'
#'
#' @return A dataframe
#' @examplesIf has_credentials()
#' # Please replace "your_username" and "your_password" with your actual 'GreenFeed' credentials.
#' # By default, the function downloads the preliminary 'GreenFeed' data,
#' # if raw data is needed use options: "feed", "rfid", or "cmds"
#'
#' download_data(
#'   user = "your_username",
#'   pass = "your_password",
#'   d = "visits",
#'   type = 2,
#'   unit = c(304, 305),
#'   start_date = "2024-01-01",
#'   end_date = Sys.Date()
#' )
#'
#' @export
#' @keywords internal

download_data <- function(user, pass, d, type = 2, unit = NULL, start_date = NULL, end_date = NULL) {

  # Authenticate to receive token
  req <- httr::POST("https://portal.c-lockinc.com/api/login", body = list(user = user, pass = pass))
  httr::stop_for_status(req)
  TOK <- trimws(httr::content(req, as = "text"))

  get_data <- function(type) {
    if (d == "visits") {
      URL <- paste0(
        "https://portal.c-lockinc.com/api/getemissions?d=", d, "&fids=", unit,
        "&st=", start_date, "&et=", end_date, "%2012:00:00&type=", type
      )
    } else {
      URL <- paste0(
        "https://portal.c-lockinc.com/api/getraw?d=", d, "&fids=", unit,
        "&st=", start_date, "&et=", end_date, "%2012:00:00"
      )
    }
    message(URL)
    req <- httr::POST(URL, body = list(token = TOK))
    httr::stop_for_status(req)
    a <- httr::content(req, as = "text")
    perline <- stringr::str_split(a, "\\n")[[1]]
    perline <- perline[trimws(perline) != ""]
    if(length(perline) < 3) return(NULL)
    df <- do.call("rbind", stringr::str_split(perline[3:length(perline)], ","))
    as.data.frame(df)
  }

  df <- tryCatch({
    df <- get_data(type)
    if (is.null(df) || nrow(df) <= 1) {
      if (d == "visits" && type == 1) {
        message("No finalized data. Trying preliminary data (type = 2)...")
        df <- get_data(2)
      }
    }
    df
  }, error = function(e) {
    message("Download failed: ", e$message)
    return(NULL)
  })

  if (is.null(df) || nrow(df) <= 1) {
    message("No valid data retrieved.")
    return(invisible(NULL))
  }

  if (d == "visits") {
    colnames(df) <- c(
      "FeederID",
      "AnimalName",
      "RFID",
      "StartTime",
      "EndTime",
      "GoodDataDuration",
      "CO2GramsPerDay",
      "CH4GramsPerDay",
      "O2GramsPerDay",
      "H2GramsPerDay",
      "H2SGramsPerDay",
      "AirflowLitersPerSec",
      "AirflowCf",
      "WindSpeedMetersPerSec",
      "WindDirDeg",
      "WindCf",
      "WasInterrupted",
      "InterruptingTags",
      "TempPipeDegreesCelsius",
      "IsPreliminary",
      "RunTime"
    )
  } else if (d == "feed") {
    colnames(df) <- c(
      "FID",
      "FeedTime",
      "CowTag",
      "CurrentCup",
      "MaxCups",
      "CurrentPeriod",
      "MaxPeriods",
      "CupDelay",
      "PeriodDelay",
      "FoodType"
    )
  } else if (d == "rfid") {
    colnames(df) <- c(
      "FID",
      "ScanTime",
      "CowTag",
      "InOrOut",
      "Tray(IfApplicable)"
    )
  } else if (d == "cmds") {
    colnames(df) <- c(
      "FID",
      "CommandTime",
      "Cmd"
    )
  }
  return(df)
}



#' @name ensure_date_format
#' @title Check date format and transform in a usable one
#'
#' @description Check date format. If the format is wrong ('NA') an error message is printed,
#'     else it will formatted the date in the correct way (YYYY-MM-DD)
#'
#' @param date_input Date included as input
#'
#' @return A character string representing the date in 'YYYY-MM-DD' format
#' @examples
#' # Example of correct date formats
#' ensure_date_format("2024-08-30") # "2024-08-30"
#' ensure_date_format("30/08/2024") # "2024-08-30"
#'
#' # Example of incorrect date formats
#' tryCatch(
#'   {
#'     ensure_date_format("Aug-30")
#'   },
#'   error = function(e) {
#'     message(e$message)
#'   }
#' )
#'
#' @export
#' @keywords internal
ensure_date_format <- function(date_input) {
  # Check if the input is already in YYYY-MM-DD format (does nothing in this case)
  if (grepl("^\\d{4}-\\d{2}-\\d{2}$", date_input)) {
    # Return the date as is
    return(date_input)
  }

  # Attempt to parse the input into a Date object
  date_obj <- tryCatch(
    {
      # Try to parse as day-month-year (DD/MM/YY) format first
      parsed_date <- lubridate::dmy(date_input, quiet = TRUE)

      # If that fails, try parsing as day-month-year (DD/MM/YYYY) format
      if (is.na(parsed_date)) parsed_date <- lubridate::dmy(date_input, quiet = TRUE, truncated = 3)

      # If still NA, raise an error
      if (is.na(parsed_date)) stop("Invalid date format. Please provide a valid date in DD/MM/YY or DD/MM/YYYY format.")

      return(parsed_date)
    },
    error = function(e) {
      stop("Error processing date: ", e$message)
    }
  )

  # Return the date in 'YYYY-MM-DD' format
  return(format(date_obj, "%Y-%m-%d"))
}




#' @name filter_within_range
#' @title Detect outliers in data using mean and standard deviation
#'
#' @description Detect outliers using the mean and standard deviation.
#'
#' @param v A vector with data
#' @param cutoff A threshold or cutoff value that defines the range (e.g., 3)
#'
#' @return A logical vector of the same length as `v`, where each element is `TRUE` if the corresponding value in `v` falls within the specified range, and `FALSE` otherwise.
#' @examples
#' # Sample data
#' data <- c(10, 12, 14, 15, 20, 25, 30, 100)
#'
#' # Detect values within 3 standard deviations from the mean
#' filter_within_range(data, cutoff = 3)
#'
#' # Result:
#' # [1] TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE
#' # Explanation: All values fall within 2.5 standard deviations from the mean.
#'
#' # Detect values within 1 standard deviation from the mean
#' filter_within_range(data, cutoff = 1)
#'
#' # Result:
#' # [1] TRUE TRUE TRUE TRUE TRUE TRUE TRUE FALSE
#' # Explanation: All values except 100 fall within 1 standard deviation from the mean.
#'
#' @export
#' @keywords internal
filter_within_range <- function(v, cutoff) {
  mean_v <- mean(v, na.rm = TRUE)
  sd_v <- sd(v, na.rm = TRUE)
  v >= (mean_v - cutoff * sd_v) & v <= (mean_v + cutoff * sd_v)
}


#' @name process_rfid_data
#' @title Process RFID Data
#'
#' @description Processes RFID data from animals in the study.
#'
#' @param rfid_file Path or data frame containing RFID data.
#'
#' @return A data frame with standardized column names (`FarmName` and `RFID`). If the input is invalid or if no valid data is provided, the function returns `NULL`.
#'
#' @examples
#' # Example with a data frame
#' df <- data.frame(
#'   V1 = c("Farm1", "Farm2", "Farm3"),
#'   V2 = c("12345", "67890", "54321")
#' )
#' processed_df <- process_rfid_data(df)
#' message(processed_df)
#'
#' # Example with invalid input
#' invalid_data <- process_rfid_data(NULL)
#' # Expected output: message "RFID is NA. It is recommended to include it." and NULL
#' message(invalid_data)
#'
#' @export
#' @keywords internal
process_rfid_data <- function(rfid_file) {
  # Standardize column names function
  standardize_columns <- function(df) {
    if (ncol(df) < 2) {
      stop("The data frame must contain at least two columns.")
    }
    names(df)[1:2] <- c("FarmName", "RFID")
    df <- df %>%
      dplyr::mutate(across(1:2, as.character))
    return(df)
  }

  # Check if rfid_file is NA
  if (is.null(rfid_file)) {
    message("RFID is NULL. It is recommended to include it.")
    return(NULL)
  }

  # Check if rfid_file is a data frame
  if (is.data.frame(rfid_file)) {
    rfid_file <- standardize_columns(rfid_file)
    return(rfid_file)
  }

  # Normalize file path
  if (is.character(rfid_file)) {
    rfid_file <- normalizePath(rfid_file, mustWork = FALSE)

    # Check if the file exists
    if (!file.exists(rfid_file)) {
      stop("The specified RFID file does not exist: ", rfid_file)
    }

    file_extension <- tolower(tools::file_ext(rfid_file))

    tryCatch(
      {
        if (file_extension == "csv") {
          rfid_file <- readr::read_csv(rfid_file, col_types = readr::cols(.default = readr::col_character()))
        } else if (file_extension %in% c("xls", "xlsx")) {
          rfid_file <- readxl::read_excel(rfid_file) %>%
            dplyr::mutate(across(everything(), as.character))
        } else if (file_extension == "txt") {
          rfid_file <- readr::read_table(rfid_file, col_types = readr::cols(.default = readr::col_character()))
        } else {
          stop("Unsupported file format: ", file_extension)
        }

        # Check if file is empty
        if (nrow(rfid_file) == 0) {
          stop("The RFID file is empty: ", rfid_file)
        }

        rfid_file <- standardize_columns(rfid_file)
        return(rfid_file)
      },
      error = function(e) {
        stop("Error reading the RFID file: ", e$message)
      }
    )
  }

  # If none of the conditions are met
  message("No valid data provided. Please include a valid 'rfid_file' parameter.")
  return(NULL)
}


#' @name convert_unit
#' @title Convert 'GreenFeed' Unit Number
#'
#' @description Processes the parameter unit to format it correctly as a comma-separated string,
#'     regardless of whether it is provided as a numeric, character, or list/vector.
#'
#' @param unit Number of the 'GreenFeed' unit(s). Can be a numeric, character, list, or vector.
#' @param t Type of function (opts: 1 and 2).
#'
#' @return A character string of the unit(s) in the correct comma-separated format.
#'
#' @examples
#' # Example 1: Providing unit as a character vector
#' unit <- c("592", "593")
#' convert_unit(unit, 1)
#'
#' # Example 2: Providing unit as a single numeric
#' unit <- 592
#' convert_unit(unit, 1)
#'
#' # Example 3: Providing unit as a comma-separated character string
#' unit <- "592, 593"
#' convert_unit(unit, 1)
#'
#' # Example 4: Providing unit as a list
#' unit <- list(592, 593)
#' convert_unit(unit, 1)
#'
#' @export
#' @keywords internal
convert_unit <- function(unit, t) {
  if (t == 1) {
    if (is.numeric(unit)) {
      unit <- as.character(unit)  # Convert numeric to character
    } else if (is.character(unit)) {
      unit <- gsub(" ", "", unit) # Remove spaces from character string
    } else if (is.list(unit) || is.vector(unit)) {
      unit <- as.character(unlist(unit))  # Flatten list/vector and convert to character
    }
    unit <- paste(unit, collapse = ",")  # Collapse into a comma-separated string

  } else if (t == 2) {
    if (is.character(unit) && length(unit) == 1) {
      unit <- strsplit(unit, ",")[[1]]  # Only split if it's a single string
    } else if (is.list(unit) || is.vector(unit)) {
      unit <- as.character(unlist(unit))  # Convert lists or vectors to character
    }
  }

  return(unit)
}



#' @name transform_gases
#' @title Transform gas production
#'
#' @description Transform gas production from g/d to L/d
#'
#' @param data a data frame with preliminary or finalized 'GreenFeed' data
#'
#' @return A data frame with the gases transform in L/d
#'
#' @examples
#' file <- readr::read_csv(system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr"))
#' data <- transform_gases(data = file)
#'
#' @export
#' @keywords internal
transform_gases <- function(data){
  # CH4 L/d: 1 mol of CH4 weighs 16g (12+1*4) and has a volume of 22.4L
  if ("CH4GramsPerDay" %in% names(data)) {
    data$CH4GramsPerDay <- data$CH4GramsPerDay / 16 * 22.4
  }

  # CO2 L/d: 1 mol of CO2 weighs 44g (12+16*2) and has a volume of 22.4L
  if ("CO2GramsPerDay" %in% names(data)) {
    data$CO2GramsPerDay <- data$CO2GramsPerDay / 44 * 22.4
  }

  # O2 L/d: 1 mol of O2 weighs 32g and has a volume of 22.4L
  if ("O2GramsPerDay" %in% names(data)) {
    data$O2GramsPerDay <- data$O2GramsPerDay / 32 * 22.4
  }

  # H2 L/d: 1 mol of H2 weighs 2.016g (1.008*2) and has a volume of 22.4L
  if ("H2GramsPerDay" %in% names(data)) {
    data$H2GramsPerDay <- data$H2GramsPerDay / 2.016 * 22.4
  }

  return(data)
}



#' @name normalize_gfdata
#' @title Normalize 'GreenFeed' data with different formats
#'
#' @description Normalize 'GreenFeed' data in their preliminary and finalized format
#'
#' @param data a data frame with preliminary or finalized 'GreenFeed' data
#'
#' @return A standardized data frame
#'
#' @examples
#' file <- readr::read_csv(system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr"))
#' data <- transform_gases(data = file)
#'
#' @export
#' @keywords internal
normalize_gfdata <- function(data) {
  # -------------------------------------------------------------------------
  # 1. Column name standardisation
  #
  # Three source formats are supported:
  #   A) Excel export from C-Lock portal  → detected by Excel-style col names
  #   B) CSV preliminary (>= 25 cols)     → rename first 14 cols by position
  #   C) CSV finalized   (<= 21 cols)     → rename all cols by position
  #
  # After this block every column has its canonical CSV name.
  # -------------------------------------------------------------------------
  excel_map <- c(
    "Start Time"                   = "StartTime",
    "End Time"                     = "EndTime",
    "Good Data Duration"           = "GoodDataDuration",
    "CH4 Massflow (g/d)"           = "CH4GramsPerDay",
    "CO2 Massflow (g/d)"           = "CO2GramsPerDay",
    "O2 Massflow (g/d)"            = "O2GramsPerDay",
    "H2 Massflow (g/d)"            = "H2GramsPerDay",
    "H2S Massflow (g/d)"           = "H2SGramsPerDay",
    "Average Airflow (L/s)"        = "AirflowLitersPerSec",
    "Airflow CF"                   = "AirflowCf",
    "Average Wind Speed (m/s)"     = "WindSpeedMetersPerSec",
    "Average Wind Direction (deg)" = "WindDirDeg",
    "Wind CF"                      = "WindCf",
    "Was Interrupted"              = "WasInterrupted",
    "Interrupting Tags"            = "InterruptingTags",
    "Pipe Temperature (deg C)"     = "TempPipeDegreesCelsius",
    "FID"                          = "FeederID"
  )
  preliminary_names <- c(
    "RFID", "AnimalName", "FeederID", "StartTime", "EndTime",
    "GoodDataDuration", "HourOfDay",
    "CO2GramsPerDay", "CH4GramsPerDay", "O2GramsPerDay", "H2GramsPerDay",
    "H2SGramsPerDay", "AirflowLitersPerSec", "AirflowCf"
  )
  finalized_names <- c(
    "FeederID", "AnimalName", "RFID", "StartTime", "EndTime",
    "GoodDataDuration",
    "CO2GramsPerDay", "CH4GramsPerDay", "O2GramsPerDay", "H2GramsPerDay",
    "H2SGramsPerDay", "AirflowLitersPerSec", "AirflowCf",
    "WindSpeedMetersPerSec", "WindDirDeg", "WindCf",
    "WasInterrupted", "InterruptingTags", "TempPipeDegreesCelsius",
    "IsPreliminary", "RunTime"
  )
  excel_hits <- sum(names(excel_map) %in% colnames(data))
  if (excel_hits >= 3) {
    to_rename <- names(excel_map)[names(excel_map) %in% colnames(data)]
    colnames(data)[match(to_rename, colnames(data))] <- excel_map[to_rename]
    #message("Note: Excel column names detected and standardised.")
  } else if (ncol(data) >= 25) {
    names(data)[seq_along(preliminary_names)] <- preliminary_names
  } else {
    n <- min(ncol(data), length(finalized_names))
    names(data)[seq_len(n)] <- finalized_names[seq_len(n)]
  }
  # -------------------------------------------------------------------------
  # 2. GoodDataDuration → uniform "HH:MM:SS" character string
  #
  # readxl reads Excel time cells as POSIXct "1899-12-31 HH:MM:SS"; format()
  # extracts only the time portion.  difftime objects are converted via secs.
  # Some CSV/Excel combos produce character strings in datetime format
  # (e.g. "1900-01-01 00:05:30") — these are caught by the third branch.
  # Character strings already in "HH:MM:SS" are left unchanged.
  # -------------------------------------------------------------------------
  if ("GoodDataDuration" %in% colnames(data)) {
    dur <- data$GoodDataDuration
    if (inherits(dur, c("POSIXct", "POSIXlt"))) {
      data$GoodDataDuration <- format(as.POSIXct(dur), "%H:%M:%S")
    } else if (inherits(dur, "difftime")) {
      secs <- as.integer(as.numeric(dur, units = "secs"))
      data$GoodDataDuration <- sprintf("%02d:%02d:%02d",
                                       secs %/% 3600L,
                                       (secs %% 3600L) %/% 60L,
                                       secs %% 60L)
    } else if (is.character(dur)) {
      # Catch datetime-style strings like "1900-01-01 00:05:30":
      # extract only the time portion so downstream parsing works correctly.
      sample_val <- dur[!is.na(dur)][1]
      if (!is.na(sample_val) && grepl("^\\d{4}-\\d{2}-\\d{2}[T ]", sample_val)) {
        parsed <- suppressWarnings(as.POSIXct(dur, tz = "UTC"))
        valid  <- !is.na(parsed)
        data$GoodDataDuration[valid] <- format(parsed[valid], "%H:%M:%S")
        message("Note: datetime-style GoodDataDuration values reformatted to HH:MM:SS.")
      }
    }
  }
  # -------------------------------------------------------------------------
  # 3. StartTime → uniform "YYYY-MM-DD HH:MM:SS" character string
  #
  # Preliminary CSV / Excel: already POSIXct → format() standardises.
  # Finalized CSV: character in "m/d/y H:M" → parsed with lubridate and
  # reformatted.  A single downstream code path then applies to all formats.
  # -------------------------------------------------------------------------
  if ("StartTime" %in% colnames(data)) {
    st <- data$StartTime
    if (inherits(st, c("POSIXct", "POSIXlt"))) {
      data$StartTime <- format(st, "%Y-%m-%d %H:%M:%S")
    } else if (is.character(st) && !grepl("^\\d{4}-\\d{2}-\\d{2}", st[!is.na(st)][1])) {
      parsed <- lubridate::parse_date_time(
        st,
        orders = c("m/d/y H:M", "m/d/Y H:M:S", "Y-m-d H:M:S", "Y-m-d H:M")
      )
      data$StartTime <- format(parsed, "%Y-%m-%d %H:%M:%S")
    }
  }
  # -------------------------------------------------------------------------
  # 4. RFID → character (15-digit integers overflow R's integer type)
  # -------------------------------------------------------------------------
  if ("RFID" %in% colnames(data)) {
    data$RFID <- as.character(data$RFID)
  }
  data
}


#' @name compare_gfdata
#' @title Compare Preliminary and Finalized 'GreenFeed' Data
#'
#' @description Compare preliminary and finalized 'GreenFeed' data.
#'
#' @param prelimrep a data frame with preliminary 'GreenFeed' data
#' @param finalrep a data frame with finalized 'GreenFeed' data
#' @param start_date a character string representing the start date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")
#' @param end_date a character string representing the end date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")
#'
#' @return Data frame including records removed from preliminary and final reports
#'
#' @examples
#' # Datasets with preliminary and finalized GreenFeed data
#' prelimrep <- system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr")
#' finalrep <- system.file("extdata", "StudyName_FinalReport.xlsx", package = "greenfeedr")
#'
#' data <- compare_gfdata(
#'   prelimrep,
#'   finalrep,
#'   start_date = "2024-05-13",
#'   end_date = "2024-05-20"
#' )
#'
#' @export
#' @keywords internal
#'
#' @import dplyr
#' @importFrom dplyr %>%
#' @import ggplot2
#' @import readr
#' @import readxl

utils::globalVariables(c(
  "group", "CH4GramsPerDay.x", "CH4GramsPerDay.y", "y"
))

compare_gfdata <- function(prelimrep, finalrep, start_date, end_date) {
  # Check date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # Open preliminary data
  prelim_data <- readr::read_csv(prelimrep, show_col_types = FALSE)

  # Open final data
  final_data <- readxl::read_excel(finalrep)
  names(final_data)[1:14] <- c(
    "RFID",
    "AnimalName",
    "FeederID",
    "StartTime",
    "EndTime",
    "GoodDataDuration",
    "HourOfDay",
    "CO2GramsPerDay",
    "CH4GramsPerDay",
    "O2GramsPerDay",
    "H2GramsPerDay",
    "H2SGramsPerDay",
    "AirflowLitersPerSec",
    "AirflowCf"
  )

  # List of datasets
  list_of_data <- list(prelim_data, final_data)

  # Process data
  for (i in seq_along(list_of_data)) {
    data <- list_of_data[[i]]
    data <- data %>%
      # Remove leading zeros from RFID column to match with IDs
      dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
      # Check format of Date
      dplyr::mutate(
        StartTime = if (is.character(StartTime)) as.POSIXct(StartTime, format = "%m/%d/%y %H:%M") else StartTime,
        EndTime = if (is.character(EndTime)) as.POSIXct(EndTime, format = "%m/%d/%y %H:%M") else EndTime
      ) %>%
      # Filter out records before and after study dates, NULL records, and low airflow
      dplyr::filter(
        as.Date(StartTime) >= as.Date(start_date),
        as.Date(StartTime) <= as.Date(end_date),
        CH4GramsPerDay > 0,
        AirflowLitersPerSec >= 25
      ) %>%
      # Remove duplicate records
      dplyr::distinct_at(vars(1:5), .keep_all = TRUE)

    # Store the processed data back in the list_of_data
    list_of_data[[i]] <- data

    # Move the processed data back to the original data frames
    if (i == 1) {
      prelim_data <- data
    } else if (i == 2) {
      final_data <- data
    }
  }

  # Difference in number of records from initial data
  records_out_finalrep <- dplyr::anti_join(prelim_data, final_data,
                                           by = c(
                                             "RFID",
                                             "FeederID",
                                             "StartTime",
                                             "EndTime"
                                           )
  )

  message("During the data processing ", nrow(records_out_finalrep), " records were removed from the finalized data")

  records_out_prelimrep <- dplyr::anti_join(final_data, prelim_data,
                                            by = c(
                                              "RFID",
                                              "FeederID",
                                              "StartTime",
                                              "EndTime"
                                            )
  )

  message("During the data processing ", nrow(records_out_prelimrep), " records were added to the finalized data")

  # Join preliminary and final data
  prelim_data$group <- "D"
  final_data$group <- "F"
  all_data <- rbind(
    prelim_data[, c(3, 2, 1, 4:8, 22)],
    final_data[, c(1:6, 8:9, 26)]
  )

  # Distribution of the CH4 and CO2 for both datasets
  plot1 <- ggplot(data = all_data, aes(x = group, y = CH4GramsPerDay, fill = group)) +
    geom_boxplot() +
    stat_summary(
      fun = mean, geom = "text",
      aes(label = round(after_stat(y), 0)),
      position = position_dodge(width = 0.75),
      vjust = -0.6, size = 4, color = "black"
    ) +
    scale_x_discrete(labels = c("D" = "Prelim data", "F" = "Final report")) +
    scale_fill_manual(values = c("#9FA8DA", "#A5D6A7")) +
    theme_classic() +
    theme(
      axis.text.x = element_text(angle = 0, size = 9),
      axis.text.y = element_text(angle = 0, size = 9),
      axis.title.y = element_text(size = 10, face = "bold"),
      axis.title.x = element_text(size = 10, face = "bold"),
      legend.position = "none",
    ) +
    labs(y = "CH4 production (g/d)")

  plot2 <- ggplot(data = all_data, aes(x = group, y = CO2GramsPerDay, fill = group)) +
    geom_boxplot() +
    stat_summary(
      fun = mean, geom = "text",
      aes(label = round(after_stat(y), 0)),
      position = position_dodge(width = 0.75),
      vjust = -0.9, size = 4, color = "black"
    ) +
    scale_x_discrete(labels = c(
      "D" = "Prelim data",
      "F" = "Final report"
    )) +
    scale_fill_manual(values = c("#9FA8DA", "#A5D6A7")) +
    theme_classic() +
    theme(
      axis.text.x = element_text(angle = 0, size = 9),
      axis.text.y = element_text(angle = 0, size = 9),
      axis.title.y = element_text(size = 10, face = "bold"),
      axis.title.x = element_text(size = 10, face = "bold"),
      legend.position = "none"
    ) +
    labs(y = "CO2 production (g/d)")

  print(plot1)
  print(plot2)

  # Comparison of CH4 values for each dataset
  joined_data <- dplyr::inner_join(prelim_data, final_data,
                                   by = c(
                                     "RFID",
                                     "FeederID",
                                     "StartTime",
                                     "EndTime"
                                   )
  )

  # Return a list of data frames
  return(list(
    out_final = records_out_finalrep,
    out_prelim = records_out_prelimrep,
    data = all_data
  ))
}
