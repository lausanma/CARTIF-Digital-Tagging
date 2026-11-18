# Internal export used only for validation and testing (NOT an official DPP/AAS export).
make_prototype_export <- function(record) {
  list(
    schema_version = "bi0space-digital-tagging-PROTOTYPE-0.1.0",
    warning = paste(
      "Local development export only. Not a Batch DT, Process DT or DPP.",
      "Data destinations and integration contracts require consortium validation."
    ),
    metadata = record$metadata,
    raw_materials = record$raw_materials,
    production_process = build_process_model(record),
    quality_control = record$quality_control,
    logistics = record$logistics,
    sustainability = record$sustainability
  )
}

write_prototype_export <- function(record, file) {
  jsonlite::write_json(make_prototype_export(record), path = file,
                       pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(file)
}

save_batch_finalisation_inputs <- function(record, start, end, amount, unit) {
  require_iso_time(start, "Batch start")
  require_iso_time(end, "Batch end")
  start_epoch <- as.POSIXct(start, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  end_epoch <- as.POSIXct(end, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (start_epoch >= end_epoch) stop("Batch end must be later than batch start.")
  if (!is_finite_number(amount) || amount < 0) stop("Output amount must be a non-negative number.")
  unit <- require_text(unit, "Output unit")
  record$metadata$batch_start <- start
  record$metadata$batch_end <- end
  record$metadata$output_amount <- amount
  record$metadata$output_unit <- unit
  # Local readiness flag only. This does NOT invoke CreateBatch / finalize the real batch.
  record$metadata$status <- "inputs_prepared_locally"
  record
}

# Only these four fields belong to the batch-details request body.
batch_details_payload <- function(record) {
  checked <- save_batch_finalisation_inputs(record, record$metadata$batch_start,
    record$metadata$batch_end, record$metadata$output_amount, record$metadata$output_unit)
  list(start = checked$metadata$batch_start, end = checked$metadata$batch_end,
       outputAmount = checked$metadata$output_amount, outputUnit = checked$metadata$output_unit)
}

# Integration hook: register function(pilot_id, batch_number, internal_id, payload).
# Its implementation resolves batch number to the actual MFT ID if needed and
# calls ONLY the confirmed endpoint. No endpoint/method is inferred from a diagram.
submit_batch_details <- function(record) {
  payload <- batch_details_payload(record)
  submit <- getOption("digital_tagging.submit_batch_details")
  if (is.function(submit)) {
    result <- submit(record$metadata$pilot_id,
      record$metadata$batch_number %||% record$metadata$batch_id,
      record$metadata$external_batch_id, payload)
    if (!is.list(result) || !isTRUE(result$confirmed))
      stop("Batch service did not confirm receipt.")
    return(list(status = "sent", payload = payload))
  }
  directory <- dt_project_path("exports", "batch_requests")
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  path <- tempfile(pattern = "batch_details_", tmpdir = directory, fileext = ".json")
  jsonlite::write_json(payload, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  list(status = "prepared", payload = payload)
}
