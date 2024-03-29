% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/geom-hazard.R
\docType{data}
\name{geom_hazard}
\alias{geom_hazard}
\alias{GeomHazard}
\alias{geom_stephazard}
\alias{GeomStepHazard}
\alias{geom_surv}
\alias{GeomSurv}
\title{(Cumulative) (Step-) Hazard Plots.}
\usage{
geom_hazard(
  mapping = NULL,
  data = NULL,
  stat = "identity",
  position = "identity",
  na.rm = FALSE,
  show.legend = NA,
  inherit.aes = TRUE,
  ...
)

geom_stephazard(
  mapping = NULL,
  data = NULL,
  stat = "identity",
  position = "identity",
  direction = "vh",
  na.rm = FALSE,
  show.legend = NA,
  inherit.aes = TRUE,
  ...
)

geom_surv(
  mapping = NULL,
  data = NULL,
  stat = "identity",
  position = "identity",
  na.rm = FALSE,
  show.legend = NA,
  inherit.aes = TRUE,
  ...
)
}
\arguments{
\item{mapping}{Set of aesthetic mappings created by \code{\link[ggplot2:aes]{aes()}}. If specified and
\code{inherit.aes = TRUE} (the default), it is combined with the default mapping
at the top level of the plot. You must supply \code{mapping} if there is no plot
mapping.}

\item{data}{The data to be displayed in this layer. There are three
options:

If \code{NULL}, the default, the data is inherited from the plot
data as specified in the call to \code{\link[ggplot2:ggplot]{ggplot()}}.

A \code{data.frame}, or other object, will override the plot
data. All objects will be fortified to produce a data frame. See
\code{\link[ggplot2:fortify]{fortify()}} for which variables will be created.

A \code{function} will be called with a single argument,
the plot data. The return value must be a \code{data.frame}, and
will be used as the layer data. A \code{function} can be created
from a \code{formula} (e.g. \code{~ head(.x, 10)}).}

\item{stat}{The statistical transformation to use on the data for this
layer, either as a \code{ggproto} \code{Geom} subclass or as a string naming the
stat stripped of the \code{stat_} prefix (e.g. \code{"count"} rather than
\code{"stat_count"})}

\item{position}{Position adjustment, either as a string naming the adjustment
(e.g. \code{"jitter"} to use \code{position_jitter}), or the result of a call to a
position adjustment function. Use the latter if you need to change the
settings of the adjustment.}

\item{na.rm}{If \code{FALSE}, the default, missing values are removed with
a warning. If \code{TRUE}, missing values are silently removed.}

\item{show.legend}{logical. Should this layer be included in the legends?
\code{NA}, the default, includes if any aesthetics are mapped.
\code{FALSE} never includes, and \code{TRUE} always includes.
It can also be a named logical vector to finely select the aesthetics to
display.}

\item{inherit.aes}{If \code{FALSE}, overrides the default aesthetics,
rather than combining with them. This is most useful for helper functions
that define both data and aesthetics and shouldn't inherit behaviour from
the default plot specification, e.g. \code{\link[ggplot2:borders]{borders()}}.}

\item{...}{Other arguments passed on to \code{\link[ggplot2:layer]{layer()}}. These are
often aesthetics, used to set an aesthetic to a fixed value, like
\code{colour = "red"} or \code{size = 3}. They may also be parameters
to the paired geom/stat.}

\item{direction}{direction of stairs: 'vh' for vertical then horizontal,
'hv' for horizontal then vertical, or 'mid' for step half-way between
adjacent x-values.}
}
\description{
\code{geom_hazard} is an extension of the \code{geom_line}, and
is optimized for (cumulative) hazard plots. Essentially, it adds a (0,0)
row to the data, if not already the case. Stolen from the
\code{RmcdrPlugin.KMggplot2} (slightly modified).
}
\examples{
library(ggplot2)
library(pammtools)
ped <- tumor[10:50,] \%>\% as_ped(Surv(days, status)~1)
pam <- mgcv::gam(ped_status ~ s(tend), data=ped, family = poisson(), offset = offset)
ndf <- make_newdata(ped, tend = unique(tend)) \%>\% add_hazard(pam)
# piece-wise constant hazards
ggplot(ndf, aes(x = tend, y = hazard)) +
 geom_vline(xintercept = c(0, ndf$tend[c(1, (nrow(ndf)-2):nrow(ndf))]), lty = 3) +
 geom_hline(yintercept = c(ndf$hazard[1:3], ndf$hazard[nrow(ndf)]), lty = 3) +
 geom_stephazard() +
 geom_step(col=2) +
 geom_step(col=2, lty = 2, direction="vh")

# comulative hazard
ndf <- ndf \%>\% add_cumu_hazard(pam)
ggplot(ndf, aes(x = tend, y = cumu_hazard)) +
 geom_hazard() +
 geom_line(col=2) # doesn't start at (0, 0)

# survival probability
ndf <- ndf \%>\% add_surv_prob(pam)
ggplot(ndf, aes(x = tend, y = surv_prob)) +
 geom_surv() +
 geom_line(col=2) # doesn't start at c(0,1)
}
\seealso{
\code{\link[ggplot2]{geom_line}},
\code{\link[ggplot2]{geom_step}}.
}
\keyword{datasets}
