---
name: yitpro-bugs
description: Consulta bugs asignados en YITPRO para el proyecto configurado y los atiende uno a la vez con tres gates de aprobacion humana (elegir bug, aprobar plan antes de tocar codigo, aprobar commit+reporte final). Usa cuando el usuario diga "atiende bugs de YITPRO", "revisa mis bugs", "/yitpro-bugs" o similar.
---

# yitpro-bugs

Flujo para atender bugs asignados en YITPRO desde Claude Code, con aprobacion humana explicita en tres puntos. Corre siempre desde la raiz del repo del proyecto real (ej. Clikalo) donde vas a hacer el fix — no desde el repo del plugin.

Los scripts de este plugin (`scripts/yitpro-list-bugs.sh`, `scripts/yitpro-report-time.sh`) leen `.yitpro.env` **en la raiz del directorio de trabajo actual**, es decir del repo del proyecto, no del plugin.

## Paso 0 — Validar config

`scripts/yitpro-list-bugs.sh` ya valida esto solo, pero si el usuario claramente no tiene `.yitpro.env` en la raiz del repo actual, dile que lo descargue del wizard en su Dashboard YITPRO ("Agente IA de Bugs" → Paso 3, ya viene lleno) o copie `.yitpro.env.example` (viene en este plugin) a `.yitpro.env` en la raiz de SU repo y llene `YITPRO_BASE_URL`, `YITPRO_API_KEY`, `YITPRO_PROJECT`, `YITPRO_REPOSITORY`. No sigas hasta que exista.

## Paso 1 — Listar bugs

Corre:
```
bash scripts/yitpro-list-bugs.sh
```
(usa la ruta del plugin, ej. via `${CLAUDE_PLUGIN_ROOT}/scripts/yitpro-list-bugs.sh` si esta disponible, o resuelve la ruta donde este instalado el plugin).

- Si falla con "no existe .yitpro.env" o "faltan variables" → repite el Paso 0, no reintentes ciego.
- Si falla con HTTP 401 → dile al usuario: "API key invalida/inactiva, regenera en tu Dashboard YITPRO". Detente.
- Si falla con HTTP 500 → error del backend YITPRO (ej. bug de EF/LINQ, ya visto en la practica), no del plugin. Ofrece reintentar una vez (puede ser transitorio); si persiste, detente e informa, no insistas en loop.
- Si `Proyectos` viene `[]` → informa "sin bugs abiertos/en progreso en este proyecto" y termina, no hay nada que hacer.
- Si hay datos, muestra una tabla resumen: `IdActividad | BR | Prioridad | Estatus | FechaAsignado`. No muestres el Markdown completo todavia (puede ser largo). La respuesta NO trae `Repositorios[]` — `YITPRO_REPOSITORY` de `.yitpro.env` es la unica fuente de verdad para el nombre del repo, sin forma de validarlo contra la API antes del Paso 7.

## Paso 2 — Gate 1: elegir bug

Pregunta al usuario (usa `AskUserQuestion` si son pocos bugs, listalos como opciones con el BR como label) cual `IdActividad` quiere atacar. No elijas tu el de mayor prioridad sin preguntar. Si el usuario dice "el mas prioritario" o similar, confirma cual es antes de seguir (prioridad mas baja en el numero = mas urgente, segun el instructivo: `Prioridad: 0` es la mas alta).

## Paso 3 — Analizar el bug

Toma el campo `Markdown` del bug elegido. Leelo como el spec del bug (titulo, descripcion, criterios de aceptacion/pasos, evidencias). Si algo esta ambiguo — no dice que pantalla/endpoint, falta criterio de exito claro, contradice lo que ves en el codigo del repo actual — pregunta al usuario ANTES de proponer nada, igual que el flujo de preguntas de un spec normal. No asumas.

Explora el codigo del repo actual para ubicar la causa probable (grep/read, no adivines a ciegas). Revisa tambien si el bug ya esta cubierto por trabajo previo (historial de git, openspec archivado) antes de proponer un fix nuevo — puede que ya este resuelto y solo falte cerrarlo en YITPRO.

## Paso 4 — Gate 2: aprobar el plan

Antes de escribir o modificar una sola linea de codigo, muestra un resumen corto:
- Causa raiz sospechada (o "ya cubierto por X" si aplica — puede haber mas de una causa/bug distinto en el mismo reporte, no asumas que es uno solo).
- Archivos que vas a tocar (o ninguno, si ya esta resuelto).
- Approach (que vas a cambiar y por que).

Pide confirmacion explicita. Si el usuario corrige el approach, ajusta y vuelve a mostrar el resumen — no implementes hasta el OK explicito. Este gate es igual de estricto que el flujo obligatorio de specs: sin aprobacion, no hay codigo.

Con el plan aprobado, **antes de tocar codigo**, escribe `mds/bugfix/<IdActividad>.md` en la raiz del repo destino (crea `mds/bugfix/` si no existe) con:
- Encabezado: IdActividad, proyecto (`YITPRO_PROJECT`), prioridad, fecha asignado.
- El reporte original (el `Markdown` del bug tal cual, en blockquote).
- Analisis (lo que encontraste explorando el codigo — causa raiz, por que pasa).
- El plan aprobado en este mismo gate (lo que se va a cambiar y por que).
- Una seccion `## Solucion implementada` vacia/pendiente — se llena en el Paso 7.

