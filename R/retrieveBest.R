#' Remix results
#'
#' Extracts the build minimizing the BIC over a grid of lambda.
#'
#'
#' @param fit output of \code{\link{cv.remix}};
#' @param criterion which criterion among "BIC" and "eBIC" to take into account.
#'
#' @return outputs from \code{\link{remix}} algorithm achieving the best BIC among those computed by \code{\link{cv.remix}}.
#' @export
#' @seealso \code{\link{cv.remix}}, \code{\link{remix}}.
#'
#' @examples
#' \dontrun{
#' project <- getMLXdir()
#'
#' ObsModel.transfo = list(S=list(AB=log10),
#'                         linkS="yAB",
#'                         R=rep(list(S=function(x){x}),5),
#'                         linkR = paste0("yG",1:5))
#'
#' alpha=list(alpha0=NULL,
#'            alpha1=setNames(paste0("alpha_1",1:5),paste0("yG",1:5)))
#'
#' y = c(S=5,AB=1000)
#'
#' cv.outputs = cv.Remix(project = project,
#'             dynFUN = dynFUN_demo,
#'             y = y,
#'             ObsModel.transfo = ObsModel.transfo,
#'             alpha = alpha,
#'             selfInit = TRUE,
#'             eps1=10**(-2),
#'             ncores=8,
#'             eps2=1)
#'
#' res <- retrieveBest(cv.outputs)
#'
#' plotConvergence(res)
#'
#' trueValue = read.csv(paste0(dirname(project),"/demoSMLX/Simulation/populationParameters.txt"))#'
#'
#' plotSAEM(res,paramToPlot = c("delta_S_pop","phi_S_pop","delta_AB_pop"),trueValue=trueValue)
#' }
retrieveBest <- function(fit,criterion="BIC"){
  if(!inherits(fit,"cvRemix")){
    stop("Class of fit must be cvRemix")
  }
  argmin.id = which.min(fit[[criterion]])

  results = list(info = append(fit$info,list(lambda=fit$lambda[argmin.id],test=FALSE,p.max=0.05)),
                 finalRes = append(fit$res[[argmin.id]],list(saemBeforeTest=NULL)),
                 iterOutputs = fit$outputs[[argmin.id]])
  class(results) <- "remix"
  return(results)
}
