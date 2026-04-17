#' @name eval_gfparam
#' @title Evaluate all combinations of parameters
#'
#' @description
#' Evaluate filtering parameters that best fit your 'GreenFeed' data using a
#' repeatability-based selection criterion.
#'
#' 'GreenFeed' units record gas emissions during voluntary animal visits,
#' producing an irregular series of individual measurements throughout the day.
#' To obtain a reliable emission estimate for each animal, records are
#' aggregated in two sequential steps: (1) individual visit records within a
#' day are averaged into a daily mean, requiring a minimum number of records
#' per day (\code{param1}); and (2) daily means within a week are averaged
#' into a weekly mean, requiring a minimum number of days with records per
#' week (\code{param2}). A minimum visit duration (\code{min_time}) can
#' additionally be applied to exclude incomplete measurements. The
#' experimental emission estimate for each animal is then derived from its
#' weekly means across the study period.
#'
#' Each aggregation step introduces potential measurement error: a daily
#' average based on a single short visit may not represent the animal's true
#' diurnal emission pattern, and a weekly average based on a single day may
#' not represent the full week. The parameters \code{param1} and \code{param2}
#' act as reliability thresholds at each level of this hierarchy, ensuring
#' that only sufficiently sampled days and weeks contribute to the final
#' animal estimate.
#'
#' \code{eval_gfparam} identifies the parameter combination that maximizes the
#' repeatability (intraclass correlation coefficient, ICC) of weekly emission
#' estimates. ICC quantifies the proportion of total variance attributable to
#' true between-animal differences, as opposed to within-animal week-to-week
#' noise. A higher ICC indicates that the chosen parameters produce weekly
#' estimates that reliably reflect each animal's true emission level.
#' Parameter combinations retaining fewer than \code{min_retention} of the
#' maximum possible animals are excluded before selection. When multiple
#' combinations yield equivalent ICC values (within \code{icc_tol}), the most
#' lenient set is preferred to maximise data retained for analysis.
#'
#' @param data a data frame with preliminary or finalized 'GreenFeed' data.
#' @param start_date a character string representing the start date of the
#'   study (format: \code{"dd/mm/yyyy"} or \code{"yyyy-mm-dd"}).
#' @param end_date a character string representing the end date of the
#'   study (format: \code{"dd/mm/yyyy"} or \code{"yyyy-mm-dd"}).
#' @param gas a character string with the type of gas to evaluate.
#'   One of \code{"CH4"}, \code{"CO2"}, \code{"O2"}, or \code{"H2"}.
#'   Default is \code{"CH4"}.
#' @param min_retention numeric (0 to 1). Minimum proportion of the maximum
#'   number of animals retained that a parameter combination must achieve to
#'   be considered. Default is \code{0.80} (80\%).
#' @param icc_tol numeric. Tolerance for ICC comparison. Combinations with
#'   ICC within \code{icc_tol} of the maximum are considered equivalent, and
#'   the most lenient among them is selected. Default is \code{0.01}.
#' @param suggest logical. If \code{TRUE}, prints the suggested parameter
#'   combination, repeatability, animal retention, within-animal CV, and a
#'   ready-to-use methods sentence for reporting. Default is \code{TRUE}.
#' @param quick logical. If \code{TRUE}, uses a reduced parameter grid
#'   (\code{param2} evaluated at 1, 3, 5, 7 instead of 1 through 7) for
#'   faster evaluation. Default is \code{FALSE}.
#' @param ncores integer. Number of CPU cores for parallel processing.
#'   Default is \code{1} (sequential). Parallelization via
#'   \code{parallel::mclapply} is supported on Unix/macOS only; on Windows
#'   the function always runs sequentially.
#'
#' @return A data frame sorted from highest to lowest repeatability, with one
#'   row per valid parameter combination and the following columns:
#'   \describe{
#'     \item{param1}{Minimum number of records per day.}
#'     \item{param2}{Minimum number of days with records per week.}
#'     \item{min_time}{Minimum visit duration in minutes.}
#'     \item{records}{Total number of weekly animal-records retained.}
#'     \item{N}{Number of unique animals retained.}
#'     \item{mean}{Mean gas production across animals (g/day).}
#'     \item{SD}{Mean within-animal standard deviation (g/day).}
#'     \item{CV}{Mean within-animal coefficient of variation (\%) [informational].}
#'     \item{repeatability}{Intraclass correlation coefficient (ICC) of weekly
#'       gas estimates; the primary selection criterion.}
#'   }
#'
#' @examples
#' \donttest{
#' file <- readr::read_csv(
#'   system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr")
#' )
#'
#' # Default: all 140 combinations, 80% animal retention threshold
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
#' # Stricter retention requirement (keep at least 90% of animals)
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
                         min_retention = 0.95,
                         icc_tol       = 0.01,
                         suggest       = TRUE,
                         quick         = FALSE,
                         ncores        = 1) {

  # ---------------------------------------------------------------------------
  # Input validation
  # ---------------------------------------------------------------------------
  if (!is.data.frame(data)) {
    stop("'data' must be a data frame.")
  }
  if (!gas %in% c("CH4", "CO2", "O2", "H2")) {
    stop("Invalid gas type. Use 'CH4', 'CO2', 'O2', or 'H2'.")
  }
  if (!is.numeric(min_retention) || min_retention <= 0 || min_retention > 1) {
    stop("'min_retention' must be a number between 0 (exclusive) and 1.")
  }
  if (!is.numeric(icc_tol) || icc_tol < 0) {
    stop("'icc_tol' must be a non-negative number.")
  }

  # ---------------------------------------------------------------------------
  # Parameter grid
  # ---------------------------------------------------------------------------
  if (quick) {
    param_combinations <- expand.grid(
      param1   = seq(1, 5),
      param2   = seq(1, 7, by = 2),   # 1, 3, 5, 7
      min_time = seq(2, 5),
      stringsAsFactors = FALSE
    )
    message(
      "Using reduced parameter grid (quick = TRUE): ",
      nrow(param_combinations), " combinations.\n"
    )
  } else {
    param_combinations <- expand.grid(
      param1   = seq(1, 5),
      param2   = seq(1, 7),
      min_time = seq(2, 5),
      stringsAsFactors = FALSE
    )
    message(
      "Evaluating ", nrow(param_combinations), " parameter combinations...\n"
    )
  }

  # ---------------------------------------------------------------------------
  # Date format
  # ---------------------------------------------------------------------------
  start_date <- ensure_date_format(start_date)
  end_date   <- ensure_date_format(end_date)

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
  # Helper: within-animal mean, SD, CV (informational only)
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
  # Helper: repeatability (ICC) via one-way ANOVA decomposition
  #
  # ICC = (MS_between - MS_within) / (MS_between + (n0 - 1) * MS_within)
  #
  # n0 is the harmonic-adjusted group size for unbalanced designs.
  # Animals with only one weekly record are excluded because a single
  # observation cannot contribute to within-animal variance estimation.
  # ---------------------------------------------------------------------------
  compute_repeatability <- function(weekly, gas_col) {
    counts <- table(weekly$RFID)
    weekly <- weekly[weekly$RFID %in% names(counts[counts > 1]), ]

    vals   <- weekly[[gas_col]]
    groups <- as.character(weekly$RFID)
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

    MS_between <- sum(animal_n * (animal_means - grand_mean)^2) /
      (n_animals - 1)
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

      if (!gas_col %in% colnames(weekly) || nrow(weekly) == 0) {
        stop("No valid data returned for this combination.")
      }

      metrics <- compute_metrics(weekly, gas_col)
      icc_val <- compute_repeatability(weekly, gas_col)

      data.frame(
        param1        = p1,
        param2        = p2,
        min_time      = mt,
        records       = nrow(weekly),
        N             = length(unique(weekly$RFID)),
        mean          = metrics$mean,
        SD            = metrics$SD,
        CV            = metrics$CV,
        repeatability = icc_val,
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      data.frame(
        param1        = p1,
        param2        = p2,
        min_time      = mt,
        records       = NA_integer_,
        N             = NA_integer_,
        mean          = NA_real_,
        SD            = NA_real_,
        CV            = NA_real_,
        repeatability = NA_real_,
        stringsAsFactors = FALSE
      )
    })
  }

  # ---------------------------------------------------------------------------
  # Run all combinations (parallel or sequential)
  # ---------------------------------------------------------------------------
  combo_list <- split(param_combinations, seq(nrow(param_combinations)))

  if (ncores > 1) {
    if (.Platform$OS.type == "windows") {
      message(
        "Note: parallel processing is not supported on Windows. ",
        "Running sequentially.\n"
      )
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
  results_valid <- results[!is.na(results$repeatability) & !is.na(results$N), ]

  if (nrow(results_valid) == 0) {
    warning(
      "No valid parameter combinations found. ",
      "Check your data and date range."
    )
    return(results)
  }

  # Stage 1: enforce minimum animal retention threshold
  max_n    <- max(results_valid$N, na.rm = TRUE)
  eligible <- results_valid[results_valid$N >= min_retention * max_n, ]

  if (nrow(eligible) == 0) {
    message(
      "No combinations met the retention threshold of ",
      round(min_retention * 100), "%. ",
      "Selecting from all valid combinations.\n"
    )
    eligible <- results_valid
  }

  # Stage 2: maximize ICC; tiebreak by preferring most lenient parameters
  best_icc  <- max(eligible$repeatability, na.rm = TRUE)
  near_best <- eligible[
    !is.na(eligible$repeatability) &
      eligible$repeatability >= best_icc - icc_tol, ]

  near_best$leniency <- near_best$param1 + near_best$param2 + near_best$min_time
  best               <- near_best[which.min(near_best$leniency), ]
  near_best$leniency <- NULL

  # Sort full results by repeatability (desc), then leniency (asc)
  results_valid$leniency <- results_valid$param1 +
    results_valid$param2 +
    results_valid$min_time
  results_valid <- results_valid[
    order(-results_valid$repeatability, results_valid$leniency), ]
  results_valid$leniency <- NULL
  rownames(results_valid) <- NULL

  # ---------------------------------------------------------------------------
  # Suggestion message with ready-to-use methods sentence
  # ---------------------------------------------------------------------------
  if (suggest) {
    pct_retained <- round(best$N / max_n * 100)

    # Retrieve package citation info for the methods sentence
    pkg_ref <- tryCatch(
      format(citation("greenfeedr"), style = "text")[[1]],
      error = function(e) "Martinez-Boggio et al. 2025 (greenfeedr R package)"
    )

    methods_sentence <- sprintf(
      paste0(
        'GreenFeed filtering parameters were selected using eval_gfparam\n',
        '  from the greenfeedr R package (%s).\n',
        '  Individual visit records were averaged into daily means requiring\n',
        '  a minimum of %d record(s) per day (param1), and daily means were\n',
        '  averaged into weekly estimates requiring a minimum of %d day(s)\n',
        '  with records per week (param2); visits shorter than %d min were\n',
        '  excluded (min_time). This combination maximized the repeatability\n',
        '  of weekly %s estimates (ICC = %.2f) while retaining %d%% of\n',
        '  study animals.'
      ),
      pkg_ref,
      best$param1, best$param2, best$min_time,
      gas,
      best$repeatability,
      pct_retained
    )

    message(sprintf(paste0(
      "\n--- Parameter Suggestion (greenfeedr::eval_gfparam) ---\n",
      "Selection criterion : max repeatability (ICC)",
      " | retention >= %.0f%%\n\n",
      "  param1   = %d  (min. records per day)\n",
      "  param2   = %d  (min. days with records per week)\n",
      "  min_time = %d  (min. minutes per visit)\n\n",
      "  Repeatability (ICC) : %.4f\n",
      "  Animals retained    : %d / %d (%d%%)\n",
      "  Within-animal CV    : %.1f%%  [informational]\n\n",
      "To process your data with these parameters, run:\n",
      "  process_gfdata(..., param1 = %d, param2 = %d, min_time = %d)\n\n",
      "-- Suggested methods text (copy/paste into your paper) --\n",
      "%s\n",
      "--------------------------------------------------------\n"
    ),
    min_retention * 100,
    best$param1, best$param2, best$min_time,
    best$repeatability,
    best$N, max_n, pct_retained,
    best$CV,
    best$param1, best$param2, best$min_time,
    methods_sentence
    ))
  }

  message("Done!")
  return(results_valid)
}
