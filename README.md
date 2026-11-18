# bi0SpaCE — Digital Tagging Dashboard
## User and developer guide

**Component:** WP4, Task 4.3 — Digital Tagging  
**Organisation:** CARTIF  
**Application:** R / Shiny prototype, v0.5.1 corrected package  
**Documentation updated:** 18 November 2026

This guide describes the implementation in the latest available corrected dashboard package. It replaces the earlier README, which contained historical instructions that no longer matched the application. Some older comments and supporting documents still use previous button names or describe an API-only QR workflow. For the current workflow, follow this guide.

## Contents

1. [Purpose and implementation status](#1-purpose-and-implementation-status)
2. [Install and start the dashboard](#2-install-and-start-the-dashboard)
3. [Understand the main buttons](#3-understand-the-main-buttons)
4. [Enter information for a batch](#4-enter-information-for-a-batch)
5. [Search, review and update information](#5-search-review-and-update-information)
6. [Finish data entry](#6-finish-data-entry)
7. [Understand JSON files and exports](#7-understand-json-files-and-exports)
8. [Generate and download a QR code](#8-generate-and-download-a-qr-code)
9. [Configure pilots and completeness](#9-configure-pilots-and-completeness)
10. [Connect future data sources and destinations](#10-connect-future-data-sources-and-destinations)
11. [Configuration reference](#11-configuration-reference)
12. [Project structure](#12-project-structure)
13. [Worked example: Fiskeby](#13-worked-example-fiskeby)
14. [Troubleshooting](#14-troubleshooting)
15. [Verification and remaining work](#15-verification-and-remaining-work)

## 1. Purpose and implementation status

The dashboard helps pilot users enter, review and update additional information associated with a batch. Its intended contribution is to manage useful information that is not already captured by other bi0SpaCE components, and make that information available alongside batch and process data.

The interface has two main tabs:

- **Data Entry:** enter batch details and save records in five information categories.
- **Data Visualization:** search for a batch, review its saved records, select records for editing, download data and display its QR code.

The five categories are Raw Materials, Production Process, Quality Control, Logistics and Sustainability.

The default application is a **local prototype**. It stores JSON files in the project and generates QR images locally. Its integration functions separate the interface from future repositories, but they do not constitute a completed connection to the bi0SpaCE platform.

| Capability | Status in this package |
| --- | --- |
| Enter, view, edit and delete additional records | Implemented using local JSON storage by default |
| Search for an existing batch | Implemented through the selected read adapter; local files by default |
| Save batch details | Saves the working record and prepares a four-field request; remote delivery needs a configured callback |
| Finish data entry | Saves the local entry status and exports the complete record |
| Export the complete Digital Tagging record | Implemented |
| Export a hierarchical process model | Implemented as prototype JSON |
| Display and download a QR image | Implemented locally; optional HTTP API mode |
| Import materials from MFT | Optional GET client with a specific expected response; deployment compatibility must be checked |
| Read/write Process DT or Batch DT via AAS | Adapter extension points exist; actual mappings and HTTP operations are not implemented |
| Read historical sensor data from DCOF | Not implemented |
| Handle missing UserProvided values requested by Batch DT Creator | Not implemented |
| Trigger real Batch DT creation or generate a DPP | Not implemented |

**Terminology:** MFT means Material Flow Tracing, associated with T4.2. DT means Digital Twin. DCOF means Data Collection and Observation Framework. AAS means Asset Administration Shell. DPP means Digital Product Passport.

### Batch number versus technical batch ID

The visible field is **Batch number**. For compatibility with earlier local files, the application still uses `metadata.batch_id` as its local batch key and adds `metadata.batch_number` when Save batch is used.

This does not prove that the entered number is a valid technical MFT identifier. A future integration must resolve or validate that relationship. `metadata.external_batch_id` is reserved for an external technical identifier when available; the local dashboard does not obtain it automatically.

## 2. Install and start the dashboard

### Requirements

Use a computer with R and, preferably, RStudio. The supplied development Dockerfiles use R 4.4.2; this is not a statement that all other R versions have been tested.

The installation script installs these packages if they are missing:

`shiny`, `shinydashboard`, `jsonlite`, `qrcode`, `png`, `uuid`, `plumber`, `httr2`.

Internet access is needed to install packages. With packages installed and the default local settings, normal data entry, local exports and QR generation do not require an external API.

### First start in RStudio

1. Extract the **entire ZIP** into a writable folder. Do not run files inside the ZIP.
2. Open `DigitalTagging_API_Demo.Rproj` from the extracted folder.
3. In the R console, install missing packages:

```r
source("install_packages.R")
```

4. Start the dashboard:

```r
source("run_app.R")
```

5. Open `http://127.0.0.1:3838` if the browser does not open automatically.

The application occupies that R session while it is running. Use RStudio's Stop button or Escape in the console to stop it before restarting.

You can also start from a terminal opened in the project folder:

```sh
Rscript run_app.R
```

### Keep existing data when changing versions

Before replacing a project folder, back up `data/local/` and `exports/`. Copy your working JSON records from the old `data/local/` into the new project's corresponding folder. If you configured a different data directory, back up that directory instead.

Do not replace your saved data with an empty folder from a new package. The folders may be created automatically when the application first saves data.

## 3. Understand the main buttons

| Button | What it does | What it does not do |
| --- | --- | --- |
| **Save batch** | Validates and saves the batch context; prepares or submits the limited batch-details payload | Does not save unfinished category forms or automatically create a real Batch DT |
| **Save material / Save parameter / Save check / Save event / Save indicator** | Saves one record in the selected category | Does not automatically create an export snapshot |
| **Search** | Reads the selected pilot and batch through the configured reader | Does not create a missing batch |
| **Update information** | Reopens the saved batch for editing | Does not itself change a selected record or send the T4.2 payload |
| **Edit selected** | Opens the chosen record in its Data Entry form | Does not save changes until Update record is clicked |
| **Update record** | Saves changes to the record being edited | Does not add a new record |
| **Delete selected** | Opens a confirmation dialog before deleting a record | Does not permit local deletion of MFT-sourced records |
| **Finish data entry** | Saves the finished entry status, exports the full Digital Tagging JSON and opens visualization | Does not finalize a real batch in MFT or trigger Batch DT Creator |
| **Save JSON** | Creates a complete JSON snapshot in the project's exports folder | Does not send the snapshot to another component |
| **Download JSON** | Downloads the complete record through the browser | Does not choose the project folder automatically |
| **Show QR / Download QR** | Generates a preview and downloads the resulting PNG | Does not store the QR in a Batch DT |

The **Save JSON** button is in Data Entry. Data Visualization offers **Download JSON** instead.

## 4. Enter information for a batch

### Step 1 — Save the batch context

In **Data Entry**, select the pilot and enter:

| Field | Requirement |
| --- | --- |
| Pilot | Select Naturae, Fiskeby, Noriware or GreenLab |
| Batch number | Enter a non-empty batch reference |
| Start date and time | Required, in UTC |
| End date and time | Required, in UTC, strictly later than the start |
| Output amount | Required, finite numeric value greater than or equal to zero |
| Output unit | Required text, such as kg or L |

Time controls accept a suggested time or a typed value in `HH:MM` or `HH:MM:SS` format. These times are interpreted as UTC, not automatically converted from your local time zone.

Click **Save batch**. In default local mode, the notification says that the batch was saved locally and the API request was prepared but not sent. This is expected.

Saving this context enables category entry. Changing the context can require saving it again before further records can be entered. Changing the pilot clears the selected batch number to prevent accidental reuse.

### Step 2 — Save each category record

Each category can contain multiple records. Save each form separately before moving on.

| Category | Information to enter | Main validation |
| --- | --- | --- |
| Raw Materials | Material name, type, source batch, amount, unit and notes | Name and unit required; amount must be non-negative |
| Production Process | Process step, optional machine, parameter, value, unit, source and notes | Step, parameter, value and unit required |
| Quality Control | Check name, result, unit, status and notes | Check name and result required |
| Logistics | Event, origin, destination, quantity, unit and notes | Event and unit required; quantity must be non-negative |
| Sustainability | Indicator, value, unit, source/method and notes | Indicator and unit required; value must be finite and numeric |

For Production Process, select a configured step or **Other / Add new**. Custom steps are retained in that batch's records; entering one does not rewrite the pilot configuration file. A machine is optional: a parameter can belong directly to a process step.

Process values can be numeric or text. Choosing a source label does not connect the dashboard to a sensor or automatically collect data. Quality status is supplied by the user; the dashboard does not independently verify laboratory limits.

### Batch-level values and specific measurements

For process, quality, logistics and sustainability records, a specific time is optional.

- Leave the time option off when the value describes the batch as a whole.
- Enable **Add a specific measurement / event time (optional)** only when a real measurement or event time is known.
- Enter that time as `YYYY-MM-DDTHH:MM:SSZ`, for example `2026-11-18T09:30:00Z`.

Batch-level values use `time_scope: "batch"`. Where a timestamp field is present, it is null when no specific time was supplied. Timed records use `time_scope: "measurement_or_event"`.

The system also creates technical record creation/update times. These indicate when information was saved, not when a measurement happened. The application does not invent measurement times from batch start or save time.

## 5. Search, review and update information

### Review an existing batch

1. Open **Data Visualization**.
2. Select the pilot and enter its **Batch number**.
3. Click **Search**.
4. Review the overview and the category tables.

Searching does not require entering new start/end dates or clicking Save batch. It can load a batch entered in the current session or a previously saved batch. A future reader can also load records from an agreed external source.

With the default local reader, only locally saved records are available. Typing an external batch number does not automatically query Process DT, Batch DT or DCOF.

### Update an existing record

1. Search for the batch.
2. Click **Update information**.
3. In the relevant category, select the record to manage.
4. Click **Edit selected**.
5. The matching Data Entry form opens with the saved values.
6. Make the changes and click **Update record**.

Use **Cancel editing** to leave edit mode without saving the form. To add a new record, ensure you are no longer editing an existing one and use the normal category save button.

Update information requires valid saved start/end dates. If you change those dates, save the new batch details before updating its records. Older records without the required context may need their context completed first.

### Delete a record

After reopening the batch, select a record and click **Delete selected**, then confirm. Deletion changes the working record; there is no undo button. Previously created export files are separate snapshots.

Records marked `source: "MFT"` cannot be edited or deleted locally. Changes to those records must be made at their authoritative source.

## 6. Finish data entry

When you want to stop entering information:

1. Save each form you want to keep.
2. Click **Finish data entry**.
3. Read the confirmation and click **Finish**.

The dashboard saves `metadata.data_entry_status = "finished"`, creates a full JSON export in `exports/`, closes the current entry mode and switches to Data Visualization.

**Unsaved form values are not included.** You do not have to fill all five categories before finishing. The prototype does not enforce a consortium-approved completeness threshold.

Finishing is reversible through **Update information**, which sets the entry status back to `"open"`. Neither status is an official production status or proof of Batch DT creation.

## 7. Understand JSON files and exports

There are several different outputs. They serve different purposes.

| Output | Location | Content | Trigger |
| --- | --- | --- | --- |
| Working batch record | `data/local/<pilot>__<batch>.json` by default | Metadata and all five categories | Save batch, category saves, updates and other persistence actions |
| Batch-details request | `exports/batch_requests/batch_details_*.json` in default mode | Only start, end, outputAmount and outputUnit | Save batch when no submission callback is registered |
| Full Digital Tagging snapshot | `exports/DigitalTagging_<pilot>_<batch>_<time>_<suffix>.json` | Full saved record | Save JSON or Finish data entry |
| Browser JSON download | Browser-selected download location | Full saved record | Download JSON |
| Process model download | Browser-selected download location | Process, steps, optional machines and parameter values | Export process JSON |
| QR download | Browser-selected download location | PNG image | Download QR |

### The four-field request

The request intended for the agreed batch-details integration contains only:

```json
{
  "start": "2026-11-18T08:00:00Z",
  "end": "2026-11-18T12:00:00Z",
  "outputAmount": 1000,
  "outputUnit": "kg"
}
```

It does not include quality checks, logistics, sustainability or other Digital Tagging records. Batch identity is supplied separately to the integration callback. The final receiving endpoint and number-to-ID mapping still need to be configured.

### The complete Digital Tagging record

The full export contains these top-level fields:

```json
{
  "schema_version": "prototype-0.1.0",
  "metadata": {},
  "raw_materials": [],
  "production_process": [],
  "quality_control": [],
  "logistics": [],
  "sustainability": []
}
```

This is an outline, not a valid completed batch example. Actual metadata contains the selected pilot, batch reference, process reference, batch interval, output quantity and technical timestamps. Category arrays contain the individual saved records.

Record identifiers are generated automatically. Updating a record preserves its identifier and creation time and adds an update time. The working JSON is replaced when the batch changes; exports receive unique filenames so previous snapshots remain available.

The full export contains the flat production-process records used by the forms. **Export process JSON** builds a separate hierarchical view: process → steps → step parameters and/or machines → machine parameters. This is prototype modelling, not an AAS-compliant export or an uploaded Process DT.

### Important storage behaviour

The full JSON, the four-field request and the QR PNG are separate artifacts. The PNG is not embedded in the JSON. Saving a category updates the working record but does not create a fresh export snapshot.

Exporting or downloading a JSON file does not mean that data has been delivered to T4.2, Process DT, Batch DT or a DPP service.

## 8. Generate and download a QR code

### Default: local generation

1. Save or search for a batch.
2. In Data Visualization, go to **Digital Tag → QR code**.
3. Click **Show QR**.
4. Click **Download QR** to download its PNG.

The default mode is `local`. It generates the image within the dashboard; no separate API process is needed.

The QR currently encodes the selected batch reference held in `metadata.batch_id`. It does not encode the complete JSON, a verified Batch DT URL or pilot-qualified identity. The final QR content remains an integration decision.

The preview is kept in session memory. It is not automatically saved to the project exports folder or to a Batch DT.

### Optional: use the QR API

To test the supplied API, open a separate R session in the same project:

```r
source("run_api.R")
```

The default API address is `http://127.0.0.1:8000`. Its documentation is available at `http://127.0.0.1:8000/__docs__/`.

In the dashboard session, before starting the app:

```r
Sys.setenv(
  DIGITAL_TAGGING_QR_MODE = "api",
  DIGITAL_TAGGING_QR_API_URL = "http://127.0.0.1:8000"
)
source("run_app.R")
```

The client sends `POST /generate-tag` with `{"batchId":"FSK-DEMO-001"}` and expects a PNG response. It checks the content type and PNG signature. A failed API request is reported; it does not silently switch to local mode.

To return to local QR generation, stop the dashboard, set the mode and restart:

```r
Sys.setenv(DIGITAL_TAGGING_QR_MODE = "local")
source("run_app.R")
```

The supplied API also exposes `GET /health`. Its reserved `POST /batch/<id>/finalize` route returns **501 Not Implemented**: it is not connected to real batch creation. In the intended platform workflow, Batch DT Creator would be responsible for storing the PNG returned by tag generation.

## 9. Configure pilots and completeness

### Pilot catalogue

Edit `config/pilots.json` to maintain pilot identifiers, display names, process references and initial step lists.

| Pilot | Local code | Initial configured steps |
| --- | --- | --- |
| Naturae | NAT | Raw material reception, Mixing, Bottling |
| Fiskeby | FSK | Pulp preparation, Sheet forming, Drying |
| Noriware | NOR | Premixing, Extrusion |
| GreenLab | GLB | Energy and material flow, Storage operation |

These are initial prototype catalogues. Confirm real process names and identifiers with each pilot. References such as `FSK-local-process` are local placeholders, not registered AAS identifiers.

Restart the dashboard after changing configuration files. Changing pilot IDs also affects lookup of existing local records; do not rename identifiers without planning how to migrate saved files.

### Tag completeness

`config/completeness_rules.json` selects which categories are counted for each pilot.

The calculation is:

**100 × number of configured categories containing at least one record ÷ number of configured categories.**

With five configured categories, one populated category gives 20%, and five give 100%. This measures the presence of records only. It does not validate required fields across the pilot process, data accuracy, DPP readiness or an official project KPI.

## 10. Connect future data sources and destinations

### Repository adapters

The UI reads and writes a canonical batch record through `R/data_access.R` and `R/storage.R`. Read and write destinations can be selected independently.

An adapter is registered with:

```r
register_batch_adapter(
  "biospace",
  read = function(pilot, batch_id) {
    # Query agreed services and map the response into the canonical record.
    # Return NULL only when absence has been confirmed.
    stop("Implement the agreed reader.")
  },
  write = function(record) {
    # Persist to the agreed destination and return the canonical saved record.
    stop("Implement the agreed writer.")
  }
)
```

This example intentionally stops. It is a developer template, not a working connection.

Use `config/adapter_example.R` as a starting point. Once implemented, configure its absolute path and adapter names **before** starting the dashboard:

```r
Sys.setenv(
  DIGITAL_TAGGING_ADAPTER_SCRIPT = "C:/path/to/project/config/my_adapter.R",
  DIGITAL_TAGGING_READ_ADAPTER = "biospace",
  DIGITAL_TAGGING_WRITE_ADAPTER = "biospace"
)
source("run_app.R")
```

The reader receives the pilot configuration object and the selected batch key. It must return a list with matching `metadata.pilot_id` and `metadata.batch_id`, plus category lists. A network or authorization failure must raise an error, not return NULL as if the batch did not exist.

The writer must return the saved canonical record only after persistence succeeds. Unknown adapters fail explicitly; there is no silent fallback to local storage.

If read and write services differ, the reader must include the saved destination in the combined view. Otherwise information could disappear from the dashboard after a refresh even though it was saved elsewhere.

### Batch-details submission callback

Save batch uses a separate extension point:

```r
options(digital_tagging.submit_batch_details =
  function(pilot_id, batch_number, internal_id, payload) {
    # Resolve identifiers and call the confirmed endpoint.
    # Return list(confirmed = TRUE) only after confirmed receipt.
    stop("Implement the agreed batch-details submission.")
  }
)
```

This callback is separate from the record repository. The payload contains exactly the four fields shown in section 7. Without the callback, Save batch writes the request to `exports/batch_requests/`.

The record is persisted before submission. If submission fails, the saved record can still exist. Before adding remote delivery, define retry and idempotency behaviour so repeating Save batch cannot unintentionally duplicate an external operation.

### Optional MFT material import

Setting `BIOSPACE_MFT_BASE_URL` enables the **Import from MFT** control. The current client requests:

`GET <base URL>/batch/<selected batch key>`

It expects a `materials` array, using fields such as `id`, `name`, `type`, `batchNo`, `amountCurrent`, `unit`, `amountOriginal` and `arrival`.

The importer adds records marked `source: "MFT"` and skips already-seen non-empty material IDs. It is not a continuous synchronization service and does not update existing imported material records.

This client uses the local batch key directly in the URL. If the real endpoint requires a technical ID rather than a batch number, add identifier resolution before use. Authentication and compatibility with the deployed MFT contract also need implementation/verification.

### Data ownership and AAS mapping

A batch-centred screen does not imply that every record belongs in the Batch DT.

Based on the project discussions, process parameters need to respect the agreed Process DT model. Additional batch-specific information may belong in the Batch DT when that ownership is agreed. Sensor history may require DCOF queries over the relevant time interval. UserProvided fields requested by Batch DT Creator are another specific interaction.

Before implementing an adapter, agree:

1. The real entity and identifier associated with each field.
2. Whether its destination is Process DT, Batch DT or another approved service.
3. Its AAS representation, units, type, timestamp semantics and source.
4. Whether another component or template will consume it.
5. The exact endpoints, authentication, permissions and conflict handling.
6. How missing user values are requested, returned and followed by resumed batch creation.

The current JSON schema and process-model export are not substitutes for that agreed AAS mapping.

## 11. Configuration reference

Set environment variables before launching the relevant R process.

| Variable | Default | Purpose |
| --- | --- | --- |
| `DIGITAL_TAGGING_PROJECT_DIR` | Automatically resolved | Additional project-root candidate |
| `DIGITAL_TAGGING_APP_HOST` | `127.0.0.1` | Shiny bind address |
| `DIGITAL_TAGGING_APP_PORT` | `3838` | Shiny port |
| `DIGITAL_TAGGING_DATA_DIR` | Project `data/local` | Local working-record directory; relative overrides resolve against the project |
| `DIGITAL_TAGGING_READ_ADAPTER` | `local` | Repository reader |
| `DIGITAL_TAGGING_WRITE_ADAPTER` | `local` | Repository writer |
| `DIGITAL_TAGGING_ADAPTER_SCRIPT` | Unset | R script registering deployment adapters |
| `DIGITAL_TAGGING_QR_MODE` | `local` | `local` or `api` |
| `DIGITAL_TAGGING_QR_API_URL` | `http://127.0.0.1:8000` | QR service base URL in API mode |
| `DIGITAL_TAGGING_API_HOST` | `127.0.0.1` | Supplied Plumber API bind address |
| `DIGITAL_TAGGING_API_PORT` | `8000` | Supplied Plumber API port |
| `BIOSPACE_MFT_BASE_URL` | Unset | Enables optional MFT import |

Full exports remain in the running project's `exports/` directory even when the local working-data directory is overridden.

### Optional Docker development setup

The package includes `compose.yaml` and two development Dockerfiles. With Docker available, run from the project root:

```sh
docker compose up --build
```

The supplied configuration exposes the dashboard on localhost:3838 and the API on localhost:8000. It mounts `./data/local` into the UI container.

**The supplied Compose file does not mount exports.** Exports created inside the container can be lost when it is replaced. Add a persistent mount such as `./exports:/app/exports` under the UI service if you need to retain those files.

The default QR mode remains local even when both services are running. In container API mode, the UI must address the API service using its container hostname, for example `http://api:8000`, rather than the UI container's own localhost.

These are development assets, not a production deployment with authentication, authorization or managed backups.

## 12. Project structure

| File or directory | Responsibility |
| --- | --- |
| `DigitalTagging_API_Demo.Rproj` | RStudio project |
| `install_packages.R` | Installs missing dependencies |
| `run_app.R` | Resolves the project folder and starts Shiny |
| `app.R` | Assembles the Shiny application |
| `global.R` | Loads modules, configuration and adapter registrations |
| `ui.R` | Tabs, controls, forms, tables and export layout |
| `server.R` | Reactive behaviour, validation, record management and button actions |
| `R/utils.R` | Identifier, time and validation helpers |
| `R/config.R` | Pilot configuration access |
| `R/storage.R` | Working records, category operations and project exports |
| `R/data_access.R` | Repository adapter registration and selection |
| `R/digital_tag_logic.R` | Four-field payload and submission callback |
| `R/process_model.R` | Hierarchical process model and experimental virtual-sensor candidates |
| `R/completeness.R` | Category-presence indicator |
| `R/tagging.R` | Local QR image generation |
| `R/qr_service.R` | Local/API QR selection and HTTP client |
| `R/api_client.R` | Optional MFT GET and materials mapping |
| `api.R`, `run_api.R` | Development Plumber service and launcher |
| `config/` | Pilot catalogue, completeness rules and adapter example |
| `www/` | Stylesheets and logos |
| `data/local/` | Default working JSON files |
| `exports/` | Full snapshots and batch-details requests |
| `examples/` | Earlier illustrative JSON files; not automatic imports |
| `tests/` | R regression/check scripts |
| `deployment/`, `compose.yaml` | Optional Docker development setup |

Some example files predate the latest batch output fields. Use the current form validations and this README when preparing a new demonstration.

## 13. Worked example: Fiskeby

The following values are **fictional test data**, not pilot measurements, approved operating conditions or quality limits.

### Batch context

| Field | Value |
| --- | --- |
| Pilot | Fiskeby |
| Batch number | FSK-DEMO-001 |
| Start date/time | 2026-11-18, 08:00 UTC |
| End date/time | 2026-11-18, 12:00 UTC |
| Output amount | 1000 |
| Output unit | kg |

Click Save batch, then save one record in each category:

| Category | Example |
| --- | --- |
| Raw Materials | Material: Recovered paper; type: Recycled fibre; source batch: PAPER-DEMO-025; amount: 1200; unit: kg |
| Production Process | Step: Pulp preparation; machine: Pulper-DEMO-01; parameter: Target pulp consistency; value: 4.5; unit: % |
| Quality Control | Check: Final moisture content; result: 7.2; unit: %; status: Informational |
| Logistics | Event: Transfer to warehouse; origin: Production line DEMO; destination: Finished goods warehouse DEMO; quantity: 1000; unit: kg |
| Sustainability | Indicator: Electricity consumption; value: 650; unit: kWh; method: Manual batch total — test data |

Add a note identifying the records as test data. Leave the optional timestamp off for these batch-level examples.

After saving all five records:

1. Open Data Visualization and check the tables.
2. With the default five-category rules, completeness should show 100%; this only means that all categories contain a record.
3. Use Show QR and Download QR.
4. Return to Data Entry and finish data entry.
5. Check that a full DigitalTagging JSON exists in `exports/`, separately from the request in `exports/batch_requests/`.
6. Search for FSK-DEMO-001 and use Update information → Edit selected to verify the editing workflow.

## 14. Troubleshooting

| Symptom | Explanation and action |
| --- | --- |
| “address already in use” / “Failed to create server” | Another process is using the port. Stop the previous dashboard or choose another port using the example below. |
| A required R package is missing | Run `source("install_packages.R")` from the project, then restart. |
| The app cannot find R/utils.R or config/pilots.json | Extract the complete ZIP and open its RStudio project. Check that all project files are together. |
| Category forms remain locked | Complete the required batch context and click Save batch, or search for a valid saved batch and use Update information. |
| Search finds no batch | Confirm the pilot, exact number and configured reader. Local mode does not search external services. |
| Only the small request JSON exists | Save batch creates the four-field request. Use Save JSON or Finish data entry for the complete export. |
| Recent form changes are absent from the export | Save the individual form before exporting. Unsaved input is not included. |
| A browser download is not in the project | Browser downloads use the browser's selected location. Save JSON and Finish data entry write into the project. |
| The QR reports that its API is unavailable | For local use, set QR mode to local and restart. For API mode, start the service and check its base URL and port. |
| Update information does not enable editing | Search first. The saved batch needs valid start/end dates matching the form. Save changed dates before reopening. |
| A record from MFT cannot be edited | Imported MFT records are protected. Update the authoritative source. |
| The button layout still looks old | Stop the old R process, check that you started the updated folder, restart and force-refresh the browser with Ctrl+F5. |
| JSON export fails after finishing | The working record may already have been saved. Check write permissions and free space, then retry Finish data entry as instructed by the notification. |
| An adapter is not configured | Check the adapter name, registration script and implemented read/write functions. The app intentionally does not fall back silently. |

Example: run the dashboard on another port:

```r
Sys.setenv(DIGITAL_TAGGING_APP_PORT = "3839")
source("run_app.R")
```

Open `http://127.0.0.1:3839`.

Local filenames sanitize characters outside letters, digits, hyphens and underscores. Different batch numbers containing other characters can therefore map to the same filename. Prefer simple distinct references such as FSK-DEMO-001 for local testing.

## 15. Verification and remaining work

### Verification of this documentation

This README was checked against the actual UI, server, storage, configuration and API source files in the corrected package. This documentation update changes the README only; it does not implement or certify additional application features.

R/Shiny and the included R tests were not executed as part of this documentation update. Included scripts are checks to run, not evidence of a fully passing current test suite. Some historical UI tests may need alignment with renamed controls and the latest required batch fields.

For a clean development check, use a copy of the project with disposable test data. From its root, run relevant scripts individually, for example:

```r
source("tests/batch_actions_test.R")
source("tests/data_access_test.R")
source("tests/local_qr_export_test.R")
source("tests/view_search_test.R")
```

Review each result and any files it creates. Do not interpret the presence of a test file as proof that the scenario has passed.

### Manual acceptance checks

Verify the following in RStudio before demonstrating a new installation:

- Save a batch with valid dates, quantity and unit.
- Confirm that Save batch creates only the limited request in batch_requests.
- Add, review and update one record in every category.
- Finish and confirm the full JSON export.
- Restart and search for the saved batch.
- Reopen information and edit a record.
- Preview and download the local QR.
- Confirm that invalid dates, missing batch numbers and missing search results are reported clearly.

### Remaining integration and deployment work

The next implementation steps are to agree the data ownership and AAS model, implement real readers/writers, confirm the batch-details destination and identifiers, implement the missing UserProvided workflow, and connect actual Batch DT creation where required.

The final QR payload, authentication/authorization, concurrent editing, conflict handling, secure deployment, audit requirements and backup arrangements also need to be defined and tested. The local file store does not provide transactional multi-user database behaviour or a full audit trail.

Do not describe local JSON persistence, a finished entry status, or a generated QR as evidence that a real Batch DT or DPP has been created.

