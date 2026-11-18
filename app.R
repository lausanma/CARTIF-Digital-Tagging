# ============================================================
# app.R - ENTRADA PRINCIPAL DE SHINY (v0.5.1)
#
# Puedes abrir el proyecto .Rproj y pulsar "Run App" o usar
#   source("run_app.R")
#
# CORRECCION: cargamos global.R, ui.R y server.R usando sus
# rutas ABSOLUTAS. No dependemos del directorio de trabajo
# de RStudio para encontrar R/utils.R o los demas modulos.
# ============================================================

# Buscar el app.R que se esta ejecutando entre los frames de R.
# Esta informacion existe tanto al usar Run App como source().
.dt_app_source_files <- unlist(lapply(sys.frames(), function(frame) {
  path <- tryCatch(frame$ofile, error = function(e) NULL)
  if (is.character(path) && length(path) == 1L && !is.na(path) &&
      nzchar(path)) path else character()
}), use.names = FALSE)
.dt_app_source_files <- .dt_app_source_files[
  basename(.dt_app_source_files) == "app.R"
]
.dt_app_candidate_dirs <- c(
  if (length(.dt_app_source_files))
    dirname(normalizePath(.dt_app_source_files, winslash = "/",
                          mustWork = FALSE)) else character(),
  Sys.getenv("DIGITAL_TAGGING_PROJECT_DIR", unset = ""),
  getwd()
)
if (requireNamespace("rstudioapi", quietly = TRUE)) {
  .dt_rstudio_project <- tryCatch(rstudioapi::getActiveProject(),
                                 error = function(e) NULL)
  if (is.character(.dt_rstudio_project) &&
      length(.dt_rstudio_project) == 1L) {
    .dt_app_candidate_dirs <- c(.dt_app_candidate_dirs, .dt_rstudio_project)
  }
}
.dt_is_app_dir <- function(path) {
  is.character(path) && length(path) == 1L && !is.na(path) &&
    nzchar(path) && all(file.exists(file.path(path,
      c("global.R", "ui.R", "server.R", "R/utils.R", "config/pilots.json"))))
}
.dt_app_candidate_dirs <- unique(.dt_app_candidate_dirs)
.dt_matches <- .dt_app_candidate_dirs[
  vapply(.dt_app_candidate_dirs, .dt_is_app_dir, logical(1))
]
if (!length(.dt_matches)) {
  stop(paste0(
    "Digital Tagging: no se encuentra la carpeta completa del proyecto.\n",
    "Comprueba que app.R, global.R, R/utils.R y config/pilots.json ",
    "estan dentro de la MISMA carpeta.\n",
    "Abre DigitalTagging_API_Demo.Rproj y usa source('run_app.R')."
  ), call. = FALSE)
}
DT_PROJECT_ROOT <- normalizePath(.dt_matches[[1L]], winslash = "/",
                                  mustWork = TRUE)

# Los tres scripts usan el mismo entorno para compartir cfg y funciones.
source(file.path(DT_PROJECT_ROOT, "global.R"), local = TRUE)
source(file.path(DT_PROJECT_ROOT, "ui.R"), local = TRUE)
source(file.path(DT_PROJECT_ROOT, "server.R"), local = TRUE)

shiny::shinyApp(ui = ui, server = server)
