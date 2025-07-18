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





#' @name eval_gfparam
#' @title Evaluate all combination of parameters
#'
#' @description Evaluate parameters that best fit your 'GreenFeed' data
#'
#' @param data a data frame with preliminary or finalized 'GreenFeed' data
#' @param start_date a character string representing the start date of the study (format: "dd/mm/yyyy")
#' @param end_date a character string representing the end date of the study (format: "dd/mm/yyyy")
#'
#' @return A data frame with the mean, SD, and CV for gas production using all possible combination of parameters
#'
#' @examples
#' file <- readr::read_csv(system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr"))
#' eval <- eval_gfparam(data = file,
#'                      start_date = "2024-05-13",
#'                      end_date = "2024-05-20"
#'                     )
#'
#' @export
#' @keywords internal
eval_gfparam <- function(data, start_date, end_date) {
  # Parameter space
  param_combinations <- expand.grid(
    param1 = seq(1, 5),
    param2 = seq(1, 7),
    min_time = seq(2, 5),
    stringsAsFactors = FALSE
  )

  # Check date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  message("Evaluating parameter combinations...\n")

  # Metric function
  compute_metrics <- function(x) {
    mean_x <- mean(x, na.rm = TRUE)
    sd_x <- sd(x, na.rm = TRUE)
    CV_x <- ifelse(mean_x == 0, NA, (sd_x / mean_x) * 100)
    c(mean = round(mean_x, 1), sd = round(sd_x, 1), CV = round(CV_x, 2))
  }

  # Main loop over parameter combinations
  results <- purrr::pmap_dfr(
    .l = param_combinations,
    .f = function(param1, param2, min_time) {
      result <- tryCatch({
        res <- suppressMessages(
          process_gfdata(
            data = data,
            start_date = start_date,
            end_date = end_date,
            param1 = param1,
            param2 = param2,
            min_time = min_time
          )
        )
        weekly <- res$weekly_data
        metrics <- compute_metrics(weekly$CH4GramsPerDay)
        data.frame(
          param1 = param1,
          param2 = param2,
          min_time = min_time,
          records = nrow(weekly),
          N = length(unique(weekly$RFID)),
          mean = metrics["mean"],
          SD = metrics["sd"],
          CV = metrics["CV"]
        )
      }, error = function(e) {
        data.frame(
          param1 = param1,
          param2 = param2,
          min_time = min_time,
          records = NA, N = NA, mean = NA, SD = NA, CV = NA
        )
      })
      return(result)
    }
  )

  message("Done!")
  return(results)
}
