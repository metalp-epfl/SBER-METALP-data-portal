## Regroups all plotting functions used with ggplot2 ##############################

## Plotting helpers ###############################################################

calculateYaxisLimits <- function(min, max, perc = 0.1) {
  axisMargin <- (max - min) * perc
  return(
    c(min - axisMargin, max + axisMargin)
  )
}

siteColors <- function(df, sitesTable) {
  namedColors <- c()
  for (site in df$Site_ID %>% unique()) {
    namedColors[site] <- sitesTable %>% filter(sites_short == site) %>% pull(sites_color)
  }
  
  return(namedColors)
}

## Plot types #####################################################################

basicPlot <- function(df, x, param, plotTitle) {
# Function that create a simple scatter plot with a LOESS curve for one value
# Parameters:
# - df: DataFrame in long format containing the following columns:
#       + 'Site_ID': factor
#       + 'values': numeric
#       + 'parameters': factor
#       + x: POSIXct datetime (column name corresponding to the string passed through the argument 'x')
# - x: String corresponding to the column name of a POSIXct datetime value of the df to use as x coordinates
# - param: List or 1-row df containing the following values accessible with '$':
#          + param_name: String
#          + units: String
# - plotTitle: String containing the title of the plot
#
# Returns a ggplot2 plot
  
  # Use !! to unquote the symbole returned by sym() -- trick to use string in ggplot2 aes()
  p <- ggplot(df, aes(!!sym(x), values, color = Site_ID, linetype = parameters, shape = parameters))+
    geom_point(size = 2, na.rm = TRUE)+
    # Use geom_line to plot LOESS curve in order to use linetype aes
    geom_line(stat="smooth", method = "loess", formula = y ~ x,
              size = 1.2,
              alpha = 0.5)+
    ggtitle(plotTitle)+
    ylab(str_interp('${param$param_name} [${param$units}]'))+
    xlab('Date')+
    # Set color of the data groups
    # And remove the line from the color legend images to keep the points only
    scale_color_manual(
      values = siteColors(df, sites),
      guide = guide_legend(override.aes = list(
        linetype = rep(0, length(unique(df$Site_ID)))
      ))
    )+
    # Change the linetype legend label to 'LOESS curve'
    scale_linetype(labels = 'LOESS curve')+
    # Set the y axis limits
    scale_y_continuous(limits = calculateYaxisLimits(min(df$values, na.rm = TRUE), max(df$values, na.rm = TRUE)))+
    # Set theme
    theme_bw()+
    # Remove legend title, move legend to the bottom of the plot and set text size
    theme(
      plot.title = element_text(size = 16, face = 'bold'),
      legend.position = "bottom", legend.title = element_blank(), legend.text = element_text(size = 10),
      axis.title = element_text(size = 14), axis.text.x = element_text(size = 10), axis.text.y = element_text(size = 11)
    )+
    # Remove the shape legend
    guides(shape = 'none')
  return(p)
}


sdPlot <- function(df, x, param, plotTitle) {
# Function that create a simple scatter plot with a LOESS curve and error bars for each point for one value
# Parameters:
# - df: DataFrame in long format containing the following columns:
#       + 'Site_ID': factor
#       + 'values': numeric
#       + 'parameters': factor
#       + x: POSIXct datetime (column name corresponding to the string passed through the argument 'x')
#       + sd: numeric (column name corresponding to the string passed via 'param$sd')
# - x: String corresponding to the column name of a POSIXct datetime value of the df to use as x coordinates
# - param: List or 1-row df containing the following values accessible with '$':
#          + param_name: String
#          + units: String
#          + sd: String (column name for the corresponding parameter's sd)
# - plotTitle: String containing the title of the plot
#
# Returns a ggplot2 plot
  
  # Create a symbole with the string contained in param$sd
  sd <- sym(param$sd)
  # Create a basicPlot
  p <- basicPlot(df, x, param, plotTitle)
  # Add error bars to the plot using the sd
  p <- p + geom_errorbar(aes(ymin = values - !!sd, ymax = values + !!sd))
  return(p)
}


