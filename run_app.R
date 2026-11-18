# ============================================================
# run_app.R - INICIAR DIGITAL TAGGING (v0.5.1)
#
# INSTRUCCIONES:
# 1. Descomprime el ZIP completo.
# 2. Abre DigitalTagging_API_Demo.Rproj.
# 3. En la consola de RStudio: source("run_app.R")
#
# Tambien funciona si se usa source("C:/.../run_app.R")
# con la ruta completa desde otra carpeta.
# ============================================================

if (!requireNamespace("shiny", quietly = TRUE)) {
  stop("Falta 'shiny'. Instala paquetes con source('install_packages.R').",
       call. = FALSE)
}

.dt_valid_project <- function(path) {
  is.character(path) && length(path) == 1L && !is.na(path) &&
    nzchar(path) && all(file.exists(file.path(path, c(
      "app.R", "global.R", "ui.R", "server.R",
      "R/utils.R", "config/pilots.json"
    ))))
}

.dt_sources <- unlist(lapply(sys.frames(), function(frame) {
  path <- tryCatch(frame$ofile, error = function(e) NULL)
  if (is.character(path) && length(path) == 1L && !is.na(path) &&
      nzchar(path)) path else character()
}), use.names = FALSE)
.dt_sources <- .dt_sources[basename(.dt_sources) == "run_app.R"]
.dt_candidates <- c(
  if (length(.dt_sources)) dirname(normalizePath(
    .dt_sources, winslash = "/", mustWork = FALSE)) else character(),
  Sys.getenv("DIGITAL_TAGGING_PROJECT_DIR", unset = ""),
  getwd()
)
if (requireNamespace("rstudioapi", quietly = TRUE)) {
  .dt_project <- tryCatch(rstudioapi::getActiveProject(),
                          error = function(e) NULL)
  if (is.character(.dt_project) && length(.dt_project) == 1L) {
    .dt_candidates <- c(.dt_candidates, .dt_project)
  }
}
.dt_candidates <- unique(.dt_candidates)
.dt_matches <- .dt_candidates[
  vapply(.dt_candidates, .dt_valid_project, logical(1))
]

if (!length(.dt_matches)) {
  stop(paste0(
    "No encuentro el proyecto completo.\n",
    "Carpeta actual: ", getwd(), "\n",
    "Asegurate de que config/pilots.json y R/utils.R\n",
    "estan junto a app.R, global.R y run_app.R.\n",
    "Abre DigitalTagging_API_Demo.Rproj antes de ejecutar."
  ), call. = FALSE)
}
project_dir <- normalizePath(.dt_matches[[1L]], winslash = "/",
                             mustWork = TRUE)
message("Iniciando Digital Tagging desde: ", project_dir)

host <- Sys.getenv("DIGITAL_TAGGING_APP_HOST", unset = "127.0.0.1")
port <- suppressWarnings(as.integer(Sys.getenv(
  "DIGITAL_TAGGING_APP_PORT", unset = "3838"
)))
if (is.na(port) || port < 1L || port > 65535L) {
  stop("DIGITAL_TAGGING_APP_PORT no es un puerto valido.", call. = FALSE)
}

# Shiny recibe la carpeta completa, no una seleccion de archivo .R.
# Las rutas internas ya se resuelven de manera absoluta desde app.R.
shiny::runApp(appDir = project_dir, host = host, port = port,
              launch.browser = interactive())
