# ============================================================
# PROTOTYPE TAG COMPLETENESS (v0.5)
# Currently counts the pilot's configured categories with >=1
# local record. NOT the formal KPI or DPP completeness.
# ============================================================
read_completeness_config <- function(file = NULL) {
  if (is.null(file)) file <- if (exists("dt_project_path", mode = "function")) {
    dt_project_path("config", "completeness_rules.json")
  } else "config/completeness_rules.json"
  if (!file.exists(file)) stop("Missing ", file)
  jsonlite::fromJSON(file, simplifyVector = FALSE)
}

get_required_categories <- function(config, pilot_id) {
  available <- record_categories()
  configured <- config$pilots[[pilot_id]]
  if (is.null(configured)) configured <- available
  categories <- unlist(configured, use.names = FALSE)
  if (!length(categories) || !all(categories %in% available)) {
    stop("Invalid completeness rules for pilot ", pilot_id)
  }
  unique(categories)
}

tag_completeness <- function(record, config) {
  required <- get_required_categories(config, record$metadata$pilot_id)
  filled <- vapply(required, function(cat) length(record[[cat]] %||% list()) > 0L,
                   logical(1))
  names(filled) <- required
  list(
    percentage = as.integer(round(100 * sum(filled) / length(required))),
    completed = as.integer(sum(filled)),
    total = as.integer(length(required)),
    populated = filled
  )
}

category_display_name <- function(category) {
  names <- c(raw_materials = "Raw Materials",
             production_process = "Production Process",
             quality_control = "Quality Control",
             logistics = "Logistics",
             sustainability = "Sustainability")
  unname(names[[category]])
}
