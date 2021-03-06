
####################################################################
##############Geniefit##############################################
####################################################################

#########introduce function: branching.sampling.times and heterochronous.gp.stat from###
##########https://github.com/sdwfrost/pangea/blob/master/skyride/skyride.Rmd###########

#' Simulate coalescent times for heterochronous data.
#'
#' \code{coalgen_hetero} simulates coalescent times for heterochronous data.
#'
#' @param sample A two columns matrix of number of individuals and the initial time.
#' @param trajectory A population growth function.
#' @param val_upper Upper end of time points to be simulated.
#'
#'
#' @return Coalescent intervals and lineages.
#'
#' @references \url{https://github.com/JuliaPalacios/coalsieve}.
#'
#'@export
#'
#' @examples
#' sample1<-cbind(c(9,1,2,1),c(0,.008,.03,.1))
#'
#' trajectory<-function(x)  exp(10*x)
#' example_hetero<-coalgen_hetero(sample1, trajectory)
#'
#'
#'
coalgen_hetero <-function(sample, trajectory,val_upper=10){
  #'sample = is a matrix with 2 columns. The first column contains the number of samples collected at the time defined in the second column
  #'trajectory = one over the effective population size function
  # this works for heterochronous sampling
  # assumes sample[1,1]>1
  s=sample[1,2]
  b<-sample[1,1]
  n<-sum(sample[,1])-1
  m<-n
  nsample<-nrow(sample)
  sample<-rbind(sample,c(0,10))
  out<-rep(0,n)
  branches<-rep(0,n)
  i<-1
  while (i<(nsample+1)){
    if (b==1) {break}
    if (b<2){
      b<-b+sample[i+1,1]
      s<-sample[i+1,2]
      i<-i+1
    }
    x<-rexp(1)
    f <- function(bran,u,x,s) .5*bran*(bran-1)*integrate(trajectory, s, s+u)$value - x
    y<-uniroot(f,bran=b,x=x,s=s,lower=0,upper=val_upper)$root
    while ( (s+y)>sample[i+1,2]) {
      #     f <- function(bran,u,x,s) .5*bran*(bran-1)*integrate(trajectory, s, s+u)$value - x
      #     y<-uniroot(f,bran=b,x=x,s=s,lower=0,upper=val_upper)$root
      x<-x-.5*b*(b-1)*integrate(trajectory,s,sample[i+1,2])$value
      b<-b+sample[i+1,1]
      s<-sample[i+1,2]
      i<-i+1
      f <- function(bran,u,x,s) .5*bran*(bran-1)*integrate(trajectory, s, s+u)$value - x
      y<-uniroot(f,bran=b,x=x,s=s,lower=0,upper=val_upper)$root
      if (i==nsample) {sample[nsample+1,2]<-10*(s+y)}
    }

    s<-s+y
    out[m-n+1]<-s
    branches[m-n+1]<-b
    n<-n-1
    b<-b-1
    if (i==nsample) {sample[nsample+1,2]<-10*(s+y)}

  }

  return(list(branches=c(out[1],diff(out)),lineages=branches))
}


#' Simulate coalescent times for isochronous data.
#'
#' \code{coalgen_iso} simulates coalescent times for isochronous data.
#'
#' @param sample A two dimensional vector of number of individuals and the initial time.
#' @param trajectory A population growth function.
#' @param val_upper Upper end of time points to be simulated.
#'
#'
#' @return Coalescent intervals and lineages.
#'
#' @references \url{https://github.com/JuliaPalacios/coalsieve}.
#'
#' @export
#'
#' @examples
#' sample<-c(100,0)
#'
#' trajectory<-function(x)  exp(10*x)
#' example_iso<-coalgen_iso(sample, trajectory)
#'
coalgen_iso<-function(sample, trajectory,val_upper=10){
  #'sample = is a matrix with 2 columns. The first column contains the number of samples collected at the time defined in the second column
  #'trajectory = one over the effective population size function
  # this works for isochronous sampling
  s=sample[2]
  n<-sample[1]
  out<-rep(0,n-1)
  #   val_upper<-10*(1/choose(n+1,3))
  for (j in n:2){
    t=rexp(1,choose(j,2))
    #' trajectory is the inverse of the effective population size function
    f <- function(x,t,s) integrate(trajectory, s, s+x)$value - t
    #--- I will probably need to catch an error here, for val_upper, it breaks if
    # val_upper is not large enough
    #    val_upper<-10
    y<-uniroot(f,t=t,s=s,lower=0,upper=val_upper)$root
    s<-s+y
    out[n-j+1]<-s
  }
  return(list(branches=c(out[1],diff(out)),lineages=seq(n,2,-1)))

}





