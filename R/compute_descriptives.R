#' Compute descriptive statistics for selected sample variables
#'
#' Computes descriptive summaries for a specified set of variables in a dataset.
#' The output includes a raw summary tibble and an APA-style formatted gt table.
#'
#' @param d0 A tibble containing the data, as generated by \code{prepare_data}.
#' @param vois A data frame, tibble, or matrix with the following columns:
#'   (1) variable name,
#'   (2) variable label,
#'   (3) variable type (one of "continuous", "binary", "nominal"),
#'   (4) optional: variable group,
#'   (5) optional: label-to-description mapping for table notes,
#'   (6) optional: score type description to append in parentheses.
#'   Alternatively, a path to a CSV file (semicolon-delimited) containing this information.
#'
#' @returns A list containing:
#'   \describe{
#'     \item{\code{table}}{A tibble with raw descriptive statistics.}
#'     \item{\code{gtable}}{An APA-style formatted gt table summarizing selected variables.}
#'   }
#'
#' @examples
#' \dontrun{
#' p <- data_paths("data-raw")
#' data <- prepare_data(p)
#' demo <- compute_descriptives(data, here::here("data-raw", "VariablesOfInterest.csv"))
#' }
#'
#' @export
compute_descriptives <- function(d0, vois) {
  # Get variables of interest:
  if (is.character(vois)) {
    v <- readr::read_delim(vois, delim = ";", col_types = cols())
  } else {
    v <- vois
  }
  # Prepare a demography table:
  demtab <-
    sapply(
      seq_len(nrow(v)),
      function(i) c(
        variable = pull(v[i, 2]),
        group    = pull(v[i, 4]),
        N  = case_when(
          pull(v[i, 3]) == "binary" ~ do_summary(d0[ , pull(v[i, 1])], 0, "Nperc"),
          pull(v[i, 3]) == "nominal" ~ do_summary(d0[ , pull(v[i, 1])], 0, "Nslash"),
          pull(v[i, 3]) == "continuous" ~ do_summary(d0[ , pull(v[i, 1])], 0, "N")
        ),
        sapply(
          c("Md","minmax","M","SD"),
          function(f) ifelse(
            test = pull(v[i, 3]) == "continuous",
            yes = ifelse(
              test = pull(v[i, 4]) %in% c("Attention and Working Memory", "Executive Function", "Language", "Memory", "Visuospatial Function"),
              yes = do_summary(pull(d0[ , pull(v[i, 1])]), 2, f),
              no = do_summary(pull(d0[ , pull(v[i, 1])]), ifelse(f %in% c("M","SD"), 2, 0), f)
            ),
            no   = "-"
          )
        )
      )
    ) |>
    t() |>
    as_tibble()
  # Prepare a gt table:
  gtab <-
    demtab |>
    filter(!(group %in% c("Demographics", "Clinical"))) |>
    mutate(
      variable = sapply(
        seq_len(length(variable)),
        function(i)
          paste0(
            variable[i],
            ifelse(
              is.na(v[v[ , 2] == variable[i] & v[ , 4] == group[i], 6]),
              "",
              paste0(" (", v[v[ , 2] == variable[i] & v[ , 4] == group[i], 6], ")")
            )
          )
      )
    ) |>
    gt_apa_table(grp = "group") |>
    cols_label(variable ~ "", minmax ~ "Min-max")
  # If there are notes, add them to the table:
  if (ncol(v) > 4 && any(!is.na(v$note))) {
    notes <- v[complete.cases(v[ , 5]), c(2,5)]
    text  <- paste0(pull(notes[ , 1]), ": ", pull(notes[ , 2])) |> paste(collapse = ", ")
    # Add the text:
    gtab <-
      gtab |>
      tab_source_note(html(paste0("<i>Note.</i> ", text)))
  }
  # Return results:
  list(table = demtab, gtable = gtab)
}
