% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/compute_z_score.R
\name{compute_z_score}
\alias{compute_z_score}
\title{Compute z-score(s) based on raw scores and demographic regression model}
\usage{
compute_z_score(calc, x, nam, AGE, GEN, EDU)
}
\arguments{
\item{calc}{A data frame or tibble containing regression parameters from the calculator.}

\item{x}{A numeric vector of raw performance scores.}

\item{nam}{A character string specifying the test index label (must match an entry in \code{calc}).}

\item{AGE}{A numeric vector indicating the participant's age (in years).}

\item{GEN}{A numeric vector indicating gender (1 = man, 0 = woman).}

\item{EDU}{A numeric vector indicating years of education.}
}
\value{
A numeric vector of computed z-scores, one for each raw score in \code{x}.
}
\description{
Computes z-scores for a given test index using regression parameters from a normative
calculator, along with the patient's raw score and demographic information
(age, gender, education).
}
\examples{
\dontrun{
# Example usage:
z <- compute_z_score(
  calc = regression_table,
  x = c(35, 42, 28),
  nam = "Digit Span Backward",
  AGE = c(67, 70, 74),
  GEN = c(1, 0, 1),
  EDU = c(15, 12, 16)
)
}
}
