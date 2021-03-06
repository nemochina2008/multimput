#' Generate simulated data
#'
#' Generate data for a regural monitoring design. The counts follow a negative binomial distribution with given size paramters and the true mean mu depending on a year, period and site effect. All effects are independent fro each other and have, on the log-scale, a normal distribution with zero mean and given standard deviation.
#' @param intercept the global mean on the log-scale
#' @param n.year the number of years
#' @param n.period the number of periods
#' @param n.site the number of sites
#' @param year.factor convert year to a factor. Defaults to FALSE
#' @param period.factor convert period to a factor. Defaults to FALSE
#' @param site.factor convert site to a factor. Defaults to FALSE
#' @param trend the longterm linear trend on the log-scale
#' @param sd.rw.year the standard deviation of the year effects on the log-scale
#' @param amplitude.period the amplitude of the periodic effect on the log-scale
#' @param mean.phase.period the mean of the phase of the periodic effect among years. Defaults to 0.
#' @param sd.phase.period the standard deviation of the phase of the periodic effect among years
#' @param sd.site the standard deviation of the site effects on the log-scale
#' @param sd.rw.site the standard deviation of the random walk along year per site on the log-scale
#' @param sd.noise the standard deviation of the noise effects on the log-scale
#' @param size the size parameter of the negative binomial distribution
#' @param n.run the number of runs with the same mu
#' @param as.list return the dataset as a list rather than a data.frame. Defaults to FALSE
#' @param details add variables containing the year, period and site effects. Defaults tot FALSE
#' @export
#' @return A \code{data.frame} with five variables. \code{Year}, \code{Month} and \code{Site} are factors identifying the location and time of monitoring. \code{Mu} is the true mean of the negative binomial distribution in the original scale. \code{Count} are the simulated counts.
#' @importFrom stats rnorm rnbinom
#' @importFrom dplyr %>% group_by_ do_
generateData <- function(
  intercept = 2,
  n.year = 24,
  n.period = 6,
  n.site = 20,
  year.factor = FALSE,
  period.factor = FALSE,
  site.factor = FALSE,
  trend = 0.01,
  sd.rw.year = 0.1,
  amplitude.period = 1,
  mean.phase.period = 0,
  sd.phase.period = 0.2,
  sd.site = 1,
  sd.rw.site = 0.02,
  sd.noise = 0.01,
  size = 2,
  n.run = 10,
  as.list = FALSE,
  details = FALSE
){
  #generate the design
  dataset <- expand.grid(
    Year = seq_len(n.year),
    Period = seq_len(n.period),
    Site = seq_len(n.site)
  )
  year.rw.effect <- cumsum(rnorm(n.year, mean = 0, sd = sd.rw.year))
  phase <- rnorm(n.year + 1, mean = mean.phase.period, sd = sd.phase.period)
  site.rw.effect <- rbind(
    rnorm(
      n.site,
      mean = 0,
      sd = sd.site
    ),
    matrix(
      rnorm(
        (n.year - 1) * n.site,
        mean = 0,
        sd = sd.rw.site
      ),
      ncol = n.site
    )
  )
  site.rw.effect <- as.vector(apply(site.rw.effect, 2, cumsum))
  observation.effect <- rnorm(nrow(dataset), mean = 0, sd = sd.noise)

  #generate the true mean
  dataset$Mu <- exp(
    intercept +
      year.rw.effect[dataset$Year] + trend * dataset$Year +
      amplitude.period *
        sin(
          dataset$Period * pi / n.period + phase[dataset$Year]
        ) +
      site.rw.effect[dataset$Year + (dataset$Site - 1) * n.year] +
      observation.effect
  )

  if (details) {
    dataset$YearEffect <- exp(
      year.rw.effect[dataset$Year] + trend * dataset$Year
    )
    dataset$PeriodEffect <- exp(
      amplitude.period *
        sin(
          dataset$Period * pi / n.period + phase[dataset$Year]
        )
    )
    dataset$SiteEffect <- exp(
      site.rw.effect[dataset$Year + (dataset$Site - 1) * n.year]
    )
  }
  if (year.factor) {
    dataset$Year <- factor(dataset$Year)
  }
  if (period.factor) {
    dataset$Period <- factor(dataset$Period)
  }
  if (site.factor) {
    dataset$Site <- factor(dataset$Site)
  }
  # add the runs
  dataset <- merge(
    dataset,
    data.frame(
      Run = seq_len(n.run)
    )
  )

  #generate the counts
  dataset$Count <- rnbinom(nrow(dataset), size = size, mu = dataset$Mu)

  if (!as.list) {
    return(dataset)
  }

  relevant <- function(x, details){
    if (details) {
      dots <- c("Year", "Period", "Site", "Mu", "YearEffect", "PeriodEffect",
        "SiteEffect", "Run", "Count")
    } else {
      dots <- c("Year", "Period", "Site", "Mu", "Run", "Count")
    }
    x %>%
      select_(.dots = dots) %>%
      as.data.frame()
  }
  dataset <- dataset %>%
    group_by_(~Run) %>%
    do_(List = ~relevant(., details = details))
  return(dataset$List)
}
