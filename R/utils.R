# General-purpose helpers. No external packages are loaded here.
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

is_text <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))
}

require_text <- function(x, field) {
  if (!is_text(x)) stop(paste0(field, " must be a non-empty text value."), call. = FALSE)
  trimws(x)
}

safe_key <- function(x) {
  x <- require_text(x, "Identifier")
  # Keys used in local paths must not contain separators, dots for traversal or slashes.
  result <- gsub("[^A-Za-z0-9_-]", "_", x)
  if (!nzchar(result) || result %in% c(".", "..")) {
    stop("Identifier cannot be used as a file key.", call. = FALSE)
  }
  result
}

slug_id <- function(x) {
  tolower(safe_key(x))
}

utc_time <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

valid_iso_time <- function(x) {
  if (!is_text(x)) return(FALSE)
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", x)) return(FALSE)
  parsed <- suppressWarnings(as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  !is.na(parsed) && identical(format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), x)
}

require_iso_time <- function(x, field = "Timestamp") {
  if (!valid_iso_time(x)) {
    stop(paste0(field, " must use UTC format YYYY-MM-DDTHH:MM:SSZ."), call. = FALSE)
  }
  x
}

new_record_id <- function() {
  if (!requireNamespace("uuid", quietly = TRUE)) {
    stop("Install package 'uuid' first (run install_packages.R).", call. = FALSE)
  }
  uuid::UUIDgenerate()
}

records_table <- function(records, fields) {
  empty <- as.data.frame(setNames(replicate(length(fields), character(0), simplify = FALSE), fields),
                         stringsAsFactors = FALSE)
  if (!length(records)) return(empty)
  lines <- lapply(records, function(item) {
    vals <- lapply(fields, function(field) {
      v <- item[[field]]
      if (is.null(v) || length(v) == 0L) return("")
      if (is.list(v)) return("[structured]")
      as.character(v[[1]])
    })
    names(vals) <- fields
    as.data.frame(vals, stringsAsFactors = FALSE)
  })
  result <- do.call(rbind, lines)
  rownames(result) <- NULL
  result
}

is_finite_number <- function(x) {
  is.numeric(x) && length(x) == 1L && is.finite(x)
}

nonempty_or <- function(x, fallback = "") {
  if (is_text(x)) trimws(x) else fallback
}

# No timestamp is inferred from save time or batch boundaries.
optional_record_timestamp <- function(enabled, value) {
  if (!isTRUE(enabled)) return(NULL)
  require_iso_time(value, "Measurement / event time")
}

# Calendar + editable time inputs; return empty until both parts are valid.
combine_batch_time <- function(date, time) {
  if (is.null(date) || length(date) != 1L || is.na(date) || !is_text(time)) return("")
  time <- trimws(time)
  if (grepl("^[0-9]{2}:[0-9]{2}$", time)) time <- paste0(time, ":00")
  value <- paste0(as.character(date), "T", time, "Z")
  if (!valid_iso_time(value)) return("")
  value
}

split_batch_time <- function(value) {
  if (!is_text(value) || !valid_iso_time(value)) return(list(date = NA, time = ""))
  list(date = as.Date(substr(value, 1, 10)), time = substr(value, 12, 19))
}
