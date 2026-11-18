# ============================================================
# ui.R - DIGITAL TAGGING | USER INTERFACE
#
# Presentation only: modify fields, labels and tabs here.
# Two main tabs separate data entry from data visualization.
# The five categories remain available inside the entry tab.
#
# IMPORTANT: entering Batch ID opens a LOCAL working context;
# it does NOT create or finalize a batch in bi0SpaCE/MFT.
# ============================================================

# Green card used by all five information categories.
tag_box <- function(title, ..., width = 12L) {
  shinydashboard::box(
    title = title, width = width, status = "success",
    solidHeader = TRUE, collapsible = FALSE, ...
  )
}

# A category is visible, but its form remains inaccessible until
# the user confirms ID and valid batch times (see output.batch_ready).
category_content <- function(...) {
  shiny::tagList(
    shiny::conditionalPanel(
      condition = "!output.batch_ready",
      shiny::div(
        class = "dt-batch-locked",
        shiny::icon("lock"),
        shiny::span("Save the batch details or select Update information to enter data.")
      )
    ),
    shiny::conditionalPanel(condition = "output.batch_ready", ...)
  )
}

# Batch-level values need no measurement time. Enable only for a dated event.
optional_record_time <- function(prefix) {
  shiny::tagList(
    shiny::checkboxInput(paste0(prefix, "_has_time"),
      "Add a specific measurement / event time (optional)", value = FALSE),
    shiny::conditionalPanel(
      condition = paste0("input.", prefix, "_has_time"),
      shiny::textInput(paste0(prefix, "_timestamp"), "Measurement / event time (UTC)",
        value = "", placeholder = "YYYY-MM-DDTHH:MM:SSZ")
    ),
    shiny::p(class = "help-block", "By default this value belongs to the whole batch. No additional time is required.")
  )
}

# Read-only tables and their record-management controls are shown
# in the visualization tab. Selecting Edit opens the matching form.
view_category <- function(title, table_id, manager_id, ...) {
  shiny::fluidRow(tag_box(title,
    shiny::div(class = "dt-table-scroll", shiny::tableOutput(table_id)),
    shiny::uiOutput(manager_id),
    ...
  ))
}

# ============================================================
# DASHBOARD - Header + full-width body (no left sidebar)
# ============================================================
# One shared set of controls placed AFTER main navigation and BEFORE tab content.
batch_context_controls <- shiny::div(class = "dt-context-bar dt-context-clean",
  shiny::div(class = "dt-selection-grid",
    shiny::selectInput("pilot", "Pilot", choices = pilot_choices(cfg), selected = pilot_ids(cfg)[[1L]]),
    shiny::textInput("batch_id", "Batch number", value = "", placeholder = "Enter batch number"),
    shiny::conditionalPanel(condition = "input.workspace_tabs == 'visualization'",
      shiny::actionButton("search_batch", "Search", icon = shiny::icon("search"), class = "btn-success"))
  ),
  shiny::conditionalPanel(condition = "input.workspace_tabs == 'visualization'",
    shiny::div(class = "dt-feedback", role = "status", shiny::textOutput("batch_search_status")),
    shiny::div(class = "dt-view-actions",
      style = "display:flex;flex-wrap:wrap;gap:14px;margin-top:28px;padding-top:22px;border-top:1px solid #e4eeeb;clear:both;",
      shiny::actionButton("update_from_view", "Update information", icon = shiny::icon("edit")))
  ),
  shiny::conditionalPanel(condition = "input.workspace_tabs == 'entry'",
    shiny::div(class = "dt-date-grid",
      shiny::div(class = "dt-date-group",
        shiny::dateInput("batch_start_date", "Start date (UTC)", value = NULL, format = "yyyy-mm-dd"),
        shiny::selectizeInput("batch_start_time", "Start time (UTC)",
          choices = c("", sprintf("%02d:%02d", rep(0:23, each = 4), rep(c(0,15,30,45),24))),
          options = list(create = TRUE, persist = FALSE, placeholder = "Select or type a time"))),
      shiny::div(class = "dt-date-group",
        shiny::dateInput("batch_end_date", "End date (UTC)", value = NULL, format = "yyyy-mm-dd"),
        shiny::selectizeInput("batch_end_time", "End time (UTC)",
          choices = c("", sprintf("%02d:%02d", rep(0:23, each = 4), rep(c(0,15,30,45),24))),
          options = list(create = TRUE, persist = FALSE, placeholder = "Select or type a time")))
    ),
    shiny::div(class = "dt-date-grid",
      shiny::numericInput("batch_output_amount", "Output amount", value = NA_real_, min = 0),
      shiny::textInput("batch_output_unit", "Output unit", value = "", placeholder = "e.g. kg, L")
    ),
    shiny::div(class = "dt-context-actions",
      shiny::actionButton("confirm_batch_context", "Save batch", icon = shiny::icon("check"), class = "btn-success"),
      shiny::actionButton("finish_entry", "Finish data entry", icon = shiny::icon("flag-checkered")),
      shiny::actionButton("update_information", "Update information", icon = shiny::icon("edit")),
      shiny::actionButton("save_entry_json", "Save JSON", icon = shiny::icon("save")),
      shiny::uiOutput("batch_context")
    ),
    shiny::div(class = "dt-feedback", role = "status", shiny::textOutput("entry_export_path"))
  )
)

