% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/crit.R
\name{AIC.remix}
\alias{AIC.remix}
\title{AIC for remix object}
\usage{
\method{AIC}{remix}(x)
}
\arguments{
\item{x}{output of \code{\link{remix}}.}
}
\value{
AIC.
}
\description{
Computes akaike information criterion from the output of \code{\link{remix}}.
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

AIC(res)
}
}