minMaxPlot <- function(df, x, param, plotTitle) {
# Function that create a simple scatter plot with a LOESS curve for one value and a min and max value
# Parameters:
# - df: DataFrame in long format containing the following columns:
#       + 'Site_ID': factor
#       + 'values': numeric
#       + 'parameters': factor, 3 levels (the average, a min and a max)
#       + x: POSIXct datetime (column name corresponding to the string passed through the argument 'x')
# - x: String corresponding to the column name of a POSIXct datetime value of the df to use as x coordinates
# - param: List or 1-row df containing the following values accessible with '$':
#          + param_name: String
#          + units: String
# - plotTitle: String containing the title of the plot
#
# Returns a ggplot2 plot
  
  # Create a basicPlot
  p <- basicPlot(df, x, param, plotTitle)
  p <- p + 
    # Set the linetype values of the parameters groups to make only the avg visible
    scale_linetype_manual(values = c(1, 0, 0))+
    # Manually set the shapes of the avg, min and max points
    scale_shape_manual(values = c(16, 1, 0))+
    # Display the shape legend
    guides(shape = 'legend')
  return(p)
}


multiPlot <- function(df, x, param, plotTitle) {
# Function that create a simple scatter plot with a LOESS curve for one, two or three parameters
# Parameters:
# - df: DataFrame in long format containing the following columns:
#       + 'Site_ID': factor
#       + 'values': numeric
#       + 'parameters': factor
#       + x: POSIXct datetime (column name corresponding to the string passed through the argument 'x')
# - x: String corresponding to the column name of a POSIXct datetime value of the df to use as x coordinates
# - param: List or 1-row df containing the following values accessible with '$':
#          + param_name: String
#          + units: String
# - plotTitle: String containing the title of the plot
#
# Returns a ggplot2 plot
  
  # Create a basicPlot
  p <- basicPlot(df, x, param, plotTitle)
  p <- p +
    # Define the linetypes in case of multiple parameters
    scale_linetype_manual(values = c(1, 3, 2), name = 'parameters')+
    # Define the point shapes in case of multiple parameters
    scale_shape_manual(values = c(16, 15, 17), name = 'parameters')+
    # Display the shape legend
    guides(shape = 'legend')
  return(p)
}

timeSeriePlot <- function(df, x, parameter, siteName) {
# Function that create a time series plot using the plotting function encoded in the parameter argument
# Parameters:
# - df: DataFrame in long format (for shape details, refer to subsequent plotting function used)
# - x: String corresponding to the column name of the df to use as x coordinates
# - parameter: List or 1-row df containing the following values accessible with '$':
#              + plot_func: String corresping to a plotting function name
#              + other required by the specific plotting function used
# - siteName: String containing the site name to use for the plot title generation
#
# Returns a ggplot2 plot
  
  # Recover plotting function using string
  plottingFunc <- match.fun(parameter$plot_func)
  # Create plot title
  plotTitle <- str_interp('${siteName} Time Serie')
  # Create plot using the plotting function
  p <- plottingFunc(df, x, parameter, plotTitle)
  # Set the x axis as datetime
  p <- p + scale_x_datetime(date_minor_breaks = '1 month')
  return(p)
}


DOYPlot <- function(df, x, parameter, siteName) {
# Function that create a DOY time series plot using the plotting function encoded in the parameter argument
# Parameters:
# - df: DataFrame in long format with the folling requiered columns:
#       + x: POSIXct datetime for which each value has 2020 set as year
#            (column name corresponding to the string passed through the argument 'x')
#       + for shape details, refer to subsequent plotting function used
# - x: String corresponding to the column name of the df to use as x coordinates
# - parameter: List or 1-row df containing the following values accessible with '$':
#              + plot_func: String corresping to a plotting function name
#              + other required by the specific plotting function used
# - siteName: String containing the site name to use for the plot title generation
#
# Returns a ggplot2 plot
  
  # Recover plotting function using string
  plottingFunc <- match.fun(parameter$plot_func)
  # Create plot title
  plotTitle <- str_interp('${siteName} DOY Serie')
  # Create plot using the plotting function
  p <- plottingFunc(df, x, parameter, plotTitle)
  # Set the x axis as datetime
  p <- p + scale_x_datetime(
    date_breaks = '1 month',
    date_labels = '%b',
    limits = c(ymd_hms('2020-01-01 00:00:00 GMT'), ymd_hms('2020-12-10 00:00:00 GMT'))
  )
  return(p)
}

