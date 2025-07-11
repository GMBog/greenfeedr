#' @name pellin
#' @title Process 'GreenFeed' Pellet Intakes
#'
#' @description Processes 'feedtimes' file from 'GreenFeed' system.
#'     Food drops are used to calculate pellet intakes per animal.
#'     Aggregates data to provide insights into the feeding behavior
#'     and pellet consumption of the animals during a study.
#'
#' @param user a character string representing the user name to logging into 'GreenFeed' system
#' @param pass a character string representing password to logging into 'GreenFeed' system
#' @param unit numeric or character vector or list representing one or more 'GreenFeed' unit numbers. The order should match with "feedtimes" files
#' @param gcup a numeric value representing the grams of pellets per cup. If dual-hopper you can define multiple grams per unit
#' @param start_date a character string representing the start date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")
#' @param end_date a character string representing the end date of the study (format: "DD-MM-YY" or "YYYY-MM-DD")
#' @param save_dir a character string representing the directory to save the output file
#' @param rfid_file a character string representing the file with individual IDs. The order should be Visual ID (col1) and RFID (col2)
#' @param file_path a character string or list representing files(s) with "feedtimes" from 'C-Lock Inc.'
#'
#' @return An Excel file with pellet intakes for all animals and days within the specified period is saved to save_dir.
#'     The file is named "Pellet_Intakes_YYYY-MM-DD_YYYY-MM-DD.csv".
#'
#' @examples
#' # You should provide the 'feedtimes' file provided by C-Lock.
#' # it could be a list of files if you have data from multiple units to combine
#' path <- system.file("extdata", "feedtimes.csv", package = "greenfeedr")
#'
#' # You must include the grams of pellets per cup based on the result obtained from the 10-drops test
#'
#' # If the user include an rfid file, the structure should be in col1 AnimalName or Visual ID, and
#' # col2 the RFID or TAG_ID. The file could be save in different formats (.xlsx, .csv, or .txt).
#' RFIDs <- system.file("extdata", "RFID_file.csv", package = "greenfeedr")
#'
#' pellin(
#'   unit = 1,
#'   gcup = 34,
#'   start_date = "2024-05-13",
#'   end_date = "2024-05-25",
#'   save_dir = tempdir(),
#'   rfid_file = RFIDs,
#'   file_path = path
#' )
#'
#' @export pellin
#'
#' @import dplyr
#' @importFrom dplyr %>%
#' @import httr
#' @import lubridate
#' @import purrr
#' @import readr
#' @import readxl
#' @import stringr
#' @import tidyr
#' @import utils

utils::globalVariables(c(
  "FID", "FeedTime", "CowTag", "Time", "CurrentPeriod", "ndrops",
  "MassFoodDrop", "Date", "RFID", "pellintakes", "FarmName", "FoodType", "n_foodtypes"
))

