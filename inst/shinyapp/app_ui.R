
# app_ui.R

ui <- fluidPage(
  tags$head(
    tags$link(href = "https://fonts.googleapis.com/css?family=Montserrat:700,400&display=swap", rel = "stylesheet"),
    tags$link(href = "https://fonts.googleapis.com/css?family=Merriweather:700,400&display=swap", rel = "stylesheet"),
    tags$link(rel = "shortcut icon", href = "favicon.ico"),
    tags$style(HTML("
      body, .main-panel, .form-group label, .control-label {
        font-family: 'Montserrat', Arial, sans-serif;
        color: #006400;
      }
      .top-bar {
        ont-family: 'Merriweather', serif;
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
    tabPanel(
      "Welcome",
      div(
        class = "welcome-container",
        style = "max-width: 1000px; margin: auto; padding: 20px;",
        tags$img(src = "GFSticker.png", width = "120px", style = "display: block; margin: 0 auto 20px auto;"),
        tags$h2("Welcome to the greenfeedr App"),
        tags$p(
          "This Shiny application empowers you to download, check, report, and process GreenFeed data
          for research or monitoring purposes."
        ),
        tags$ul(
          style = "margin-bottom: 20px;",
          tags$li(tags$b("Downloading Data:"), " Easily retrieve all types of GreenFeed data (emissions, visits, feed, and commands)"),
          tags$li(tags$b("Checking Data:"), " Quickly inspect visits and calculate intakes from your GreenFeed units"),
          tags$li(tags$b("Reporting Data:"), " Generate interactive reports for all your GreenFeed units"),
          tags$li(tags$b("Processing Data:"), " Process your GreenFeed records using different filters and parameters"),
          tags$li(tags$b("Analayzing Data:"), " Analyze your GreenFeed records based on groups or treatments"),
        ),
        tags$div(
          style = "margin-bottom: 20px;",
          tags$b("How to use the app:"),
          tags$ol(
            tags$li("Download data directly from the API"),
            tags$li("Check visitation and calculate intakes for your ongoing trials"),
            tags$li("Generate data reports by day and by animal"),
            tags$li("Process and filter gas measurements using your own criteria"),
            tags$li("Analyze gas measurements per group or treatments"),
          )
        ),
        tags$p(
          "The ", tags$b("greenfeedr"), " package is an open-source R package developed by ",
          tags$a(href = "https://github.com/GMBog", "Guillermo Martinez-Boggio")
        ),
        tags$p(
          "All the functions and documentation for processing GreenFeed data are available both
          in this ", tags$a(href = "https://gmbog.shinyapps.io/shinyapp/", "shinyapps.io"), "and
          for direct use in ", tags$a(href = "https://cran.r-project.org/package=greenfeedr", "R")
        ),
        tags$hr()
      )
    ),

    tabPanel("Downloading Data",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:", placeholder = "Enter your username"),
                 passwordInput("pass", "Password:", placeholder = "Enter your password"),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 55 or 100,101"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 selectInput("d", "Data Type:", choices = c("visits", "feed", "rfid", "cmds")),
                 fluidRow(
                   column(6, actionButton("load_data", "Load Data", icon = icon("sync"))),
                   column(6, uiOutput("download_ui"))
                 )
               ),
               mainPanel(
                 uiOutput("summary_card1"),
                 uiOutput("error_message1"),
                 div(style = "margin-bottom: 15px;"),
                 uiOutput("preview")
               )
             )
    ),

    tabPanel("Checking Data",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:", placeholder = "Enter your username"),
                 passwordInput("pass", "Password:", placeholder = "Enter your password"),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 55 or 100,101"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date()),
                 actionButton("run_viseat", "Run Viseat", icon = icon("running")),
                 div(style = "margin-bottom: 25px;"),
                 textInput("gcup", "Grams per Cup:", placeholder = "e.g. 34 or 34,35"),
                 fileInput("rfid_file1", "Upload RFID file (optional):"),
                 actionButton("run_pellin", "Run Pellin", icon = icon("running"))
               ),
               mainPanel(
                 textOutput("viseat_status"),
                 uiOutput("summary_card2_1"),
                 uiOutput("error_message2"),
                 div(style = "margin-bottom: 15px;"),
                 plotlyOutput("plot2_1"),
                 plotlyOutput("plot2_2"),
                 div(style = "margin-bottom: 15px;"),
                 hr(),
                 verbatimTextOutput("pellin_status"),
                 uiOutput("summary_card2_2"),
                 uiOutput("pellin_table"),
                 conditionalPanel(
                   condition = "input.run_pellin > 0",
                   downloadButton("download_pellin", "Download Intakes")
                 )
             )
          )
    ),

    tabPanel("Reporting Data",
             sidebarLayout(
               sidebarPanel(
                 textInput("user", "Username:", placeholder = "Enter your username"),
                 passwordInput("pass", "Password:", placeholder = "Enter your password"),
                 textInput("unit", "GreenFeed Unit(s):", placeholder = "e.g. 55 or 100,101"),
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 fileInput("rfid_file2", "Upload RFID file (optional):"),
                 actionButton("run_report", "Report Data", icon = icon("file-alt")),
                 div(style = "margin-bottom: 15px;"),
                 selectInput(
                   "which_plot", "Show Plot:",
                   choices = c(
                     "Records Per Day" = "plot_1",
                     "Gas Production Across The Day" = "plot_3",
                     "Records Per Animal" = "plot_2"
                   ),
                   selected = "plot_1"
                 ),
                 conditionalPanel(
                   condition = "input.which_plot == 'plot_3'",
                   checkboxGroupInput(
                     "plot3_gas",
                     label = "Select gases to plot (multiple allowed):",
                     choices = list("CH4" = "ch4", "CO2" = "co2", "O2" = "o2", "H2" = "h2"),
                     selected = "ch4"
                   )
                 )
               ),
               mainPanel(
                 uiOutput("error_message3"),
                 uiOutput("report_summary"),
                 uiOutput("report_preview"),
                 uiOutput("chosen_plot")
               )
             )
    ),

    tabPanel("Processing Data",
             sidebarLayout(
               sidebarPanel(
                 dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
                 fileInput("gf_file1", "Upload GreenFeed Data:"),
                 actionButton("run_eval_param", "Evaluate Parameters", icon = icon("search")),
                 div(style = "margin-bottom: 15px;"), hr(),
                 numericInput("param1", "N Records-Day (Param1):", value = 2, min = 1),
                 numericInput("param2", "N Days-Week (Param2):", value = 3, min = 1),
                 numericInput("min_time", "Min. minutes per record (Min_time):", value = 2),
                 checkboxInput("transform", "Transform gases to L/d?", value = FALSE),
                 numericInput("cutoff", "Outlier SD cutoff:", value = 3, min = 1),
                 actionButton("run_process", "Process Data", icon = icon("sync"))
               ),
               mainPanel(
                 conditionalPanel(
                   condition = "input.run_eval_param > 0",
                   uiOutput("error_message4"),
                   DTOutput("eval_param_table")
                 ),
                 conditionalPanel(
                   condition = "input.run_process > 0",
                   div(style = "margin-bottom: 15px;"),
                   tableOutput("proc_summary_table"),
                   div(style = "margin-bottom: 15px;"),
                   fluidRow(
                     column(4, downloadButton("download_filtered", "Download Filtered Data")),
                     column(4, downloadButton("download_daily", "Download Daily Data")),
                     column(4, downloadButton("download_weekly", "Download Weekly Data"))
                   )
                 )
               )
             )
  ),

  tabPanel("Analyzing Data",
           sidebarLayout(
             sidebarPanel(
               dateRangeInput("dates", "Date Range:", start = Sys.Date() - 30, end = Sys.Date() - 1),
               fileInput("gf_file2", "Upload GreenFeed Data:"),
               fileInput("rfid_file3", "Upload Groups File:"),
               numericInput("param1", "N Records-Day (Param1):", value = 2, min = 1),
               numericInput("param2", "N Days-Week (Param2):", value = 3, min = 1),
               numericInput("min_time", "Min. minutes per record (Min_time):", value = 2),
               numericInput("cutoff", "Outlier SD cutoff:", value = 3, min = 1),
               actionButton("run_analysis", "Analyze Data", icon = icon("sync"))
             ),
             mainPanel(
               conditionalPanel(
                 condition = "input.run_analysis > 0",
                 uiOutput("summary_card"),
                 tableOutput("group_summary_table"),
                 div(style = "margin-bottom: 15px;"), hr(),
                 selectInput("selected_gas", "Choose gas to plot:",
                             choices = c("CO2" = "CO2GramsPerDay",
                                         "CH4" = "CH4GramsPerDay",
                                         "O2" = "O2GramsPerDay",
                                         "H2" = "H2GramsPerDay"),
                             selected = "CH4GramsPerDay"
                 ),
                 tableOutput("tukey_table")
               )
             )
           )
  ),

  tags$footer(
    style = "text-align: center; padding: 10px 0; color: #999; font-size: 13px; margin-top: 30px;",
    "2025 greenfeedr | Develop by Guillermo Martinez-Boggio"
  ))
  )


