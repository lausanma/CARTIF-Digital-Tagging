# Dev/Fraunhofer-inspired hierarchical Process Parameter Model.
# Process -> Steps -> [Step Parameters] + [Optional Machines -> Machine Parameters]
# Prototype extensions: each parameter has id/name/source; each value has time/value.
# No sensor values are fetched here.

append_parameter_value <- function(parameters, p) {
  parameter_key <- paste(p$parameter_id, p$unit, sep = "::")
  index <- which(vapply(parameters, function(x) paste(x$id, x$unit, sep = "::"), character(1)) == parameter_key)
  new_value <- list(time = p$timestamp,
                    time_scope = p$time_scope %||% if (is_text(p$timestamp)) "measurement_or_event" else "batch",
                    value = p$value,
                    batch_id = p$batch_id, source = p$source)
  if (!length(index)) {
    parameters[[length(parameters) + 1L]] <- list(
      id = p$parameter_id, name = p$parameter_name,
      unit = p$unit, values = list(new_value)
    )
  } else {
    i <- index[[1L]]
    parameters[[i]]$values[[length(parameters[[i]]$values) + 1L]] <- new_value
  }
  parameters
}

build_process_model <- function(record) {
  model <- list(id = record$metadata$process_id,
                batch_context = list(batch_id = record$metadata$batch_id,
                  start = record$metadata$batch_start, end = record$metadata$batch_end),
                steps = list())
  entries <- record$production_process %||% list()
  for (p in entries) {
    step_index <- which(vapply(model$steps, function(s) identical(s$id, p$step_id), logical(1)))
    if (!length(step_index)) {
      model$steps[[length(model$steps) + 1L]] <- list(
        id = p$step_id, name = p$step_name, parameters = list(), machines = list()
      )
      step_index <- length(model$steps)
    }
    si <- step_index[[1L]]
    machine_id <- p$machine_id %||% ""
    if (!nzchar(machine_id)) {
      model$steps[[si]]$parameters <- append_parameter_value(model$steps[[si]]$parameters, p)
    } else {
      machines <- model$steps[[si]]$machines
      machine_index <- which(vapply(machines, function(m) identical(m$id, machine_id), logical(1)))
      if (!length(machine_index)) {
        machines[[length(machines) + 1L]] <- list(
          id = machine_id, name = p$machine_name, parameters = list()
        )
        machine_index <- length(machines)
      }
      mi <- machine_index[[1L]]
      machines[[mi]]$parameters <- append_parameter_value(machines[[mi]]$parameters, p)
      model$steps[[si]]$machines <- machines
    }
  }
  model
}

virtual_sensor_candidates <- function(record) {
  # Export-only staging format. It is NOT the DCOF measurement API contract.
  fields <- c("pilot_id", "process_id", "batch_id", "step_id", "machine_id",
              "parameter_id", "parameter_name", "timestamp", "value", "unit", "source")
  values <- list()
  for (p in record$production_process %||% list()) {
    # A batch-level value cannot be represented as a timed sensor observation.
    if (!valid_iso_time(p$timestamp)) next
    val <- suppressWarnings(as.numeric(p$value))
    if (is.na(val) || !is.finite(val)) next
    values[[length(values) + 1L]] <- list(
      pilot_id = record$metadata$pilot_id,
      process_id = record$metadata$process_id,
      batch_id = p$batch_id,
      step_id = p$step_id,
      machine_id = p$machine_id %||% "",
      parameter_id = p$parameter_id,
      parameter_name = p$parameter_name,
      timestamp = p$timestamp,
      value = val,
      unit = p$unit,
      source = p$source
    )
  }
  result <- records_table(values, fields)
  if (nrow(result)) result$value <- as.numeric(result$value)
  result
}
