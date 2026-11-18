# Development-only local storage. NOT a bi0SpaCE repository or Process DT.
local_data_dir <- function() {
  # Default: always inside THIS project, even if RStudio uses a
  # different current working directory. Existing JSON files persist.
  configured <- Sys.getenv("DIGITAL_TAGGING_DATA_DIR", unset = "")
  if (nzchar(configured)) {
    path <- configured
    # Relative user overrides also resolve relative to this project.
    is_absolute <- startsWith(path, "/") || startsWith(path, "~") ||
      grepl("^[A-Za-z]:", path) || startsWith(path, "\\\\")
    if (!is_absolute && exists("dt_project_path", mode = "function")) {
      path <- dt_project_path(path)
    }
  } else if (exists("dt_project_path", mode = "function")) {
    path <- dt_project_path("data", "local")
  } else {
    path <- "data/local"
  }
  path <- path.expand(path)
  dir.create(path, showWarnings = FALSE, recursive = TRUE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

batch_file <- function(pilot_id, batch_id) {
  file.path(local_data_dir(), paste0(safe_key(pilot_id), "__", safe_key(batch_id), ".json"))
}

new_batch_record <- function(pilot, batch_id) {
  batch_id <- require_text(batch_id, "batchId")
  list(
    schema_version = "prototype-0.1.0",
    metadata = list(
      pilot_id = pilot$id,
      pilot_name = pilot$name,
      batch_id = batch_id,
      process_id = pilot$process_id,
      status = "draft",
      created_at = utc_time(),
      updated_at = utc_time(),
      batch_start = NULL,
      batch_end = NULL,
      output_amount = NULL,
      output_unit = NULL
    ),
    raw_materials = list(),
    production_process = list(),
    quality_control = list(),
    logistics = list(),
    sustainability = list()
  )
}

local_load_batch_record <- function(pilot, batch_id) {
  path <- batch_file(pilot$id, batch_id)
  if (!file.exists(path)) return(NULL)
  record <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (!identical(record$metadata$pilot_id, pilot$id) ||
      !identical(record$metadata$batch_id, batch_id)) {
    stop("Saved record does not match selected pilot and batch.")
  }
  record
}

local_save_batch_record <- function(record) {
  path <- batch_file(record$metadata$pilot_id, record$metadata$batch_id)
  record$metadata$updated_at <- utc_time()
  # Write a complete JSON file first, then replace the old file.
  tmp <- tempfile(tmpdir = dirname(path), fileext = ".json")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  jsonlite::write_json(record, path = tmp, pretty = TRUE, auto_unbox = TRUE, null = "null")
  if (file.exists(path)) unlink(path)
  if (!file.rename(tmp, path)) stop("Failed to save: ", path)
  record
}

# Read original batch IDs from saved metadata (not sanitized file names).
list_local_batches <- function(pilot_id) {
  paths <- list.files(local_data_dir(), pattern = "\\.json$", full.names = TRUE)
  if (!length(paths)) return(character())
  result <- character()
  for (path in paths) {
    entry <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
                      error = function(e) NULL)
    if (!is.null(entry) && identical(entry$metadata$pilot_id, pilot_id)) {
      result <- c(result, entry$metadata$batch_id)
    }
  }
  sort(unique(result))
}

add_to_category <- function(record, category, item) {
  permitted <- c("raw_materials", "production_process", "quality_control", "logistics", "sustainability")
  if (!(category %in% permitted)) stop("Unknown category: ", category)
  item$record_id <- new_record_id()
  item$created_at <- utc_time()
  records <- record[[category]] %||% list()
  records[[length(records) + 1L]] <- item
  record[[category]] <- records
  record
}


# ============================================================
# ADDITIONAL CRUD HELPERS (v0.5)
# Existing JSON files remain compatible. Updating a record
# preserves its UUID, creation time and external metadata.
# ============================================================
record_categories <- function() {
  c("raw_materials", "production_process", "quality_control",
    "logistics", "sustainability")
}

find_category_record <- function(record, category, record_id) {
  if (!(category %in% record_categories())) stop("Unknown category.")
  if (!is_text(record_id)) stop("Select a record first.")
  entries <- record[[category]] %||% list()
  hits <- which(vapply(entries, function(x) identical(x$record_id %||% "", record_id),
                       logical(1)))
  if (length(hits) != 1L) stop("Record is no longer available for this batch.")
  entries[[hits]]
}

update_category_record <- function(record, category, record_id, new_values) {
  old <- find_category_record(record, category, record_id)
  # Imported MFT materials have another authoritative source.
  if (identical(old$source %||% "", "MFT")) {
    stop("This record comes from MFT. Modify it at the source, not in Digital Tagging.")
  }
  entries <- record[[category]] %||% list()
  idx <- which(vapply(entries, function(x) identical(x$record_id %||% "", record_id),
                      logical(1)))
  if (!is.list(new_values) || !length(new_values)) stop("No values to update.")
  # Preserve unknown legacy fields, source attribution and identity.
  for (field in names(new_values)) {
    if (!(field %in% c("record_id", "created_at", "updated_at", "external_id", "source"))) {
      old[field] <- new_values[field]
    }
  }
  old$updated_at <- utc_time()
  entries[[idx]] <- old
  record[[category]] <- entries
  record
}

# Prevent accidental editing of items synchronized from MFT.
remove_from_category <- function(record, category, record_id) {
  old <- find_category_record(record, category, record_id)
  if (identical(old$source %||% "", "MFT")) {
    stop("This record comes from MFT. Modify it at the source, not in Digital Tagging.")
  }
  record[[category]] <- Filter(
    function(x) !identical(x$record_id %||% "", record_id),
    record[[category]] %||% list()
  )
  record
}

# A human-readable label for the select record control.
record_display_label <- function(item, category, index) {
  values <- switch(category,
    raw_materials = c(item$material_name %||% "", item$material_batch %||% ""),
    production_process = c(item$step_name %||% "", item$parameter_name %||% ""),
    quality_control = c(item$check_name %||% "", item$result %||% ""),
    logistics = c(item$event %||% "", item$destination %||% ""),
    sustainability = c(item$indicator %||% "", as.character(item$value %||% "")),
    character(0)
  )
  values <- values[nzchar(trimws(values))]
  preview <- if (length(values)) paste(values, collapse = " / ") else "Record"
  paste0(index, ". ", substr(preview, 1L, 75L))
}

# Required local batch context. Preserves every category and legacy field.
set_batch_context <- function(record, start, end) {
  require_text(record$metadata$batch_id, "Batch ID")
  require_iso_time(start, "Batch start")
  require_iso_time(end, "Batch end")
  if (as.POSIXct(end, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC") <=
      as.POSIXct(start, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
    stop("Batch end must be later than batch start.", call. = FALSE)
  }
  record$metadata$batch_start <- start
  record$metadata$batch_end <- end
  record
}

# Public storage boundary. UI never depends on a file path or remote endpoint.
read_batch_record <- function(pilot, batch_id) {
  batch_id <- require_text(batch_id, "Batch ID")
  adapter <- batch_repository()
  record <- adapter$read(pilot, batch_id)
  if (is.null(record)) return(NULL)
  validate_repository_record(record, pilot$id, batch_id)
  record
}

# Only the data-entry flow may create an unsaved draft for an unknown batch.
load_batch_record <- function(pilot, batch_id) {
  record <- read_batch_record(pilot, batch_id)
  if (is.null(record)) new_batch_record(pilot, batch_id) else record
}

save_batch_record <- function(record) {
  validate_repository_record(record, record$metadata$pilot_id, record$metadata$batch_id)
  record$metadata$updated_at <- utc_time()
  saved <- batch_repository()$write(record)
  validate_repository_record(saved, record$metadata$pilot_id, record$metadata$batch_id)
  saved
}

# Loaded by global.R after this file; standalone tests must source data_access.R too.

# Explicit export to the running R project's exports directory.
# A unique filename retains previous exports and avoids sanitized-ID collisions.
export_batch_to_project <- function(record) {
  validate_repository_record(record, record$metadata$pilot_id, record$metadata$batch_id)
  directory <- dt_project_path("exports")
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(directory)) stop("Cannot create project exports folder.")
  prefix <- paste0("DigitalTagging_", safe_key(record$metadata$pilot_id), "_",
                   safe_key(record$metadata$batch_id), "_",
                   format(Sys.time(), "%Y%m%d_%H%M%S", tz = "UTC"), "_")
  path <- tempfile(pattern = prefix, tmpdir = directory, fileext = ".json")
  tryCatch(jsonlite::write_json(record, path, pretty = TRUE, auto_unbox = TRUE,
                               null = "null"), error = function(e) {
    if (file.exists(path)) unlink(path)
    stop("JSON export failed: ", conditionMessage(e))
  })
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
