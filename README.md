# Datos manuales por batch

Por defecto los valores manuales no requieren hora: `timestamp: null`,
`time_scope: "batch"`. Para mediciones/eventos, activa la casilla de hora opcional.
El contexto ID/inicio/final del batch sigue siendo obligatorio.

# Actualizacion 06/11/2026: contexto obligatorio y JSON visible

Antes de introducir datos, confirma Batch ID, inicio y final (UTC).
Consulta `GUIA_CODIGO_Y_JSON.txt` y los JSON didacticos en `examples/`.
Las instrucciones historicas siguientes sobre habilitar con solo ID quedan sustituidas.

# Digital Tagging v0.5.1 - Entrada y visualización separadas

**Este ZIP incluye TODO el proyecto.** Mantiene la corrección de rutas
de la versión 0.5.1 y organiza el dashboard en dos pestañas principales:

1. **Data Entry:** formularios para introducir datos en las cinco categorías.
2. **Data Visualization:** resumen del lote, tablas, gestión de registros,
   exportación JSON y vista del QR.

El piloto y el Batch ID son comunes a las dos pestañas. Para modificar un
registro, pulsa **Edit selected** junto a su tabla: se abre automáticamente
el formulario de su categoría. Guarda el cambio con **Update record**.

## Empezar

1. Descomprime el ZIP con **Extraer todo**. No abras `app.R` desde el interior del ZIP.
2. En la carpeta descomprimida abre `DigitalTagging_API_Demo.Rproj`.
3. Si faltan paquetes, ejecuta `source("install_packages.R")`.
4. Arranca con `source("run_app.R")` o con el boton **Run App** de RStudio.

## Conservar tus datos

Este ZIP contiene `data/local/` vacio. Si has guardado informacion en
la version anterior, **copia los archivos `.json` de su carpeta
`data/local/` a la nueva**. No sobrescribas ni elimines esos archivos
sin una copia de seguridad.

## Que se ha corregido

- `app.R` localiza el proyecto y usa rutas absolutas al cargar `global.R`, `ui.R` y `server.R`.
- `global.R` carga los modulos desde `R/` usando rutas absolutas.
- `run_app.R` resuelve la carpeta raiz y no depende exclusivamente de `getwd()`.
- `R/storage.R` guarda los registros en la carpeta local **de este proyecto** aunque cambie el directorio de trabajo.
- La configuracion se lee de la ruta correcta; tambien se ha reforzado el arranque de `run_api.R`.
- Se conserva la lógica de edición de las cinco categorías.

## Que NO hace

- No crea batches ni finaliza Batch DT reales.
- No se conecta a Process DT, Batch DT, MFT o DCOF por defecto.
- No genera DPP; `Download JSON` es una exportacion LOCAL.
- El porcentaje de Tag Completeness es provisional.

---

# bi0SpaCE T4.3 — Digital Tagging dashboard v0.5

## Qué incluye (prototipo local)

- Dos pestañas principales: Data Entry y Data Visualization. Dentro de Data Entry se mantienen las cinco categorías: Raw Materials, Production Process, Quality Control, Logistics y Sustainability.
- Selector de piloto y Batch ID obligatorio para registrar información (no crea ningún batch real).
- Desplegable de pasos de proceso específico para cada piloto, más `Other / Add new`.
- **Crear, consultar, editar, actualizar y eliminar** registros de las cinco categorías. Antes de eliminar se pide confirmación.
- Registros importados de MFT protegidos frente a edición/eliminación local.
- **Tag completeness**: barra porcentual provisional y configurable. En esta versión una categoría cuenta si contiene al menos un registro local. No es un KPI oficial ni representa la completitud del DPP.
- Resumen de la información adicional registrada y botón **Download JSON**.
- **Preview QR (API)**: el dashboard solicita el PNG a la API independiente por `POST /generate-tag`. No genera el QR dentro de Shiny ni lo escribe en el JSON.
- Guardado local en `data/local/`, un archivo JSON por piloto + Batch ID.

## Qué NO hace todavía

- No verifica si el Batch ID existe realmente en Material Flow Tracing.
- No crea ni finaliza batches, ni activa Batch DT Creator.
- No lee ni escribe mediante API AAS en Process DT / Batch DT.
- No gestiona todavía los campos `UserProvided` solicitados dinámicamente por Batch DT Creator.
- No obtiene automáticamente todos los datos de sensores ni genera un DPP.
- El contenido definitivo del QR (ID o URL) sigue pendiente de acuerdo.

## Ejecutar el dashboard en RStudio

1. Descomprime el proyecto en una carpeta nueva (o sustituye los archivos indicados en `INSTRUCCIONES_REEMPLAZO.txt`).
2. Abre `DigitalTagging_API_Demo.Rproj`.
3. Si faltan paquetes, ejecuta una vez `source("install_packages.R")`.
4. Inicia la aplicación con `source("run_app.R")`.
5. Selecciona piloto, introduce un Batch ID y registra datos en **Data Entry**.
6. Abre **Data Visualization** para consultar las tablas de las cinco categorías.
7. Para actualizar un dato: selecciona un registro debajo de su tabla, pulsa **Edit selected**, cambia el formulario que se abre y pulsa **Update record**.

## API QR: se inicia POR SEPARADO

En otra sesión/proyecto de RStudio inicia la API independiente `bi0SpaCE_QR_API_Independiente` con:

```r
source("iniciar_api.R")
```

De forma predeterminada esa API usa `http://127.0.0.1:8000`.
Si en tu ordenador utiliza el puerto **6730** (como en tu captura de Swagger), antes de iniciar el dashboard ejecuta:

```r
Sys.setenv(DIGITAL_TAGGING_QR_API_URL = "http://127.0.0.1:6730")
source("run_app.R")
```

Si la API está en el puerto 8000, basta con ejecutar `source("run_app.R")`.
La pantalla muestra la URL configurada y un error no fatal si la API no está activa.
La API recibe `{ "batchId": "NAT-001" }` y devuelve `image/png`. El QR codifica solo el texto `NAT-001` mientras no se acuerde la URL final.

## Reglas de completitud

Editar `config/completeness_rules.json` permite elegir las categorías que entran en el cálculo para cada piloto. Los cinco grupos son un ejemplo provisional, **no son campos obligatorios aprobados**. El porcentaje no debe utilizarse para medir cumplimiento de los KPIs oficiales.

## Archivos más importantes

- `ui.R`: las dos pestañas principales, formularios, tablas y exportación.
- `server.R`: gestión de datos, edición, completitud y comunicación con QR API.
- `R/storage.R`: lectura/escritura/CRUD local (JSON).
- `R/completeness.R` y `config/completeness_rules.json`: reglas de completitud.
- `R/qr_service.R`: cliente HTTP para la API QR independiente.
- `www/features_v05.css`: estilos de las funciones nuevas.
- `www/styles.css`: tus estilos originales.
- `config/pilots.json`: catálogo inicial de procesos por piloto.

## Comprobaciones en tu RStudio

```r
source("tests/ui_contract_test.R")
source("tests/two_tabs_test.R")
source("tests/v05_features_test.R")
source("tests/startup_test.R")
```

Estas pruebas no necesitan una API bi0SpaCE real. Las pruebas de CRUD utilizan un directorio temporal, no tus archivos locales.

**Limitación de QA:** se han comprobado la estructura del proyecto y los scripts de forma estática. En el entorno donde se preparó el ZIP no hay una instalación de R/Shiny, por lo que la aplicación, las pruebas R y la comunicación HTTP deben ejecutarse en RStudio.
