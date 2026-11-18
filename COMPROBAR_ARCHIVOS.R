# ============================================================
# COMPROBAR_ARCHIVOS.R - diagnostico sin abrir Shiny
# Desde la carpeta del proyecto: source("COMPROBAR_ARCHIVOS.R")
# ============================================================
.dt_necesarios <- c(
  "app.R", "global.R", "ui.R", "server.R", "run_app.R",
  "config/pilots.json", "config/completeness_rules.json",
  "R/utils.R", "R/config.R", "R/storage.R", "R/completeness.R",
  "R/qr_service.R", "R/process_model.R", "R/tagging.R",
  "R/api_client.R", "R/digital_tag_logic.R",
  "www/styles.css", "www/features_v05.css"
)
cat("Carpeta de trabajo:", getwd(), "\n")
.dt_encontrados <- file.exists(.dt_necesarios)
for (i in seq_along(.dt_necesarios)) {
  cat(if (.dt_encontrados[[i]]) "OK    " else "FALTA ",
      .dt_necesarios[[i]], "\n", sep = "")
}
if (all(.dt_encontrados)) {
  cat("\nEstructura completa. Ejecuta source('run_app.R').\n")
} else {
  cat("\nAbre DigitalTagging_API_Demo.Rproj y comprueba la extraccion del ZIP.\n")
}
