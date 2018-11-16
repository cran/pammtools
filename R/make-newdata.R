#' Extract information of the sample contained in a data set
#'
#' Given a data set and grouping variables, this function returns mean values
#' for numeric variables and modus for characters and factors. Usually
#' this function should not be called directly but will rather be called
#' as part of a call to \code{make_newdata}.
#'
#' @rdname sample_info
#' @param x A data frame (or object that inherits from \code{data.frame}).
#' @importFrom stats median
#' @return A data frame containing sample information (for each group).
#' If applied to an object of class \code{ped}, the sample means of the
#' original data is returned.
#' Note: When applied to a \code{ped} object, that doesn't contain covariates
#' (only interval information), returns data frame with 0 columns.
#'
#' @export
#' @keywords internal
sample_info <- function(x) {
  UseMethod("sample_info", x)
}

#' @inheritParams sample_info
#' @import checkmate dplyr
#' @importFrom purrr compose
#' @export
#' @rdname sample_info
sample_info.data.frame <- function(x) {

  cn  <- colnames(x)
  num <- summarize_if (x, .predicate = is.numeric, ~mean(., na.rm = TRUE))
  fac <- summarize_if (x, .predicate = compose("!", is.numeric), modus)

  nnames <- intersect(names(num), names(fac))

  if (length(nnames) != 0) {
    suppressMessages(
      x <- left_join(num, fac) %>% grouped_df(vars = lapply(nnames, as.name))
    )
  } else {
    x <- bind_cols(num, fac)
  }

  return(select(x, one_of(cn)))

}

#' @rdname sample_info
#' @inheritParams sample_info
#' @import checkmate dplyr
#' @importFrom rlang sym
#' @export
sample_info.ped <- function(x) {
  # is.grouped_df
  # remove "noise" information on interval variables
  grps <- group_vars(x)
  iv <- attr(x, "intvars")
  id_var <- attr(x, "id_var")
  x <- x %>%
    group_by(!!sym(id_var)) %>%
    slice(1) %>%
    ungroup() %>%
    grouped_df(grps) %>%
    select(-one_of(iv))
  if (test_data_frame(x, min.rows = 1, min.cols = 1)) {
    sample_info.data.frame(x)
  } else {
    NULL
  }

}

#' @rdname sample_info
#' @inherit sample_info
#' @export
sample_info.fped <- function(x) {

  x %>% select_if (~!is.matrix(.x)) %>% sample_info.ped()

}


#' Combines multiple data frames
#'
#' Works like \code{\link[base]{expand.grid}} but for data frames.
#'
#' @importFrom dplyr slice bind_cols combine
#' @importFrom purrr map map_lgl map2 transpose cross
#' @importFrom checkmate test_data_frame
#' @param ... Data frames that should be combined to one data frame.
#' Elements of first df vary fastest, elements of last df vary slowest.
#' @examples
#' combine_df(
#'   data.frame(x=1:3, y=3:1),
#'   data.frame(x1=c("a", "b"), x2=c("c", "d")),
#'   data.frame(z=c(0, 1)))
#' @export
combine_df <- function(...) {

  dots <- list(...)
  if (!all(sapply(dots, test_data_frame))) {
    stop("All elements in ... must inherit from data.frame!")
  }
  ind_seq   <- map(dots, ~ seq_len(nrow(.x)))
  not_empty <- map_lgl(ind_seq, ~ length(.x) > 0)
  ind_list  <- ind_seq[not_empty] %>% cross() %>% transpose() %>% map(combine)

  map2(dots[not_empty], ind_list, function(.x, .y) slice(.x, .y)) %>%
    bind_cols()

}


