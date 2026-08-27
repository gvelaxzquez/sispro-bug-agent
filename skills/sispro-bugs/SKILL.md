---
name: sispro-bugs
description: Consulta bugs asignados en SISPRO para el proyecto configurado y los atiende uno a la vez con tres gates de aprobacion humana (elegir bug, aprobar plan antes de tocar codigo, aprobar antes de reportar tiempo/mandar a revision). Usa cuando el usuario diga "atiende bugs de SISPRO", "revisa mis bugs", "/sispro-bugs" o similar.
---

# sispro-bugs

Flujo para atender bugs asignados en SISPRO desde Claude Code, con aprobacion humana explicita en tres puntos. Corre siempre desde la raiz del repo del proyecto real (ej. Clikalo) donde vas a hacer el fix — no desde el repo del plugin.

Los scripts de este plugin (`scripts/sispro-list-bugs.sh`, `scripts/sispro-report-time.sh`) leen `config/sispro.env` **relativo al directorio de trabajo actual**, es decir del repo del proyecto, no del plugin.

## Paso 0 — Validar config

Corre `scripts/sispro-list-bugs.sh` mas adelante ya valida esto solo, pero si el usuario claramente no tiene `config/sispro.env` en el repo actual, dile que copie `config/sispro.env.example` (viene en este plugin) a `config/sispro.env` en la raiz de SU repo y llene `SISPRO_BASE_URL`, `SISPRO_API_KEY`, `SISPRO_PROJECT_ID`. No sigas hasta que exista.

## Paso 1 — Listar bugs

Corre:
```
bash scripts/sispro-list-bugs.sh
```
(usa la ruta del plugin, ej. via `${CLAUDE_PLUGIN_ROOT}/scripts/sispro-list-bugs.sh` si esta disponible, o resuelve la ruta donde este instalado el plugin).

- Si falla con "no existe config/sispro.env" o "faltan variables" → repite el Paso 0, no reintentes ciego.
- Si falla con HTTP 401 → dile al usuario: "API key invalida/inactiva, regenera en tu Dashboard SISPRO". Detente.
- Si `Proyectos` viene `[]` → informa "sin bugs abiertos/en progreso en este proyecto" y termina, no hay nada que hacer.
- Si hay datos, muestra una tabla resumen agrupada por proyecto: `IdActividad | BR | Prioridad | Estatus | FechaAsignado`. No muestres el Markdown completo todavia (puede ser largo).

## Paso 2 — Gate 1: elegir bug

Pregunta al usuario (usa `AskUserQuestion` si son pocos bugs, listalos como opciones con el BR como label) cual `IdActividad` quiere atacar. No elijas tu el de mayor prioridad sin preguntar. Si el usuario dice "el mas prioritario" o similar, confirma cual es antes de seguir (prioridad mas baja en el numero = mas urgente, segun el instructivo: `Prioridad: 0` es la mas alta).

## Paso 3 — Analizar el bug

Toma el campo `Markdown` del bug elegido. Leelo como el spec del bug (titulo, descripcion, criterios de aceptacion/pasos, evidencias). Si algo esta ambiguo — no dice que pantalla/endpoint, falta criterio de exito claro, contradice lo que ves en el codigo del repo actual — pregunta al usuario ANTES de proponer nada, igual que el flujo de preguntas de un spec normal. No asumas.

Explora el codigo del repo actual para ubicar la causa probable (grep/read, no adivines a ciegas).

## Paso 4 — Gate 2: aprobar el plan

Antes de escribir o modificar una sola linea de codigo, muestra un resumen corto:
- Causa raiz sospechada.
- Archivos que vas a tocar.
- Approach (que vas a cambiar y por que).

Pide confirmacion explicita. Si el usuario corrige el approach, ajusta y vuelve a mostrar el resumen — no implementes hasta el OK explicito. Este gate es igual de estricto que el flujo obligatorio de specs: sin aprobacion, no hay codigo.

## Paso 5 — Implementar

Con el plan aprobado, haz el fix en el repo actual. Sigue las convenciones/CLAUDE.md de ESE repo (no las de este plugin). Corre build/tests del repo si existen y son rapidos de correr. Si algo no compila o rompe un test, resuelvelo antes de pasar al siguiente gate — no reportes tiempo sobre un fix roto.

## Paso 6 — Gate 3: aprobar el reporte final

Antes de llamar `ReportarTiempo` (accion irreversible: mueve el bug a Revision y dispara un correo):

1. Muestra un resumen de lo que se cambio (diff o lista de archivos + que se hizo).
2. Pregunta al usuario el `Tiempo` real invertido en horas — **no lo inventes ni lo estimes tu solo**, es dato que solo el usuario sabe.
3. Propon un `Comentario` corto describiendo el fix (el usuario puede ajustarlo).
4. Pide confirmacion final explicita antes de ejecutar.

## Paso 7 — Reportar

Corre:
```
bash scripts/sispro-report-time.sh <IdActividad> <Tiempo> "<Comentario>"
```

Maneja la respuesta:
- Exito (200, `Exito: true`) → confirma al usuario, menciona que el bug ya esta en Revision.
- `400` → Tiempo invalido, el script ya valida `> 0` antes de llamar; si igual pasa, revisa el formato (debe ser numero, ej. `1.5`).
- `403` → "el bug no existe, no es un bug, o no esta asignado a tu usuario" — no reintentes con otro IdActividad sin preguntar al usuario primero.
- `409` → "el bug ya no esta en Abierto/Progreso, no se puede volver a mandar a revision" — informa y detente, no insistas.
- `401` → API key invalida/inactiva, mismo mensaje que en el Paso 1.

No repitas el ciclo con otro bug automaticamente al terminar — si el usuario quiere atender otro, que lo pida explicitamente (vuelve al Paso 1).
