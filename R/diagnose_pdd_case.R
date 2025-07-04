#' Diagnose PDD in a single patient sample using specified criteria
#'
#' Applies a specified set of diagnostic criteria to a data matrix representing
#' patient-level data to determine whether each patient meets the criteria for
#' probable Parkinson’s disease dementia (PDD).
#' This function is intended to be used internally by the wrapper function
#' \code{diagnose_pdd_sample}.
#'
#' @param x A data frame or matrix containing patient-level variables used for diagnosis.
#' @param c A named vector (or single-row data frame) specifying the criteria
#' to be applied for PDD diagnosis.
#'
#' @returns A logical vector indicating PDD diagnosis for each patient
#' (TRUE = diagnosed, FALSE = not diagnosed).
#'
#' @examples
#' \dontrun{
#' p <- data_paths("data-raw")
#' data <- prepare_data(p)
#' crit <- specify_criteria()
#' pdd  <- diagnose_pdd_case(data, crit[1, ])
#' }
#'
#' @export
diagnose_pdd_case <- function(x, c) {
  c[ , c(is.na(c))] <- "drsii" # DRS-2 as a dummy variable.
  x |>
    mutate(
      impaired_orig_att = if_else(x[[c$atte]] < c$atte_t, TRUE, FALSE),
      impaired_orig_exe = if_else(x[[c$exec]] < c$exec_t, TRUE, FALSE),
      impaired_orig_con = if_else(x[[c$cons]] < c$cons_t, TRUE, FALSE),
      impaired_orig_mem = if_else(x[[c$memo]] < c$memo_t, TRUE, FALSE),
      impaired_new_lan  = if_else(x[[c$lang]] < c$lang_t, TRUE, FALSE),
      # PDD criteria proper:
      crit1 = TRUE, # 1. Parkinson’s disease
      crit2 = TRUE, # 2. Parkinson’s disease developed before dementia
      crit3 = if_else(x[[c$glob]] < c$glob_t, TRUE, FALSE), # 3. Global deficit
      crit4 = if_else(x[[c$iadl]] > c$iadl_t, TRUE, FALSE), # 4. Dementia has Impact on ADLs
      crit5 = case_when( # 5. Impaired cognition (for Yes, at least of 2 tests abnormal)
        c$group == "mmse" ~if_else(rowSums(across(starts_with("impaired_orig"))) > 1, TRUE, FALSE),
        c$group == "moca" ~if_else(rowSums(across(starts_with("impaired"))) > 1, TRUE, FALSE),
        c$group %in% c("smoca","lvlII") ~ crit3
      ),
      crit6 = TRUE, # 6. Absence of Major Depression
      crit7 = TRUE, # 7. Absence of Major Depression
      crit8 = TRUE, # 8. Absence of other abnormalities that obscure diagnosis
      PDD   = if_else(rowSums(across(starts_with("crit"))) == 8, TRUE, FALSE)
    ) |>
    select(id, PDD, starts_with("impaired"), starts_with("crit"))
}