main_workspace_tabs <- function(...) {
  panel <- shiny::tabsetPanel(...)
  panel$children <- append(panel$children, list(batch_context_controls), after = 1L)
  panel
}

ui <- shinydashboard::dashboardPage(
  skin = "blue",

  # 1. Keep the original project header and logos.
  header = shinydashboard::dashboardHeader(
    title = "DIGITAL TAGGING", titleWidth = 235,
    shiny::tags$li(
      class = "dropdown branding",
      shiny::tags$img(src = "logobio.png", alt = "bi0SpaCE", class = "brand-bio"),
      shiny::tags$img(src = "LogoCartif.png", alt = "CARTIF", class = "brand-cartif")
    )
  ),

  # 2. Remove the sidebar completely. Navigation is placed on top.
  sidebar = shinydashboard::dashboardSidebar(disable = TRUE),

  body = shinydashboard::dashboardBody(
    shiny::tags$head(
      shiny::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      shiny::tags$link(rel = "stylesheet", type = "text/css", href = "styles.css?v=20261109-spacing-2"),
      shiny::tags$link(rel = "stylesheet", type = "text/css", href = "features_v05.css?v=20261109-spacing-2")
    ),

    # =========================================================
    # PILOT + EXISTING BATCH ID (REQUIRED)
    # Confirming ID and valid times enables all five data-entry panels.
    # =========================================================


    # Two main tabs share the pilot and Batch ID selected above.
    shiny::div(class = "dt-main-tabs",
      main_workspace_tabs(
        id = "workspace_tabs", type = "tabs",
        shiny::tabPanel("Data Entry", value = "entry",
          icon = shiny::icon("edit"),
          shiny::p(class = "dt-section-intro",
            "Select a category, enter the information and save it. ",
            "Open Data Visualization to review the records."),
          # The existing five categories stay as sub-tabs.
          shiny::div(class = "dt-top-tabs",
            shiny::tabsetPanel(
              id = "category_tabs", type = "tabs",

        # -----------------------------------------------------
        # A. RAW MATERIALS
        # -----------------------------------------------------
        if (isTRUE(UI_FEATURES$show_raw_materials))
          shiny::tabPanel("Raw Materials", value = "raw",
            icon = shiny::icon("cubes"),
            category_content(
              shiny::fluidRow(tag_box("Raw Materials",
                shiny::fluidRow(
                  shiny::column(6, shiny::textInput("rm_name", "Material name", "")),
                  shiny::column(6, shiny::textInput("rm_type", "Type", "")),
                  shiny::column(6, shiny::textInput("rm_batch", "Source batch", "")),
                  shiny::column(3, shiny::numericInput("rm_amount", "Amount", NA_real_, min = 0)),
                  shiny::column(3, shiny::textInput("rm_unit", "Unit", ""))
                ),
                shiny::textInput("rm_notes", "Notes", ""),
                shiny::div(class = "dt-actions",
                  shiny::uiOutput("rm_edit_notice"),
                  shiny::actionButton("add_rm", "Save material", class = "btn-success"),
                  if (mft_is_configured())
                    shiny::actionButton("import_mft", "Import from MFT", class = "btn-default")
                ),
                shiny::p(class = "help-block", "Review saved materials in Data Visualization.")
              ))
            )
          ),

        # -----------------------------------------------------
        # B. PRODUCTION PROCESS - Dev metamodel
        # Process -> Process Step -> Parameter or Machine/Parameter
        # -----------------------------------------------------
        if (isTRUE(UI_FEATURES$show_production_process))
          shiny::tabPanel("Production Process", value = "process",
            icon = shiny::icon("industry"),
            category_content(
              shiny::fluidRow(tag_box("Production Process",
                shiny::fluidRow(
                  # =======================================================
                  # PROCESS STEP - PILOT-SPECIFIC DROPDOWN
                  # Options come from config/pilots.json + previously saved
                  # custom steps in the current pilot/batch.
                  # =======================================================
                  shiny::column(6,
                    shiny::selectInput(
                      inputId = "proc_step",
                      label = "Process step",
                      choices = c("Select a process step" = "",
                                  "Other / Add new" = "__other__"),
                      selected = ""
                    ),
                    # Show this textbox ONLY for an unlisted step.
                    shiny::conditionalPanel(
                      condition = "input.proc_step == '__other__'",
                      shiny::textInput(
                        inputId = "proc_custom_step",
                        label = "New process step",
                        value = ""
                      )
                    )
                  ),
                  shiny::column(6, shiny::textInput("proc_machine", "Machine (optional)", "")),
                  shiny::column(6, shiny::textInput("proc_parameter", "Parameter", "")),
                  shiny::column(3, shiny::textInput("proc_value", "Value", "")),
                  shiny::column(3, shiny::textInput("proc_unit", "Unit", "")),
                  shiny::column(6, optional_record_time("proc")),
                  shiny::column(6, shiny::selectInput(
                    "proc_source", "Source",
                    choices = c("Manual" = "manual", "Reported externally" = "automatic_import")
                  ))
                ),
                shiny::textInput("proc_notes", "Notes", ""),
                shiny::uiOutput("proc_edit_notice"),
                  shiny::actionButton("add_process", "Save parameter", class = "btn-success"),
                shiny::p(class = "help-block", "Review saved parameters in Data Visualization.")
              ))
            )
          ),

        # -----------------------------------------------------
        # C. QUALITY CONTROL
        # -----------------------------------------------------
        if (isTRUE(UI_FEATURES$show_quality_control))
          shiny::tabPanel("Quality Control", value = "quality",
            icon = shiny::icon("check-circle"),
            category_content(
              shiny::fluidRow(tag_box("Quality Control",
                shiny::fluidRow(
                  shiny::column(6, shiny::textInput("qc_check", "Check name", "")),
                  shiny::column(6, shiny::textInput("qc_result", "Result", "")),
                  shiny::column(6, shiny::textInput("qc_unit", "Unit", "")),
                  shiny::column(6, shiny::selectInput("qc_status", "Status",
                    choices = c("Pending", "Pass", "Fail", "Informational")))
                ),
                optional_record_time("qc"),
                shiny::textInput("qc_notes", "Notes", ""),
                shiny::uiOutput("qc_edit_notice"),
                  shiny::actionButton("add_qc", "Save check", class = "btn-success"),
                shiny::p(class = "help-block", "Review saved quality records in Data Visualization.")
              ))
            )
          ),

        # -----------------------------------------------------
        # D. LOGISTICS
        # -----------------------------------------------------
        if (isTRUE(UI_FEATURES$show_logistics))
          shiny::tabPanel("Logistics", value = "logistics",
            icon = shiny::icon("truck"),
            category_content(
              shiny::fluidRow(tag_box("Logistics",
                shiny::fluidRow(
                  shiny::column(6, shiny::textInput("log_event", "Event", "")),
                  shiny::column(6, shiny::textInput("log_origin", "Origin", "")),
                  shiny::column(6, shiny::textInput("log_destination", "Destination", "")),
                  shiny::column(3, shiny::numericInput("log_amount", "Quantity", NA_real_, min = 0)),
                  shiny::column(3, shiny::textInput("log_unit", "Unit", ""))
                ),
                optional_record_time("log"),
                shiny::textInput("log_notes", "Notes", ""),
                shiny::uiOutput("log_edit_notice"),
                  shiny::actionButton("add_log", "Save event", class = "btn-success"),
                shiny::p(class = "help-block", "Review saved logistics records in Data Visualization.")
              ))
            )
          ),

        # -----------------------------------------------------
        # E. SUSTAINABILITY
        # -----------------------------------------------------
        if (isTRUE(UI_FEATURES$show_sustainability))
          shiny::tabPanel("Sustainability", value = "sustainability",
            icon = shiny::icon("leaf"),
            category_content(
              shiny::fluidRow(tag_box("Sustainability",
                shiny::fluidRow(
                  shiny::column(6, shiny::textInput("sus_indicator", "Indicator", "")),
                  shiny::column(3, shiny::numericInput("sus_value", "Value", NA_real_)),
                  shiny::column(3, shiny::textInput("sus_unit", "Unit", ""))
                ),
                shiny::textInput("sus_method", "Source / method", ""),
                optional_record_time("sus"),
                shiny::textInput("sus_notes", "Notes", ""),
                shiny::uiOutput("sus_edit_notice"),
                  shiny::actionButton("add_sus", "Save indicator", class = "btn-success"),
                shiny::p(class = "help-block", "Review saved indicators in Data Visualization.")
              ))
            )
          )
            )
          )
        ),
        shiny::tabPanel("Data Visualization", value = "visualization",
          icon = shiny::icon("table"),
          shiny::p(class = "dt-section-intro",
            "Review the records for the selected pilot and Batch ID. ",
            "Use Edit selected to change a record in Data Entry."),
          shiny::conditionalPanel(
            condition = "output.view_ready",
            # Prototype completeness is based on local record presence.
            shiny::uiOutput("tag_completeness"),
            shiny::fluidRow(tag_box("Batch overview",
              shiny::uiOutput("record_summary")
            )),
            if (isTRUE(UI_FEATURES$show_raw_materials))
              view_category("Raw Materials", "rm_table", "rm_manage_ui"),
            if (isTRUE(UI_FEATURES$show_production_process))
              view_category("Production Process", "proc_table", "proc_manage_ui",
                shiny::tags$details(class = "dt-details",
                  shiny::tags$summary("Export process model"),
                  shiny::downloadButton("download_process", "Export process JSON")
                )
              ),
            if (isTRUE(UI_FEATURES$show_quality_control))
              view_category("Quality Control", "qc_table", "qc_manage_ui"),
            if (isTRUE(UI_FEATURES$show_logistics))
              view_category("Logistics", "log_table", "log_manage_ui"),
            if (isTRUE(UI_FEATURES$show_sustainability))
              view_category("Sustainability", "sus_table", "sus_manage_ui"),
            # JSON export and QR remain local prototype functions.
            shiny::div(class = "dt-export-section",
        shiny::fluidRow(
          tag_box("Digital Tag",
            shiny::div(class = "dt-tag-grid",
              shiny::div(class = "dt-tag-card",
                shiny::tags$h4(shiny::icon("file-code"), " Batch data"),
                shiny::div(class = "dt-tag-actions",
                  shiny::downloadButton("download_batch_json", "Download JSON")
                ),
                shiny::span()
              ),
              shiny::div(class = "dt-tag-card dt-tag-qr",
                shiny::tags$h4(shiny::icon("qrcode"), " QR code"),
                shiny::actionButton("preview_qr", "Show QR", icon = shiny::icon("qrcode"), class = "btn-success"),
                shiny::conditionalPanel(condition = "output.qr_ready",
                  shiny::div(class = "dt-qr-preview",
                    shiny::imageOutput("qr_preview", width = "210px", height = "210px"),
                    shiny::downloadButton("download_qr_png", "Download QR")
                  )
                )
              )
            )
          )
              )
            )
          )
        )
      )
    )
  )
)
