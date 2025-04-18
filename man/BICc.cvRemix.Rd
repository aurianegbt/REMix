% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/crit.R
\name{BICc.cvRemix}
\alias{BICc.cvRemix}
\title{BICc for cvRemix object}
\usage{
\method{BICc}{cvRemix}(x)
}
\arguments{
\item{x}{output of \code{\link{cv.remix}}.}
}
\value{
BICc accross the grid.
}
\description{
Computes corrected Bayesian Information Criterion from the output of \code{\link{cv.remix}}.
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

res = cv.remix(project = project,
               dynFUN = dynFUN_demo,
               y = y,
               ObsModel.transfo = ObsModel.transfo,
               alpha = alpha,
               selfInit = TRUE,
               eps1=10**(-2),
               ncores=8,
               nlambda=8,
               eps2=1)

BICc(res)
}
}
\references{
Delattre M, Lavielle M, Poursat M-A. A note on BIC in mixed-effects models. Elect J Stat. 2014; 8(1): 456-475.
}