Este archivo es el spec del fix, igual que cualquier spec de este repo — se escribe ANTES de implementar, no como changelog despues del hecho.

## Paso 5 — Implementar

Con el plan aprobado, haz el fix en el repo actual (si aplica — puede que el Paso 4 haya concluido que ya estaba resuelto, en cuyo caso no hay nada que implementar aqui). Sigue las convenciones/CLAUDE.md de ESE repo (no las de este plugin). Corre build/tests del repo si existen y son rapidos de correr. Si algo no compila o rompe un test, resuelvelo antes de pasar al siguiente gate — no cierres el bug sobre un fix roto.

## Paso 6 — Gate 3: aprobar cierre (commit + tiempo + reporte, todo junto)

YITPRO liga el commit al bug en la misma llamada que reporta tiempo — no son pasos separados. Antes de ejecutar nada irreversible, muestra en un solo bloque:

1. **Mensaje de commit propuesto** — sigue las convenciones de commit del repo destino (revisa su `CLAUDE.md`). Debe mencionar el spec (`mds/bugfix/<IdActividad>.md`). Si no hay nada que commitear porque el bug ya estaba resuelto, dilo explicitamente y salta a reusar el commit existente como `IdLink` (ver Paso 7, nota) — igual escribe/actualiza el `.md` del bugfix y comitealo aparte si aplica.
2. **`Tiempo`** — pregunta al usuario las horas reales invertidas. No lo inventes ni lo estimes tu solo.
3. **`Comentario`** — propuesta corta para la bitacora, el usuario puede ajustarla.
4. **`DescripcionCommit`** — si el usuario no da una distinta, usa el subject del commit que se va a hacer (no un valor generico tipo "fix").

Pide confirmacion explicita de TODO el bloque junto. Si el usuario corrige el mensaje de commit, el tiempo, o el comentario, ajusta y vuelve a mostrar — no ejecutes nada hasta el OK.

## Paso 7 — Cerrar

Con el OK del Gate 3:

1. Llena la seccion `## Solucion implementada` de `mds/bugfix/<IdActividad>.md` (Paso 4) con: archivos tocados y que cambio cada uno, y si se corrio/paso build o tests (o si no se pudo verificar en vivo — decilo explicito, no lo omitas).
2. Si hay cambios sin commitear: revisa `git status`/`git diff` (nunca `git add -A` ciego), stagea lo relevante **junto con `mds/bugfix/<IdActividad>.md`** — el spec del fix va SIEMPRE en el mismo commit que el codigo que soluciona, nunca separado — y corre `git commit` con el mensaje aprobado en el Paso 6.
3. Captura el hash: `git rev-parse HEAD` → hash completo de 40 caracteres (ej. `45175419aa4e36e7d1c6fec05610621343d77b1e`). **Eso exacto va en `IdLink`** — el hash crudo, no una URL de Azure/GitHub.
   - Nota: si el bug ya estaba resuelto por un commit previo (Paso 4/5), usa el hash de ESE commit en vez de crear uno nuevo — no inventes un commit vacio solo para tener un `IdLink`.
4. Corre:
   ```
   bash scripts/yitpro-report-time.sh <IdActividad> <Tiempo> <IdLink> "<Comentario>" "<DescripcionCommit>"
   ```
   El script arma `NombreRepositorio` internamente desde `YITPRO_REPOSITORY` (config) — no lo pases como argumento.
5. Maneja la respuesta:
   - Exito (200, `Exito: true`) → confirma al usuario, menciona que el bug ya esta en Revision.
   - `400` (Tiempo invalido) → el script ya valida `> 0` antes de llamar.
   - `400` (`NombreRepositorio`/`IdLink` faltante) → no deberia pasar, el script siempre los manda; si pasa, es bug del plugin, reporta el error tal cual, no reintentes ciego.
   - `400` (`NombreRepositorio` no matchea el proyecto del bug) → `YITPRO_REPOSITORY` en `.yitpro.env` no es el que YITPRO espera para este proyecto. Dile al usuario que lo revise/redescargue del wizard del Dashboard.
   - `403` → "el bug no existe, no es un bug, o no esta asignado a tu usuario" — no reintentes con otro IdActividad sin preguntar al usuario primero.
   - `409` → "el bug ya no esta en Abierto/Progreso, no se puede volver a mandar a revision" — informa y detente, no insistas.
   - `401` → API key invalida/inactiva, mismo mensaje que en el Paso 1.
   - `500` → error del backend YITPRO (visto en la practica, no documentado en el instructivo). Ofrece reintentar una vez; si persiste, detente e informa, no insistas en loop.

No repitas el ciclo con otro bug automaticamente al terminar — si el usuario quiere atender otro, que lo pida explicitamente (vuelve al Paso 1).
