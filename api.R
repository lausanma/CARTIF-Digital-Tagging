# ==============================================================
# bi0SpaCE | T4.3 Digital Tagging REST API (Plumber)
# Actual integration contract confirmed for tag generation:
# POST /generate-tag {"batchId":"BATCH-001"} -> image/png
# The PNG is returned and is NOT saved by this service.
# ==============================================================

if (!requireNamespace("plumber", quietly = TRUE) ||
    !requireNamespace("qrcode", quietly = TRUE) ||
    !requireNamespace("png", quietly = TRUE)) {
  stop("Packages plumber, qrcode and png are required; run install_packages.R first.")
}
# The dedicated independent QR service remains unchanged. This local
# compatibility endpoint sources helpers relative to its own api.R.
.dt_api_sources <- unlist(lapply(sys.frames(), function(frame) {
  path <- tryCatch(frame$ofile, error = function(e) NULL)
  if (is.character(path) && length(path) == 1L && !is.na(path) &&
      nzchar(path)) path else character()
}), use.names = FALSE)
.dt_api_sources <- .dt_api_sources[basename(.dt_api_sources) == "api.R"]
.dt_api_candidates <- c(
  if (length(.dt_api_sources)) dirname(normalizePath(
    .dt_api_sources, winslash = "/", mustWork = FALSE)) else character(),
  getwd()
)
.dt_api_candidates <- unique(.dt_api_candidates)
.dt_api_valid <- .dt_api_candidates[vapply(.dt_api_candidates, function(path) {
  is.character(path) && length(path) == 1L && !is.na(path) && nzchar(path) &&
    all(file.exists(file.path(path, c("R/utils.R", "R/tagging.R"))))
}, logical(1))]
if (!length(.dt_api_valid)) stop("No encuentro modulos R para la API.")
.dt_api_root <- normalizePath(.dt_api_valid[[1L]], winslash = "/", mustWork = TRUE)
source(file.path(.dt_api_root, "R", "utils.R"), local = TRUE)
source(file.path(.dt_api_root, "R", "tagging.R"), local = TRUE)

#* @apiTitle bi0SpaCE Digital Tagging API
#* @apiDescription CARTIF T4.3 prototype. QR content is provisional (batchId).
#* @apiVersion 0.1.0

#* Check whether the Digital Tagging service is running
#* @get /health
#* @serializer json
function() {
  list(status = "ok", service = "bi0space-digital-tagging", version = "0.1.0")
}

#* Generate a QR PNG for a batch (the caller is responsible for storing it)
#* @param body:object* JSON body containing batchId; example {"batchId":"BATCH-001"}
#* @parser json
#* @post /generate-tag
#* @serializer contentType list(type="image/png")
function(body = NULL, req, res) {
  # Some parser/client combinations pass data as an argument, others via req$body.
  input <- body
  if (is.null(input) && !is.null(req$body)) input <- req$body
  if (is.character(input) && length(input) == 1L) {
    input <- tryCatch(jsonlite::fromJSON(input, simplifyVector = FALSE),
                      error = function(e) NULL)
  }
  if (!is.list(input) || !is_text(input$batchId)) {
    res$status <- 400L
    res$setHeader("Content-Type", "text/plain; charset=utf-8")
    return(charToRaw("A valid batchId is required."))
  }
  batch_id <- trimws(input$batchId)
  # The content is ONLY the batch ID until the consortium confirms a resolvable URL.
  tryCatch(
    qr_png_raw(batch_id),
    error = function(e) {
      message("QR generation failed: ", conditionMessage(e))
      res$status <- 500L
      res$setHeader("Content-Type", "text/plain; charset=utf-8")
      charToRaw("QR generation failed; check the R console log.")
    }
  )
}

#* RESERVED: batch finalisation still needs the real CreateBatch integration
#* @param id Batch identifier
#* @param body:object* JSON with start, end, outputAmount and outputUnit
#* @parser json
#* @post /batch/<id>/finalize
#* @serializer json
function(id, body = NULL, res) {
  # Never acknowledge finalisation without invoking the authorised Process DT API.
  res$status <- 501L
  list(error = "not_implemented",
       detail = paste("Batch finalisation for", id,
                      "is not connected to the Process DT CreateBatch operation."))
}
