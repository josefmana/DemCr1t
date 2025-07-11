#' Compute and visualise measures of concordance between diagnostic criteria
#'
#' Computes pairwise concordance statistics between different operationalisations
#' of probable Parkinson’s disease dementia (PDD). Metrics include Cohen's Kappa,
#' Sensitivity, Positive Predictive Value (PPV), Specificity, Negative Predictive
#' Value (NPV), and Accuracy. Visual summaries are also generated.
#'
#' @param d0 A list containing PDD diagnostic results, as produced by
#' \code{diagnose_pdd_sample}.
#'
#' @returns A list with two components:
#' \describe{
#'   \item{\code{stats}}{A data frame summarising pairwise concordance statistics
#'   (e.g., Kappa, Accuracy, Sensitivity, Specificity, PPV, NPV).}
#'   \item{\code{plots}}{A list of ggplot2-based visualisations, including matrices
#'   of Cohen's Kappa, Accuracy (with significance tests against the No Information Rate),
#'   Sensitivity, and Specificity.}
#' }
#'
#' @examples
#' \dontrun{
#' p <- data_paths("data-raw")
#' data <- prepare_data(p)
#' pdd <- diagnose_pdd_sample(data)
#' concmats <- describe_concordance(pdd)
#' }
#' @export
describe_concordance <- function(d0, vars) {
  # Get pairs of operationalisations:
  p <- crossing(predictor = d0$criteria$type, reference = d0$criteria$type)
  # Calculate Kappas:
  k <- lapply(
    seq_len(nrow(p)),
    function(i) {
      if(p[i, 1] == p[i, 2]) {
        list(kappa = 1)
      } else {
        d0$PDD |>
          filter(type %in% p[i, ]) |>
          pivot_wider(names_from = type, values_from = PDD, id_cols = id) |>
          select(-id) |>
          as.matrix() |>
          cohen.kappa()
      }
    }
  )
  # Calculate confusion matrixes:
  confmats <- lapply(
    seq_len(nrow(p)),
    function(i) {
      if(p[i, 1] == p[i, 2]) {
        NULL
      } else {
        d0$PDD |>
          filter(type %in% p[i, ]) |>
          pivot_wider(names_from = type, values_from = PDD, id_cols = id) |>
          select(all_of(unlist(p[i, ], use.names = FALSE))) |>
          mutate_all(~2-as.numeric(.x)) |> # re-scoring such that prevalence is calculated for PDD == 1
          table() |>
          confusionMatrix()
      }
    }
  )
  metrics <- names(confmats[[2]]$byClass)
  # Prepare a table with all statistics:
  # (check https://changjunlee.com/blogs/posts/4_confusion_mat_and_roc#interpreting-the-confusion-matrix
  # for a guide to interpretation)
  tab <-
    p |>
    mutate(
      # Estimate [95% CI] for Kappa & Accuracy:
      Kappa = sapply(
        seq_len(length(reference)),
        function(i) ifelse(
          test = reference[i] == predictor[i],
          yes  = "-",
          no   = do_summary(k[[i]]$confid[1, ], 2, "estCI")
        )
      ),
      Accuracy = sapply(
        seq_len(length(reference)),
        function(i) ifelse(
          test = reference[i] == predictor[i],
          yes = "1.00",
          no = do_summary(confmats[[i]]$overall[c("Accuracy", "AccuracyUpper", "AccuracyLower")], 2, "estCI")
        )
      ),
      # Raw values for Kappa & Accuracy (and NIR):
      Kappa_raw = sapply(
        seq_len(length(reference)),
        function(i) ifelse(
          test = reference[i] == predictor[i],
          yes = NA,
          no = k[[i]]$kappa
        )
      ),
      McnemarPValue = sapply(
        seq_len(length(reference)),
        function(i) ifelse(
          test = reference[i] == predictor[i],
          yes = NA,
          no = confmats[[i]]$overall["McnemarPValue"]
        )
      ),
      Accuracy_raw = sapply(
        seq_len(length(reference)),
        function(i) ifelse(
          test = reference[i] == predictor[i],
          yes = 1,
          no = confmats[[i]]$overall["Accuracy"]
        )
      ),
      NoInformationRate_raw = sapply(
        seq_len(length(reference)),
        function(i) ifelse(
          test = reference[i] == predictor[i],
          yes = NA,
          no = confmats[[i]]$overall["AccuracyNull"]
        )
      ),
      AccuracyPValue = sapply(
        seq_len(length(reference)),
        function(i) ifelse(
          test = reference[i] == predictor[i],
          yes = NA,
          no = confmats[[i]]$overall["AccuracyPValue"]
        )
      ),
      # All the other metrics:
      !!!set_names(rep(NA, length(metrics)), metrics),
      across(
        .cols = all_of(metrics),
        .fns = ~sapply(
          seq_len(length(.x)),
          function(i) ifelse(
            test = reference[i] == predictor[i],
            yes = NA,
            no = confmats[[i]]$byClass[cur_column()]
          )
        )
      ),
      NULL
    )
  # Get order of the criteria by prevalence:
  ord <-
    data.frame(
      predictor = tab |>
        arrange(desc(Prevalence)) |>
        select(reference) |>
        pull() |>
        unique()
    ) |>
    mutate(
      reference = rev(predictor),
      # Colours to separate operationalisations based on IADL criterion
      xcol = sapply(
        seq_len(length(predictor)),
        function(i) ifelse(
          test = subset(d0$criteria, type == predictor[i])$iadl == "faq",
          yes = "blue2",
          no = "black"
        )
      ),
      ycol = rev(xcol)
    )
  # Add order to the table:
  ordtab <-
    tab |>
    mutate(
      across(
        .cols = all_of(c("predictor", "reference")),
        .fns = ~factor(
          .x,
          levels = ord[ , cur_column()],
          ordered = TRUE
        )
      ),
      across(
        .cols = all_of(c("Kappa_raw")),
        .fns  = ~case_when(
          as.numeric(predictor) < (nrow(ord) + 1 - as.numeric(reference)) ~ .x,
          predictor == reference ~ 1,
          .default = NA
        )
      ),
      Accuracy_raw = if_else(predictor == reference, NA, Accuracy_raw),
      Accuracy_sig = if_else(AccuracyPValue < .05, "*", "")
    )
  # Kappa matrix:
  kappaplt <-
    ordtab |>
    ggplot() +
    aes(x = predictor, y = reference, fill = Kappa_raw) +
    geom_tile() +
    scale_fill_gradient2(high = "steelblue", na.value = "white") +
    labs(x = "Predictor", y = "Reference") +
    theme(
      axis.text.x = element_text(colour = if_else(ord$xcol == "black", "black", "red3"), angle = 66, hjust = 1),
      axis.text.y = element_text(colour = if_else(ord$ycol == "black", "black", "red3"))
    )
  # Accuracy matrix:
  E_NIR <-
    tab$NoInformationRate_raw |>
    unique() |>
    mean(na.rm = TRUE) # Expected Negative Information Rate
  accplt <-
    ordtab |>
    select(-Accuracy) |>
    rename("Accuracy" = "Accuracy_raw") |>
    ggplot() +
    aes(x = predictor, y = reference, fill = Accuracy) +
    geom_tile() +
    geom_text(aes(label = Accuracy_sig)) +
    scale_fill_gradient2(low = "red4", high = "yellow4", midpoint = E_NIR, na.value = "white") +
    labs(x = "Predictor", y = "Reference") +
    theme(
      axis.text.x = element_text(colour = ord$xcol, angle = 66, hjust = 1),
      axis.text.y = element_text(colour = ord$ycol)
    )
  # Sensitivity matrix:
  sensplt <-
    ordtab |>
    ggplot() +
    aes(x = predictor, y = reference, fill = Sensitivity) +
    geom_tile() +
    scale_fill_gradient2(high = "green4", na.value = "white", midpoint = .5) +
    labs(x = "Predictor", y = "Reference") +
    theme(
      axis.text.x = element_text(colour = ord$xcol, angle = 66, hjust = 1),
      axis.text.y = element_text(colour = ord$ycol)
  ) +
  NULL
  # Specificity matrix:
  specplt <-
    ordtab |>
    ggplot() +
    aes(x = predictor, y = reference, fill = Specificity) +
    geom_tile() +
    scale_fill_gradient2(high = "orange3", na.value = "white", midpoint = .5) +
    labs(x = "Predictor", y = "Reference") +
    theme(
      axis.text.x = element_text(colour = ord$xcol, angle = 66, hjust = 1),
      axis.text.y = element_text(colour = ord$ycol)
    ) +
    NULL
  # Return it all:
  list(
    table = tab,
    plots = list(
      Kappa = kappaplt,
      Accuracy = accplt,
      Sensitivity = sensplt,
      Specificity = specplt
    )
  )
}
