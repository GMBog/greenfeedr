#' @name process_gfdata
#' @title Process Preliminary and Finalized 'GreenFeed' Data
#'
#' @description
#' Processes and calculates daily and weekly averages of 'GreenFeed' data.
#'
#' When \code{param1}, \code{param2}, and \code{min_time} are all omitted
#' (the default), the function automatically selects the combination of
#' filtering parameters that maximises the composite repeatability (ICC) of
#' \code{gas} emission estimates while retaining at least
#' \code{min_retention} of the study animals. Biological floors are applied
#' before the search: the minimum \code{param1} is determined by the degree
#' of diurnal variation (low -> 1, moderate -> 2, high -> 3); \code{param2}
#' is bounded at a minimum of 2 days per week; and \code{min_bins = 2} is
#' only included in the grid when the study median visits per animal per day
#' is >= 2 (otherwise requiring both diurnal phases per day would incorrectly
#' exclude animals with random once-daily visit timing). Diurnal time bins
#' are derived from the data. The selected parameters and repeatability
#' statistics are printed to the console, and the full optimisation table is
#' attached as \code{attr(result, "optimization")}.
#'
#' When all three of \code{param1}, \code{param2}, and \code{min_time} are
#' supplied, the function runs in manual mode with those exact values.
#'
#' @param data a data frame with preliminary or finalized 'GreenFeed' data.
#' @param start_date character. Start date (\code{"DD-MM-YY"} or
#'   \code{"YYYY-MM-DD"}).
#' @param end_date character. End date (\code{"DD-MM-YY"} or
#'   \code{"YYYY-MM-DD"}).
#' @param param1 integer. Minimum records per day. Omit for automatic
#'   selection (default: \code{NULL}).
#' @param param2 integer. Minimum days with records per week. Omit for
#'   automatic selection (default: \code{NULL}).
#' @param min_time numeric. Minimum visit duration in minutes. Omit for
#'   automatic selection (default: \code{NULL}).
#' @param gas character. Gas whose ICC is maximised in automatic mode.
#'   One of \code{"CH4"}, \code{"CO2"}, \code{"O2"}, \code{"H2"}.
#'   Default: \code{"CH4"}.
#' @param min_retention numeric (0--1). Minimum proportion of study animals
#'   a combination must retain in automatic mode. Default: \code{0.80}.
#' @param icc_tol numeric. Combinations within \code{icc_tol} of the maximum
#'   composite ICC are treated as tied; the most lenient is selected.
#'   Default: \code{0.01}.
#' @param quick logical. Use a reduced parameter grid in automatic mode.
#'   Default: \code{FALSE}.
#' @param peak_hour optional integer. Hour of peak emissions for bin-weighted
#'   daily means (manual mode only; auto-detected in automatic mode).
#' @param trough_hour optional integer. Hour of trough emissions for
#'   bin-weighted daily means (manual mode only).
#' @param min_bins integer (1 or 2). Minimum diurnal phases an animal-day
#'   must cover to be retained. Optimised automatically in auto mode;
#'   default \code{1} in manual mode.
#' @param transform logical. Convert gas production from g/day to L/day.
#'   Default: \code{FALSE}.
#' @param cutoff integer. SDs for outlier removal. Default: \code{3}.
#'
#' @return A named list with three data frames:
#'   \item{filtered_data}{visit-level records after quality filtering.}
#'   \item{daily_data}{daily emission estimates.}
#'   \item{weekly_data}{weekly emission estimates.}
#'   In automatic mode, the full optimisation table is accessible via
#'   \code{attr(result, "optimization")} and the diurnal analysis via
#'   \code{attr(result, "diurnal")}.
#'
#' @examples
#' \donttest{
#' file <- system.file("extdata", "StudyName_GFdata.csv", package = "greenfeedr")
#' datafile <- readr::read_csv(file)
#'
#' # Automatic mode (recommended)
#' gf <- process_gfdata(datafile, "2024-05-13", "2024-05-25")
#' attr(gf, "optimization")   # full grid results
#' attr(gf, "diurnal")$plot   # diurnal curve
#'
#' # Manual mode
#' gf <- process_gfdata(datafile, "2024-05-13", "2024-05-25",
#'                      param1 = 2, param2 = 3, min_time = 2)
#' }
#'
#' @export process_gfdata
#'
#' @import dplyr
#' @importFrom dplyr %>%
#' @import readxl
#' @importFrom stats weighted.mean sd aggregate setNames
utils::globalVariables(c(
  "EndTime", "CH4GramsPerDay", "CO2GramsPerDay", "O2GramsPerDay", "H2GramsPerDay",
  "nDays", "nRecords", "TotalMin",
  "value", "phase",
  "bin", "n_bin", "bin_minutes", "n_bins_covered"
))
process_gfdata <- function(data, start_date, end_date,
                           param1        = NULL,
                           param2        = NULL,
                           min_time      = NULL,
                           gas           = "CH4",
                           min_retention = 0.80,
                           icc_tol       = 0.01,
                           quick         = FALSE,
                           peak_hour     = NULL,
                           trough_hour   = NULL,
                           min_bins      = 1,
                           transform     = FALSE,
                           cutoff        = 3) {
  # ---------------------------------------------------------------------------
  # Parameter mode detection
  # ---------------------------------------------------------------------------
  auto_mode <- is.null(param1) && is.null(param2) && is.null(min_time)
  if (!auto_mode && (is.null(param1) || is.null(param2) || is.null(min_time)))
    stop("Supply all three of param1, param2, and min_time together, ",
         "or omit all three for automatic selection.")
  # ---------------------------------------------------------------------------
  # Input validation
  # ---------------------------------------------------------------------------
  start_date <- ensure_date_format(start_date)
  end_date   <- ensure_date_format(end_date)
  if (!gas %in% c("CH4", "CO2", "O2", "H2"))
    stop("'gas' must be one of 'CH4', 'CO2', 'O2', 'H2'.")
  gas_col <- switch(gas,
                    "CH4" = "CH4GramsPerDay", "CO2" = "CO2GramsPerDay",
                    "O2"  = "O2GramsPerDay",  "H2"  = "H2GramsPerDay")
  if (!auto_mode) {
    param1   <- as.integer(param1)
    param2   <- as.integer(param2)
    min_time <- as.numeric(min_time)
    min_bins <- as.integer(min_bins)
    if (!min_bins %in% 1:2) stop("'min_bins' must be 1 or 2.")
  }
  if (!is.numeric(min_retention) || min_retention <= 0 || min_retention > 1)
    stop("'min_retention' must be between 0 (exclusive) and 1.")
  if (!is.numeric(icc_tol) || icc_tol < 0)
    stop("'icc_tol' must be a non-negative number.")
  # ---------------------------------------------------------------------------
  # Normalise, quality-filter, derive columns (common to both modes)
  # ---------------------------------------------------------------------------
  df <- normalize_gfdata(data)
  df <- df %>%
    dplyr::mutate(RFID = gsub("^0+", "", RFID)) %>%
    dplyr::filter(RFID != "unknown", AirflowLitersPerSec >= 25) %>%
    dplyr::mutate(
      CH4GramsPerDay   = ifelse(CH4GramsPerDay <= 0, NA, CH4GramsPerDay),
      CO2GramsPerDay   = ifelse(CO2GramsPerDay <= 0, NA, CO2GramsPerDay),
      O2GramsPerDay    = ifelse(O2GramsPerDay  <= 0, NA, O2GramsPerDay),
      H2GramsPerDay    = ifelse(H2GramsPerDay  <= 0, NA, H2GramsPerDay),
      day              = as.Date(substr(StartTime, 1, 10)),
      hour             = as.integer(substr(StartTime, 12, 13)),
      GoodDataDuration = round(
        as.numeric(substr(GoodDataDuration, 1, 2)) * 60 +
          as.numeric(substr(GoodDataDuration, 4, 5)) +
          as.numeric(substr(GoodDataDuration, 7, 8)) / 60, 2)
    )
  # Base dataset: outlier-removed and date-filtered; min_time not yet applied
  # so the grid search can explore different min_time thresholds.
  d_base <- df %>%
    dplyr::filter(
      dplyr::if_all(c(CH4GramsPerDay, CO2GramsPerDay),
                    ~ filter_within_range(.x, cutoff)),
      !is.na(CH4GramsPerDay) & !is.na(CO2GramsPerDay),
      day >= start_date & day <= end_date
    )
  if (nrow(d_base) == 0)
    stop("No valid records found after date range and quality filters.")
  # ---------------------------------------------------------------------------
  # Optimisation output placeholders
  # ---------------------------------------------------------------------------
  opt_results <- NULL
  diurnal     <- NULL
  # ===========================================================================
  # [AUTO MODE] Diurnal analysis + ICC grid search
  # ===========================================================================
  if (auto_mode) {
    message("\n[process_gfdata] No parameters supplied. Running automatic optimisation...\n")
    # ---- Diurnal analysis --------------------------------------------------
    diurnal <- tryCatch({
      df_d  <- d_base[!is.na(d_base$GoodDataDuration) & d_base$GoodDataDuration >= 2 &
                        !is.na(d_base[[gas_col]]) & d_base[[gas_col]] > 0, ]
      if (length(unique(df_d$hour)) < 4)
        stop("Too few distinct hours for diurnal analysis.")
      vals         <- df_d[[gas_col]]
      hours        <- df_d$hour
      hourly_means <- tapply(vals, hours, mean)
      grand_mean   <- mean(vals)
      hour_groups  <- split(vals, hours)
      SS_between   <- sum(sapply(hour_groups,
                                 function(g) length(g) * (mean(g) - grand_mean)^2))
      SS_total     <- sum((vals - grand_mean)^2)
      eta_sq       <- SS_between / SS_total
      diurnal_cv   <- stats::sd(hourly_means) / mean(hourly_means) * 100
      peak_h       <- as.integer(names(which.max(hourly_means)))
      trough_h     <- as.integer(names(which.min(hourly_means)))
      level        <- if (eta_sq < 0.03) "low" else
        if (eta_sq < 0.10) "moderate" else "high"
      # Plot
      diurnal_plot <- if (requireNamespace("ggplot2", quietly = TRUE)) {
        all_hours   <- 0:23
        hmeans_full <- as.numeric(
          hourly_means[match(as.character(all_hours), names(hourly_means))])
        hour_df <- data.frame(hour = all_hours, value = hmeans_full)
        hour_df$phase <- if (peak_h > trough_h) {
          ifelse(hour_df$hour >= trough_h & hour_df$hour < peak_h,
                 "Rising phase", "Declining phase")
        } else {
          ifelse(hour_df$hour >= trough_h | hour_df$hour < peak_h,
                 "Rising phase", "Declining phase")
        }
        hour_df$phase <- factor(hour_df$phase,
                                levels = c("Rising phase", "Declining phase"))
        ymax  <- max(hour_df$value, na.rm = TRUE)
        y_ann <- ymax + (ymax - min(hour_df$value, na.rm = TRUE)) * 0.10
        ggplot2::ggplot(hour_df, ggplot2::aes(x = hour, y = value)) +
          ggplot2::geom_line(color = "grey30", linewidth = 0.9, na.rm = TRUE) +
          ggplot2::geom_point(ggplot2::aes(color = phase), size = 3, na.rm = TRUE) +
          ggplot2::geom_vline(xintercept = peak_h,   linetype = "dashed",
                              color = "#d6604d", linewidth = 0.7) +
          ggplot2::geom_vline(xintercept = trough_h, linetype = "dashed",
                              color = "#4575b4", linewidth = 0.7) +
          ggplot2::annotate("text", x = peak_h,   y = y_ann,
                            label = sprintf("Peak\n%02d:00 h",   peak_h),
                            color = "#d6604d", hjust = 0.5, size = 3.2, fontface = "bold") +
          ggplot2::annotate("text", x = trough_h, y = y_ann,
                            label = sprintf("Trough\n%02d:00 h", trough_h),
                            color = "#4575b4", hjust = 0.5, size = 3.2, fontface = "bold") +
          ggplot2::scale_color_manual(
            values = c("Rising phase" = "#4dac26", "Declining phase" = "#d01c8b"),
            name   = "Diurnal phase") +
          ggplot2::scale_x_continuous(breaks = seq(0, 22, by = 2),
                                      limits = c(-0.5, 23.5)) +
          ggplot2::coord_cartesian(clip = "off") +
          ggplot2::labs(
            x        = "Hour of day",
            y        = paste0(gas, " production (g/day)"),
            title    = sprintf("Diurnal pattern of %s emissions", gas),
            subtitle = sprintf(
              "eta-squared = %.4f  |  Variation: %s  |  Peak: %02d:00 h  |  Trough: %02d:00 h",
              eta_sq, toupper(level), peak_h, trough_h)) +
          ggplot2::theme_bw(base_size = 11) +
          ggplot2::theme(legend.position  = "bottom",
                         panel.grid.minor = ggplot2::element_blank(),
                         plot.margin      = ggplot2::margin(20, 10, 5, 10))
      } else {
        message("Install ggplot2 for the diurnal curve plot."); NULL
      }
      message(sprintf(paste0(
        "-- Diurnal analysis (%s) --\n",
        "  eta-squared       : %.4f (%.1f%% of variance)  ->  Variation: %s\n",
        "  CV of hourly means: %.1f%%\n",
        "  Peak: %02d:00 h  |  Trough: %02d:00 h\n",
        "  Bins: rising [%02d:00--%02d:00]  |  declining [%02d:00--%02d:00]\n",
        "-------------------------------"),
        gas, eta_sq, eta_sq * 100, toupper(level), diurnal_cv,
        peak_h, trough_h, trough_h, peak_h, peak_h, trough_h))
      if (!is.null(diurnal_plot)) print(diurnal_plot)
      list(eta_sq       = round(eta_sq, 4),
           diurnal_cv   = round(diurnal_cv, 2),
           peak_hour    = peak_h,
           trough_hour  = trough_h,
           level        = level,
           hourly_means = hourly_means,
           plot         = diurnal_plot)
    }, error = function(e) {
      message("Note: Diurnal analysis could not be completed: ", conditionMessage(e))
      NULL
    })
    # ---- Bin assignment function for the grid search -----------------------
    if (!is.null(diurnal) && diurnal$peak_hour != diurnal$trough_hour) {
      ph_g <- diurnal$peak_hour; th_g <- diurnal$trough_hour
      assign_bin_g <- if (ph_g > th_g) {
        function(h) ifelse(h >= th_g & h < ph_g, 1L, 2L)
      } else {
        function(h) ifelse(h >= th_g | h < ph_g, 1L, 2L)
      }
      n_bins_possible <- 2L
    } else {
      assign_bin_g    <- function(h) rep(1L, length(h))
      n_bins_possible <- 1L
    }
    # ---- Retention denominator & annotate d_base ---------------------------
    max_n       <- length(unique(d_base$RFID))
    d_base$bin  <- assign_bin_g(d_base$hour)
    d_base$week <- floor(as.numeric(
      difftime(d_base$day, as.Date(start_date), units = "weeks"))) + 1
    # ---- Study visit statistics (set biological floors) --------------------
    vpd_tbl <- stats::aggregate(
      list(n_visits = rep(1L, nrow(d_base))),
      by  = list(RFID = d_base$RFID, day = d_base$day),
      FUN = sum)
    median_vpd <- median(vpd_tbl$n_visits, na.rm = TRUE)
    mean_vpd   <- mean(vpd_tbl$n_visits,   na.rm = TRUE)

    dpw_tbl <- stats::aggregate(
      list(n_days = d_base$day),
      by  = list(RFID = d_base$RFID, week = d_base$week),
      FUN = function(x) length(unique(x)))
    mean_dpw <- mean(dpw_tbl$n_days, na.rm = TRUE)
    # ---- ICC helper --------------------------------------------------------
    compute_repeatability <- function(df_r, col) {
      if (is.null(df_r) || nrow(df_r) == 0 || !col %in% colnames(df_r))
        return(NA_real_)
      counts <- table(df_r$RFID)
      df_r   <- df_r[df_r$RFID %in% names(counts[counts > 1]), ]
      vals   <- df_r[[col]]; groups <- as.character(df_r$RFID)
      keep   <- !is.na(vals); vals <- vals[keep]; groups <- groups[keep]
      n_tot  <- length(vals); n_an <- length(unique(groups))
      if (n_an < 2 || n_tot < 3) return(NA_real_)
      am  <- tapply(vals, groups, mean)
      an  <- tapply(vals, groups, length)
      gm  <- mean(vals)
      n0  <- (n_tot - sum(an^2) / n_tot) / (n_an - 1)
      MSb <- sum(an * (am - gm)^2) / (n_an - 1)
      MSw <- sum(tapply(vals, groups,
                        function(x) sum((x - mean(x))^2))) / (n_tot - n_an)
      den <- MSb + (n0 - 1) * MSw
      if (den == 0) return(NA_real_)
      round(max((MSb - MSw) / den, 0), 4)
    }
    # ---- Biological floors for grid construction ---------------------------
    # param1 minimum: LOW diurnal -> 1, MODERATE -> 2, HIGH -> 3
    p1_min <- if (is.null(diurnal)) 1L else
      switch(diurnal$level, low = 1L, moderate = 2L, high = 3L, 1L)

    # min_bins = 2 only feasible when median visits/animal/day >= 2;
    # otherwise animals with random once-daily visits are incorrectly excluded
    mb_grid <- if (n_bins_possible > 1 && median_vpd >= 2) 1:2 else 1L

    # param2 minimum = 2: one day/week cannot constitute a weekly estimate
    param_grid <- if (quick) {
      expand.grid(param1   = p1_min:4,
                  param2   = c(2, 4, 7),
                  min_time = 2:4,
                  min_bins = mb_grid,
                  stringsAsFactors = FALSE)
    } else {
      expand.grid(param1   = p1_min:8,
                  param2   = 2:7,
                  min_time = 2:6,
                  min_bins = mb_grid,
                  stringsAsFactors = FALSE)
    }
    message(sprintf("Evaluating %d parameter combinations...", nrow(param_grid)))
    # ---- Precompute per min_time (avoids redundant filtering) --------------
    mt_vals <- sort(unique(param_grid$min_time))
    precomp <- lapply(stats::setNames(mt_vals, as.character(mt_vals)), function(mt) {
      d <- d_base[!is.na(d_base$GoodDataDuration) & d_base$GoodDataDuration >= mt &
                    !is.na(d_base[[gas_col]]) & d_base[[gas_col]] > 0, ]
      if (nrow(d) == 0) return(NULL)
      bin_agg <- stats::aggregate(d[[gas_col]],
                                  by  = list(RFID = d$RFID, day = d$day,
                                             week = d$week, bin = d$bin),
                                  FUN = mean)
      names(bin_agg)[names(bin_agg) == "x"] <- gas_col
      n_visits_df <- stats::aggregate(d[[gas_col]],
                                      by  = list(RFID = d$RFID, day = d$day),
                                      FUN = length)
      names(n_visits_df)[names(n_visits_df) == "x"] <- "n_visits"
      n_bins_df <- stats::aggregate(bin_agg$bin,
                                    by  = list(RFID = bin_agg$RFID, day = bin_agg$day),
                                    FUN = function(x) length(unique(x)))
      names(n_bins_df)[names(n_bins_df) == "x"] <- "n_bins_covered"
      daily_all <- stats::aggregate(bin_agg[[gas_col]],
                                    by  = list(RFID = bin_agg$RFID, day = bin_agg$day,
                                               week = bin_agg$week),
                                    FUN = mean)
      names(daily_all)[names(daily_all) == "x"] <- gas_col
      daily_all <- merge(daily_all, n_visits_df, by = c("RFID", "day"))
      daily_all <- merge(daily_all, n_bins_df,   by = c("RFID", "day"))
      list(daily_all = daily_all)
    })
    # ---- Run grid ----------------------------------------------------------
    run_one <- function(combo) {
      p1 <- combo$param1; p2 <- combo$param2
      mt <- combo$min_time; mb <- combo$min_bins
      tryCatch({
        pc <- precomp[[as.character(mt)]]
        if (is.null(pc)) stop("no data")
        daily <- pc$daily_all[pc$daily_all$n_visits       >= p1 &
                                pc$daily_all$n_bins_covered >= mb, ]
        if (nrow(daily) == 0 || length(unique(daily$RFID)) < 2)
          stop("no daily data")
        wn <- stats::aggregate(daily[[gas_col]],
                               by = list(RFID = daily$RFID, week = daily$week),
                               FUN = length)
        names(wn)[names(wn) == "x"] <- "n_days"
        wm <- stats::aggregate(daily[[gas_col]],
                               by = list(RFID = daily$RFID, week = daily$week),
                               FUN = mean)
        names(wm)[names(wm) == "x"] <- gas_col
        weekly <- merge(wn, wm, by = c("RFID", "week"))
        weekly <- weekly[weekly$n_days >= p2, ]
        if (nrow(weekly) == 0 || length(unique(weekly$RFID)) < 2)
          stop("no weekly data")
        data.frame(
          param1               = p1, param2 = p2,
          min_time             = mt, min_bins = mb,
          N                    = length(unique(weekly$RFID)),
          repeatability_daily  = compute_repeatability(daily,  gas_col),
          repeatability_weekly = compute_repeatability(weekly, gas_col),
          stringsAsFactors     = FALSE)
      }, error = function(e)
        data.frame(param1 = p1, param2 = p2, min_time = mt, min_bins = mb,
                   N = NA_integer_, repeatability_daily = NA_real_,
                   repeatability_weekly = NA_real_, stringsAsFactors = FALSE))
    }
    results      <- do.call(rbind, lapply(split(param_grid, seq(nrow(param_grid))), run_one))
    rownames(results) <- NULL
    # ---- Selection ---------------------------------------------------------
    results_valid <- results[!is.na(results$repeatability_daily) & !is.na(results$N), ]
    if (nrow(results_valid) == 0)
      stop("No valid parameter combinations found. Check your data and date range.")
    eligible <- results_valid[results_valid$N >= min_retention * max_n, ]
    if (nrow(eligible) == 0) {
      message("No combinations met the retention threshold of ",
              round(min_retention * 100), "%. Selecting from all valid combinations.")
      eligible <- results_valid
    }
    eligible$composite_icc <- ifelse(
      !is.na(eligible$repeatability_daily) & !is.na(eligible$repeatability_weekly),
      (eligible$repeatability_daily + eligible$repeatability_weekly) / 2,
      ifelse(!is.na(eligible$repeatability_daily),
             eligible$repeatability_daily, eligible$repeatability_weekly))
    best_icc  <- max(eligible$composite_icc, na.rm = TRUE)
    near_best <- eligible[!is.na(eligible$composite_icc) &
                            eligible$composite_icc >= best_icc - icc_tol, ]
    near_best$leniency <- near_best$param1 + near_best$param2 +
      near_best$min_time + (near_best$min_bins - 1)
    if (!is.null(diurnal) && diurnal$level == "high") {
      near_best <- near_best[order(-near_best$min_bins, near_best$leniency), ]
      best <- near_best[1, ]
    } else {
      best <- near_best[which.min(near_best$leniency), ]
    }
    # ---- Assign selected params to outer scope ----------------------------
    param1      <- best$param1
    param2      <- best$param2
    min_time    <- best$min_time
    min_bins    <- best$min_bins
    if (!is.null(diurnal)) {
      peak_hour   <- diurnal$peak_hour
      trough_hour <- diurnal$trough_hour
    }
    # ---- Sort and store full optimisation table ----------------------------
    results_valid$composite_icc <- ifelse(
      !is.na(results_valid$repeatability_daily) & !is.na(results_valid$repeatability_weekly),
      (results_valid$repeatability_daily + results_valid$repeatability_weekly) / 2,
      ifelse(!is.na(results_valid$repeatability_daily),
             results_valid$repeatability_daily, results_valid$repeatability_weekly))
    results_valid$leniency <- results_valid$param1 + results_valid$param2 +
      results_valid$min_time + (results_valid$min_bins - 1)
    results_valid <- results_valid[order(-results_valid$composite_icc,
                                         results_valid$leniency), ]
    results_valid$leniency <- NULL
    rownames(results_valid) <- NULL
    opt_results <- results_valid
    # ---- Print selection summary -------------------------------------------
    pct_retained <- round(best$N / max_n * 100)
    effective_p1 <- max(param1, min_bins)
    binding_note <- if (min_bins > 1 && min_bins > param1)
      sprintf(
        "\n  Note: min_bins = %d is the binding constraint (effective records/day = %d).",
        min_bins, effective_p1) else ""
    mb_excl_note <- if (n_bins_possible > 1 && median_vpd < 2)
      sprintf(paste0(
        "\n  Note: min_bins = 2 excluded from grid (median visits/animal/day = %.1f < 2).\n",
        "    Requiring both phases per day would incorrectly penalise animals\n",
        "    with random, once-daily visit timing."), median_vpd) else ""
    reproduce_call <- if (!is.null(diurnal) && diurnal$peak_hour != diurnal$trough_hour) {
      sprintf(paste0(
        "    process_gfdata(data, \"%s\", \"%s\",\n",
        "      param1 = %d, param2 = %d, min_time = %d, min_bins = %d,\n",
        "      peak_hour = %d, trough_hour = %d)"),
        format(start_date), format(end_date),
        param1, param2, min_time, min_bins,
        diurnal$peak_hour, diurnal$trough_hour)
    } else {
      sprintf(paste0(
        "    process_gfdata(data, \"%s\", \"%s\",\n",
        "      param1 = %d, param2 = %d, min_time = %d)"),
        format(start_date), format(end_date),
        param1, param2, min_time)
    }
    message(sprintf(paste0(
      "\n--- Selected parameters ---\n",
      "  Study diagnostics (unfiltered):\n",
      "    Animals available:          %d\n",
      "    Mean visits/animal/day:     %.1f  (median: %.1f)\n",
      "    Mean days/animal/week:      %.1f\n",
      "  param1   = %d  (min. records per day)\n",
      "  param2   = %d  (min. days with records per week)\n",
      "  min_time = %d  (min. minutes per visit)\n",
      "  min_bins = %d  (min. diurnal phases per day)%s%s\n",
      "  Repeatability daily  (ICC) : %.4f\n",
      "  Repeatability weekly (ICC) : %.4f\n",
      "  Composite ICC              : %.4f\n",
      "  Animals retained           : %d / %d (%d%%)\n",
      "  Full optimisation table    : attr(result, 'optimization')\n",
      "  To reproduce in manual mode:\n%s\n",
      "---------------------------"),
      max_n, mean_vpd, median_vpd, mean_dpw,
      param1, param2, min_time, min_bins, binding_note, mb_excl_note,
      best$repeatability_daily, best$repeatability_weekly,
      (best$repeatability_daily + best$repeatability_weekly) / 2,
      best$N, max_n, pct_retained,
      reproduce_call))
  } else {
    # Manual mode message
    message(paste("Using param1 =", param1, ", param2 =", param2,
                  ", min_time =", min_time, ", min_bins =", min_bins))
  }
  # ===========================================================================
  # Apply selected / supplied min_time -> final visit-level dataset
  # ===========================================================================
  df <- d_base %>% dplyr::filter(GoodDataDuration >= min_time)
  # ---------------------------------------------------------------------------
  # Bin assignment (common to both modes, uses resolved peak/trough)
  # ---------------------------------------------------------------------------
  use_bins <- !is.null(peak_hour) && !is.null(trough_hour) &&
    as.integer(peak_hour) != as.integer(trough_hour)
  if (use_bins) {
    ph <- as.integer(peak_hour)
    th <- as.integer(trough_hour)
    message(paste0(
      "Bin-weighted daily mean enabled ",
      "(rising: ", sprintf("%02d", th), ":00-", sprintf("%02d", ph), ":00 h; ",
      "declining: ", sprintf("%02d", ph), ":00-", sprintf("%02d", th), ":00 h; ",
      "min_bins = ", min_bins, ")"))
    if (min_bins == 2)
      message("  Note: min_bins = 2. Only animal-days covering BOTH phases are retained.")
  }
  # ---------------------------------------------------------------------------
  # Optional log-transform
  # ---------------------------------------------------------------------------
  if (isTRUE(transform)) {
    metric <- "(L/d)"
    df <- transform_gases(data = df)
  } else {
    metric <- "(g/d)"
  }
  # ---------------------------------------------------------------------------
  # Daily aggregation
  # ---------------------------------------------------------------------------
  if (use_bins) {
    daily_df <- df %>%
      dplyr::mutate(
        bin = if (ph > th) {
          ifelse(hour >= th & hour < ph, 1L, 2L)
        } else {
          ifelse(hour >= th | hour < ph, 1L, 2L)
        }
      ) %>%
      dplyr::group_by(RFID, day, bin) %>%
      dplyr::summarise(
        n_bin          = dplyr::n(),
        CH4GramsPerDay = weighted.mean(CH4GramsPerDay, GoodDataDuration, na.rm = TRUE),
        CO2GramsPerDay = weighted.mean(CO2GramsPerDay, GoodDataDuration, na.rm = TRUE),
        O2GramsPerDay  = weighted.mean(O2GramsPerDay,  GoodDataDuration, na.rm = TRUE),
        H2GramsPerDay  = weighted.mean(H2GramsPerDay,  GoodDataDuration, na.rm = TRUE),
        bin_minutes    = sum(GoodDataDuration, na.rm = TRUE),
        .groups        = "drop"
      ) %>%
      dplyr::group_by(RFID, day) %>%
      dplyr::summarise(
        n              = sum(n_bin),
        n_bins_covered = dplyr::n(),
        CH4GramsPerDay = mean(CH4GramsPerDay, na.rm = TRUE),
        CO2GramsPerDay = mean(CO2GramsPerDay, na.rm = TRUE),
        O2GramsPerDay  = mean(O2GramsPerDay,  na.rm = TRUE),
        H2GramsPerDay  = mean(H2GramsPerDay,  na.rm = TRUE),
        minutes        = sum(bin_minutes,      na.rm = TRUE),
        .groups        = "drop"
      ) %>%
      dplyr::filter(n >= param1, n_bins_covered >= min_bins) %>%
      dplyr::select(-n_bins_covered) %>%
      dplyr::mutate(
        week = floor(as.numeric(difftime(day, as.Date(start_date), units = "weeks"))) + 1
      ) %>%
      dplyr::select(RFID, week, day, n, minutes,
                    CO2GramsPerDay, CH4GramsPerDay, O2GramsPerDay, H2GramsPerDay)
  } else {
    daily_df <- df %>%
      dplyr::group_by(RFID, day) %>%
      dplyr::summarise(
        n = dplyr::n(),
        dplyr::across(
          c(CO2GramsPerDay, CH4GramsPerDay, O2GramsPerDay, H2GramsPerDay),
          ~ weighted.mean(.x, GoodDataDuration, na.rm = TRUE),
          .names = "{.col}"
        ),
        minutes = sum(GoodDataDuration, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::filter(n >= param1) %>%
      dplyr::mutate(
        week = floor(as.numeric(difftime(day, as.Date(start_date), units = "weeks"))) + 1
      ) %>%
      dplyr::select(RFID, week, day, n, minutes,
                    CO2GramsPerDay, CH4GramsPerDay, O2GramsPerDay, H2GramsPerDay)
  }
  # ---------------------------------------------------------------------------
  # Weekly aggregation
  # ---------------------------------------------------------------------------
  weekly_df <- daily_df %>%
    dplyr::group_by(RFID, week) %>%
    dplyr::summarise(
      nDays    = dplyr::n(),
      nRecords = sum(n),
      TotalMin = round(sum(minutes), 2),
      dplyr::across(
        c(CH4GramsPerDay, CO2GramsPerDay, O2GramsPerDay, H2GramsPerDay),
        ~ weighted.mean(.x, minutes, na.rm = TRUE),
        .names = "{.col}"
      ),
      .groups = "drop"
    ) %>%
    dplyr::filter(nDays >= param2) %>%
    dplyr::select(RFID, week, nDays, nRecords, TotalMin,
                  CO2GramsPerDay, CH4GramsPerDay, O2GramsPerDay, H2GramsPerDay)
  # ---------------------------------------------------------------------------
  # Summary messages
  # ---------------------------------------------------------------------------
  for (gas_nm in c("CO2", "CH4", "O2", "H2")) {
    col <- paste0(gas_nm, "GramsPerDay")
    if (col %in% names(weekly_df)) {
      vals <- weekly_df[[col]]
      message(paste0(gas_nm, metric, " = ",
                     round(mean(vals, na.rm = TRUE), 2), " +- ",
                     round(stats::sd(vals, na.rm = TRUE), 2),
                     " [CV(%) = ", round(stats::sd(vals, na.rm = TRUE) /
                                           mean(vals, na.rm = TRUE) * 100, 1), "]"))
    }
  }
  # ---------------------------------------------------------------------------
  # Optional rename for transform
  # ---------------------------------------------------------------------------
  if (isTRUE(transform)) {
    rename_map <- c(
      "CO2GramsPerDay" = "CO2LitersPerDay", "CH4GramsPerDay" = "CH4LitersPerDay",
      "O2GramsPerDay"  = "O2LitersPerDay",  "H2GramsPerDay"  = "H2LitersPerDay"
    )
    rename_gases <- function(d) {
      common <- intersect(names(rename_map), names(d))
      names(d)[match(common, names(d))] <- rename_map[common]
      d
    }
    df        <- rename_gases(df)
    daily_df  <- rename_gases(daily_df)
    weekly_df <- rename_gases(weekly_df)
  }
  # ---------------------------------------------------------------------------
  # Return
  # ---------------------------------------------------------------------------
  result <- list(filtered_data = df, daily_data = daily_df, weekly_data = weekly_df)
  if (auto_mode) {
    attr(result, "optimization") <- opt_results
    attr(result, "diurnal")      <- diurnal
  }
  result
}
