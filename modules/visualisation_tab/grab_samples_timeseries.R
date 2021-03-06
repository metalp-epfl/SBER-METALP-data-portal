## This module contains the code for the grab samples timeserie visualisation

## Create the UI function of the module ###############################################

grabSamplesTimeSeriesUI <- function(id, pool) {
# Create the UI for the grabSamplesTimeSeries module
# Parameters:
#  - id: String, the module id
#  - pool: The pool connection to the database
# 
# Returns a list containing:
#  - inputs: the inputs UI elements of the module
#  - plots: the plots UI elements of the module
  
  # Create namespace
  ns <- NS(id)
  
  # Create the UI list to be returned
  list(
    # Create the UI inputs
    'inputs' = div(
      # Set UI inputs id and class
      id = paste0('time-serie-plot-input-', id),
      class = 'time-serie-input',
      # Create select input for catchment selection
      selectInput(
        ns('catchment'),
        'Catchment',
        parseOptions(
          getRows(pool, 'stations', columns = c('order', 'catchment')) %>%
            arrange(order) %>% select(-order),
          'catchment'
        )
      ),
      # Create an empty checkbox group input for station selection
      # Will update dynamically in function of the catchment
      checkboxGroupInput(ns('sites'), 'Station'),
      # Create a select input for parameter selection
      selectInput(
        ns('param'),
        # Create a label with an icon button
        tags$span(
          'Parameter',
          # Create an icon button that trigger a modal to display the parameter description
          actionButton(ns('paramHelper'), icon('question-circle'), class = 'icon-btn')
        ),
        parseOptionsWithSections(
          getRows(pool, 'grab_params_plotting', active == TRUE, columns = c('order', 'section_name', 'option_name', 'param_name')) %>%
            arrange(order) %>% select(-order),
          'param_name'
        )
      ),
      # Create an hidden checkbox input group (with shinyjs) for sub parameter selection
      # Will be displayed only if there is a sub parameter selection available
      hidden(
        checkboxGroupInput(ns('paramfilter'), label = 'Parameter filter')
      ),
      # Create a button that trigger a modal to display some stats info of the currently plotted data
      actionButton(ns('showstats'), 'Show Stats', class = 'custom-style')
    ),
    # Create the UI plots
    'plots' = div(
      # Set UI plots id and class
      id = paste0('time-serie-plots-', id),
      class = 'time-serie-plot two-plots point-hover-widget-plot',
      # Create a plotOutput for the regular timeserie plot
      spinnerPlotOutput(
        ns('lowfreq'),
        # Make data points hoverable
        hover = hoverOpts(ns('lowfreq_hover')),
        # Make plot brushable in the x direction with a debouncing delay type
        # Reset it when the plot is refreshed
        brush = brushOpts(
          ns('lowfreq_brush'),
          direction = 'x',
          delayType = 'debounce',
          resetOnNew = TRUE
        ),
        # Make plot double clickable
        dblclick = dblclickOpts(ns('lowfreq_dblclick'))
      ),
      # Create a plotOutput for the day of the Year timeserie plot
      # Make data points hoverable
      spinnerPlotOutput(ns('doy'),  hover = hoverOpts(ns('doy_hover')))
    )
  )
}



## Create the server function of the module ###############################################

