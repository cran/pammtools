% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data.R
\docType{data}
\name{staph}
\alias{staph}
\title{Time until staphylococcus aureaus infection in children, with possible recurrence}
\format{
An object of class \code{tbl_df} (inherits from \code{tbl}, \code{data.frame}) with 374 rows and 6 columns.
}
\usage{
staph
}
\description{
This dataset originates from the Drakenstein child health study.
The data contains the following variables:
\describe{
\item{id}{Randomly generated unique child ID}
\item{t.start}{The time at which the child enters the risk set for the $k$-th event}
\item{t.stop}{Time of $k$-th infection or censoring}.
\item{enum}{Event number. Maximum of 6.}
\item{hiv}{}
}
}
\keyword{datasets}
