#' Import item-data
#'
#' Imports item-level data from a specified file path, checks for unrealistic values
#' (e.g., in MMSE scores), and prepares the data for further processing.
#' This function is intended to be called within the larger \code{prepare_data} workflow.
#'
#' @param paths A character string specifying the path to the data file. Typically generated
#' by the \code{data_paths} function.
#'
#' @returns A tibble containing item-level data.
#'
#' @examples
#' \dontrun{
#' p    <- data_paths("data-raw")
#' data <- import_item_data(p[1])
#' }
#'
#' @export
import_item_data <- function(path) {
  df <-
    read_delim(path, delim = ";", col_types = cols()) |>
    rename(
      id = IPN,
      birth = born_NA_RC,
      sex = gender_NA_RC,
      hand = hand_NA_RC,
      mmse = MMSE_tot,
      faq = FAQ_seb,
      bdi = `BDI-II`
    ) |>
    rename_all(tolower) |>
    mutate(
      cloc = clox_num + clox_hands,
      sex = factor(
        case_when(sex == "F" ~ 0, sex == "M" ~ 1),
        levels = 0:1,
        labels = c("female", "male"),
        ordered = F
      ),
      hand = factor(
        case_when(hand == "R" ~ 0, hand == "L" ~ 1),
        levels = 0:1,
        labels = c("right", "left"),
        ordered = F
      ),
      across(ends_with("name"), ~make_clean_names(.x, allow_dupes = TRUE)),
      across(all_of(c("assdate", "birth")), ~as.Date(.x, tryFormats = "%d.%m.%Y")),
      incl = 1 # As a baseline, include everyone
    )
  # Check MMSE variables:
  mistakes <- list(
    mmse = subset(df, mmse < 0 | mmse > 30),
    faq = subset(df, faq < 0 | faq > 30),
    faq_9 = subset(df, faq_9 < 0 | faq_9 > 3),
    mmse_7 = subset(df, mmse_7 < 0 | mmse_7 > 5),
    clox_num = subset(df, clox_num < 0 | clox_num > 1),
    clox_hands = subset(df, clox_hands < 0 | clox_hands > 1),
    mmse_pent = subset(df, mmse_pent < 0 | mmse_pent > 1),
    mmse_3words = subset(df, mmse_3words < 0 | mmse_3words > 3),
    vf_s = subset(df, vf_s < 0 )
  )
  stop <- FALSE
  for (i in names(mistakes)) {
    if (nrow(mistakes[[i]]) == 0) next
    else {
      stop <- TRUE
      cat("\nSee the problematic cases below:\n\n")
      print(mistakes[[i]][ , c("surname", "firstname", "id", "assdate", i)])
    }
  }
  if(stop) stop("There seem to be typos in the data, check the data printed above to locate and repair them.")
  # !Duplicated cases, rows selected manually:
  # IPN138: keep the first assessment because it is the "screening" in REDCap.
  # IPN347: keep the first assessment because the second one was just one year later & the first one is REDCap's "screening".
  # IPN661: keep the second assessment which was three years after the first one & is REDCap's "screening".
  df[with(df, id == "IPN138" & assdate == "2018-02-07"), "incl"] <- 0
  df[with(df, id == "IPN347" & assdate == "2021-01-25"), "incl"] <- 0
  df[with(df, id == "IPN661" & assdate == "2019-10-23"), "incl"] <- 0
  # IPN225's name from item-data is consistent with IPN335 in REDCap (i.e., metadata)
  # date of birth is inconsistent with IPN225 though so re-coding
  df[df$id == "IPN225", "id"] <- "IPN335"
  df
}
