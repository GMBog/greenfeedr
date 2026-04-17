#' @name eval_gfparam
#' @title Evaluate all combinations of parameters
#'
#' @description
#' Evaluate filtering parameters that best fit your 'GreenFeed' data using a
#' two-stage, data-driven approach.
#'
#' 'GreenFeed' units record gas emissions during voluntary animal visits,
#' producing an irregular series of individual measurements throughout the day.
#' To obtain a reliable emission estimate for each animal, records are
#' aggregated in two sequential steps: (1) individual visit records within a
#' day are averaged into a daily mean, requiring a minimum number of records
#' per day (\code{param1}); and (2) daily means within a week are averaged
#' into a weekly mean, requiring a minimum number of days with records per
#' week (\code{param2}). A minimum visit duration (\code{min_time}) can
#' additionally be applied to exclude incomplete measurements.
#'
#' The function first performs a \strong{diurnal analysis} on the raw visit
#' records, quantifying how much gas emissions vary across hours of the day
#' via the eta-squared statistic (proportion of total variance explained by
#' hour of day). This directly informs the relevance of \code{param1}: when
#' diurnal variation is high, a single record per day may capture only a peak
#' or trough, producing a biased daily average; more records per day are
#' needed to sample the diurnal cycle adequately. The diurnal result is
#' reported as a recommendation but all parameter combinations are always
#' evaluated.
#'
#' The \strong{parameter selection} uses repeatability (intraclass correlation
#' coefficient, ICC) computed at two levels of the aggregation hierarchy,
#' each sensitive to a different parameter:
#' \itemize{
#'   \item \strong{Daily ICC}: computed on daily emission estimates. Sensitive
#'     to \code{param1} — more records per day produce more stable daily
#'     averages, reducing within-animal day-to-day noise and increasing ICC.
#'   \item \strong{Weekly ICC}: computed on weekly emission estimates. Sensitive
#'     to \code{param2} — more days per week produce more representative weekly
#'     averages, reducing within-animal week-to-week noise and increasing ICC.
#' }
#' Both ICCs are computed via one-way ANOVA decomposition with a
#' harmonic-adjusted group size for unbalanced designs. Selection proceeds
#' in three stages: (1) combinations retaining fewer than \code{min_retention}
#' of all study animals are excluded; (2) among the remainder, the
#' combination maximising the \strong{composite ICC} — the average of daily
#' and weekly ICC — is identified; (3) any remaining ties are broken by
#' preferring the most lenient parameter set (lowest
#' \code{param1 + param2 + min_time}). Using a composite score avoids the
#' failure mode of sequential optimisation, where locking onto the highest
#' daily ICC first can force selection of an excessively lenient
#' \code{param2} due to the retention constraint.
#'
#' \strong{Note on animal IDs:} \code{N} reflects the number of unique RFIDs
#' in the processed data. If an animal received a new RFID tag mid-study, it
#' will appear as two separate IDs. Pre-process your data to harmonise IDs
#' before running this function.
#'
#' @param data a data frame with preliminary or finalized 'GreenFeed' data,
#'   containing at minimum the columns \code{RFID}, \code{StartTime},
#'   \code{GoodDataDuration}, and the gas column(s).
#' @param start_date a character string representing the start date of the
#'   study (format: \code{"dd/mm/yyyy"} or \code{"yyyy-mm-dd"}).
#' @param end_date a character string representing the end date of the
#'   study (format: \code{"dd/mm/yyyy"} or \code{"yyyy-mm-dd"}).
#' @param gas a character string with the type of gas to evaluate.
#'   One of \code{"CH4"}, \code{"CO2"}, \code{"O2"}, or \code{"H2"}.
#'   Default is \code{"CH4"}.
#' @param min_retention numeric (0 to 1). Minimum proportion of total study
#'   animals that a parameter combination must retain to be considered.
#'   For example, \code{min_retention = 0.70} excludes any combination
#'   that retains fewer than 70\% of all animals in the dataset.
#'   Lower values allow stricter filtering parameters to be considered at
#'   the cost of losing more animals; higher values prioritise animal
#'   coverage at the cost of potentially noisier emission estimates.
#'   Default is \code{0.70} (70\%).
#' @param icc_tol numeric. Tolerance for ICC comparison. Combinations with
#'   ICC within \code{icc_tol} of the maximum are considered equivalent, and
#'   the most lenient among them is selected. Default is \code{0.01}.
#' @param suggest logical. If \code{TRUE}, prints the suggested parameters,
#'   repeatability, animal retention, and a ready-to-use methods sentence.
#'   Default is \code{TRUE}.
#' @param quick logical. If \code{TRUE}, uses a reduced parameter grid
#'   (\code{param2} at 1, 3, 5, 7 instead of 1 through 7). Default is
#'   \code{FALSE}.
#' @param ncores integer. Number of CPU cores for parallel processing.
#'   Default is \code{1}. Parallelization via \code{parallel::mclapply} is
#'   supported on Unix/macOS only; Windows always runs sequentially.
#'
#' @return A data frame sorted from highest to lowest repeatability (ICC),
#'   with one row per valid parameter combination and the following columns:
#'   \describe{
#'     \item{param1}{Minimum number of records per day.}
#'     \item{param2}{Minimum number of days with records per week.}
#'     \item{min_time}{Minimum visit duration in minutes.}
#'     \item{records}{Total weekly animal-records retained.}
#'     \item{N}{Number of unique RFIDs retained.}
#'     \item{mean}{Mean gas production across animals (g/day).}
#'     \item{SD}{Mean within-animal standard deviation (g/day).}
#'     \item{CV}{Mean within-animal CV (\%) computed from weekly data
#'       [informational].}
#'     \item{repeatability_daily}{ICC of daily gas estimates; sensitive to
#'       \code{param1}.}
#'     \item{repeatability_weekly}{ICC of weekly gas estimates; sensitive to
#'       \code{param2}.}
#'     \item{composite_icc}{Mean of daily and weekly ICC; primary selection
#'       criterion. The row with the highest \code{composite_icc} (subject to
#'       the retention threshold) is the recommended parameter set.}
#'   }
#'
#' @examples
#' \donttest{
#' file <- readr::read_csv(
#'   system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr")
#' )
#'
#' # Default: all 140 combinations, 80% retention threshold
#' eval <- eval_gfparam(
#'   data       = file,
#'   start_date = "2024-05-13",
#'   end_date   = "2024-05-20",
#'   gas        = "CH4"
#' )
#'
#' # Faster evaluation with reduced grid
#' eval_quick <- eval_gfparam(
#'   data       = file,
#'   start_date = "2024-05-13",
#'   end_date   = "2024-05-20",
#'   gas        = "CH4",
#'   quick      = TRUE
#' )
#'
#' # Stricter retention requirement
#' eval_strict <- eval_gfparam(
#'   data          = file,
#'   start_date    = "2024-05-13",
#'   end_date      = "2024-05-20",
#'   gas           = "CH4",
#'   min_retention = 0.90
#' )
#' }
#'
#' @export
eval_gfparam <- function(data,
                         start_date,
                         end_date,
                         gas           = "CH4",
                         min_retention = 0.90,
                         icc_tol       = 0.01,
                         suggest       = TRUE,
                         quick         = FALSE,
                         ncores        = 1) {

  # ---------------------------------------------------------------------------
  # Input validation
  # ---------------------------------------------------------------------------
  if (!is.data.frame(data)) stop("'data' must be a data frame.")
  if (!gas %in% c("CH4", "CO2", "O2", "H2"))
    stop("Invalid gas type. Use 'CH4', 'CO2', 'O2', or 'H2'.")
  if (!is.numeric(min_retention) || min_retention <= 0 || min_retention > 1)
    stop("'min_retention' must be a number between 0 (exclusive) and 1.")
  if (!is.numeric(icc_tol) || icc_tol < 0)
    stop("'icc_tol' must be a non-negative number.")

  # ---------------------------------------------------------------------------
  # Gas column mapping
  # ---------------------------------------------------------------------------
  gas_col <- switch(
    gas,
    "CH4" = "CH4GramsPerDay",
    "CO2" = "CO2GramsPerDay",
    "O2"  = "O2GramsPerDay",
    "H2"  = "H2GramsPerDay"
  )

  # ---------------------------------------------------------------------------
  # Helper: parse GoodDataDuration ("HH:MM:SS") to minutes
  # ---------------------------------------------------------------------------
  parse_duration_min <- function(x) {
    parts <- strsplit(as.character(x), ":")
    sapply(parts, function(p) {
      if (length(p) == 3)
        as.numeric(p[1]) * 60 + as.numeric(p[2]) + as.numeric(p[3]) / 60
      else NA_real_
    })
  }

  # ---------------------------------------------------------------------------
  # Stage 1: Diurnal analysis
  # Quantifies how much gas emissions vary across hours of the day.
  # eta-squared = proportion of total variance explained by hour of day.
  # This informs how important param1 is for this specific dataset:
  #   eta < 0.03  -> low diurnal variation  -> param1 = 1-2 acceptable
  #   eta 0.03-0.10 -> moderate             -> param1 = 2-3 recommended
  #   eta > 0.10  -> high diurnal variation -> param1 = 3-5 recommended
  # ---------------------------------------------------------------------------
  diurnal <- tryCatch({
    dur_min <- parse_duration_min(data$GoodDataDuration)
    df_d    <- data[!is.na(dur_min) & dur_min >= 2 & !is.na(data[[gas_col]]), ]

    df_d$hour <- as.integer(format(as.POSIXct(df_d$StartTime), "%H"))
    df_d      <- df_d[!is.na(df_d$hour), ]

    vals  <- df_d[[gas_col]]
    hours <- df_d$hour

    if (length(unique(hours)) < 4) stop("Too few hours represented.")

    hourly_means <- tapply(vals, hours, mean)
    grand_mean   <- mean(vals)
    hour_groups  <- split(vals, hours)

    SS_between <- sum(sapply(hour_groups, function(g)
      length(g) * (mean(g) - grand_mean)^2))
    SS_total   <- sum((vals - grand_mean)^2)
    eta_sq     <- SS_between / SS_total
    diurnal_cv <- sd(hourly_means) / mean(hourly_means) * 100

    # Within-animal diurnal CV (average across animals)
    wa_diurnal_cv <- tryCatch({
      animal_cv <- sapply(split(df_d, df_d$RFID), function(a) {
        h <- tapply(a[[gas_col]], a$hour, mean)
        if (length(h) >= 4) sd(h) / mean(h) * 100 else NA_real_
      })
      round(mean(animal_cv, na.rm = TRUE), 1)
    }, error = function(e) NA_real_)

    level        <- if (eta_sq < 0.03) "low" else if (eta_sq < 0.10) "moderate" else "high"
    param1_range <- if (eta_sq < 0.03) "1-2" else if (eta_sq < 0.10) "2-3" else "3-5"
    note         <- if (eta_sq < 0.03) {
      "Diurnal variation is low. A single record per day is likely sufficient (param1 = 1-2)."
    } else if (eta_sq < 0.10) {
      "Diurnal variation is moderate. At least 2 records/day are recommended (param1 = 2-3)."
    } else {
      "Diurnal variation is high. At least 3 records/day are recommended (param1 = 3-5)."
    }

    list(
      eta_sq        = round(eta_sq, 4),
      diurnal_cv    = round(diurnal_cv, 2),
      wa_diurnal_cv = wa_diurnal_cv,
      peak_hour     = as.integer(names(which.max(hourly_means))),
      trough_hour   = as.integer(names(which.min(hourly_means))),
      level         = level,
      param1_range  = param1_range,
      note          = note
    )
  }, error = function(e) {
    message("Note: Diurnal analysis could not be completed: ", conditionMessage(e))
    NULL
  })

  # Print diurnal result
  if (!is.null(diurnal)) {
    message(sprintf(paste0(
      "\n-- Diurnal analysis (%s) --\n",
      "  eta-squared (hour of day)  : %.4f (%.1f%% of variance)\n",
      "  CV of hourly means         : %.1f%%\n",
      "  Within-animal diurnal CV   : %.1f%%\n",
      "  Peak: %02d:00h | Trough: %02d:00h\n",
      "  %s\n",
      "  -> Recommended param1 range: %s\n",
      "  Note: all param1 values (1-5) are still evaluated below.\n",
      "-------------------------------\n"
    ),
    gas,
    diurnal$eta_sq, diurnal$eta_sq * 100,
    diurnal$diurnal_cv,
    diurnal$wa_diurnal_cv,
    diurnal$peak_hour, diurnal$trough_hour,
    diurnal$note,
    diurnal$param1_range
    ))
  }

  # ---------------------------------------------------------------------------
  # Parameter grid
  # ---------------------------------------------------------------------------
  if (quick) {
    param_combinations <- expand.grid(
      param1   = seq(1, 5),
      param2   = seq(1, 7, by = 2),
      min_time = seq(2, 5),
      stringsAsFactors = FALSE
    )
    message("Using reduced parameter grid (quick = TRUE): ",
            nrow(param_combinations), " combinations.\n")
  } else {
    param_combinations <- expand.grid(
      param1   = seq(1, 5),
      param2   = seq(1, 7),
      min_time = seq(2, 5),
      stringsAsFactors = FALSE
    )
    message("Evaluating ", nrow(param_combinations), " parameter combinations...\n")
  }

  # ---------------------------------------------------------------------------
  # Date format
  # ---------------------------------------------------------------------------
  start_date <- ensure_date_format(start_date)
  end_date   <- ensure_date_format(end_date)

  # ---------------------------------------------------------------------------
  # Helper: within-animal mean, SD, CV from weekly data (informational)
  # ---------------------------------------------------------------------------
  compute_metrics <- function(weekly, gas_col) {
    animal_stats <- dplyr::group_by(weekly, RFID)
    animal_stats <- dplyr::summarize(
      animal_stats,
      mean_gas = mean(.data[[gas_col]], na.rm = TRUE),
      sd_gas   = sd(.data[[gas_col]],   na.rm = TRUE),
      cv_gas   = ifelse(
        .data$mean_gas == 0 | is.na(.data$sd_gas),
        NA_real_,
        (.data$sd_gas / .data$mean_gas) * 100
      ),
      .groups = "drop"
    )
    data.frame(
      mean = round(mean(animal_stats$mean_gas, na.rm = TRUE), 1),
      SD   = round(mean(animal_stats$sd_gas,   na.rm = TRUE), 1),
      CV   = round(mean(animal_stats$cv_gas,   na.rm = TRUE), 2)
    )
  }

  # ---------------------------------------------------------------------------
  # Helper: ICC via one-way ANOVA decomposition
  #
  # Applied to DAILY estimates (not weekly) so that param1 is properly
  # evaluated: more records per day -> more stable daily averages ->
  # lower within-animal day-to-day noise -> higher ICC.
  #
  # Animals with only one daily record are excluded as they cannot
  # contribute to within-animal variance estimation.
  # ---------------------------------------------------------------------------
  compute_repeatability <- function(daily, gas_col) {
    if (is.null(daily) || nrow(daily) == 0) return(NA_real_)
    if (!gas_col %in% colnames(daily))      return(NA_real_)

    # Keep only animals with >= 2 daily records
    counts <- table(daily$RFID)
    daily  <- daily[daily$RFID %in% names(counts[counts > 1]), ]

    vals   <- daily[[gas_col]]
    groups <- as.character(daily$RFID)
    keep   <- !is.na(vals)
    vals   <- vals[keep]
    groups <- groups[keep]

    n_total   <- length(vals)
    n_animals <- length(unique(groups))
    if (n_animals < 2 || n_total < 3) return(NA_real_)

    animal_means <- tapply(vals, groups, mean)
    animal_n     <- tapply(vals, groups, length)
    grand_mean   <- mean(vals)

    # Harmonic-adjusted n for unbalanced design
    n0 <- (n_total - sum(animal_n^2) / n_total) / (n_animals - 1)

    MS_between <- sum(animal_n * (animal_means - grand_mean)^2) / (n_animals - 1)
    MS_within  <- sum(
      tapply(vals, groups, function(x) sum((x - mean(x))^2))
    ) / (n_total - n_animals)

    denom <- MS_between + (n0 - 1) * MS_within
    if (denom == 0) return(NA_real_)

    icc <- (MS_between - MS_within) / denom
    round(max(icc, 0), 4)
  }

  # ---------------------------------------------------------------------------
  # Single combination runner
  # ---------------------------------------------------------------------------
  run_one <- function(combo) {
    p1 <- combo$param1
    p2 <- combo$param2
    mt <- combo$min_time

    tryCatch({
      res <- suppressMessages(
        process_gfdata(
          data       = data,
          start_date = start_date,
          end_date   = end_date,
          param1     = p1,
          param2     = p2,
          min_time   = mt
        )
      )

      weekly <- res$weekly_data
      daily  <- res$daily_data

      if (!gas_col %in% colnames(weekly) || nrow(weekly) == 0)
        stop("No valid weekly data returned.")

      metrics     <- compute_metrics(weekly, gas_col)
      # Daily ICC: sensitive to param1 (quality of daily averages)
      icc_daily   <- compute_repeatability(daily,  gas_col)
      # Weekly ICC: sensitive to param2 (quality of weekly averages)
      icc_weekly  <- compute_repeatability(weekly, gas_col)

      data.frame(
        param1               = p1,
        param2               = p2,
        min_time             = mt,
        records              = nrow(weekly),
        N                    = length(unique(weekly$RFID)),
        mean                 = metrics$mean,
        SD                   = metrics$SD,
        CV                   = metrics$CV,
        repeatability_daily  = icc_daily,
        repeatability_weekly = icc_weekly,
        stringsAsFactors     = FALSE
      )
    }, error = function(e) {
      data.frame(
        param1               = p1,
        param2               = p2,
        min_time             = mt,
        records              = NA_integer_,
        N                    = NA_integer_,
        mean                 = NA_real_,
        SD                   = NA_real_,
        CV                   = NA_real_,
        repeatability_daily  = NA_real_,
        repeatability_weekly = NA_real_,
        stringsAsFactors     = FALSE
      )
    })
  }

  # ---------------------------------------------------------------------------
  # Run all combinations (parallel or sequential)
  # ---------------------------------------------------------------------------
  combo_list <- split(param_combinations, seq(nrow(param_combinations)))

  if (ncores > 1) {
    if (.Platform$OS.type == "windows") {
      message("Note: parallel processing not supported on Windows. Running sequentially.\n")
      results_list <- lapply(combo_list, run_one)
    } else {
      message("Running in parallel with ", ncores, " cores...\n")
      results_list <- parallel::mclapply(combo_list, run_one, mc.cores = ncores)
    }
  } else {
    results_list <- lapply(combo_list, run_one)
  }

  results           <- do.call(rbind, results_list)
  rownames(results) <- NULL

  # ---------------------------------------------------------------------------
  # Parameter selection
  # ---------------------------------------------------------------------------
  results_valid <- results[
    !is.na(results$repeatability_daily) & !is.na(results$N), ]

  if (nrow(results_valid) == 0) {
    warning("No valid parameter combinations found. Check your data and date range.")
    return(results)
  }

  # Stage 1: enforce minimum global animal retention.
  # A combination is eligible only if it retains at least min_retention
  # of the maximum number of animals observed across all combinations.
  # This lets users directly control the retention trade-off:
  # min_retention = 0.70 means "keep combinations that retain >= 70%
  # of all study animals."
  max_n    <- max(results_valid$N, na.rm = TRUE)  # global max = all animals
  eligible <- results_valid[
    !is.na(results_valid$N) & results_valid$N >= min_retention * max_n, ]

  if (nrow(eligible) == 0) {
    message(
      "No combinations met the global retention threshold of ",
      round(min_retention * 100), "%. Selecting from all valid combinations.\n"
    )
    eligible <- results_valid
  }

  # Stage 2: compute composite ICC = mean(daily_ICC, weekly_ICC).
  # A joint score avoids the failure mode of sequential optimisation: locking
  # onto the combination with the highest daily ICC (which may force param2=1
  # due to retention) before weekly ICC is considered.  If only one ICC is
  # available (e.g., too few weekly records for some combos), the available
  # one is used.
  eligible$composite_icc <- ifelse(
    !is.na(eligible$repeatability_daily) & !is.na(eligible$repeatability_weekly),
    (eligible$repeatability_daily + eligible$repeatability_weekly) / 2,
    ifelse(!is.na(eligible$repeatability_daily),
           eligible$repeatability_daily,
           eligible$repeatability_weekly)
  )

  # Stage 3: select combination maximising composite ICC
  best_composite <- max(eligible$composite_icc, na.rm = TRUE)
  near_best      <- eligible[
    !is.na(eligible$composite_icc) &
      eligible$composite_icc >= best_composite - icc_tol, ]

  # Stage 4: tiebreak by most lenient parameters
  near_best$leniency <- near_best$param1 + near_best$param2 + near_best$min_time
  best               <- near_best[which.min(near_best$leniency), ]
  near_best$leniency <- NULL

  # Add composite_icc to full results and sort
  results_valid$composite_icc <- ifelse(
    !is.na(results_valid$repeatability_daily) & !is.na(results_valid$repeatability_weekly),
    (results_valid$repeatability_daily + results_valid$repeatability_weekly) / 2,
    ifelse(!is.na(results_valid$repeatability_daily),
           results_valid$repeatability_daily,
           results_valid$repeatability_weekly)
  )
  results_valid$leniency <- results_valid$param1 +
    results_valid$param2 +
    results_valid$min_time
  results_valid <- results_valid[
    order(-results_valid$composite_icc,
          results_valid$leniency), ]
  results_valid$leniency <- NULL
  rownames(results_valid) <- NULL

  # ---------------------------------------------------------------------------
  # Suggestion message with ready-to-use methods sentence
  # ---------------------------------------------------------------------------
  if (suggest) {
    pct_retained <- round(best$N / max_n * 100)

    pkg_ref <- tryCatch(
      format(citation("greenfeedr"), style = "text")[[1]],
      error = function(e) "Martinez-Boggio et al. (greenfeedr R package)"
    )

    # Diurnal context for methods sentence
    diurnal_text <- if (!is.null(diurnal)) {
      sprintf(
        "Diurnal analysis indicated %s variation in %s emissions across hours of the day (eta-squared = %.2f), ",
        diurnal$level, gas, diurnal$eta_sq
      )
    } else ""

    methods_sentence <- sprintf(paste0(
      "GreenFeed filtering parameters were selected using eval_gfparam\n",
      "  from the greenfeedr R package (%s).\n",
      "  %s",
      "suggesting that %d record(s) per day adequately account for\n",
      "  diurnal variation. Individual visit records were averaged into\n",
      "  daily means requiring a minimum of %d record(s) per day (param1),\n",
      "  and daily means were averaged into weekly estimates requiring a\n",
      "  minimum of %d day(s) with records per week (param2); visits shorter\n",
      "  than %d min were excluded (min_time). This combination maximized\n",
      "  the composite repeatability of %s estimates (daily ICC = %.2f,\n",
      "  weekly ICC = %.2f, composite ICC = %.2f) while retaining %d%% of\n",
      "  study animals."
    ),
    pkg_ref,
    diurnal_text,
    best$param1,
    best$param1, best$param2, best$min_time,
    gas,
    best$repeatability_daily,
    best$repeatability_weekly,
    best$composite_icc,
    pct_retained
    )

    message(sprintf(paste0(
      "\n--- Parameter Suggestion (greenfeedr::eval_gfparam) ---\n",
      "Selection: composite ICC = (daily + weekly) / 2",
      " -> leniency | retention >= %.0f%%\n\n",
      "  param1   = %d  (min. records per day)\n",
      "  param2   = %d  (min. days with records per week)\n",
      "  min_time = %d  (min. minutes per visit)\n\n",
      "  Repeatability daily  (ICC) : %.4f\n",
      "  Repeatability weekly (ICC) : %.4f\n",
      "  Composite ICC              : %.4f  [selection criterion]\n",
      "  Animals retained           : %d / %d (%d%%)\n",
      "  Within-animal CV (weekly)  : %.1f%%  [informational]\n\n",
      "To process your data with these parameters, run:\n",
      "  process_gfdata(..., param1 = %d, param2 = %d, min_time = %d)\n\n",
      "-- Suggested methods text (copy/paste into your paper) --\n",
      "%s\n",
      "--------------------------------------------------------\n"
    ),
    min_retention * 100,
    best$param1, best$param2, best$min_time,
    best$repeatability_daily,
    best$repeatability_weekly,
    best$composite_icc,
    best$N, max_n, pct_retained,
    best$CV,
    best$param1, best$param2, best$min_time,
    methods_sentence
    ))
  }

  message("Done!")
  return(results_valid)
}
