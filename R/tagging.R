# ============================================================
# R/tagging.R - QR generation
# Shared by Shiny UI and Plumber API.
#
# The QR currently encodes only batchId (PROVISIONAL).
# Do not silently invent a Batch DT URL.
# ============================================================

qr_payload <- function(batch_id) {
  require_text(batch_id, "batchId")
}

save_qr_png <- function(batch_id, output_file, scale_factor = 12L) {
  if (!requireNamespace("qrcode", quietly = TRUE) ||
      !requireNamespace("png", quietly = TRUE)) {
    stop("Packages 'qrcode' and 'png' are required.")
  }
  content <- qr_payload(batch_id)
  # qrcode::qr_code returns a two-dimensional module matrix.
  qr_matrix <- as.matrix(qrcode::qr_code(content))
  bits <- matrix(as.numeric(qr_matrix), nrow = nrow(qr_matrix),
                 ncol = ncol(qr_matrix))
  if (!all(bits %in% c(0, 1))) stop("QR module matrix is invalid.")

  # In PNG grayscale: 0 = black, 1 = white.
  modules <- 1 - bits
  k <- as.integer(scale_factor)
  if (is.na(k) || k < 1L) stop("scale_factor must be positive.")
  enlarged <- modules[rep(seq_len(nrow(modules)), each = k),
                      rep(seq_len(ncol(modules)), each = k), drop = FALSE]

  # White quiet zone (4 modules wide) makes the code easier to scan.
  margin <- 4L * k
  image <- matrix(1, nrow = nrow(enlarged) + 2L * margin,
                  ncol = ncol(enlarged) + 2L * margin)
  image[(margin + 1L):(margin + nrow(enlarged)),
        (margin + 1L):(margin + ncol(enlarged))] <- enlarged
  png::writePNG(image, target = output_file)
  invisible(output_file)
}

# For API output, return raw PNG bytes (no permanent image storage).
qr_png_raw <- function(batch_id) {
  path <- tempfile(fileext = ".png")
  on.exit(if (file.exists(path)) unlink(path), add = TRUE)
  save_qr_png(batch_id, path)
  size <- file.info(path)$size
  if (is.na(size) || size < 8L) stop("QR PNG generation failed.")
  readBin(path, what = "raw", n = size)
}
