# Run once manually in RStudio. Never put install.packages() in app.R/api.R.
packages <- c("shiny", "shinydashboard", "jsonlite", "qrcode", "png",
              "uuid", "plumber", "httr2")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
} else {
  message("All required packages are already installed.")
}
