# Pilot configuration is data-driven; add/edit pilots in config/pilots.json.
read_project_config <- function(file = NULL) {
  # If loaded by global.R, resolve against the project root.
  # Directly sourced unit tests can still run from the project folder.
  if (is.null(file)) file <- if (exists("dt_project_path", mode = "function")) {
    dt_project_path("config", "pilots.json")
  } else "config/pilots.json"
  if (!file.exists(file)) stop("Cannot find ", file, ". Open the project folder in RStudio.")
  config <- jsonlite::fromJSON(file, simplifyVector = FALSE)
  if (is.null(config$pilots) || length(config$pilots) < 1L) {
    stop("The configuration must include at least one pilot.")
  }
  config
}

pilot_ids <- function(config) {
  vapply(config$pilots, function(p) p$id, character(1))
}

pilot_choices <- function(config) {
  stats::setNames(pilot_ids(config), vapply(config$pilots, function(p) p$name, character(1)))
}

get_pilot <- function(config, pilot_id) {
  for (p in config$pilots) {
    if (identical(p$id, pilot_id)) return(p)
  }
  stop("Unknown pilot ID: ", pilot_id, call. = FALSE)
}

pilot_steps <- function(pilot) pilot$steps %||% list()

get_step <- function(pilot, step_id) {
  for (step in pilot_steps(pilot)) {
    if (identical(step$id, step_id)) return(step)
  }
  NULL
}

step_choices <- function(pilot) {
  steps <- pilot_steps(pilot)
  options <- stats::setNames(
    vapply(steps, function(s) s$id, character(1)),
    vapply(steps, function(s) s$name, character(1))
  )
  c(options, "Other step (custom)" = "__other__")
}

machine_choices <- function(step) {
  machines <- if (!is.null(step)) step$machines %||% list() else list()
  options <- c("No machine (step parameter)" = "")
  if (length(machines)) {
    options <- c(options, stats::setNames(
      vapply(machines, function(m) m$id, character(1)),
      vapply(machines, function(m) m$name, character(1))
    ))
  }
  c(options, "Other machine (custom)" = "__other__")
}

step_parameters <- function(step, machine_id = "") {
  if (is.null(step)) return(list())
  params <- step$parameters %||% list()
  Filter(function(p) {
    scope <- p$scope %||% "step"
    if (!nzchar(machine_id)) identical(scope, "step")
    else identical(scope, "machine") && identical(p$machine_id %||% "", machine_id)
  }, params)
}

parameter_choices <- function(step, machine_id = "") {
  params <- step_parameters(step, machine_id)
  opts <- if (length(params)) stats::setNames(
    vapply(params, function(p) p$id, character(1)),
    vapply(params, function(p) p$name, character(1))
  ) else character(0)
  c(opts, "Other parameter (custom)" = "__other__")
}

get_parameter <- function(step, parameter_id, machine_id = "") {
  for (p in step_parameters(step, machine_id)) {
    if (identical(p$id, parameter_id)) return(p)
  }
  NULL
}

# ============================================================
# VISIBLE USER-INTERFACE CATEGORIES
# Set FALSE to hide a category from the top navigation.
# QR generation stays in the separate Plumber API.
# ============================================================
UI_FEATURES <- list(
  show_raw_materials = TRUE,
  show_production_process = TRUE,
  show_quality_control = TRUE,
  show_logistics = TRUE,
  show_sustainability = TRUE
)