pellin <- function(user = NA, pass = NA, unit, gcup, start_date, end_date,
                   save_dir = tempdir(), rfid_file = NULL, file_path = NULL) {

  # Check Date format
  start_date <- ensure_date_format(start_date)
  end_date <- ensure_date_format(end_date)

  # If the 'feedtimes' file is not provided, download data through the API
  if (is.null(file_path)) {

    # Authenticate to receive token
    req <- httr::POST("https://portal.c-lockinc.com/api/login", body = list(user = user, pass = pass))
    httr::stop_for_status(req)
    TOK <- trimws(httr::content(req, as = "text"))

    # Get data using the login token
    URL <- paste0(
      "https://portal.c-lockinc.com/api/getraw?d=feed&fids=", convert_unit(unit,1),
      "&st=", start_date, "&et=", end_date, "%2012:00:00"
    )
    message(URL)

    req <- httr::POST(URL, body = list(token = TOK))
    httr::stop_for_status(req)
    a <- httr::content(req, as = "text")

    # Split the lines
    perline <- stringr::str_split(a, "\\n")[[1]]

    # Split the commas into a data frame, while getting rid of the "Parameters" line and the headers line
    df <- do.call("rbind", stringr::str_split(perline[3:length(perline)], ","))
    df <- as.data.frame(df)
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

    # Remove leading zeros from tag IDs and formatting Date
    df <- df %>%
      dplyr::mutate(
        CowTag = gsub("^0+", "", CowTag),
        FeedTime = as.POSIXct(FeedTime, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
      )

  } else {

    file_path <- normalizePath(file_path, mustWork = FALSE) # Convert to absolute path
    ext <- tools::file_ext(file_path)
    if (ext == "csv") {
        # Read CSV file
        df <- readr::read_csv(file_path, show_col_types = FALSE)
    } else if (ext %in% c("xls", "xlsx")) {
        # Read Excel file (both xls and xlsx)
        df <- readxl::read_excel(file_path)
    } else {
        stop("Unsupported file type. Please provide a CSV, XLS, or XLSX file.")
    }


    # Detect date format
    df <- df[!is.na(df$FeedTime),] # Remove NA to match format date
    if (all(grepl("^\\d{4}-\\d{2}-\\d{2}", df$FeedTime))) {
      detected_format <- "%Y-%m-%d %H:%M:%S"
    } else if (all(grepl("^\\d{1,2}/\\d{1,2}/\\d{2}", df$FeedTime))) {
      detected_format <- "mdy_hm"
    } else {
      stop("Unknown FeedTime format in dataset!")
    }

    # Convert FeedTime using the detected format
    df <- df %>%
      mutate(
        FID = as.character(FID),
        CowTag = gsub("^0+", "", CowTag),
        FeedTime = if (detected_format == "%Y-%m-%d %H:%M:%S") {
          as.POSIXct(FeedTime, format = detected_format)
        } else {
          mdy_hm(FeedTime)
        }
      )

  }

  # Process the rfid data
  rfid_file <- process_rfid_data(rfid_file)

  # If the 'rfid_file' is provided, filter the data and identify animals not visiting the GreenFeed units
  if (!is.null(rfid_file) && is.data.frame(rfid_file) && nrow(rfid_file) > 0) {
    df <- df[df$CowTag %in% rfid_file$RFID, ]
    noGFvisits <- rfid_file$FarmName[!(rfid_file$RFID %in% df$CowTag)]

    if (length(noGFvisits) > 0) {
      message("\nAnimals not visiting the GreenFeed(s):\n", paste(noGFvisits, collapse = "\n"))
    }
  }

  # Create a table with visit day and time and calculate drops per animal/FID/day
  number_drops <- df %>%
    dplyr::mutate(
      ## Convert FeedTime to POSIXct with the correct format
      FeedTime = as.POSIXct(FeedTime, format = "%m/%d/%y %H:%M:%S"),
      Date = as.character(as.Date(FeedTime)),
      Time = as.numeric(lubridate::period_to_seconds(lubridate::hms(format(FeedTime, "%H:%M:%S"))) / 3600),
      FoodType = as.character(FoodType)
    ) %>%
    dplyr::relocate(Date, Time, .before = FID) %>%
    dplyr::select(-FeedTime) %>%
    ## Calculate drops per animal/FID/day
    dplyr::group_by(CowTag, FID, FoodType, Date) %>%
    dplyr::summarise(
      ndrops = dplyr::n(),
      TotalPeriod = max(CurrentPeriod)
    )

  # Format the GreenFeed unit numbers
  unit <- convert_unit(unit,2)


  #######

  # Unique combinations of unit (FID) and food type from the data
  gf_combinations <- df %>%
    dplyr::select(FID, FoodType) %>%
    dplyr::distinct() %>%
    dplyr::mutate(FID = as.character(FID),
                  FoodType = as.character(FoodType)) %>%
    dplyr::filter(FID != "") %>%   # <-- removes empty unit
    dplyr::arrange(FID, FoodType)

  # Count food types per unit in the data
  unit_foodtypes <- gf_combinations %>%
    dplyr::group_by(FID) %>%
    dplyr::summarise(n_foodtypes = dplyr::n()) %>%
    dplyr::ungroup()

  # Case 1: Single gcup value
  message("\nPlease set the 'gcup' parameter based on the 10-drops test.")
  if (length(gcup) == 1) {
    message("Single gcup provided: applying to all FID/FoodType combinations.")
    gcup_expanded <- rep(gcup, nrow(gf_combinations))

    # Case 2: One gcup per unit, replicate across food types
  } else if (length(gcup) == length(unit)) {
    # Match gcup to units
    unit_gcup_df <- data.frame(FID = unit, gcup = gcup, stringsAsFactors = FALSE)

    # Join with actual foodtype counts
    match_check <- dplyr::left_join(unit_foodtypes, unit_gcup_df, by = "FID")

    if (any(is.na(match_check$gcup))) {
      stop("Some units in the data do not have a corresponding gcup value.")
    }

    # Repeat gcup per foodtype
    gcup_expanded <- match_check %>%
      dplyr::rowwise() %>%
      dplyr::mutate(gcup = list(rep(gcup, n_foodtypes))) %>%
      dplyr::pull(gcup) %>%
      unlist()

    message("gcup provided per unit: applied to each food type within that unit.")

    # Case 3: One gcup per unit-foodtype
  } else if (length(gcup) == nrow(gf_combinations)) {
    gcup_expanded <- gcup
    message("gcup provided per unit-foodtype so used directly.")

    # Case 4: mismatch
  } else {
    stop("Mismatch between the number of gcup values and detected unit-foodtype combinations.")
  }

  # Final result
  grams_df <- gf_combinations %>%
    dplyr::mutate(gcup = gcup_expanded)


  #######

  # Calculate MassFoodDrop by number of cup drops times grams per cup
  pellintakes <- number_drops %>%
    dplyr::left_join(grams_df, by = c("FID", "FoodType")) %>%
    dplyr::mutate(MassFoodDrop = ndrops * gcup) %>%
    ## Create a table with alfalfa pellets (AP) intakes in kg
    dplyr::group_by(CowTag, FoodType, Date) %>%
    ## MassFoodDrop divided by 1000 to transform g in kg
    dplyr::summarise(MassFoodDrop = sum(MassFoodDrop) / 1000)


  # Animals with visits:
  ## Create a grid with all unique combinations of dates and IDs
  grid_visits <- expand.grid(
    Date = unique(pellintakes$Date),
    CowTag = unique(pellintakes$CowTag)
  )

  ## Merge pellet intakes with our 'grid' and set to 0 the NA values
  pellintakes <- merge(pellintakes, grid_visits, all = TRUE) %>%
    dplyr::mutate(
      MassFoodDrop = ifelse(is.na(MassFoodDrop), 0, MassFoodDrop)#,
      #FoodType = ifelse(is.na(FoodType), 0, FoodType)
    ) %>%
    dplyr::relocate(FoodType, .after = MassFoodDrop)


  ## Adding the farm name (if rfid_file is provided) to the pellet intakes file
  if (!is.null(rfid_file) && is.data.frame(rfid_file) && nrow(rfid_file) > 0) {
    pellintakes <- rfid_file[, 1:2] %>%
      dplyr::inner_join(pellintakes, by = c("RFID" = "CowTag"))
    names(pellintakes) <- c("FarmName", "RFID", "Date", "PIntake_kg", "FoodType")
  } else {
    names(pellintakes) <- c("RFID", "Date", "PIntake_kg", "FoodType")
  }


  # Animals without visits:
  ## Create a sequence of dates from the start date to the end date of the study
  all_dates <- seq(as.Date(start_date), as.Date(end_date), by = "day")

  ## Create file with pellet intakes in kg within the specified date range
  df <- pellintakes %>%
    dplyr::filter(Date >= start_date & Date <= end_date) %>%
    dplyr::mutate(Date = as.Date(Date))

  # Add missing dates for each RFID (and FarmName if available)
  if (!is.null(rfid_file) && is.data.frame(rfid_file) && nrow(rfid_file) > 0) {
    df <- df %>% tidyr::complete(Date = all_dates, tidyr::nesting(FarmName, RFID))

    ## Create all possible combinations of date and RFID for animals without visits
    grid_missing <- expand.grid(
      Date = unique(df$Date),
      RFID = rfid_file$RFID[rfid_file$FarmName %in% noGFvisits],
      PIntake_kg = 0,
      FoodType = NA
    )

    ## Add the corresponding FarmName for each RFID
    grid_missing$FarmName <- rfid_file$FarmName[match(grid_missing$RFID, rfid_file$RFID)]

    ## Combine data with cows visiting and not visiting
    df <- rbind(df, grid_missing)

  } else {
    df <- df %>% tidyr::complete(Date = all_dates, tidyr::nesting(RFID))
  }


  # Ensure save_dir is an absolute path
  if (!is.null(save_dir)) {
    save_dir <- normalizePath(save_dir, mustWork = FALSE)

    # Check if the directory exists, and create it if necessary
    if (!dir.exists(save_dir)) {
      dir.create(save_dir, recursive = TRUE)
    }

    # Save pellet intakes as a CSV file with pellet weight (kg) for the requested period
    file_name <- paste0("Pellet_Intakes_", start_date, "_", end_date, ".csv")
    file_path <- file.path(save_dir, file_name)

    readr::write_excel_csv(df, file = file_path)

    message("\nPellet intake file saved. Look for '", file_name, "' in: ", save_dir, "\n")
    }

  return(df)
}