#' Construct a data frame suitable for prediction
#'
#' Given a data set, returns a data set that can be used
#' as \code{newdata} argument in a call to \code{predict} and similar functions.
#' The function is particularly useful in combination with one of the
#' \code{add_*} functions, e.g., \code{\link{add_term}}, \code{\link{add_hazard}},
#' etc.
#'
#' @rdname newdata
#' @aliases make_newdata
#' @inheritParams sample_info
#' @param ... Covariate specifications (expressions) that will be evaluated
#' by looking for variables in \code{x} (or \code{data}). Must be of the form \code{z = f(z)}
#' where \code{z} is a variable in the data set \code{x} and \code{f} a known
#' function that can be usefully applied to \code{z}. See examples below.
#' @import dplyr
#' @importFrom checkmate assert_data_frame assert_character
#' @importFrom purrr map cross_df
#' @details Depending on the class of \code{x}, mean or modus values will be
#' used for variables not specified in ellipsis. If x is an object that inherits
#' from class \code{ped}, useful data set completion will be attempted depending
#' on variables specified in ellipsis.
#' @examples
#' tumor %>% make_newdata()
#' tumor %>% make_newdata(age=c(50))
#' tumor %>% make_newdata(days=seq_range(days, 3), age=c(50, 55))
#' tumor %>% make_newdata(days=seq_range(days, 3), status=unique(status), age=c(50, 55))
#' # mean/modus values of unspecified variables are calculated over whole data
#' tumor %>% make_newdata(sex=unique(sex))
#' tumor %>% group_by(sex) %>% make_newdata()
#' # You can also pass a part of the data sets as data frame to make_newdata
#' purrr::cross_df(list(days = c(0, 500, 1000), sex = c("male", "female"))) %>%
#'   make_newdata(x=tumor)
#'
#' # Examples for PED data
#' ped <- tumor %>% slice(1:3) %>% as_ped(Surv(days, status)~., cut = c(0, 500, 1000))
#' ped %>% make_newdata(age=c(50, 55))
#' # if time information is specified, other time variables will be specified
#' # accordingly and offset calculated correctly
#' ped %>% make_newdata(tend = c(1000), age = c(50, 55))
#' ped %>% make_newdata(tend = unique(tend))
#' ped %>% group_by(sex) %>% make_newdata(tend = unique(tend))
#' @export
make_newdata <- function(x, ...) {
  UseMethod("make_newdata", x)
}


#' @inherit make_newdata
#' @rdname newdata
#' @export
make_newdata.default <- function(x, ...) {

  assert_data_frame(x, all.missing = FALSE, min.rows = 2, min.cols = 1)

  orig_names <- names(x)

  expressions    <- quos(...)
  expr_evaluated <- map(expressions, lazyeval::f_eval, data = x)

  # construct data parts depending on input type
  lgl_atomic <- map_lgl(expr_evaluated, is_atomic)
  part1  <- expr_evaluated[lgl_atomic] %>% cross_df()
  part2 <- do.call(combine_df, expr_evaluated[!lgl_atomic])

  ndf    <- combine_df(part1, part2)
  rest   <- x %>% select(-one_of(c(colnames(ndf))))
  if (ncol(rest) > 0) {
    si     <- sample_info(rest) %>% ungroup()
    ndf <- combine_df(si, ndf)

  }

  ndf %>% select(one_of(orig_names))

}

#' @rdname newdata
#' @inherit make_newdata.default
#' @export
make_newdata.ped <- function(x, ...) {

  assert_data_frame(x, all.missing = FALSE, min.rows = 2, min.cols = 1)

  # prediction time points have to be interval end points so that piece-wise
  # constancy of predicted hazards is respected. If user overrides this, warn.

  orig_vars <- names(x)
  int_df <- int_info(x)

  expressions <- quos(...)
  dot_names   <- names(expressions)
  int_names   <- names(int_df)
  x <- select(x, -one_of(setdiff(int_names, c(dot_names, "intlen", "intmid"))))

  ndf <- make_newdata(unped(x), ...)

  if (any(names(int_df) %in% names(ndf))) {
    suppressMessages(
      ndf <- right_join(int_df, ndf)
      )
  } else {
    ndf <- combine_df(int_df[1, ], ndf)
  }

  int_names <- intersect(int_names, c("intlen", orig_vars))
  ndf %>% select(one_of(c(int_names, setdiff(orig_vars, int_names)))) %>%
    mutate(
      intlen = .data$tend - .data$tstart,
      offset = log(.data$tend - .data$tstart),
      ped_status = 0)

}

