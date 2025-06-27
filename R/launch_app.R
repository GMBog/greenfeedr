#' Launch the GreenFeed Shiny App
#'
#' @export
launch_gf_app <- function() {
  appDir <- system.file("shinyapp", package = "greenfeedr")
  if (appDir == "") {
    stop("Could not find the Shiny app directory. Try reinstalling the package.")
  }
  shiny::runApp(appDir, display.mode = "normal")
}
