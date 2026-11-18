# Integration boundary: canonical batch JSON in, canonical batch JSON out.
# No remote endpoint/schema is assumed. Register validated functions at startup.
# A reader may aggregate Process DT, DCOF and other agreed sources.
# A writer must target only the agreed repository (not Batch DT implicitly).
repository_adapters <- new.env(parent = emptyenv())
register_batch_adapter <- function(name, read = NULL, write = NULL) {
  if (!is_text(name) || identical(name, "local")) stop("Choose a non-local adapter name.")
  if (!is.null(read) && !is.function(read)) stop("read must be a function.")
  if (!is.null(write) && !is.function(write)) stop("write must be a function.")
  assign(name, list(read = read, write = write), envir = repository_adapters)
  invisible(name)
}

resolve_batch_adapter <- function(name, operation) {
  if (identical(name, "local")) {
    return(if (operation == "read") local_load_batch_record else local_save_batch_record)
  }
  if (!exists(name, envir = repository_adapters, inherits = FALSE))
    stop("Batch adapter '", name, "' is not configured. No fallback or write was performed.")
  fun <- get(name, envir = repository_adapters, inherits = FALSE)[[operation]]
  if (!is.function(fun)) stop("Adapter does not implement ", operation, ".")
  fun
}

batch_repository <- function() {
  # Independent selection permits different origins and destinations.
  # If different, reader must include the saved destination in its merged view.
  reader <- Sys.getenv("DIGITAL_TAGGING_READ_ADAPTER", unset = "local")
  writer <- Sys.getenv("DIGITAL_TAGGING_WRITE_ADAPTER", unset = "local")
  list(read = function(pilot, batch_id) resolve_batch_adapter(reader, "read")(pilot, batch_id),
       write = function(record) resolve_batch_adapter(writer, "write")(record))
}

validate_repository_record <- function(record, pilot_id, batch_id) {
  if (!is.list(record) || !is.list(record$metadata) ||
      !identical(record$metadata$pilot_id, pilot_id) ||
      !identical(record$metadata$batch_id, batch_id)) {
    stop("Adapter returned a different pilot/batch or an invalid record.")
  }
  for (category in record_categories()) {
    if (!is.null(record[[category]]) && !is.list(record[[category]]))
      stop("Invalid category returned by adapter: ", category)
  }
  invisible(record)
}

# Optional deployment-owned registration script. No credentials in source code.
initialize_batch_adapters <- function() {
  path <- Sys.getenv("DIGITAL_TAGGING_ADAPTER_SCRIPT", unset = "")
  if (!nzchar(path)) return(invisible(NULL))
  if (!file.exists(path)) stop("Configured adapter script does not exist.")
  sys.source(path, envir = environment(register_batch_adapter))
  invisible(NULL)
}