#' @rdname newdata
#' @inherit make_newdata.ped
#' @importFrom rlang quos
#' @export
make_newdata.fped <- function(x, ...) {

  assert_data_frame(x, all.missing = FALSE, min.rows = 2, min.cols = 1)

  # prediction time points have to be interval end points so that piece-wise
  # constancy of predicted hazards is respected. If user overrides this, warn.
  expressions <- quos(...)
  dot_names   <- names(expressions)
  orig_vars   <- names(x)
  cumu_vars   <- setdiff(unlist(attr(x, "func_mat_names")), dot_names)
  cumu_smry   <- smry_cumu_vars(x, attr(x, "time_var")) %>%
    select(one_of(cumu_vars))

  int_names   <- attr(x, "intvars")
  ndf <- x %>%
    select(one_of(setdiff(names(x), cumu_vars))) %>%
    unfped() %>% make_newdata(...)

  out_df <- do.call(combine_df, compact(list(cumu_smry, ndf)))
  int_df <- int_info(attr(x, "breaks"))
  suppressMessages(
    out_df <- right_join(int_df, out_df) %>%
      select(-one_of(c("intmid"))) %>% as_tibble()
      )

  # adjust lag-lead indicator
  out_df <- adjust_ll(out_df, x)

  out_df

}


smry_cumu_vars <- function(data, time_var) {

  cumu_vars <- unlist(attr(data, "func_mat_names"))
  func_list <- attr(data, "func")
  z_vars    <- map(func_list, ~get_zvars(.x, time_var, length(func_list))) %>%
    unlist()
  smry_z <- select(data, one_of(z_vars)) %>%
    map(~ .x[1, ]) %>% map(~mean(unlist(.x))) %>% bind_cols()
  smry_time <- select(data, setdiff(cumu_vars, z_vars)) %>% map(~.x[1, 1])

  bind_cols(smry_z, smry_time)

}

get_zvars <- function(func, time_var, n_func) {

  col_vars <- func$col_vars
  all_vars <- make_mat_names(c(col_vars, "LL"), func$latency_var, func$tz_var,
    func$suffix, n_func)
  time_vars <- make_mat_names(c(time_var, func$tz_var, "LL"),
    func$latency_var, func$tz_var, func$suffix, n_func)

  setdiff(all_vars, time_vars)

}


## apply ll_fun to newly created data
adjust_ll <- function(out_df, data) {

  func_list <- attr(data, "func")
  n_func    <- length(func_list)
  LL_names <- grep("LL", unlist(attr(data, "func_mat_names")), value = TRUE)

  for (i in LL_names) {
    ind_ll <- map_lgl(names(attr(data, "ll_funs")), ~grepl(.x, i))
    if (any(ind_ll)) {
      ind_ll <- which(ind_ll)
    } else {
      ind_ll <- 1
    }

    func   <- func_list[[ind_ll]]
    ll_i   <- attr(data, "ll_funs")[[ind_ll]]
    tz_var <- attr(data, "tz_vars")[[ind_ll]]
    tz_var <- make_mat_names(tz_var, func$latency_var, func$tz_var, func$suffix,
      n_func)
    if (func$latency_var == "") {
      out_df[[i]] <- ll_i(out_df[["tend"]], out_df[[tz_var]]) * 1L
    } else {
      out_df[[i]] <- ll_i(out_df[["tend"]], out_df[["tend"]] -
        out_df[[tz_var]]) * 1L
    }
  }

  out_df

}

# All variables that represent follow-up time should have the same values
# adjust_time_vars <- function(out_df, data, dot_names) {

#   time_vars <- c("tend",
#     grep(attr(data, "time_var"), unlist(attr(data, "func_mat_names")), value=TRUE))
#   time_vars_dots <- c(grep("tend", dot_names, value=TRUE),
#     grep(attr(data, "time_var"), dot_names, value=TRUE))
#   if (length(time_vars_dots) == 0) {
#     time_vars_dots <- "tend"
#   } else {
#     if (length(time_vars_dots) > 1) {
#       warning(paste0("Only one of ", paste0(time_vars_dots, collapse=", "),
#         "must be specified. Only the first one will be used!"))
#       time_vars_dots <- time_vars_dots[1]
#     }
#   }
#   for (i in setdiff(time_vars, time_vars_dots)) {
#     out_df[[i]] <- out_df[[time_vars_dots]]
#   }

#   out_df

# }