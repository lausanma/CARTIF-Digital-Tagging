# ============================================================
# global.R - CONFIGURACION COMPARTIDA (v0.5.1)
#
# Carga los modulos con rutas absolutas para evitar:
#   no fue posible abrir el archivo 'R/utils.R'
#
# NO instala paquetes, NO crea batches y NO accede a las APIs
# reales de Process DT / Batch DT.
# ============================================================

# Tambien permite que Shiny cargue global.R por separado
# (estructura tradicional global.R / ui.R / server.R).
.dt_root_is_valid <- function(root) {
  is.character(root) && length(root) == 1L && !is.na(root) &&
    nzchar(root) && all(file.exists(file.path(root, c(
      "app.R", "ui.R", "server.R", "R/utils.R", "config/pilots.json"
    ))))
}

if (!exists("DT_PROJECT_ROOT", inherits = TRUE) ||
    !.dt_root_is_valid(DT_PROJECT_ROOT)) {
  .dt_sources <- unlist(lapply(sys.frames(), function(frame) {
    path <- tryCatch(frame$ofile, error = function(e) NULL)
    if (is.character(path) && length(path) == 1L && !is.na(path) &&
        nzchar(path)) path else character()
  }), use.names = FALSE)
  .dt_sources <- .dt_sources[basename(.dt_sources) == "global.R"]
  .dt_candidate_roots <- c(
    if (length(.dt_sources)) dirname(normalizePath(
      .dt_sources, winslash = "/", mustWork = FALSE)) else character(),
    Sys.getenv("DIGITAL_TAGGING_PROJECT_DIR", unset = ""),
    getwd()
  )
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    .dt_project <- tryCatch(rstudioapi::getActiveProject(),
                            error = function(e) NULL)
    if (is.character(.dt_project) && length(.dt_project) == 1L) {
      .dt_candidate_roots <- c(.dt_candidate_roots, .dt_project)
    }
  }
  .dt_candidate_roots <- unique(.dt_candidate_roots)
  .dt_candidates <- .dt_candidate_roots[
    vapply(.dt_candidate_roots, .dt_root_is_valid, logical(1))
  ]
  if (!length(.dt_candidates)) {
    stop("Digital Tagging: no encuentro R/utils.R en la carpeta del proyecto. ",
         "Extrae TODO el ZIP y abre el archivo .Rproj.", call. = FALSE)
  }
  DT_PROJECT_ROOT <- normalizePath(.dt_candidates[[1L]],
                                   winslash = "/", mustWork = TRUE)
}

# Todas las funciones pueden obtener rutas internas de forma fiable.
dt_project_path <- function(...) file.path(DT_PROJECT_ROOT, ...)

required_packages <- c("shiny", "shinydashboard", "jsonlite",
                       "qrcode", "png", "uuid")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Faltan paquetes: ", paste(missing_packages, collapse = ", "),
       ". Ejecuta source('install_packages.R') en la carpeta del proyecto.",
       call. = FALSE)
}

# Cargar todos los modulos (nunca usar source('R/archivo.R')
# ya que dependeria del directorio de trabajo).
source(dt_project_path("R", "utils.R"), local = TRUE)
source(dt_project_path("R", "config.R"), local = TRUE)
source(dt_project_path("R", "storage.R"), local = TRUE)
source(dt_project_path("R", "data_access.R"), local = TRUE)
initialize_batch_adapters()
source(dt_project_path("R", "completeness.R"), local = TRUE)
source(dt_project_path("R", "qr_service.R"), local = TRUE)
source(dt_project_path("R", "process_model.R"), local = TRUE)
source(dt_project_path("R", "tagging.R"), local = TRUE)
source(dt_project_path("R", "api_client.R"), local = TRUE)
source(dt_project_path("R", "digital_tag_logic.R"), local = TRUE)

# Ahora cfg y now_default existen antes de construir ui.R.
cfg <- read_project_config(dt_project_path("config", "pilots.json"))
completeness_cfg <- read_completeness_config(
  dt_project_path("config", "completeness_rules.json")
)
now_default <- utc_time()