grabSamplesTimeSeries <- function(input, output, session, dateRange, pool) {
# Create the logic for the grabSamplesTimeSeries module
# Parameters:
#  - input, output, session: Default needed parameters to create a module
#  - dateRange: Reactive expression that returns the date range to filter the data with.
#               Date range format must be a list containing:
#               + min: Date, the lower bound to filter the date
#               + max: Date, the upper bound to filter the data
#  - pool: The pool connection to the database
# 
# Returns a reactive expression containing the updated date range with the same format as the input
  
  ## Stations update logic ########################################################
  
  # Create an observeEvent that react to the catchment select input
  observeEvent(input$catchment, {
    # Get catchment sites info
    catchmentSites <- getRows(
      pool,
      'stations',
      catchment == local(input$catchment),
      columns = c('order', 'name', 'full_name')
    ) %>% arrange(order) %>% select(-order)
    
    # Update sites checkbox group input with current sites info
    updateCheckboxGroupInput(session, 'sites',
                             selected = catchmentSites$name,
                             choiceNames = catchmentSites$full_name,
                             choiceValues = catchmentSites$name)
  })
  
  # Create a reactive expression returning the selected sites
  selectedSites <- reactive({input$sites})
  
  # Create a debounced reactive expression returning the selected sites
  selectedSites_d <-  selectedSites %>% debounce(1000)

  # Create a reactive expression that returns the current catchment sites
  currentSites <- reactive(getRows(
    pool,
    'stations',
    name %in% local(selectedSites_d()),
    columns = c('order', 'name', 'full_name', 'catchment', 'color')
  ) %>% arrange(order) %>% select(-order))
  
  # Create a currentCatchment reactive expression
  currentCatchment <- reactive(currentSites() %>% pull(catchment) %>% unique())
  
  
  
  
  
  ## Parameter logic ###################################################
  
  # Create a reactive expression that return the parameter infos
  currentParam <- reactive(getRows(
    pool, 'grab_params_plotting',
    active == TRUE,
    param_name == local(input$param),
    columns = c('order', 'param_name', 'units', 'data', 'sd', 'min_max', 'plot_func', 'description')
  ) %>% arrange(order) %>% select(-order))
  
  
  
  
  
  ## Sub parameter update logic ###################################################
  
  # Create an observeEvent that react to the param select input
  observeEvent(input$param,{
    # Get parameter info
    dataColumns <- currentParam() %>% select(data) %>% str_split(',') %>% unlist()
    
    # Update sub parameter checkbox group input with current parameter info
    updateCheckboxGroupInput(session, 'paramfilter',
                             choices = dataColumns,
                             selected = dataColumns[1])
    
    # Toggle sub parameter checkbox group input visibility
    # In function of the number of sub parameters
    # length(dataColumns) > 1 == TRUE -> show else hide
    toggleElement('paramfilter', condition = length(dataColumns) > 1)
  })
  
  # Create a reactive expression returning the parameter info as a named list:
  #  - filter: the sub parameters to display
  #  - param: the parameter info
  paramfilter <- reactive({
    # Save the parameter and sub parameters into variables
    inputParam <- input$param
    paramToDisplay <- input$paramfilter
    
    # If either paramToDisplay or inputParam is NULL
    # Return a list of NULL values
    if (is.null(paramToDisplay) | is.null(inputParam)) return(list(
      'filter' = NULL,
      'param' = NULL
    ))
    
    
    # Return the sub parameters and parameter info
    return(list(
      'filter' = paramToDisplay,
      'param' = currentParam()
    ))
  })
  
  # Create a debounced reactive expression returning the parameter info
  paramfilter_d <- paramfilter %>% debounce(1000)
  
  
  
  ## Data manipulation logic ######################################################
  
  # Create a data reactive expression that return a subset of the data
  # Using the dateRange, selectedSites_d and paramfilter_d reactive expressions
  data <- reactive({
    # Save the sub parameters to display
    paramCols <- paramfilter_d()$filter
    
    # If there is no sub parameter return NULL
    if (is.null(paramCols)) return(NULL)
    
    # Get a vector of column names containing the sd info for the current parameter
    sdCols <- paramfilter_d()$param$sd %>% str_split(',') %>% unlist()
    # If sdCols is not NULL and is NA
    # Set it to NULL
    if (!is.null(sdCols)) {
      if (sdCols %>% is.na()) sdCols <- NULL
    }
    
    # Get a vector of column names containing the min and max info for the current parameter
    minMaxCols <- paramfilter_d()$param$min_max %>% str_split(',') %>% unlist()
    # If minMaxCols is not NULL and is NA
    # Set it to NULL
    if (!is.null(minMaxCols)) {
      if (minMaxCols %>% is.na()) minMaxCols <- NULL
    }
    
    # Filter the data using the selected sites and the date range
    # And select the columns
    df <- getRows(
      pool = pool,
      table = 'data',
      station %in% local(selectedSites_d()),
      DATE_reading >= local(dateRange()$min),
      DATE_reading <= local(dateRange()$max),
      columns = c(
        'station', 'DATE_reading', 'TIME_reading_GMT',
        paramCols, sdCols, minMaxCols
      )
      # Parse the DATE and time
    ) %>% mutate(
      station = as.factor(station),
      DATETIME_GMT = ymd_hms(paste(DATE_reading, TIME_reading_GMT), tz = 'GMT'),
      DATE_reading = ymd(DATE_reading),
      DATETIME_month_day_time_GMT = `year<-`(DATETIME_GMT, 2020)
      # Rename for the plotting function
    ) %>% rename(
      Site_ID = station
    )
    
    # If there is no data return NULL
    if (nrow(df) == 0) return(NULL)
    
    # Set the same arbitrary year for all the samples to plot all the results on one year
    year(df$DATETIME_month_day_time_GMT) <- 2020
    
    # Select all relevant data.frame columns and pivot it to a long format

    df %>% pivot_longer(
      cols = c(all_of(paramCols), all_of(minMaxCols)),
      names_to = 'parameter',
      values_to = 'value'
    )
  })
  
  
  ## Plots output logic ###########################################################
  
  # Render the regular timeserie plot
  output$lowfreq <- renderPlot({
    # If there are no data return NULL
    if (data() %>% is.null()) return(NULL)
    
    # Create and return a timeSeriePlot
    timeSeriePlot(
      df = data(),
      x = 'DATETIME_GMT',
      parameter = paramfilter_d()$param,
      siteName = paste(currentCatchment(), 'catchment'),
      sites = currentSites()
    )
  })
  
  # Render the day of the year timeserie plot
  output$doy <- renderPlot({
    # If there are no data return NULL
    if (data() %>% is.null()) return(NULL)
    
    # Create and return a DOYPlot
    DOYPlot(
      df = data(),
      x = 'DATETIME_month_day_time_GMT',
      parameter = paramfilter_d()$param,
      siteName = paste(currentCatchment(), 'catchment'),
      sites = currentSites()
    )
  })
  
  
  
  ## Plot hovering logic ##########################################################
  
  # Activate the hover widget for the regular timeserie plot
  pointHoverWidgetServer(session, 'lowfreq', data, reactive(input$lowfreq_hover),
                         x_label = 'Date', y_label = 'parameter')

  # Activate the hover widget for the day of the year timeserie plot
  pointHoverWidgetServer(session, 'doy', data, reactive(input$doy_hover),
                         x_label = 'Date', y_label = 'parameter',
                         override.mapping = list('x' = 'DATETIME_GMT'))
  
  
  
  ## Stats summary modal logic ####################################################
  
  # Render the stats tables in the modal
  output$stats <- renderStatsTables(
    elements = selectedSites_d,
    data = data,
    sites = currentSites,
    tableFunction = createStatsTablePerSite
  )
  
  # Create an observeEvent that react to show stats button
  observeEvent(input$showstats, {
    # Create modal with the corresponding htmlOutput
    showModal(modalDialog(
      title = paste('Summary statistics of the', currentCatchment(), 'catchment'),
      withSpinner(
        htmlOutput(session$ns('stats'), class = 'stats-summary'),
        type = 4, color = "#e24727", size = .5
      ),
      footer = modalButtonWithClass('Dismiss', class = 'custom-style'),
      easyClose = TRUE
    ))
  })
  
  
  
  ## Parameter description modal logic ############################################
  
  # Create an observeEvent that react to the parameter helper icon button
  observeEvent(input$paramHelper, {
    # Render the description UI in the modal
    output$description <- renderUI(tags$p(
      class = 'description',
      currentParam() %>% pull(description)
    ))
    
    # Create modal with the corresponding htmlOutput
    showModal(modalDialog(
      title = 'Parameter description',
      htmlOutput(session$ns('description')),
      footer = modalButtonWithClass('Dismiss', class = 'custom-style'),
      easyClose = TRUE
    ))
  })
  
  
  
  ## Update dateRange with plot brushing and double click logic ###################
  
  # Create a reactive expression that contains the new dateRange to be used globally
  # With the same format as the input dateRange
  # Should be returned by the module
  # Converting number to date using the Linux epoch time as origin
  updateDateRange <- reactive(list(
    'min' = as.Date(as.POSIXct(input$lowfreq_brush$xmin, origin = "1970-01-01", tz = "GMT")),
    'max' = as.Date(as.POSIXct(input$lowfreq_brush$xmax, origin = "1970-01-01", tz = "GMT"))
  ))
  
  # Create a reactive value that update each time the plot is double clicked
  # Used as trigger to reset the date range in the outer module
  # Initialised to NULL to avoid a dateRange reset when a new unit is created
  resetDateRange <- reactiveVal(NULL)
  
  # Create an observe event that react on plot double click to reset the date range
  observeEvent(input$lowfreq_dblclick, {
    if (is.null(resetDateRange())) {
      resetDateRange(1)
    } else {
      resetDateRange(resetDateRange() + 1)
    }
  })
  
  # Return the new dateRange values and date range reset trigger in order to update the outer module dateRangeInput
  return(list(
    'update' = updateDateRange,
    'reset' = resetDateRange
  ))
}

