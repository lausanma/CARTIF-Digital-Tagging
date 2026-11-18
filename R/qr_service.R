# ============================================================
# QR API CLIENT (v0.5)
# IMPORTANT: QR generation is NOT implemented here.
# We only call the separately running Plumber QR API and
# display the PNG returned by POST /generate-tag.
# ============================================================
qr_api_base_url <- function() {
  url <- Sys.getenv("DIGITAL_TAGGING_QR_API_URL",
                    unset = "http://127.0.0.1:8000")
  url <- sub("/+$", "", trimws(url))
  if (!grepl("^https?://", url, ignore.case = TRUE)) {
    stop("DIGITAL_TAGGING_QR_API_URL must be an HTTP(S) address.")
  }
  url
}

request_batch_qr <- function(batch_id) {
  batch_id <- require_text(batch_id, "Batch ID")
  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop("Install package 'httr2' to connect to the QR API.")
  }
  endpoint <- paste0(qr_api_base_url(), "/generate-tag")
  request <- httr2::request(endpoint)
  request <- httr2::req_body_json(request, list(batchId = batch_id),
                                  auto_unbox = TRUE)
  request <- httr2::req_timeout(request, seconds = 10)
  response <- tryCatch(httr2::req_perform(request), error = function(e) {
    stop("QR API is not available at ", qr_api_base_url(),
         ". Check that the separate QR API is running. Detail: ",
         conditionMessage(e), call. = FALSE)
  })
  content_type <- httr2::resp_header(response, "content-type") %||% ""
  if (!grepl("^image/png", content_type, ignore.case = TRUE)) {
    stop("The QR API did not return an image/png response.")
  }
  bytes <- httr2::resp_body_raw(response)
  if (!is.raw(bytes) || length(bytes) < 8L ||
      !identical(as.integer(bytes[1:8]),
                 c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))) {
    stop("The QR API returned an invalid PNG.")
  }
  bytes
}

# Default: generate within Shiny, with no HTTP server or second R session.
# Future API use is explicit; network failures never silently change the mode.
get_batch_qr <- function(batch_id) {
  mode <- tolower(trimws(Sys.getenv("DIGITAL_TAGGING_QR_MODE", unset = "local")))
  switch(mode,
    local = qr_png_raw(batch_id),
    api = request_batch_qr(batch_id),
    stop("DIGITAL_TAGGING_QR_MODE must be local or api.")
  )
}