#' Extract sampling and coalescent times from a phylogenetic tree.
#'
#' \code{branching.sampling.times} extracts sampling and coalescent times from a phylogenetic tree.
#'
#' @param phy A phylogenetic tree.
#'
#'
#' @return Sampling times and coalescent times
#'
#' @references Palacios JA and Minin VN. Integrated nested Laplace approximation for Bayesian nonparametric phylodynamics, in Proceedings of the Twenty-Eighth Conference on Uncertainty in Artificial Intelligence, 2012.
#'
#' @examples
#' library(ape)
#' t1=rcoal(20)
#' branching.sampling.times(t1)
#'
#'
#' @export
branching.sampling.times <- function(phy){
  phy = new2old.phylo(phy)
  if (class(phy) != "phylo")
    stop("object \"phy\" is not of class \"phylo\"")
  tmp <- as.numeric(phy$edge)
  nb.tip <- max(tmp)
  nb.node <- -min(tmp)
  xx <- as.numeric(rep(NA, nb.tip + nb.node))
  names(xx) <- as.character(c(-(1:nb.node), 1:nb.tip))
  xx["-1"] <- 0
  for (i in 2:length(xx)) {
    nod <- names(xx[i])
    ind <- which(phy$edge[, 2] == nod)
    base <- phy$edge[ind, 1]
    xx[i] <- xx[base] + phy$edge.length[ind]
  }
  depth <- max(xx)
  branching.sampling.times <- depth - xx
  return(branching.sampling.times)
}

#' Sort out sampling times, coalescent times and sampling lineages from a phylogenetic tree
#'
#' \code{heterochronous.gp.stat} sorts out sampling times, coalescent times and sampling lineages from a phylogenetic tree.
#'
#' @param phy A phylogenetic tree.
#'
#'
#' @return Sorted sampling times, coalescent times and sampling lineages.
#'
#' @references Palacios JA and Minin VN. Integrated nested Laplace approximation for Bayesian nonparametric phylodynamics, in Proceedings of the Twenty-Eighth Conference on Uncertainty in Artificial Intelligence, 2012.
#' @examples
#' library(ape)
#' t1=rcoal(20)
#' heterochronous.gp.stat(t1)
#'
#' @export




heterochronous.gp.stat <- function(phy){
  b.s.times = branching.sampling.times(phy)
  int.ind = which(as.numeric(names(b.s.times)) < 0)
  tip.ind = which(as.numeric(names(b.s.times)) > 0)
  num.tips = length(tip.ind)
  num.coal.events = length(int.ind)
  sampl.suf.stat = rep(NA, num.coal.events)
  coal.interval = rep(NA, num.coal.events)
  coal.lineages = rep(NA, num.coal.events)
  sorted.coal.times = sort(b.s.times[int.ind])
  names(sorted.coal.times) = NULL
  #unique.sampling.times = sort(unique(b.s.times[tip.ind]))
  sampling.times = sort((b.s.times[tip.ind]))
  for (i in 2:length(sampling.times)){
    if ((sampling.times[i]-sampling.times[i-1])<1e-6){
      sampling.times[i]<-sampling.times[i-1]}
  }
  unique.sampling.times<-unique(sampling.times)
  sampled.lineages = NULL
  for (sample.time in unique.sampling.times){
    sampled.lineages = c(sampled.lineages,
                         sum(sampling.times == sample.time))
  }
  return(list(coal.times=sorted.coal.times, sample.times = unique.sampling.times, sampled.lineages=sampled.lineages))
}




