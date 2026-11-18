# ============================================================
# run_api.R - API DE DESARROLLO EN OTRO PROCESO DE R
#
# Nota: la API de QR independiente entregada anteriormente
# puede ejecutarse en su proyecto separado (recomendado).
# ============================================================
if (!requireNamespace("plumber", quietly = TRUE)) {
  stop("Falta el paquete plumber. Ejecuta source('install_packages.R').")
}
.dt_scripts <- unlist(lapply(sys.frames(), function(frame) {
  path <- tryCatch(frame$ofile, error = function(e) NULL)
  if (is.character(path) && length(path) == 1L && !is.na(path) &&
      nzchar(path)) path else character()
}), use.names = FALSE)
.dt_scripts <- .dt_scripts[basename(.dt_scripts) == "run_api.R"]
.dt_dirs <- c(
  if (length(.dt_scripts)) dirname(normalizePath(
    .dt_scripts, winslash = "/", mustWork = FALSE)) else character(),
  getwd()
)
.dt_dirs <- unique(.dt_dirs)
.dt_ok <- .dt_dirs[vapply(.dt_dirs, function(path) {
  is.character(path) && length(path) == 1L && !is.na(path) &&
  nzchar(path) && all(file.exists(file.path(path, c("api.R", "R/utils.R"))))
}, logical(1))]
if (!length(.dt_ok)) stop("No encuentro api.R y R/utils.R. Abre el proyecto RStudio.")
project_dir <- normalizePath(.dt_ok[[1L]], winslash = "/", mustWork = TRUE)
run_digital_tagging_api <- function() {
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(project_dir)
  port <- as.integer(Sys.getenv("DIGITAL_TAGGING_API_PORT", unset = "8000"))
  host <- Sys.getenv("DIGITAL_TAGGING_API_HOST", unset = "127.0.0.1")
  api <- plumber::pr(file.path(project_dir, "api.R"))
  message("API: http://", host, ":", port, "/__docs__/")
  api$run(host = host, port = port)
}
run_digital_tagging_api()
