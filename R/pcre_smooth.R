
# Custom PCRE Smooth Without Constraints ----------------------------------


#' mgcv-style constructor for PC-basis functional random effects (no constraint)
#'
#' Sets up design matrix for functional random effects based on the PC scores
#' of the covariance operator of the random effect process. Note that there is
#' no constraint on the smoother.
#' See \code{\link[mgcv]{smooth.construct.re.smooth.spec}} for more details on
#' \code{mgcv}-style smoother specification
#' and \code{\link[refund]{smooth.construct.pcre.smooth.spec}} for the
#' corresponding \code{refund} implementation.
#'
#' This is an internal function as the corresponding smooth object and its
#' predict method is primarily used within the bamlss call.
#'
#' @param object a smooth specification object, see
#'  \code{\link[mgcv]{smooth.construct}}
#' @param data  see \code{\link[mgcv]{smooth.construct}}.
#' @param knots see \code{\link[mgcv]{smooth.construct}}.
#' @param ... see \code{\link[bamlss]{smooth.construct}}.
#' @return An object of class \code{"random.effect"}. See
#' \code{\link[mgcv]{smooth.construct}}
#'  for the elements that this object will contain.
#' @author Alexander Volkmann; adapted from 'pcre' constructor by F. Scheipl
#'  (adapted from 're' constructor by S.N. Wood).
#' @exportS3Method mgcv::smooth.construct unc_pcre.smooth.spec
#' @examples
#' data(pbc_subset)
#' mfpca <- preproc_MFPCA(pbc_subset, uni_mean = paste0(
#'   "logy ~ 1 + sex + drug + s(obstime, k = 5, bs = 'ps') + ",
#'   "s(age, k = 5, bs = 'ps')"),
#'   pve_uni = 0.99, nbasis = 5, weights = TRUE, save_uniFPCA = TRUE)
#' pbc_subset <- attach_wfpc(mfpca, pbc_subset, n = 2)
#' mfpca_list <- list(
#'   list(functions = funData::extractObs(mfpca$functions, 1),
#'        values = mfpca$values[1]),
#'   list(functions = funData::extractObs(mfpca$functions, 2),
#'        values = mfpca$values[2]))
#' sm <- smoothCon(s(id, fpc.1, bs = "unc_pcre",
#'       xt = list("mfpc" = mfpca_list[[1]], scale = "FALSE")), pbc_subset)
smooth.construct.unc_pcre.smooth.spec <- function(object, data, knots, ...) {
  if (!is.null(object$id))
    stop("random effects don't work with ids.")
  form <- as.formula(
    paste("~",
          paste(object$term[1], ":",
                paste("(",
                      paste(object$term[-1], collapse="+"),
                      ")")
                ),
          "-1"))
  X_id <- model.matrix(as.formula(paste("~ 0 +", object$term[1])), data)
  X_ef <- model.matrix(as.formula(
    paste("~ 0 +", paste(object$term[-1], collapse="+"))), data)
  object$X <- mgcv::tensor.prod.model.matrix(list(X_id, X_ef))

  object$bs.dim <- ncol(object$X)
  object$S <- list(diag(object$bs.dim))
  object$rank <- object$bs.dim
  object$null.space.dim <- 0
  object$C <- matrix(0, 0, ncol(object$X))
  object$form <- form
  object$side.constrain <- FALSE
  object$plot.me <- TRUE
  object$te.ok <- 2
  class(object) <- c("unc_pcre.random.effect", "pcre.random.effect",
                     "random.effect")
  object
}

#' mgcv-style constructor for prediction of PC-basis functional random effects
#'
#' This predictor function uses time-information saved in the object. This is
#' handled within the bamlss-transform function, so this function is not
#' exported.
#'
#' @param object a smooth specification object, see
#'  \code{\link[mgcv]{smooth.construct}}
#' @param data  see \code{\link[mgcv]{smooth.construct}}
#' @return design matrix for PC-based functional random effects
#' @author Alexander Volkmann, adapted from 'Predict.matrix.pcre.random.effect
#'  by F. Scheipl (adapted from 'Predict.matrix.random.effect' by S.N. Wood).
#' @export
#' @examples
#' data(pbc_subset)
#' mfpca <- preproc_MFPCA(pbc_subset, uni_mean = paste0(
#'   "logy ~ 1 + sex + drug + s(obstime, k = 5, bs = 'ps') + ",
#'   "s(age, k = 5, bs = 'ps')"),
#'   pve_uni = 0.99, nbasis = 5, weights = TRUE, save_uniFPCA = TRUE)
#' pbc_subset <- attach_wfpc(mfpca, pbc_subset, n = 2)
#' mfpca_list <- list(
#'   list(functions = funData::extractObs(mfpca$functions, 1),
#'        values = mfpca$values[1]),
#'   list(functions = funData::extractObs(mfpca$functions, 2),
#'        values = mfpca$values[2]))
#' sm <- smoothCon(s(id, fpc.1, bs = "unc_pcre",
#'       xt = list("mfpc" = mfpca_list[[1]], scale = "FALSE")), pbc_subset)[[1]]
#' sm$timevar <- "obstime"
#' sm$term <- c(sm$term, "obstime")
#' pm <- PredictMat(sm, pbc_subset, n = 4*nrow(pbc_subset))
Predict.matrix.unc_pcre.random.effect <- function(object, data){

  if(is.null(object$xt$mfpc))
    stop("need mfpa object!")

  # If basis should be evaluated for different marker timepoints, then
  # which_marker is not NULL
  which_marker <- attr(object, "which_marker")
  eval_w <- if(is.null(object$xt$eval_weight)) FALSE else object$xt$eval_weight
  X <- eval_mfpc(mfpca = object$xt$mfpc, timepoints = data[[object$timevar]],
                 marker = which_marker, eval_weight = eval_w)

  if(ncol(X) != (length(object$term) - 2))
    stop("check M argument in MFPCA()!")
  if(any(is.na(X)))
    stop("Problems in FPC. Maybe survtime > max(obstime)?")
  X <- data.frame(data[[object$term[1]]], X)
  colnames(X) <- object$term[-length(object$term)]

  object$term <- object$term[-length(object$term)]

  X_id <- model.matrix(as.formula(paste("~ 0 +", object$term[1])), X)
  X_ef <- model.matrix(as.formula(
    paste("~ 0 +", paste(object$term[-1], collapse="+"))), X)
  mgcv::tensor.prod.model.matrix(list(X_id, X_ef))
}