#' A function to fit coalescent models to a given phylogenetic tree.
#' @param phy A phylogenetic tree.
#' @param Model A Model choice from const (constant population size), expo (exponetial growth),expan (expansion growth), log (logistic growth), step (piecewise constant), pexpan (piecewise expansion growth) and plog (piecewise logistic growth).
#' @param start Initial values for the parameters to be optimized over.
#' @param lower, upper Bounds on the variables.
#' @return Parameters estimation of a given model, loglikelihood and AIC
#' @examples
#' library(ape)
#' t1=rcoal(20)
#' Geniefit(t1,Model="expo",start=c(100,.1,.1),upper=Inf,lower=0)
#' @export
#######one function to produce the fit######
Geniefit=function(phy,Model="user",start,upper,lower){
  #####wash the data from the tree file#########
  phy.times=heterochronous.gp.stat (phy)
  ##################times frame given the coalesent events#############
  n=length(phy.times$coal.times)
  coaltimes.pop=matrix(0,nrow=n,ncol=2)
  coaltimes.pop[,1]=phy.times$coal.times
  coaltimes.pop[,2]=-1
  #################times frame given the sampled events################
  xn=length(phy.times$sample.times)
  samptimes.pop=matrix(0,nrow=xn,ncol=2)
  samptimes.pop[,1]=phy.times$sample.times
  samptimes.pop[,2]=phy.times$sampled.lineages
  ######sorted time and index matrix#####
  times.pop=rbind(samptimes.pop,coaltimes.pop)
  sort.times.pop=times.pop
  sort.times.pop[,1]=times.pop[,1][order(times.pop[,1])]
  sort.times.pop[,2]=times.pop[,2][order(times.pop[,1])]
  #####population at diffrent times###
  pop.times=cumsum(sort.times.pop[,2])
  #####type of time, 0 denoting sampling event and 1 denoting coalesent event####
  type=c(rep(0,xn),rep(1,n))
  sort.type=type[order(times.pop[,1])]
  ntotal=length(sort.type)
  #####if statement to get rid of first event when it is sampling event##########
  if (pop.times[1]<2) {
    pop.times=pop.times[-1]
    sort.times.pop=sort.times.pop[-1,]
    sort.times.pop[,1]=sort.times.pop[,1]-sort.times.pop[1,1]
    ntotal=ntotal-1
    sort.type=sort.type[-1]
  }
  ######population trajectory function#########
  fnpar=function(parr){
    ####function of t for population trajectory#####
    fnt=function(t){
      if (Model=="const") {trajectory=parr[1]}
      if (Model=="expo")  {trajectory=parr[1]*exp(-parr[2]*t)}
      if (Model=="expan") {trajectory=parr[1]*(parr[3]+(1-parr[3])*exp(-parr[2]*t))}
      if (Model=="log")   {trajectory=parr[1]*((1+parr[3])/(1+parr[3]*exp(parr[2]*t)))}
      if (Model=="step")  {trajectory=ifelse(t<parr[3],parr[1],parr[1]*parr[2])}
      if (Model=="pexpan") {trajectory=ifelse(t<-log(parr[3])/parr[2],parr[1]*exp(-parr[2]*t),parr[1]*parr[3])}
      return(1/trajectory)
    }
    ######define the integral explicit function given fnt###########
    intfnt=function(lowerlim,upperlim){
      if (Model=="const") {intg=1/parr[1]*(upperlim-lowerlim)}
      if (Model=="expo")  {intg=1/parr[1]/parr[2]*(exp(parr[2]*upperlim)-exp(parr[2]*lowerlim))}
      if (Model=="expan") {intg=1/parr[1]/parr[2]/parr[3]*(log(parr[3]*exp(parr[2]*upperlim)+1-parr[3])-log(parr[3]*exp(parr[2]*lowerlim)+1-parr[3]))}
      if (Model=="log")   {intg=1/parr[1]/(1+parr[3])*(upperlim-lowerlim+parr[3]/parr[2]*(exp(parr[2]*upperlim)-exp(parr[2]*lowerlim)))}
      if (Model=="step")  {
        intg=ifelse(upperlim<parr[3],1/parr[1]*(upperlim-lowerlim),ifelse(lowerlim>parr[3],1/parr[1]/parr[2]*(upperlim-lowerlim),1/parr[1]*(parr[3]-lowerlim)+1/parr[1]/parr[2]*(upperlim-parr[3])) )
      }
      if (Model=="pexpan") {
        intg=(upperlim< -log(parr[3])/parr[2])*1/parr[1]/parr[2]*(exp(parr[2]*upperlim)-exp(parr[2]*lowerlim))+(lowerlim>-log(parr[3])/parr[2])*1/parr[1]/parr[3]*(upperlim-lowerlim)+(lowerlim< -log(parr[3])/parr[2] && -log(parr[3])/parr[2]<upperlim)*(1/parr[1]/parr[3]*(upperlim+log(parr[3])/parr[2])+1/parr[1]/parr[2]*(exp(parr[2]*
                                                                                                                                                                                                                                                                                                                                      -log(parr[3])/parr[2])-exp(parr[2]*lowerlim)))
      }
      return(intg)
    }
    logcoe=sort.type[-1]*(log(fnt(sort.times.pop[-1,1]))+log(pop.times[-ntotal]*(pop.times[-ntotal]-1)/2))
    logint=-pop.times[-ntotal]*(pop.times[-ntotal]-1)/2*intfnt(sort.times.pop[-ntotal,1],sort.times.pop[-1,1])
    return(-sum(logcoe)-sum(logint))

  }
  fn2 <- function(x){
    fnpar(exp(x))
  }
  require(minqa)
  fit2 <- bobyqa(log(start),fn2,lower=log(lower),upper=log(upper))
  return(list(parr=exp(fit2$par),loglikelihood=-fit2$fval,AIC=2*length(start)+2*fit2$fval))
}





