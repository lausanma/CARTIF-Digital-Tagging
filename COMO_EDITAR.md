# Como modificar Digital Tagging v0.5.1

El codigo sigue dividido en los mismos modulos:

- `ui.R`: interfaz y cinco categorias.
- `server.R`: guardado, consulta, edicion, eliminacion, exportacion y QR.
- `global.R`: configuracion e inicializacion de modulos (rutas absolutas).
- `run_app.R`: inicia Shiny desde la carpeta correcta.
- `R/storage.R`: JSON local. **No borres `data/local/`**.
- `R/qr_service.R`: cliente HTTP de la API independiente de QR.
- `www/styles.css` y `www/features_v05.css`: estetica.
- `config/pilots.json`: pasos iniciales de cada piloto.
- `config/completeness_rules.json`: reglas de completitud provisionales.

Para cambiar la interfaz, modifica solo `ui.R`/`www/`.
Para cambiar la logica, modifica `server.R` o el modulo `R/` correspondiente.
Evita cambiar las rutas de `app.R` y `global.R`, que permiten arrancar
sin depender del directorio de trabajo.
