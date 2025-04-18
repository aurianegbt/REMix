#' Generate individual parameters
#'
#' @description
#' Generate the individual parameters of indivual whose covariates are \code{covariates} and random effects \code{eta_i}.
#'
#' @details
#' The models used for the parameters are :
#' \deqn{ h_l(\psi_{li}) = h_l(\psi_{lpop})+X_i\beta_l + \eta_{li} }
#' with \eqn{h_l} the transformation, \eqn{\beta_l} the vector of covariates effect and  with \eqn{\eta_i} the random effects associated \eqn{\psi_l} parameter ;
#' \deqn{ g_k(\phi_{ki}) = g_k(\phi_{kpop})+X_i \gamma_l }
#' with \eqn{g_k} the transformation and  \eqn{\gamma_k} the vector of covariates effect associated \eqn{\phi_k} parameter.
#'
#' @param theta list with at least \code{phi_pop}, \code{psi_pop}, \code{gamma}, \code{beta} (named ; corresponding to the model parameter \eqn{\phi_{pop}}, \eqn{\psi_{pop}}, \eqn{\gamma}, \eqn{\beta} ) : \itemize{\item \code{phi_pop} named vector of population parameters without r.e ;\item \code{psi_pop} named vector of population parameters with r.e ;\item \code{gamma} named list of vector of covariates effects for  \code{phi_pop} parameters, if NULL no covariates effect on parameters. ;\item \code{beta} named list of vector of covariates effects for each \code{psi_pop}, if NULL no covariates effect on parameters.}
#' @param covariates line data.frame of individual covariates ;
#' @param eta_i named vector of random effect for each \code{psi} parameter ;
#' @param transfo named list of transformation functions \eqn{(h_l)_{l\leq m}} and \eqn{(s_k)_{k\leq K}} for the individual parameter model (names must be consistent with \code{phi_pop} and \code{psi_pop}, missing entries are set by default to the identity function).
#' @param transfo.inv amed list of inverse transformation functions for the individual parameter model (names must be consistent with\code{phi_pop} and\code{psi_pop}).
#'
#' @return a list with \code{phi_i} and \code{psi_i} parameters.
#' @export
#' @seealso \code{\link{model.clairon}}, \code{\link{model.pasin}}.
#'
#' @examples
#' phi_pop = c(delta_S = 0.231, delta_L = 0.000316)
#' psi_pop = c(delta_Ab = 0.025,phi_S = 3057, phi_L = 16.6)
#' gamma = NULL
#' covariates = data.frame(cAGE = runif(1,-15,15), G1 = rnorm(1), G2 = rnorm(1))
#' beta = list(delta_Ab=c(0,1.2,0),phi_S = c(0.93,0,0),phi_L=c(0,0,0.8))
#'
#' theta=list(phi_pop = phi_pop,psi_pop = psi_pop,gamma = gamma, beta = beta)
#' eta_i = c(delta_Ab = rnorm(1,0,0.3),phi_S=rnorm(1,0,0.92),phi_L=rnorm(1,0,0.85))
#' transfo = list(delta_Ab=log,phi_S=log,phi_L=log)
#' transfo.inv = list(delta_Ab = exp,phi_S=exp,phi_L=exp)
#'
#' indParm(theta,covariates,eta_i,transfo,transfo.inv)
indParm <- function(theta,covariates,eta_i,transfo,transfo.inv){

  check.indparm(theta,covariates,eta_i,transfo,transfo.inv)



  phi_i = numeric()
  psi_i = numeric()

  phi.names = names(theta$phi_pop)
  psi.names = names(theta$psi_pop)

  if(!is.null(covariates)){
    if(!is.matrix(covariates)){
      covariates <- as.matrix(covariates)
    }
  }

  ## Compute phi parameters -> parameters with no r.e
  for(p in phi.names){
    trans = transfo[[p]]
    if(is.null(trans)){
      trans <- trans.inv <- function(x){x}
    }else{trans.inv <- transfo.inv[[p]]}
    if(is.null(theta$gamma[[p]])){
      phi_i[[p]] <- trans.inv(trans(theta$phi_pop[[p]]))
    }else{
      phi_i[[p]] <- trans.inv(trans(theta$phi_pop[[p]])+as.numeric(covariates%*%matrix(theta$gamma[[p]],ncol=1)))
    }
  }

  ## Compute psi parameters -> parameters with r.e.
  for(p in psi.names){
    trans = transfo[[p]]
    if(is.null(trans)){
      trans <- trans.inv <- function(x){x}
    }else{trans.inv <- transfo.inv[[p]]}
    if(is.null(theta$beta[[p]])){
      psi_i[[p]] <- trans.inv(trans(theta$psi_pop[[p]])+eta_i[[p]])
    }else{
      psi_i[[p]] <- trans.inv(trans(theta$psi_pop[[p]])+as.numeric(covariates%*%matrix(theta$beta[[p]],ncol=1)) + eta_i[[p]])
    }
  }
  return(list(phi_i=phi_i,psi_i=psi_i))
}


# check -------------------------------------------------------------------
check.indparm <- function(theta,covariates,eta_i,transfo,transfo.inv){

  if( length(theta$phi_pop)!=0 && any(length(names(theta$phi_pop))==0)){
    stop("Please set unique names for each parameter in theta$phi_pop vector.")
  }
  if(length(theta$psi_pop)!=0 && any(length(names(theta$psi_pop))==0)){
    stop("Please set unique names for each parameter in theta$psi_pop vector.")
  }

  if(!is.null(theta$beta)){
    if(length(covariates)==0){
      stop("If covariates effects are provided through theta$beta, covariates need to be provided.")
    }
    if(any(sapply(theta$beta,FUN=function(b){length(b)}) > length(covariates))){
      stop("Please provide as many covariates effects coefficients in theta$beta as in covariates dataframe.")
    }
    if(any(!(names(theta$beta) %in% names(theta$psi_pop)))){
      stop("All parameters named in theta$beta should be present in theta$psi_pop.")
    }
    if(length(theta$psi_pop)!=length(eta_i)){
      stop("Please provide as many random effects values as parameters in theta$psi_pop")
    }
  }

  if(!is.null(theta$gamma)){
    if(length(covariates)==0){
      stop("If covariates effects are provided through theta$gamma, covariates need to be provided.")
    }
    if(any(sapply(theta$gamma,FUN=function(b){length(b)}) > length(covariates))){
      stop("Please provide at least as many covariates effects coefficients in theta$beta as in covariates dataframe.")
    }
    if(any(!(names(theta$gamma) %in% names(theta$phi_pop)))){
      stop("All parameters named in theta$gamma should be present in theta$phi_pop.")
    }
  }
  return(invisible(TRUE))
}

