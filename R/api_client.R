# Explicit integration boundaries: only GET MFT is optionally active.
# No automatic DCOF POST, Process DT write, Batch DT Creator invocation or DPP write.

mft_is_configured <- function() {
  nzchar(Sys.getenv("BIOSPACE_MFT_BASE_URL", unset = ""))
}

get_mft_batch <- function(batch_id) {
  batch_id <- require_text(batch_id, "batchId")
  base_url <- Sys.getenv("BIOSPACE_MFT_BASE_URL", unset = "")
  if (!nzchar(base_url)) {
    stop("BIOSPACE_MFT_BASE_URL is not configured. MFT import is disabled.")
  }
  if (!requireNamespace("httr2", quietly = TRUE)) stop("Install package 'httr2'.")
  target <- paste0(sub("/+$", "", base_url), "/batch/", utils::URLencode(batch_id, reserved = TRUE))
  req <- httr2::request(target)
  req <- httr2::req_timeout(req, seconds = 12)
  result <- httr2::req_perform(req)
  httr2::resp_body_json(result, simplifyVector = FALSE)
}

merge_materials_from_mft <- function(record, mft_data) {
  if (is.null(mft_data$materials) || !is.list(mft_data$materials)) {
    stop("MFT response does not contain a materials array.")
  }
  seen <- vapply(record$raw_materials %||% list(), function(x) x$external_id %||% "", character(1))
  count <- 0L
  for (material in mft_data$materials) {
    external <- material$id %||% ""
    if (nzchar(external) && external %in% seen) next
    item <- list(
      material_name = material$name %||% "",
      material_type = material$type %||% "",
      material_batch = material$batchNo %||% "",
      amount = material$amountCurrent %||% NA_real_,
      unit = material$unit %||% "",
      notes = paste("MFT amountOriginal:", material$amountOriginal %||% "N/A",
                    "| Arrival:", material$arrival %||% "N/A"),
      external_id = external,
      source = "MFT"
    )
    record <- add_to_category(record, "raw_materials", item)
    count <- count + 1L
    if (nzchar(external)) seen <- c(seen, external)
  }
  list(record = record, count = count)
}
