#' Compute final estimation
#'
#' Computes a final saem and wald test if `test` on the final model found by remix algorithm.
#'
#' @param remix.output a \link{\code{remix}} outputs. It's important that the \code{project} path of this outputs is still existing.
#' @param final.project directory of the final Monolix project (default add "_upd" to the Monolix project).
#' @param pop.set population parameters setting for final estimation (see \code{\link{setPopulationParameterEstimationSettings}}).
#' @param print logical, if the results and algotihm steps should be displayed in the console (default to TRUE).
#' @param digits number of digits to print (default to 3).
#' @param trueValue -for simulation purposes- named vector of true value for parameters.
#' @param test if Wald test should be computed at the end of the iteration.
#' @param p.max maximum value to each for wald test p.value (default 0.05).
#'
#' @returns a remix object on which final SAEM and test, if \code{test} is \code{TRUE}, have been computed.
#' @export
#'
#' @examples
#' \dontrun{
#' project <- getMLXdir()
#'
#' ObsModel.transfo = list(S=list(Ab=log10),
#'                         linkS="yAB",
#'                         R=rep(list(S=function(x){x}),5),
#'                         linkR = paste0("yG",1:5))
#'
#' alpha=list(alpha0=NULL,
#'            alpha1=setNames(paste0("alpha_1",1:5),paste0("yG",1:5)))
#'
#' y = c(S=5,Ab=1000)
#'
#' res = cv.remix(project = project,
#'                dynFUN = dynFUN_demo,
#'                y = y,
#'                ObsModel.transfo = ObsModel.transfo,
#'                alpha = alpha,
#'                selfInit = TRUE,
#'                eps1=10**(-2),
#'                ncores=8,
#'                nlambda=8,
#'                eps2=1)
#'
#' res_with_test = computeFinalTest(retrieveBest(res0,criterion=BICc),
#'                                  dynFUN_demo,
#'                                  y,
#'                                  ObsModel.transfo)
#' }
computeFinalTest <- function(remix.output,
                             dynFUN,
                             y,
                             ObsModel.transfo,
                             final.project=NULL,
                             pop.set=NULL,
                             prune = NULL,
                             n = NULL,
                             parallel=TRUE,
                             ncores = NULL,
                             print=TRUE,
                             digits = 3,
                             trueValue=NULL,
                             test=TRUE,
                             p.max = 0.05){

  if(!inherits(remix.output,"remix")){
    stop("Class of fit must be remix")
  }

  ptm.first <- ptm <- proc.time()
  dashed.line <- "--------------------------------------------------\n"
  plain.line <- "__________________________________________________\n"
  dashed.short <- "-----------------------\n"
  plain.short <- "_______________________\n"

  op.original <- options()
  op.new <- options()
  op.new$lixoft_notificationOptions$warnings <- 1
  options(op.new)

  ### Start initialization of project
  check.proj(remix.output$info$project,remix.output$info$alpha)

  project = remix.output$info$project
  if (!grepl("\\.", project))
    project <- paste0(project, ".mlxtran")
  if (!grepl("\\.mlxtran", project))
    stop(paste0(project, " is not a valid name for a Monolix project (use the .mlxtran extension)"),call. = FALSE)

  regParam.toprint = remix.output$info$regParam.toprint
  param.toprint = remix.output$info$param.toprint
  alpha = remix.output$info$alpha

  project.dir <- lixoftConnectors::getProjectSettings()$directory
  if (!dir.exists(project.dir))
    dir.create(project.dir)
  remix.dir <- file.path(lixoftConnectors::getProjectSettings()$directory,"remix")
  Sys.sleep(0.1)
  if (!dir.exists(remix.dir))
    dir.create(remix.dir)
  Sys.sleep(0.1)
  summary.file = file.path(remix.dir, "summary.txt")
  # unlink(summary.file,force=TRUE)
  Sys.sleep(0.1)


  if (is.null(final.project)){
    final.project <- paste0(sub(pattern = "(.*)\\..*$",
                                replacement = "\\1", project), "_final.mlxtran")
  }
  if (!grepl("\\.", final.project))
    final.project <- paste0(final.project, ".mlxtran")
  if (!grepl("\\.mlxtran", final.project))
    stop(paste0(final.project, " is not a valid name for a Monolix project (use the .mlxtran extension)"),
         call. = FALSE)
  lixoftConnectors::saveProject(final.project)

  ###### Starting first estimation

  to.cat <- paste0("\n     ", dashed.line, " Starting Final Regulatization and Estimation Algorithm Step \n")
  to.cat <- c(to.cat,"      \u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\u203E\n")
  print_result(print,summary.file,to.cat,to.print=NULL)

  pset <- list(nbsmoothingiterations=200,nbexploratoryiterations=500,
               simulatedannealing=T, smoothingautostop=T,exploratoryautostop=T)
  if(!is.null(pop.set))
    pset <-  modifyList(pset, pop.set[intersect(names(pop.set),
                                                names(pset))])
  pop.set <- lixoftConnectors::getPopulationParameterEstimationSettings()
  pop.set <- modifyList(pop.set, pset[intersect(names(pset), names(pop.set))])

  ## RENDER INITIAL PARAMETER
  param0 <- param <- remix.output$finalRes$param

  to.cat <- "\n      - - - <  INITIAL PARAMETERS  > - - -     \n\n"

  to.print <- data.frame(EstimatedValue = sapply(param0,FUN=function(p){format(signif(p,digits=digits),scientific=TRUE)})[param.toprint])
  row.names(to.print) <- param.toprint

  if(!is.null(trueValue)){
    to.print <- cbind(to.print,
                      TrueValue = format(signif(as.numeric(trueValue[param.toprint]),digits=digits),scientific = TRUE),
                      RelativeBias = round((param0[param.toprint]-as.numeric(trueValue[param.toprint]))/as.numeric(trueValue[param.toprint]),digits=digits))
  }
  print_result(print, summary.file, to.cat = to.cat, to.print = to.print)

  to.cat <- "\n"
  to.print <- data.frame(EstimatedValue = sapply(param0,FUN=function(p){format(signif(p,digits=digits),scientific = T)})[regParam.toprint])
  row.names(to.print) <- regParam.toprint
  if(!is.null(trueValue)){
    to.print <- cbind(to.print,
                      TrueValue = format(signif(as.numeric(trueValue[regParam.toprint]),digits=digits),scientific = TRUE),
                      RelativeBias = round((param0[regParam.toprint]-as.numeric(trueValue[regParam.toprint]))/as.numeric(trueValue[regParam.toprint]),digits=digits))

    to.print[is.nan(to.print$RelativeBias) | is.infinite(to.print$RelativeBias),"RelativeBias"] <- " "

    to.print[trueValue[regParam.toprint]==0,"TrueValue"] <- "  "
    to.print[param0[regParam.toprint]==0,"EstimatedValue"] <- "  "
  }
  print_result(print, summary.file, to.cat = to.cat, to.print = to.print)

  to.cat <- paste0("\nComputing final SAEM... \n")
  print_result(print, summary.file, to.cat = to.cat, to.print = NULL)


  currentData = readMLX(project = final.project,
                        ObsModel.transfo = ObsModel.transfo,
                        alpha = alpha)

  populationParameters <- data.frame(name=names(param),initialValue=as.numeric(unname(param)))
  lixoftConnectors::setPopulationParameterInformation(populationParameters)
  populationParameters <- lixoftConnectors::getPopulationParameterInformation()

  populationParameters[populationParameters$name %in% unname(paste0(remix.output$info$alpha$alpha1,"_pop")) & populationParameters$initialValue==0,"method"] <- "FIXED"
  populationParameters[populationParameters$name %in% unname(paste0(remix.output$info$alpha$alpha1,"_pop")) & populationParameters$initialValue!=0,"method"] <- "MLE"

  a.final <- setNames(param[paste0(alpha$alpha1,"_pop")],names(alpha$alpha1))

  MLE = list()
  for(k in 1:length(alpha$alpha1)){
    yGk = names(alpha$alpha1)[k]
    Yk = currentData$Robs[[yGk]][,yGk]
    if(is.null(alpha$alpha0)){
      MLE[[k]] <- list(estimate=c(mean=0,
                                  sd=sd(Yk)*sqrt((length(Yk)-1)/length(Yk))),
                       sd=c(mean=1e-5,
                            sd=sd(Yk)*sqrt((length(Yk)-1)/length(Yk))/sqrt(2*length(Yk))))
    }else{
      MLE[[k]] <- list(estimate=c(mean=mean(Yk),
                                  sd=sd(Yk)*sqrt((length(Yk)-1)/length(Yk))),
                       sd=c(mean=sd(Yk)*sqrt((length(Yk)-1)/length(Yk))/sqrt(length(Yk)),
                            sd=sd(Yk)*sqrt((length(Yk)-1)/length(Yk))/sqrt(2*length(Yk))))
    }

    if(a.final[yGk]==0){
      if(!is.null(alpha$alpha0)){

        populationParameters[populationParameters$name==paste0(alpha$alpha0[k],"_pop"),c("initialValue","method")] <- c(MLE[[k]]$estimate[["mean"]],"FIXED")
      }
      populationParameters[populationParameters$name==lixoftConnectors::getContinuousObservationModel()$parameter[[yGk]],c("initialValue","method")] <-c(MLE[[k]]$estimate[["sd"]],"FIXED")
    }else{
      if(!is.null(alpha$alpha0)){
        populationParameters[populationParameters$name==paste0(alpha$alpha0[k],"_pop"),"method"] <- "MLE"
      }
      populationParameters[populationParameters$name==lixoftConnectors::getContinuousObservationModel()$parameter[[yGk]],"method"] <- "MLE"
    }
  }
  MLE <- setNames(MLE,names(alpha$alpha0))

  populationParameters$initialValue <- as.numeric(populationParameters$initialValue)

  lixoftConnectors::setPopulationParameterInformation(populationParameters)
  lixoftConnectors::setPopulationParameterEstimationSettings(pop.set)
  lixoftConnectors::saveProject(final.project)
  lixoftConnectors::runPopulationParameterEstimation()
  lixoftConnectors::runConditionalDistributionSampling()
  lixoftConnectors::runStandardErrorEstimation()
  lixoftConnectors::saveProject(final.project)

  se = lixoftConnectors::getEstimatedStandardErrors()
  if(any(a.final==0)){
    if(!is.null(alpha$alpha0)){
      se$stochasticApproximation <- rbind(se$stochasticApproximation,
                                          data.frame(parameter = paste0(unname(alpha$alpha0[names(which(a.final==0))]),"_pop"),
                                                     se = sapply(names(which(a.final==0)),FUN=function(yGk){MLE[[yGk]]$sd[["mean"]]}),
                                                     rse = sapply(names(which(a.final==0)),FUN=function(yGk){MLE[[yGk]]$sd[["mean"]]/MLE[[yGk]]$estimate[["mean"]]*100}),row.names = 1:length(which(a.final==0))))
    }

    se$stochasticApproximation <- rbind(se$stochasticApproximation,
                                        data.frame(parameter = unlist(unname(lixoftConnectors::getContinuousObservationModel()$parameter[names(which(a.final==0))])),
                                                   se = sapply(names(which(a.final==0)),FUN=function(yGk){MLE[[yGk]]$sd[["sd"]]}),
                                                   rse = sapply(names(which(a.final==0)),FUN=function(yGk){MLE[[yGk]]$sd[["sd"]]/MLE[[yGk]]$estimate[["sd"]]*100}),row.names = 1:length(which(a.final==0))))
  }

  re <- saemfinal <- list(SAEMiterations = lixoftConnectors::getChartsData("plotSaem"),
                          param = lixoftConnectors::getEstimatedPopulationParameters(),
                          standardErrors=se)

  to.cat <- paste0("Estimating log-likelihood... \n")
  print_result(print, summary.file, to.cat = to.cat, to.print = NULL)
  currentData0 <- currentData <- readMLX(project = final.project,
                                         ObsModel.transfo = ObsModel.transfo,
                                         alpha = alpha)
  LLfinal <- gh.LL(dynFUN = dynFUN, y = y, data = currentData, n = n, prune = prune, parallel = parallel,verbose = print,onlyLL = TRUE)

  populationParameters <- merge(data.frame(name=names(re$param),initialValue=as.numeric(unname(re$param))),lixoftConnectors::getPopulationParameterInformation()[,c(1,3)],by="name")

  sd.est = re$standardErrors$stochasticApproximation[,-3]
  if(length(setdiff(names(re$param),sd.est$parameter))!=0){
    sd.est <- rbind(sd.est, data.frame(parameter=setdiff(names(re$param),sd.est$parameter),se=NA))
  }

  to.print <- data.frame(EstimatedValue = sapply(re$param,FUN=function(p){format(signif(p,digits=digits),scientific=TRUE)}))

  sd.est <- merge(data.frame(parameter=names(re$param),EstimatedValue=unname(re$param)),sd.est,by="parameter")
  sd.est <- cbind(sd.est,CI_95=sapply(1:nrow(sd.est),FUN=function(i){ifelse(!is.na(sd.est$se[i]),paste0("[",format(signif(sd.est$EstimatedValue[i]-1.96*sd.est$se[i],digits=digits),scientific=TRUE),";",format(signif(sd.est$EstimatedValue[i]+1.96*sd.est$se[i],digits=digits),scientific=TRUE),"]")," ")}))
  rownames(sd.est) <- sd.est$parameter
  sd.est <- sd.est[rownames(to.print),-1]

  to.print <- dplyr::mutate(dplyr::mutate(sd.est,EstimatedValue = sapply(sd.est$EstimatedValue,FUN=function(p){format(signif(p,digits=digits),scientific=TRUE)})),se=sapply(sd.est$se,FUN=function(p){format(signif(p,digits=digits),scientific=TRUE)}))
  to.print$se[to.print$se=="NA"] <- " "

  if(!is.null(trueValue)){
    to.print <- cbind(to.print,
                      TrueValue = format(signif(as.numeric(trueValue[rownames(to.print)]),digits=digits),scientific=TRUE),
                      RelativeBias = round(as.numeric((re$param[rownames(to.print)]-trueValue[rownames(to.print)])/trueValue[rownames(to.print)]),digits=digits))
  }

  paramfinal <- re$param
  print_result(print, summary.file, to.cat = NULL, to.print = to.print)

  to.cat <- "\n      - - - <  CRITERION  > - - -     \n"
  to.cat <- paste0(to.cat,"        LL : ",round(LLfinal,digits=digits))
  to.cat <- paste0(to.cat,"\n       BIC :  ",round(-2*LLfinal+log(remix.output$info$N)*(sum(paramfinal[paste0(alpha$alpha1,"_pop")]!=0)+length(remix.output$info$param.toprint)),digits=digits))
  to.cat <- paste0(to.cat,"\n      BICc :  ",round(-2*LLfinal+log(remix.output$info$ntot)*(sum(paramfinal[paste0(alpha$alpha1,"_pop")]!=0)+PFPR(remix.output$info$param.toprint)$PF)+log(remix.output$info$N)*PFPR(remix.output$info$param.toprint)$PR,digits=digits),"\n")
  print_result(print, summary.file, to.cat = to.cat, to.print = NULL)

  if(test){
    to.cat <- "\nComputing Wald test (with null hypothesis alpha1=0)...\n"
    print_result(print, summary.file, to.cat = to.cat, to.print = NULL)

    ST <- re$standardErrors$stochasticApproximation
    ST <- merge(ST[ST$parameter %in% regParam.toprint,,drop=FALSE],data.frame(parameter=ST$parameter,ES=re$param[ST$parameter]),by="parameter")

    ST <- dplyr::mutate(ST,stat.test=abs(ST$ES/ST$se))
    ST <- dplyr::mutate(ST,p.value=2*(1-pnorm(stat.test)))
    ST <- dplyr::mutate(ST," "=ifelse(p.value<=p.max,paste0("<",p.max)," "))

    if(!is.null(trueValue)){
      aux.print <- dplyr::mutate(merge(data.frame(parameter=rownames(to.print),dplyr::select(to.print,-RelativeBias)),ST[,c("parameter","stat.test","p.value"," ")],by="parameter",all.x = TRUE),stat.test=round(stat.test,digits=digits))
    }else{
      aux.print <- dplyr::mutate(dplyr::mutate(merge(data.frame(parameter=rownames(to.print),to.print),ST[,c("parameter","stat.test","p.value"," ")],by="parameter",all.x = TRUE),stat.test=round(stat.test,digits=digits)),p.value=round(p.value,digits=digits))
    }
    aux.print[is.na(aux.print$stat.test),"stat.test"] <- " "
    aux.print[is.na(aux.print$p.value),"p.value"] <- " "
    aux.print[is.na(aux.print$` `)," "] <- " "
    rownames(aux.print) <- aux.print$parameter
    aux.print <- dplyr::select(aux.print,-parameter)

    to.print <- aux.print[rownames(to.print),]
    to.print <- to.print[regParam.toprint,-2]
    print_result(print, summary.file, to.cat = NULL, to.print = to.print)


    if(any(ST$p.value>p.max)){
      setToZero = names(alpha$alpha1[paste0(alpha$alpha1,"_pop") %in% ST[ST$p.value>p.max,"parameter"]])

      populationParameters[populationParameters$name %in% ST[ST$p.value>p.max,"parameter"],"initialValue"]=0
      populationParameters[populationParameters$name %in% unname(paste0(remix.output$info$alpha$alpha1,"_pop")) & populationParameters$initialValue==0,"method"] <- "FIXED"
      for(yGk in setToZero){
        if(!is.null(alpha$alpha0)){
          populationParameters[populationParameters$name==paste0(alpha$alpha0[yGk],"_pop"),c("initialValue","method")] <-c(MLE[[yGk]]$estimate[["mean"]],"FIXED")
        }
        populationParameters[populationParameters$name==lixoftConnectors::getContinuousObservationModel()$parameter[[yGk]],c("initialValue","method")] <-c(MLE[[yGk]]$estimate[["sd"]],"FIXED")
        }

      to.cat <- paste0("   time elapsed : ",round((proc.time()-ptm)["elapsed"],digits=digits),"s\n")
      to.cat <- c(" Setting parameters to 0...\n")
      print_result(print, summary.file, to.cat = to.cat, to.print = NULL)
      to.cat <- paste0("(re)Computing final SAEM... \n")
      print_result(print, summary.file, to.cat = to.cat, to.print = NULL)

      populationParameters$initialValue <- as.numeric(populationParameters$initialValue)

      lixoftConnectors::setPopulationParameterInformation(populationParameters)
      lixoftConnectors::setPopulationParameterEstimationSettings(pop.set)
      lixoftConnectors::saveProject(final.project)
      lixoftConnectors::runPopulationParameterEstimation()
      lixoftConnectors::runConditionalDistributionSampling()
      lixoftConnectors::runStandardErrorEstimation()
      lixoftConnectors::saveProject(final.project)

      a.final = setNames(lixoftConnectors::getEstimatedPopulationParameters()[paste0(alpha$alpha1,"_pop")],names(alpha$alpha1))

      se = lixoftConnectors::getEstimatedStandardErrors()
      if(any(a.final==0)){
        if(!is.null(alpha$alpha0)){
          se$stochasticApproximation <- rbind(se$stochasticApproximation,
                                              data.frame(parameter = paste0(unname(alpha$alpha0[names(which(a.final==0))]),"_pop"),
                                                         se = sapply(names(which(a.final==0)),FUN=function(yGk){MLE[[yGk]]$sd[["mean"]]}),
                                                         rse = sapply(names(which(a.final==0)),FUN=function(yGk){MLE[[yGk]]$sd[["mean"]]/MLE[[yGk]]$estimate[["mean"]]*100}),row.names = 1:length(which(a.final==0))))
        }
        se$stochasticApproximation <- rbind(se$stochasticApproximation,
                                            data.frame(parameter = unlist(unname(lixoftConnectors::getContinuousObservationModel()$parameter[names(which(a.final==0))])),
                                                       se = sapply(names(which(a.final==0)),FUN=function(yGk){MLE[[yGk]]$sd[["sd"]]}),
                                                       rse = sapply(names(which(a.final==0)),FUN=function(yGk){MLE[[yGk]]$sd[["sd"]]/MLE[[yGk]]$estimate[["sd"]]*100}),row.names = 1:length(which(a.final==0))))
      }

      re = list(SAEMiterations = lixoftConnectors::getChartsData("plotSaem"),
                param = lixoftConnectors::getEstimatedPopulationParameters(),
                standardErrors=se)

      to.cat <- paste0("Estimating log-likelihood... \n")
      print_result(print, summary.file, to.cat = to.cat, to.print = NULL)
      currentData0 <- currentData <- readMLX(project = final.project,
                                             ObsModel.transfo = ObsModel.transfo,
                                             alpha = alpha)

      LLfinal <- gh.LL(dynFUN = dynFUN, y = y, data = currentData, n=n, prune=prune,  parallel = parallel ,ncores = ncores,verbose = print,onlyLL = TRUE)

      to.cat <- "\n      - - - <  FINAL PARAMETERS  > - - -     \n\n"
      print_result(print,summary.file, to.cat = to.cat,to.print=NULL)


      sd.est = re$standardErrors$stochasticApproximation[,-3]
      sd.est <- rbind(sd.est, data.frame(parameter=setdiff(names(re$param),sd.est$parameter),se=NA))

      to.print <- data.frame(EstimatedValue = sapply(re$param,FUN=function(p){format(signif(p,digits=digits),scientific=TRUE)}))

      sd.est <- merge(data.frame(parameter=names(re$param),EstimatedValue=unname(re$param)),sd.est,by="parameter")
      sd.est <- cbind(sd.est,CI_95=sapply(1:nrow(sd.est),FUN=function(i){ifelse(!is.na(sd.est$se[i]),paste0("[",format(signif(sd.est$EstimatedValue[i]-1.96*sd.est$se[i],digits=digits),scientific=TRUE),";",format(signif(sd.est$EstimatedValue[i]+1.96*sd.est$se[i],digits=digits),scientific=TRUE),"]")," ")}))
      rownames(sd.est) <- sd.est$parameter
      sd.est <- sd.est[rownames(to.print),-1]

      to.print <- dplyr::mutate(dplyr::mutate(sd.est,EstimatedValue = sapply(sd.est$EstimatedValue,FUN=function(p){format(signif(p,digits=digits),scientific=TRUE)})),se=sapply(sd.est$se,FUN=function(p){format(signif(p,digits=digits),scientific=TRUE)}))
      to.print$se[to.print$se=="NA"] <- " "

      if(!is.null(trueValue)){
        to.print <- cbind(to.print,
                          TrueValue = format(signif(as.numeric(trueValue[rownames(to.print)]),digits=digits),scientific=TRUE),
                          RelativeBias = round(as.numeric((re$param[rownames(to.print)]-trueValue[rownames(to.print)])/trueValue[rownames(to.print)]),digits=digits))
      }

      paramfinal <- re$param
      print_result(print, summary.file, to.cat = NULL, to.print = to.print)
    }
  }else{
    print_result(print, summary.file, to.cat = NULL, to.print = to.print)
  }

  to.cat <- "\n      - - - <  CRITERION  > - - -     \n"
  to.cat <- paste0(to.cat,"        LL : ",round(LLfinal,digits=digits))
  to.cat <- paste0(to.cat,"\n       BIC :  ",round(-2*LLfinal+log(remix.output$info$N)*(sum(paramfinal[paste0(alpha$alpha1,"_pop")]!=0)+length(remix.output$info$param.toprint)),digits=digits))
  to.cat <- paste0(to.cat,"\n      BICc :  ",round(-2*LLfinal+log(remix.output$info$ntot)*(sum(paramfinal[paste0(alpha$alpha1,"_pop")]!=0)+PFPR(remix.output$info$param.toprint)$PF)+log(remix.output$info$N)*PFPR(remix.output$info$param.toprint)$PR,digits=digits),"\n")
  print_result(print, summary.file, to.cat = to.cat, to.print = NULL)

  lixoftConnectors::saveProject(final.project)

  results <- list(info = list(project=final.project,
                              param.toprint=param.toprint,
                              regParam.toprint=regParam.toprint,
                              alpha=alpha,
                              lambda=remix.output$info$lambda,
                              finalSAEM = TRUE,
                              test=test,
                              p.max=if(test){p.max}else{NULL},
                              N=remix.output$info$N,
                              ntot=remix.output$info$ntot),
                  finalRes=list(LL=LLfinal,
                                LL.pen = LLfinal -remix.output$info$lambda*sum(paramfinal[paste0(alpha$alpha1,"_pop")]!=0),
                                param=paramfinal,
                                alpha=paramfinal[paste0(alpha$alpha1,"_pop")],
                                iter=remix.output$finalRes$iter,
                                time=remix.output$finalRes$time+(proc.time()-ptm.first)["elapsed"],
                                standardError=se,
                                saemBeforeTest=if(test){saemfinal}else{NULL}),
                  iterOutputs=list(param=remix.output$iterOutputs$param,
                                   LL=remix.output$iterOutputs$LL,
                                   LL.pen = remix.output$iterOutputs$LL.pen,
                                   estimates=remix.output$iterOutputs$estimates,
                                   criterion = remix.output$iterOutputs$criterion))
  class(results) <- "remix"

  return(results)
}

