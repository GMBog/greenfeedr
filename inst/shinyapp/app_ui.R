
# app_ui.R

ui <- fluidPage(
  tags$head(
    tags$link(
      href = "https://fonts.googleapis.com/css?family=Montserrat:700,400&display=swap", rel = "stylesheet"
    ),
    tags$link(rel = "shortcut icon", href = "favicon.ico"),
    tags$style(HTML("
      body, .main-panel, .form-group label, .control-label {
        font-family: 'Montserrat', Arial, sans-serif;
        color: #006400;
      }
      .top-bar {
        background-color: #124B12;
        color: white;
        padding: 10px 20px;
        font-size: 24px;
        font-weight: bold;
        text-align: center;
        letter-spacing: 2px;
        border-radius: 0 0 18px 18px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.04);
      }
      .tab-content, .main-panel, .sidebar-panel, .welcome-container {
        background: #f7fff7;
        border-radius: 15px;
        box-shadow: 0 6px 24px rgba(18,75,18,0.08), 0 1.5px 5px rgba(18,75,18,0.04);
        padding: 24px;
        margin-bottom: 24px;
      }
      .btn, .action-button, .download-button {
        background: linear-gradient(90deg, #198754 0%, #124B12 100%);
        border: none;
        color: white !important;
        font-weight: bold;
        border-radius: 8px !important;
        transition: background 0.2s;
      }
      .btn:hover, .action-button:hover, .download-button:hover {
        background: #0e2e0e !important;
        color: #c1ffc1 !important;
      }
      .nav-tabs > li > a, .nav-tabs > li.active > a {
        color: #006400 !important;
        font-weight: bold;
      }
      .tab-content > .tab-pane {
        opacity: 0;
        transition: opacity 0.5s;
      }
      .tab-content > .active {
        opacity: 1;
      }
      #download, #run_report, #run_pellin, #run_viseat, #run_eval_param, #run_process, #run_compare {
        animation: pulse 1.5s infinite alternate;
      }
      @keyframes pulse {
        from { box-shadow: 0 0 0 0 rgba(24, 135, 84, 0.7); }
        to   { box-shadow: 0 0 12px 6px rgba(24, 135, 84, 0.15); }
      }

      .form-group .btn-default,
      .form-group .btn-default:focus,
      .form-group .btn-default:active,
      .form-group .btn-default:hover {
        background: linear-gradient(90deg, #B4E197 0%, #6FCF97 100%) !important;
        color: #124B12 !important;
        border: none;
        border-radius: 8px !important;
        font-weight: bold;
        box-shadow: none !important;
        transition: background 0.2s;
      }
      .form-group .btn-default:hover {
        background: #a0d883 !important;
        color: #124B12 !important;
      }
      /* Make sure action/download buttons don't pick up the .btn-default style */
      .action-button, .download-button {
        background: linear-gradient(90deg, #198754 0%, #124B12 100%) !important;
        color: white !important;
      }
    "))
  ),
  div(class = "top-bar", "greenfeedr app"),


  # Main UI layout with tabs
  tabsetPanel(

    # Welcome tab
    tabPanel("Welcome",
             div(class = "welcome-container",
                 tags$img(src = "GFSticker.png", width = "120px"),
                 tags$h2("Welcome to the greenfeedr app"),
                 tags$p(
                   "This Shiny application helps you download, process, report, and compare GreenFeed data
                    for research or monitoring purposes.",
                   "Navigate through the tabs to access features like downloading data from the API,
                    generating reports, checking visitation and intakes, processing gas data using different filters."
                 ),
                 tags$p(
                   "greenfeedr is an open-source R package developed by Guillermo Martinez-Boggio.",
                   "The package contains the code for this Shiny app as well as all functions and documentation for processing data,
                    which can be used directly in R."
                 ),
                 tags$p(
                   "The source code is available on ",
                   tags$a(href = "https://cran.r-project.org/package=greenfeedr", "CRAN"),
                   " and ",
                   tags$a(href = "https://github.com/GMBog/greenfeedr", "GitHub"),
                   ". This Shiny app is also available at ",
                   tags$a(href = "https://greenfeedr.shinyapps.io/app/", "shinyapps.io"),
                   "."
                 ),
                 tags$hr()
             )
    ),

    tabPanel("Downloading",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:"),
                 passwordInput("pass", "Password:"),
                 textInput("unit", "Unit(s):", placeholder = "e.g. 55 or 100,101"),
                 textInput("exp", "Experiment/Study Name:", value = "DemoStudy"),
                 selectInput("d", "Data Type:", choices = c("visits", "feed", "rfid", "cmds")),
                 dateRangeInput("dates", "Date Range:",
                                start = Sys.Date() - 30, end = Sys.Date() - 1),
                 textInput("save_dir", "Save Directory:", placeholder = "e.g. /Users/Downloads/"),
                 actionButton("download", "Download Data", icon = icon("download"))
               ),
               mainPanel(
                 uiOutput("status_card"),
                 uiOutput("preview")
               )
             )
    ),

    tabPanel("Checking",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:"),
                 passwordInput("pass", "Password:"),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 55 or 100,101"),
                 textInput("gcup", "Grams per Cup:", placeholder = "e.g. 34 or 34,35"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 fileInput("rfid_file", "Upload RFID file (optional):"),
                 fileInput("feedtimes_file", "Upload Feedtimes file (optional):"),
                 textInput("save_dir", "Save Directory:", placeholder = "e.g. /Users/Downloads/"),
                 actionButton("run_pellin", "Run Pellin", icon = icon("running")),
                 actionButton("run_viseat", "Run Viseat", icon = icon("running"))
               ),
               mainPanel(
                 verbatimTextOutput("pellin_status"),
                 uiOutput("pellin_table"),
                 br(), hr(), br(),
                 textOutput("viseat_status"),
                 plotOutput("unit_plot"),
                 uiOutput("viseat_download_ui")
               )
             )
    ),

    tabPanel("Reporting",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:", placeholder = "Enter your username"),
                 passwordInput("pass", "Password:", placeholder = "Enter your password"),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 55 or 100,101"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 fileInput("rfid_file", "Upload RFID file (optional):"),
                 actionButton("run_report", "Report Data", icon = icon("file-alt")),
                 div(style = "margin-bottom: 15px;"),
                 selectInput(
                   "which_plot", "Show Plot:",
                   choices = c(
                     "Records Per Day" = "plot_1",
                     "Gas Production Across The Day" = "plot_4",
                     "Records Per Animal" = "plot_3"
                   ),
                   selected = "plot_1"
                 ),
                 # Only show gas selection for plot 4
                 conditionalPanel(
                   condition = "input.which_plot == 'plot_4'",
                   checkboxGroupInput(
                     "plot4_gas",
                     label = "Select gases to plot (multiple allowed):",
                     choices = list("CH4" = "ch4", "CO2" = "co2", "O2" = "o2", "H2" = "h2"),
                     selected = "ch4"
                   )
                 )
               ),
               mainPanel(
                 uiOutput("report_summary"),
                 uiOutput("report_preview"),
                 uiOutput("chosen_plot")
               )
             )
    ),

    tabPanel("Processing",
             sidebarLayout(
               sidebarPanel(
                 fileInput("gf_file", "Upload GreenFeed Data:"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 actionButton("run_eval_param", "Evaluate Parameters", icon = icon("search")),
                 br(), hr(),
                 numericInput("param1", "N records/day (param1):", value = 2, min = 1),
                 numericInput("param2", "N days/week (param2):", value = 3, min = 1),
                 numericInput("min_time", "Min. minutes per record:", value = 2),
                 checkboxInput("transform", "Transform gases to L/d?", value = FALSE),
                 numericInput("cutoff", "Outlier SD cutoff:", value = 3, min = 1),
                 actionButton("run_process", "Process Data", icon = icon("sync"))
               ),
               mainPanel(
                 conditionalPanel(
                   condition = "input.run_eval_param > 0",
                   hr(),
                   uiOutput("eval_section_title"),
                   DTOutput("eval_param_table")
                 ),
                 conditionalPanel(
                   condition = "input.run_process > 0",
                   br(),hr(),
                   uiOutput("proc_section_title"),
                   tableOutput("proc_summary_table"),
                   br(),
                   h4("Download Processed Files:"),
                   fluidRow(
                     column(4, downloadButton("download_filtered", "Filtered Data")),
                     column(4, downloadButton("download_daily", "Daily Data")),
                     column(4, downloadButton("download_weekly", "Weekly Data"))
                   )
                 )
               )
             )
    ),

  tags$footer(
    style = "text-align: center; padding: 10px 0; color: #999; font-size: 13px; margin-top: 30px;",
    "© 2025 greenfeedr | Built with Shiny & R"
  ))
  )


