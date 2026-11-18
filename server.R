# ============================================================
# server.R - REACTIVE BEHAVIOUR / SAVE ACTIONS
# Each category can be edited independently.
# The interface NEVER creates or finalizes a real MFT batch.
# ============================================================

server <- function(input, output, session) {
  current <- shiny::reactiveVal(NULL)
  entry_closed <- shiny::reactiveVal(FALSE)
  record_exists <- shiny::reactiveVal(FALSE)
  search_status <- shiny::reactiveVal("")
  last_saved <- shiny::reactiveVal(NULL)
  editing <- shiny::reactiveValues(
    raw_materials = NULL, production_process = NULL,
    quality_control = NULL, logistics = NULL, sustainability = NULL
  )
  pending_finish <- shiny::reactiveVal(NULL)
  pending_delete <- shiny::reactiveVal(NULL)
  qr_cache <- shiny::reactiveVal(NULL)

  # A record can only be updated in the pilot and batch where it was opened.
  active_edit_id <- function(category) {
    target <- editing[[category]]
    record <- current()
    if (is.null(target) || is.null(record) ||
        !identical(target$pilot_id, input$pilot) ||
        !identical(target$batch_id, trimws(input$batch_id %||% "")) ||
        !identical(record$metadata$pilot_id, input$pilot) ||
        !identical(record$metadata$batch_id, trimws(input$batch_id %||% ""))) {
      return(NULL)
    }
    target$record_id
  }

  category_buttons <- list(
    raw_materials = list(button = "add_rm", label = "Save material"),
    production_process = list(button = "add_process", label = "Save parameter"),
    quality_control = list(button = "add_qc", label = "Save check"),
    logistics = list(button = "add_log", label = "Save event"),
    sustainability = list(button = "add_sus", label = "Save indicator")
  )

  clear_edit <- function(category) {
    editing[[category]] <- NULL
    entry <- category_buttons[[category]]
    shiny::updateActionButton(session, entry$button, label = entry$label)
  }

  save_category_item <- function(category, item, new_label) {
    record <- get_current()
    item$time_scope <- if (is_text(item$timestamp)) "measurement_or_event" else "batch"
    selected_id <- active_edit_id(category)
    if (is.null(selected_id)) {
      persist(add_to_category(record, category, item), new_label)
    } else {
      persist(update_category_record(record, category, selected_id, item),
              "Record updated")
      clear_edit(category)
    }
  }

  # ==========================================================
  # BATCH CONTEXT
  # Typing a Batch ID only selects a LOCAL workspace. If there
  # are existing locally entered values for this pilot + ID,
  # they are reopened automatically. No MFT POST is performed.
  # ==========================================================
  get_selected_pilot <- function() {
    get_pilot(cfg, input$pilot)
  }

  # Server-side guard: not only visual disabling.
  # Prevent writing data under a previous pilot or batch ID.
  get_selected_record <- function() {
    record <- current()
    entered_id <- input$batch_id
    if (is.null(record) || !is_text(entered_id) ||
        !identical(record$metadata$batch_id, trimws(entered_id)) ||
        !identical(record$metadata$pilot_id, input$pilot)) {
      stop("Enter a valid Batch ID before saving information.", call. = FALSE)
    }
    record
  }

  get_current <- function() {
    record <- get_selected_record()
    if (!isTRUE(batch_ready())) {
      stop("Confirm Batch ID, start and end in Data Entry before saving information.", call. = FALSE)
    }
    record
  }

  view_ready <- shiny::reactive({
    record <- current()
    isTRUE(record_exists()) && !is.null(record) && identical(record$metadata$pilot_id, input$pilot) &&
      identical(record$metadata$batch_id, trimws(input$batch_id %||% ""))
  })

  safely <- function(expr) {
    tryCatch(expr, error = function(e) {
      shiny::showNotification(conditionMessage(e), type = "error", duration = 7)
    })
  }

  # Save a category record to LOCAL JSON only.
  # This does not create a batch in Material Flow Tracing.
  persist <- function(record, label = "Saved") {
    get_current()  # confirm that pilot and batch context is still valid
    record <- save_batch_record(record)
    current(record)
    record_exists(TRUE)
    show_saved_json(record, label)
    shiny::showNotification(label, type = "message", duration = 4)
    invisible(record)
  }

  # Changing pilot clears the Batch ID so that an ID from a
  # different pilot cannot accidentally be reused.
  shiny::observeEvent(input$pilot, {
    current(NULL)
    shiny::updateTextInput(session, "batch_id", value = "")
  }, ignoreInit = TRUE)

  # Load existing data without enabling edits. Stored times are suggested;
  # confirmation is required each time the pilot/batch context changes.
  update_batch_time <- function(prefix, value) {
    parts <- split_batch_time(value)
    shiny::updateDateInput(session, paste0(prefix, "_date"), value = parts$date)
    choices <- unique(c("", sprintf("%02d:%02d", rep(0:23, each = 4), rep(c(0,15,30,45),24)), parts$time))
    shiny::updateSelectizeInput(session, paste0(prefix, "_time"), choices = choices, selected = parts$time)
  }

  confirmed_context <- shiny::reactiveVal(NULL)
  shiny::observeEvent(list(input$pilot, input$batch_id), {
    current(NULL)
    record_exists(FALSE)
    entry_closed(FALSE)
    search_status("")
    confirmed_context(NULL)
    last_saved(NULL)
    for (prefix in c("proc", "qc", "log", "sus")) {
      shiny::updateCheckboxInput(session, paste0(prefix, "_has_time"), value = FALSE)
      shiny::updateTextInput(session, paste0(prefix, "_timestamp"), value = "")
    }
    qr_cache(NULL)
    pending_delete(NULL)
    for (category in record_categories()) clear_edit(category)
    update_batch_time("batch_start", NULL)
    update_batch_time("batch_end", NULL)
    shiny::updateNumericInput(session, "batch_output_amount", value = NA_real_)
    shiny::updateTextInput(session, "batch_output_unit", value = "")
    if (!is_text(input$batch_id) || identical(input$workspace_tabs, "visualization")) return()
    safely({
      record <- read_batch_record(get_selected_pilot(), trimws(input$batch_id))
      record_exists(!is.null(record))
      if (is.null(record)) record <- new_batch_record(get_selected_pilot(), trimws(input$batch_id))
      current(record)
      update_batch_time("batch_start", record$metadata$batch_start)
      update_batch_time("batch_end", record$metadata$batch_end)
      shiny::updateNumericInput(session, "batch_output_amount", value = record$metadata$output_amount %||% NA_real_)
      shiny::updateTextInput(session, "batch_output_unit", value = record$metadata$output_unit %||% "")
      entry_closed(identical(record$metadata$data_entry_status, "finished"))
    })
  }, ignoreInit = FALSE)

  # Explicit read-only search: does not require entry confirmation or write access.
  search_selected_batch <- function() {
    current(NULL)
    record_exists(FALSE)
    confirmed_context(NULL)
    last_saved(NULL)
    pending_delete(NULL)
    qr_cache(NULL)
    for (category in record_categories()) clear_edit(category)
    tryCatch({
      id <- require_text(input$batch_id, "Batch number")
      record <- read_batch_record(get_selected_pilot(), id)
      if (is.null(record)) {
        search_status("Batch not found in the configured data source.")
        return(invisible(NULL))
      }
      current(record)
      record_exists(TRUE)
      update_batch_time("batch_start", record$metadata$batch_start)
      update_batch_time("batch_end", record$metadata$batch_end)
      shiny::updateNumericInput(session, "batch_output_amount", value = record$metadata$output_amount %||% NA_real_)
      shiny::updateTextInput(session, "batch_output_unit", value = record$metadata$output_unit %||% "")
      entry_closed(identical(record$metadata$data_entry_status, "finished"))
      search_status("Batch loaded.")
    }, error = function(e) {
      search_status(paste("Unable to load batch:", conditionMessage(e)))
      shiny::showNotification(conditionMessage(e), type = "error")
    })
  }
  shiny::observeEvent(input$search_batch, { search_selected_batch() })
  shiny::observeEvent(input$workspace_tabs, {
    if (identical(input$workspace_tabs, "visualization") && is_text(input$batch_id) && !isTRUE(view_ready()))
      search_selected_batch()
  }, ignoreInit = TRUE)
  output$batch_search_status <- shiny::renderText(search_status())
  output$view_ready <- shiny::reactive(view_ready())
  shiny::outputOptions(output, "view_ready", suspendWhenHidden = FALSE)

  entered_context <- function() {
    list(pilot_id = input$pilot, batch_id = trimws(input$batch_id %||% ""),
         batch_start = combine_batch_time(input$batch_start_date, input$batch_start_time),
         batch_end = combine_batch_time(input$batch_end_date, input$batch_end_time),
         output_amount = input$batch_output_amount, output_unit = input$batch_output_unit)
  }
  batch_ready <- shiny::reactive({
    record <- current()
    !isTRUE(entry_closed()) && !is.null(record) && !is.null(confirmed_context()) &&
      identical(confirmed_context(), entered_context()) &&
      identical(record$metadata$pilot_id, input$pilot) &&
      identical(record$metadata$batch_id, trimws(input$batch_id %||% ""))
  })

  # Called only after a successful disk write: preview the exact stored bytes.
  show_saved_json <- function(record, label) {
    last_saved(list(label = label, json = jsonlite::toJSON(record,
      pretty = TRUE, auto_unbox = TRUE, null = "null")))
  }
  output$last_saved_action <- shiny::renderText({
    if (is.null(last_saved())) "No save in this batch context yet." else last_saved()$label
  })
  output$last_saved_json <- shiny::renderText({
    shiny::req(last_saved())
    last_saved()$json
  })

  shiny::observeEvent(input$confirm_batch_context, {
    safely({
      id <- require_text(input$batch_id, "Batch number")
      # Re-read the selected file before changing its metadata, keeping categories.
      record <- load_batch_record(get_selected_pilot(), id)
      context <- entered_context()
      record <- save_batch_finalisation_inputs(record, context$batch_start, context$batch_end,
        context$output_amount, context$output_unit)
      record$metadata$batch_number <- id
      # Persist before submission so a local write failure cannot cause a remote retry.
      record$metadata$data_entry_status <- "open"
      record <- save_batch_record(record)
      current(record)
      record_exists(TRUE)
      entry_closed(FALSE)
      confirmed_context(entered_context())
      show_saved_json(record, "Batch details saved")
      delivery <- submit_batch_details(record)
      shiny::showNotification(if (delivery$status == "sent") "Batch details sent."
        else "Batch saved locally. API request prepared; not sent.", type = "message", duration = 8)
    })
  })

  shiny::observeEvent(input$finish_entry, {
    safely({
      if (!isTRUE(view_ready())) stop("Save or load a batch first.")
      pending_finish(list(pilot = input$pilot, batch = trimws(input$batch_id)))
      shiny::showModal(shiny::modalDialog(title = "Finish data entry?",
        "Saved records will be exported as Digital Tagging JSON. Unsaved form values are not included.",
        footer = shiny::tagList(shiny::modalButton("Cancel"),
          shiny::actionButton("confirm_finish_entry", "Finish", class = "btn-success"))))
    })
  })
  shiny::observeEvent(input$confirm_finish_entry, {
    safely({
      target <- pending_finish()
      if (is.null(target) || !identical(target$pilot, input$pilot) ||
          !identical(target$batch, trimws(input$batch_id))) stop("Batch changed. Please try again.")
      record <- get_selected_record()
      record$metadata$data_entry_status <- "finished"
      record <- save_batch_record(record)
      current(record)
      # Export the entire saved batch, not the four-field T4.2 request.
      path <- tryCatch(export_batch_to_project(record), error = function(e) {
        stop("Data saved, but JSON export failed. Please retry Finish data entry. ",
             conditionMessage(e), call. = FALSE)
      })
      export_result(list(pilot_id = record$metadata$pilot_id,
                         batch_id = record$metadata$batch_id, path = path))
      entry_closed(TRUE)
      confirmed_context(NULL)
      for (category in record_categories()) clear_edit(category)
      shiny::removeModal()
      shiny::updateTabsetPanel(session, "workspace_tabs", selected = "visualization")
      pending_finish(NULL)
      shiny::showNotification("Data entry finished. Digital Tagging JSON saved.", type = "message")
    })
  })
  reopen_information <- function() {
    safely({
      if (!isTRUE(view_ready())) stop("Search for an existing batch first.")
      record <- get_selected_record()
      context <- entered_context()
      set_batch_context(record, context$batch_start, context$batch_end)
      if (!identical(context$batch_start, record$metadata$batch_start) ||
          !identical(context$batch_end, record$metadata$batch_end))
        stop("Save the changed batch dates before updating information.")
      record$metadata$data_entry_status <- "open"
      record <- save_batch_record(record)
      current(record)
      entry_closed(FALSE)
      confirmed_context(context)
      shiny::updateTabsetPanel(session, "workspace_tabs", selected = "visualization")
      shiny::showNotification("Select a record and click Edit selected.", type = "message", duration = 7)
    })
  }
  shiny::observeEvent(input$update_information, { reopen_information() })
  shiny::observeEvent(input$update_from_view, { reopen_information() })

  output$batch_ready <- shiny::reactive({ batch_ready() })
  shiny::outputOptions(output, "batch_ready", suspendWhenHidden = FALSE)

  output$batch_context <- shiny::renderUI({
    if (!isTRUE(batch_ready())) return(NULL)
    shiny::span(class = "dt-saved-state", shiny::icon("check-circle"), "Batch saved")
  })

  # ==========================================================
  # RAW MATERIALS - Add a new manual material
  # ==========================================================
  shiny::observeEvent(input$add_rm, {
    safely({
      record <- get_current()
      item <- list(material_name = require_text(input$rm_name, "Material name"),
                   material_type = nonempty_or(input$rm_type),
                   material_batch = nonempty_or(input$rm_batch),
                   amount = input$rm_amount,
                   unit = require_text(input$rm_unit, "Material unit"),
                   notes = nonempty_or(input$rm_notes),
                   external_id = "", source = "manual")
      if (!is_finite_number(item$amount) || item$amount < 0) stop("Amount must be a non-negative number.")
      save_category_item("raw_materials", item, "Material saved")
    })
  })
  output$rm_table <- shiny::renderTable({
    shiny::req(view_ready())
    records_table(get_selected_record()$raw_materials,
                  c("material_name", "material_type", "material_batch", "amount", "unit", "source", "notes"))
  }, striped = TRUE, bordered = TRUE)

  # ==========================================================
  # PRODUCTION PROCESS - Dev parameter metamodel
  # ==========================================================

  # ----------------------------------------------------------
  # PROCESS STEP DROPDOWN
  # 1. Load the configured steps for the selected pilot.
  # 2. Include custom steps already used in THIS batch.
  # 3. Offer Other / Add new for anything not in the list.
  # Nothing here writes to MFT or modifies config/pilots.json.
  # ----------------------------------------------------------
  last_step_context <- shiny::reactiveVal(NULL)

  shiny::observeEvent(list(input$pilot, current()), {
    if (!is_text(input$pilot)) return()
    pilot <- get_selected_pilot()

    # Permanent pilot-specific catalogue (editable in pilots.json).
    configured_steps <- pilot_steps(pilot)
    configured_options <- if (length(configured_steps)) {
      stats::setNames(
        vapply(configured_steps, function(s) s$id, character(1)),
        vapply(configured_steps, function(s) s$name, character(1))
      )
    } else {
      character(0)
    }

    # Custom steps saved for the currently selected batch only.
    record <- current()
    saved_options <- character(0)
    if (!is.null(record) &&
        identical(record$metadata$pilot_id, input$pilot) &&
        identical(record$metadata$batch_id, trimws(input$batch_id %||% ""))) {
      for (entry in record$production_process %||% list()) {
        saved_id <- entry$step_id %||% ""
        saved_name <- entry$step_name %||% ""
        if (is_text(saved_id) && is_text(saved_name) &&
            !(saved_id %in% c(unname(configured_options), unname(saved_options)))) {
          saved_options <- c(saved_options, stats::setNames(saved_id, saved_name))
        }
      }
    }

    choices <- c(
      "Select a process step" = "",
      configured_options,
      saved_options,
      "Other / Add new" = "__other__"
    )

    # Reset on pilot/batch changes, but preserve the selected step
    # when saving another parameter within the same batch.
    context_key <- paste(input$pilot, trimws(input$batch_id %||% ""), sep = "::")
    existing_choice <- shiny::isolate(input$proc_step %||% "")
    selected_choice <- if (identical(last_step_context(), context_key) &&
                           existing_choice %in% unname(choices)) {
      existing_choice
    } else {
      ""
    }
    last_step_context(context_key)

    shiny::updateSelectInput(
      session,
      inputId = "proc_step",
      choices = choices,
      selected = selected_choice
    )
  }, ignoreInit = FALSE)

  # ----------------------------------------------------------
  # SAVE PARAMETER
  # ----------------------------------------------------------
  shiny::observeEvent(input$add_process, {
    safely({
      record <- get_current()
      # Selected values are step IDs, NOT names. Resolve them to
      # the correct name/id before storing the Process Parameter.
      selected_step <- require_text(input$proc_step, "Process step")

      if (identical(selected_step, "__other__")) {
        # The user wrote an unlisted process step.
        step_name <- require_text(input$proc_custom_step, "New process step")
        step_id <- slug_id(step_name)
      } else {
        # Configured step: take its id and name from pilots.json.
        configured_step <- get_step(get_selected_pilot(), selected_step)
        if (!is.null(configured_step)) {
          step_name <- configured_step$name
          step_id <- configured_step$id
        } else {
          # Previously saved custom step: resolve its name from
          # this batch, never from another pilot or batch.
          matching <- Filter(
            function(entry) identical(entry$step_id %||% "", selected_step),
            record$production_process %||% list()
          )
          if (!length(matching)) {
            stop("The selected process step is not available for this batch.")
          }
          step_name <- matching[[1L]]$step_name
          step_id <- selected_step
        }
      }

      machine_name <- nonempty_or(input$proc_machine)
      parameter_name <- require_text(input$proc_parameter, "Parameter")
      val_text <- require_text(input$proc_value, "Value")
      val_num <- suppressWarnings(as.numeric(gsub(",", ".", val_text, fixed = TRUE)))
      value <- if (is.finite(val_num)) val_num else val_text
      item <- list(
        batch_id = record$metadata$batch_id,
        step_id = step_id, step_name = step_name,
        machine_id = if (nzchar(machine_name)) slug_id(machine_name) else "",
        machine_name = machine_name,
        parameter_id = slug_id(parameter_name), parameter_name = parameter_name,
        value = value, unit = require_text(input$proc_unit, "Unit"),
        timestamp = optional_record_timestamp(input$proc_has_time, input$proc_timestamp),
        source = input$proc_source %||% "manual",
        notes = nonempty_or(input$proc_notes)
      )
      save_category_item("production_process", item, "Parameter saved")
      shiny::updateTextInput(session, "proc_value", value = "")
      shiny::updateTextInput(session, "proc_timestamp", value = "")
      shiny::updateCheckboxInput(session, "proc_has_time", value = FALSE)
    })
  })

  output$proc_table <- shiny::renderTable({
    shiny::req(view_ready())
    records_table(get_selected_record()$production_process,
                  c("step_name", "machine_name", "parameter_name", "value", "unit", "timestamp", "source", "notes"))
  }, striped = TRUE, bordered = TRUE)
  output$process_json <- shiny::renderText({
    shiny::req(view_ready())
    jsonlite::toJSON(build_process_model(get_selected_record()), pretty = TRUE, auto_unbox = TRUE, null = "null")
  })
  output$download_process <- shiny::downloadHandler(
    filename = function() paste0(safe_key(get_selected_record()$metadata$batch_id), "_process_model.json"),
    content = function(file) jsonlite::write_json(build_process_model(get_selected_record()), file,
                                                   auto_unbox = TRUE, pretty = TRUE, null = "null"),
    contentType = "application/json"
  )

  # ==========================================================
  # QUALITY CONTROL - Generic records
  # ==========================================================
  shiny::observeEvent(input$add_qc, {
    safely({
      record <- get_current()
      item <- list(check_name = require_text(input$qc_check, "Quality check"),
                   result = require_text(input$qc_result, "Result"),
                   unit = nonempty_or(input$qc_unit), status = input$qc_status,
                   timestamp = optional_record_timestamp(input$qc_has_time, input$qc_timestamp),
                   notes = nonempty_or(input$qc_notes), source = "manual")
      save_category_item("quality_control", item, "Quality check saved")
    })
  })
  output$qc_table <- shiny::renderTable({
    shiny::req(view_ready())
    records_table(get_selected_record()$quality_control, c("check_name", "result", "unit", "status", "timestamp", "notes"))
  }, striped = TRUE, bordered = TRUE)

  # ==========================================================
  # LOGISTICS - Generic records
  # ==========================================================
  shiny::observeEvent(input$add_log, {
    safely({
      record <- get_current()
      item <- list(event = require_text(input$log_event, "Logistics event"),
                   origin = nonempty_or(input$log_origin), destination = nonempty_or(input$log_destination),
                   amount = input$log_amount, unit = require_text(input$log_unit, "Logistics unit"),
                   timestamp = optional_record_timestamp(input$log_has_time, input$log_timestamp),
                   notes = nonempty_or(input$log_notes), source = "manual")
      if (!is_finite_number(item$amount) || item$amount < 0) stop("Quantity must be non-negative.")
      save_category_item("logistics", item, "Logistics event saved")
    })
  })
  output$log_table <- shiny::renderTable({
    shiny::req(view_ready())
    records_table(get_selected_record()$logistics, c("event", "origin", "destination", "amount", "unit", "timestamp", "notes"))
  }, striped = TRUE, bordered = TRUE)

  # ==========================================================
  # SUSTAINABILITY - Generic indicators
  # ==========================================================
  shiny::observeEvent(input$add_sus, {
    safely({
      record <- get_current()
      item <- list(indicator = require_text(input$sus_indicator, "Sustainability indicator"),
                   value = input$sus_value, unit = require_text(input$sus_unit, "Unit"),
                   method = nonempty_or(input$sus_method),
                   timestamp = optional_record_timestamp(input$sus_has_time, input$sus_timestamp),
                   notes = nonempty_or(input$sus_notes), source = "manual")
      if (!is_finite_number(item$value)) stop("Value must be numeric.")
      save_category_item("sustainability", item, "Indicator saved")
    })
  })
  output$sus_table <- shiny::renderTable({
    shiny::req(view_ready())
    records_table(get_selected_record()$sustainability, c("indicator", "value", "unit", "method", "timestamp", "notes"))
  }, striped = TRUE, bordered = TRUE)

  # ==========================================================
  # RECORD MANAGEMENT - Select / Edit / Update / Delete
  # The controls are in Data Visualization and use local JSON.
  # ==========================================================

  # Populate a category's form when editing an existing record.
  populate_form <- function(category, item) {
    txt <- function(x) if (is.null(x) || length(x) == 0L) "" else as.character(x[[1L]])
    num <- function(x) if (is_finite_number(x)) x else NA_real_
    if (identical(category, "raw_materials")) {
      shiny::updateTextInput(session, "rm_name", value = txt(item$material_name))
      shiny::updateTextInput(session, "rm_type", value = txt(item$material_type))
      shiny::updateTextInput(session, "rm_batch", value = txt(item$material_batch))
      shiny::updateNumericInput(session, "rm_amount", value = num(item$amount))
      shiny::updateTextInput(session, "rm_unit", value = txt(item$unit))
      shiny::updateTextInput(session, "rm_notes", value = txt(item$notes))
    } else if (identical(category, "production_process")) {
      # Stored step IDs (configured or custom) are already available
      # in the selectInput choices for the selected pilot/batch.
      shiny::updateSelectInput(session, "proc_step", selected = txt(item$step_id))
      shiny::updateTextInput(session, "proc_custom_step", value = txt(item$step_name))
      shiny::updateTextInput(session, "proc_machine", value = txt(item$machine_name))
      shiny::updateTextInput(session, "proc_parameter", value = txt(item$parameter_name))
      shiny::updateTextInput(session, "proc_value", value = txt(item$value))
      shiny::updateTextInput(session, "proc_unit", value = txt(item$unit))
      shiny::updateCheckboxInput(session, "proc_has_time", value = is_text(item$timestamp))
      shiny::updateTextInput(session, "proc_timestamp", value = txt(item$timestamp))
      shiny::updateSelectInput(session, "proc_source", selected = txt(item$source))
      shiny::updateTextInput(session, "proc_notes", value = txt(item$notes))
    } else if (identical(category, "quality_control")) {
      shiny::updateTextInput(session, "qc_check", value = txt(item$check_name))
      shiny::updateTextInput(session, "qc_result", value = txt(item$result))
      shiny::updateTextInput(session, "qc_unit", value = txt(item$unit))
      shiny::updateSelectInput(session, "qc_status", selected = txt(item$status))
      shiny::updateCheckboxInput(session, "qc_has_time", value = is_text(item$timestamp))
      shiny::updateTextInput(session, "qc_timestamp", value = txt(item$timestamp))
      shiny::updateTextInput(session, "qc_notes", value = txt(item$notes))
    } else if (identical(category, "logistics")) {
      shiny::updateTextInput(session, "log_event", value = txt(item$event))
      shiny::updateTextInput(session, "log_origin", value = txt(item$origin))
      shiny::updateTextInput(session, "log_destination", value = txt(item$destination))
      shiny::updateNumericInput(session, "log_amount", value = num(item$amount))
      shiny::updateTextInput(session, "log_unit", value = txt(item$unit))
      shiny::updateCheckboxInput(session, "log_has_time", value = is_text(item$timestamp))
      shiny::updateTextInput(session, "log_timestamp", value = txt(item$timestamp))
      shiny::updateTextInput(session, "log_notes", value = txt(item$notes))
    } else if (identical(category, "sustainability")) {
      shiny::updateTextInput(session, "sus_indicator", value = txt(item$indicator))
      shiny::updateNumericInput(session, "sus_value", value = num(item$value))
      shiny::updateTextInput(session, "sus_unit", value = txt(item$unit))
      shiny::updateTextInput(session, "sus_method", value = txt(item$method))
      shiny::updateCheckboxInput(session, "sus_has_time", value = is_text(item$timestamp))
      shiny::updateTextInput(session, "sus_timestamp", value = txt(item$timestamp))
      shiny::updateTextInput(session, "sus_notes", value = txt(item$notes))
    }
  }

  # Common behaviour but independent selectors in each category.
  management_specs <- list(
    list(category = "raw_materials", prefix = "rm", entry_tab = "raw"),
    list(category = "production_process", prefix = "proc", entry_tab = "process"),
    list(category = "quality_control", prefix = "qc", entry_tab = "quality"),
    list(category = "logistics", prefix = "log", entry_tab = "logistics"),
    list(category = "sustainability", prefix = "sus", entry_tab = "sustainability")
  )

  for (spec in management_specs) {
    local({
      category <- spec$category
      prefix <- spec$prefix
      entry_tab <- spec$entry_tab
      select_id <- paste0(prefix, "_selected_record")
      edit_id <- paste0("edit_", prefix)
      delete_id <- paste0("delete_", prefix)
      cancel_id <- paste0("cancel_edit_", prefix)
      manager_output <- paste0(prefix, "_manage_ui")
      notice_output <- paste0(prefix, "_edit_notice")

      output[[manager_output]] <- shiny::renderUI({
        if (!isTRUE(view_ready())) return(NULL)
        if (!isTRUE(batch_ready())) return(shiny::p("Select Update information to edit saved records."))
        record <- current()
        entries <- record[[category]] %||% list()
        if (!length(entries)) return(
          shiny::div(class = "dt-record-manager", "No records added yet.")
        )
        ids <- vapply(entries, function(item) item$record_id %||% "", character(1))
        if (any(!nzchar(ids))) return(
          shiny::div(class = "dt-record-manager",
                     "Some legacy records have no record ID. Please export a JSON backup before editing.")
        )
        names(ids) <- vapply(seq_along(entries), function(i) {
          record_display_label(entries[[i]], category, i)
        }, character(1))
        shiny::div(class = "dt-record-manager",
          shiny::selectInput(select_id, "Select a record to manage", choices = ids),
          shiny::actionButton(edit_id, "Edit selected", icon = shiny::icon("edit"),
                              class = "btn-default"),
          shiny::actionButton(delete_id, "Delete selected", icon = shiny::icon("trash"),
                              class = "btn-default")
        )
      })

      output[[notice_output]] <- shiny::renderUI({
        selected <- active_edit_id(category)
        if (is.null(selected)) return(NULL)
        shiny::div(class = "dt-edit-notice",
          shiny::icon("edit"),
          " Editing an existing record. The Save button will update it.",
          shiny::actionButton(cancel_id, "Cancel editing", class = "btn-default")
        )
      })

      shiny::observeEvent(input[[edit_id]], {
        safely({
          record <- get_current()
          selected <- require_text(input[[select_id]], "Record")
          entry <- find_category_record(record, category, selected)
          if (identical(entry$source %||% "", "MFT")) {
            stop("MFT-imported records can only be edited in MFT.")
          }
          editing[[category]] <- list(record_id = selected,
                                     pilot_id = input$pilot,
                                     batch_id = trimws(input$batch_id))
          populate_form(category, entry)
          shiny::updateActionButton(session, category_buttons[[category]]$button,
                                    label = "Update record")
          # Editing starts in the visualization tab. Move to the
          # corresponding form so the populated fields are visible.
          shiny::updateTabsetPanel(session, "workspace_tabs", selected = "entry")
          shiny::updateTabsetPanel(session, "category_tabs", selected = entry_tab)
          shiny::showNotification("Editing selected record. Change values and click Update record.",
                                  type = "message", duration = 5)
        })
      })

      shiny::observeEvent(input[[cancel_id]], {
        clear_edit(category)
      })

      shiny::observeEvent(input[[delete_id]], {
        safely({
          record <- get_current()
          selected <- require_text(input[[select_id]], "Record")
          entry <- find_category_record(record, category, selected)
          if (identical(entry$source %||% "", "MFT")) {
            stop("MFT-imported records must be managed in MFT.")
          }
          pending_delete(list(category = category, record_id = selected,
                              pilot_id = input$pilot,
                              batch_id = trimws(input$batch_id)))
          shiny::showModal(shiny::modalDialog(
            title = "Delete selected record?",
            shiny::p("This will remove the record from the local JSON for this batch."),
            shiny::p(record_display_label(entry, category, 1L)),
            footer = shiny::tagList(
              shiny::modalButton("Cancel"),
              shiny::actionButton("confirm_delete_record", "Delete record",
                                  class = "btn-danger")
            ), easyClose = TRUE
          ))
        })
      })
    })
  }

  # Deletion is confirmed explicitly; never delete on selection alone.
  shiny::observeEvent(input$confirm_delete_record, {
    safely({
      target <- pending_delete()
      if (is.null(target)) return()
      record <- get_current()
      if (!identical(input$pilot, target$pilot_id) ||
          !identical(trimws(input$batch_id), target$batch_id)) {
        stop("Batch changed. Delete operation cancelled.")
      }
      revised <- remove_from_category(record, target$category, target$record_id)
      persist(revised, "Record deleted")
      if (identical(active_edit_id(target$category), target$record_id)) {
        clear_edit(target$category)
      }
      pending_delete(NULL)
      shiny::removeModal()
    })
  })

  # ==========================================================
  # DOWNLOAD LOCAL JSON FOR THE SELECTED PILOT / BATCH
  # This is a copy of the same record we store in data/local/:
  # metadata + all five categories (including full parameter
  # entries). No QR generation and no AAS / MFT API call.
  # ==========================================================
  export_result <- shiny::reactiveVal(NULL)
  save_project_export <- function() {
    safely({
      if (!isTRUE(view_ready())) stop("Save or load an existing batch before exporting.")
      record <- get_selected_record()
      path <- export_batch_to_project(record)
      export_result(list(pilot_id = record$metadata$pilot_id,
                         batch_id = record$metadata$batch_id, path = path))
      shiny::showNotification("JSON saved in the project exports folder.", type = "message", duration = 8)
    })
  }
  shiny::observeEvent(input$save_entry_json, { save_project_export() })
  shiny::observeEvent(input$save_view_json, { save_project_export() })
  export_message <- function() {
    result <- export_result()
    if (is.null(result) || !identical(result$pilot_id, input$pilot) ||
        !identical(result$batch_id, trimws(input$batch_id %||% ""))) return("")
    "JSON saved."
  }
  output$entry_export_path <- shiny::renderText(export_message())
  output$view_export_path <- shiny::renderText(export_message())

  output$download_batch_json <- shiny::downloadHandler(
    filename = function() {
      record <- get_selected_record()  # ensures valid pilot and Batch ID
      paste0(
        "DigitalTagging_",
        safe_key(record$metadata$pilot_id), "_",
        safe_key(record$metadata$batch_id), ".json"
      )
    },
    content = function(file) {
      record <- get_selected_record()
      jsonlite::write_json(
        record, path = file,
        pretty = TRUE, auto_unbox = TRUE, null = "null"
      )
    },
    contentType = "application/json"
  )

  # ==========================================================
  # OPTIONAL MFT INTEGRATION - only enabled if URL exists
  # ==========================================================
  shiny::observeEvent(input$import_mft, {
    safely({
      record <- get_current()
      if (!mft_is_configured()) stop("MFT is not configured; no request was sent.")
      result <- get_mft_batch(record$metadata$batch_id)
      if (is_text(result$id) && !identical(result$id, record$metadata$batch_id)) {
        stop("MFT returned a different batch ID.")
      }
      merged <- merge_materials_from_mft(record, result)
      persist(merged$record, paste(merged$count, "new materials imported from MFT."))
    })
  })
  # ==========================================================
  # PROTOTYPE TAG COMPLETENESS / SUMMARY
  # The denominator is configurable for every pilot in
  # config/completeness_rules.json. It is NOT an official KPI.
  # ==========================================================
  output$tag_completeness <- shiny::renderUI({
    if (!isTRUE(view_ready())) return(NULL)
    record <- get_selected_record()
    info <- tag_completeness(record, completeness_cfg)
    chips <- lapply(names(info$populated), function(category) {
      filled <- isTRUE(info$populated[[category]])
      shiny::tags$span(
        class = paste("dt-complete-chip", if (!filled) "is-missing"),
        paste0(category_display_name(category), if (filled) " - filled" else " - missing")
      )
    })
    shiny::div(class = "dt-complete-card",
      shiny::div(class = "dt-complete-percent", paste0(info$percentage, "%")),
      shiny::div(class = "dt-complete-title", "Tag completeness"),
      shiny::div(class = "dt-complete-sub",
                 paste(info$completed, "of", info$total,
                       "configured sections contain local records."),
                 " Prototype indicator; not a validated pilot KPI."),
      shiny::tags$div(class = "dt-complete-track", role = "progressbar",
        `aria-valuenow` = as.character(info$percentage),
        `aria-valuemin` = "0", `aria-valuemax` = "100",
        shiny::div(class = "dt-complete-bar",
                   style = paste0("width:", info$percentage, "%;"))
      ),
      shiny::div(class = "dt-complete-badges", shiny::tagList(chips))
    )
  })

  output$record_summary <- shiny::renderUI({
    if (!isTRUE(view_ready())) return(NULL)
    record <- get_selected_record()
    fields <- record_categories()
    cards <- lapply(fields, function(category) {
      shiny::div(class = "dt-overview-stat",
        shiny::tags$strong(length(record[[category]] %||% list())),
        shiny::tags$span(category_display_name(category))
      )
    })
    shiny::tagList(
      shiny::tags$p(shiny::tags$b("Pilot: "), record$metadata$pilot_name,
                    "   |   ", shiny::tags$b("Batch number: "), record$metadata$batch_id,
                    "   |   ", shiny::tags$b("Start (UTC): "), record$metadata$batch_start,
                    "   |   ", shiny::tags$b("End (UTC): "), record$metadata$batch_end,
                    "   |   ", shiny::tags$b("Updated: "),
                    record$metadata$updated_at %||% "Not saved yet"),
      shiny::div(class = "dt-overview-counts", shiny::tagList(cards))
    )
  })

  # ==========================================================
  # QR PREVIEW FROM INDEPENDENT QR API
  # QR only requested when the user clicks Preview QR (API).
  # The response image lives in session memory, not in data/local.
  # ==========================================================
  qr_context_ok <- shiny::reactive({
    cached <- qr_cache()
    isTRUE(view_ready()) && !is.null(cached) &&
      identical(cached$pilot_id, input$pilot) &&
      identical(cached$batch_id, trimws(input$batch_id))
  })
  output$qr_ready <- shiny::reactive({ qr_context_ok() })
  shiny::outputOptions(output, "qr_ready", suspendWhenHidden = FALSE)

  shiny::observeEvent(input$preview_qr, {
    safely({
      record <- get_selected_record()
      qr_cache(NULL)
      bytes <- get_batch_qr(record$metadata$batch_id)
      qr_cache(list(pilot_id = input$pilot,
                    batch_id = record$metadata$batch_id, png = bytes))
      shiny::showNotification("QR ready.",
                              type = "message", duration = 4)
    })
  })

  output$qr_status <- shiny::renderUI({
    if (!isTRUE(view_ready())) return(NULL)
    shiny::div(class = "dt-qr-status",
      if (isTRUE(qr_context_ok())) "QR ready to view and download."
      else "Click Show QR to generate the batch code.")
  })

  output$qr_preview <- shiny::renderImage({
    shiny::req(qr_context_ok())
    cached <- qr_cache()
    image_path <- tempfile(fileext = ".png")
    writeBin(cached$png, image_path)
    list(src = image_path, contentType = "image/png", width = 210, height = 210,
         alt = paste("QR for", cached$batch_id))
  }, deleteFile = TRUE)

  output$download_qr_png <- shiny::downloadHandler(
    filename = function() {
      shiny::req(qr_context_ok())
      paste0("QR_", safe_key(qr_cache()$batch_id), ".png")
    },
    content = function(file) {
      shiny::req(qr_context_ok())
      writeBin(qr_cache()$png, file)
    },
    contentType = "image/png"
  )
}
