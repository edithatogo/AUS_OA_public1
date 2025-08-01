% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/Stats_temp_fcn.R
\name{BMI_summary_RMSE}
\alias{BMI_summary_RMSE}
\title{Calculate RMSE for BMI Summary}
\usage{
BMI_summary_RMSE(
  percent_overweight_and_obesity_by_sex_joint,
  BMI_by_sex_and_year,
  current.mod.value
)
}
\arguments{
\item{percent_overweight_and_obesity_by_sex_joint}{A data.frame of observed
BMI data.}

\item{BMI_by_sex_and_year}{A data.frame of simulated BMI data, typically from
\code{BMI_summary_data()}.}

\item{current.mod.value}{(Not used) A value intended for file naming, currently
has no effect in the function.}
}
\value{
A data.frame containing the RMSE values, grouped by age category and sex.
}
\description{
Calculates the Root Mean Squared Error (RMSE) between simulated and observed
BMI data to quantify model fit.
}
