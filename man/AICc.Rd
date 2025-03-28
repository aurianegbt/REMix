% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/crit.R
\name{AICc}
\alias{AICc}
\title{AICc}
\usage{
AICc(x, ...)
}
\arguments{
\item{x}{output of \code{\link{remix}} or \code{\link{cv.remix}}.}
}
\value{
AICc.
}
\description{
Computes corrected akaike information criterion .
}
\examples{
\dontrun{
project <- getMLXdir()

ObsModel.transfo = list(S=list(Ab=log10),
                        linkS="yAB",
                        R=rep(list(S=function(x){x}),5),
                        linkR = paste0("yG",1:5))

alpha=list(alpha0=NULL,
           alpha1=setNames(paste0("alpha_1",1:5),paste0("yG",1:5)))

y = c(S=5,Ab=1000)
lambda = 1440

res = remix(project = project,
            dynFUN = dynFUN_demo,
            y = y,
            ObsModel.transfo = ObsModel.transfo,
            alpha = alpha,
            selfInit = TRUE,
            eps1=10**(-2),
            eps2=1,
            lambda=lambda)

AICc(res)
}
}
