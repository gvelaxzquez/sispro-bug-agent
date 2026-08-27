# SPEC: sispro-bug-agent (Claude Code Plugin)

## Proposito

Plugin de Claude Code, instalable por cualquier miembro del equipo, que:
1. Consulta bugs asignados en SISPRO (`GET /AgenteIA/ConsultarBugs`).
2. Deja elegir un bug (gate 1).
3. Lee el `Markdown` del bug, hace preguntas de aclaracion si algo no esta claro, propone un mini-plan/spec de la correccion (gate 2 — aprobacion antes de tocar codigo, replicando el flujo de `CLAUDE.md`).
4. Implementa el fix en el repo donde se invoco el plugin (el repo del proyecto real, ej. Clikalo).
5. Antes de reportar tiempo y mover el bug a Revision, pide confirmacion final (gate 3 — accion irreversible: dispara correo, cambia estatus).
6. Llama `POST /AgenteIA/ReportarTiempo`.

No es un script Python standalone: es una **skill de Claude Code** (slash command) que usa `Bash`/`curl` para hablar con la API SISPRO directamente. Empaquetado como plugin (`.claude-plugin/plugin.json`) para poder compartirse via marketplace privado o `git clone` + `/plugin install <path>`.

## Estructura del repo

```
sispro-bug-agent/
├── .claude-plugin/
│   └── plugin.json              # manifest del plugin
├── skills/
│   └── sispro-bugs/
│       └── SKILL.md             # instrucciones de la skill (el "cerebro" del flujo)
├── scripts/
│   ├── sispro-list-bugs.sh      # curl GET ConsultarBugs, wrapper delgado
│   └── sispro-report-time.sh    # curl POST ReportarTiempo, wrapper delgado
├── config/
│   └── sispro.env.example       # plantilla de config (base url + api key)
├── README.md                    # instalacion + como generar API key + como usar
└── LICENSE
```

Los `.sh` son wrappers delgados (curl + jq), no un cliente completo — la logica de negocio (preguntas, plan, gates) vive en `SKILL.md`, ejecutada por Claude, no por codigo.

## Configuracion / credenciales

- Archivo `config/sispro.env` **por repo** (no global, no por variables de shell) — vive en la raiz del repo donde se usa la skill (ej. raiz de Clikalo), gitignored. Se crea copiando `config/sispro.env.example` (este si va en el plugin, versionado).
- Campos, **todos obligatorios** — la skill valida al arrancar que los 3 esten presentes y no vacios; si falta alguno, aborta con mensaje claro (no llama la API a ciegas):
  - `SISPRO_BASE_URL` — ej. `http://localhost:47566` (local) / URL de QA / URL de prod.
  - `SISPRO_API_KEY` — la key generada en el Dashboard (`/Dashboard/p/{clave}` → "Generar API Key Agente IA").
  - `SISPRO_PROJECT_ID` — el `idProyecto` fijo de ese repo (ej. Clikalo=246). El comando `/sispro-bugs` ya no acepta un id como argumento — siempre usa el de config, filtrado automatico a ese proyecto.
- README explica el flujo de generacion de key (paso 1 del instructivo SISPRO) y advierte: se muestra una sola vez, regenerar invalida la anterior; y como obtener el `idProyecto` correcto (URL/Dashboard de SISPRO).

## Slash command: `/sispro-bugs`

Invocacion: `/sispro-bugs`, sin argumentos — el `idProyecto` siempre sale de `config/sispro.env` (`SISPRO_PROJECT_ID`), nunca se pasa a mano.

### Flujo (definido en `SKILL.md`)

0. **Validar config**: lee `config/sispro.env`; si no existe o le falta `SISPRO_BASE_URL`/`SISPRO_API_KEY`/`SISPRO_PROJECT_ID`, aborta y dice exactamente que falta (y que copie `sispro.env.example`).
1. **Listar**: corre `scripts/sispro-list-bugs.sh` (usa `SISPRO_PROJECT_ID` internamente como query param `idProyecto`), parsea el JSON, muestra tabla resumen (BR / IdActividad / Prioridad / FechaAsignado) del unico proyecto configurado. Si `Proyectos` viene vacio, informa "sin bugs abiertos" y termina.
2. **Gate 1 — elegir bug**: pregunta al usuario cual `IdActividad` atacar (via `AskUserQuestion` si son pocos, o pidiendo el numero si son muchos). No elige solo.
3. **Analizar**: toma el campo `Markdown` del bug elegido, lo interpreta como el spec/reporte de bug. Si falta info para entender el bug (criterios de aceptacion ambiguos, falta contexto de que pantalla/endpoint es), hace preguntas al usuario en este punto — mismo criterio que el flujo obligatorio de `CLAUDE.md` (PASO 1/2 de ese archivo: junta todo el contexto antes de proponer nada).
4. **Gate 2 — mini-plan**: antes de tocar codigo, muestra un resumen corto (causa raiz sospechada, archivos a tocar, approach) y pide confirmacion explicita. Si el usuario corrige, ajusta el plan y vuelve a confirmar (no implementa hasta el OK).
5. **Implementar**: hace el fix en el repo actual (el directorio donde Claude Code esta corriendo — se asume que el usuario ya tiene el repo del proyecto real abierto). Corre build/tests si el repo los tiene configurados.
6. **Gate 3 — reportar**: muestra diff/resumen de lo hecho + el tiempo estimado invertido (pregunta al usuario el valor real de `Tiempo` en horas, no lo inventa) + comentario propuesto. Pide confirmacion final antes de la llamada irreversible.
7. **Reportar**: corre `scripts/sispro-report-time.sh <IdActividad> <Tiempo> "<Comentario>"`. Muestra el resultado (`Exito`/`Mensaje` o el error 400/403/409/401 tal cual lo regresa la API).

### Manejo de errores de la API

- `401` → mensaje claro: "API key invalida/inactiva, regenera en tu Dashboard" — no reintenta solo.
- `403` en ReportarTiempo → "el bug no existe o no es tuyo" — no reintenta con otro IdActividad sin preguntar.
- `409` → "el bug ya no esta en Abierto/Progreso, no se puede mandar a revision" — informa y no insiste.
- `400` → valida `Tiempo > 0` antes de llamar, para no depender del error del server.

## plugin.json (manifest)

Repo de un solo plugin → **no necesita `marketplace.json`**, solo `.claude-plugin/plugin.json` en la raiz. Skills se auto-descubren por la carpeta `skills/`, no se listan a mano en el manifest.

```json
{
  "name": "sispro-bug-agent",
  "description": "Agente que consulta bugs asignados en SISPRO y los atiende con gates de aprobacion.",
  "version": "1.0.0",
  "author": { "name": "<tu nombre>" },
  "repository": "<owner>/sispro-bug-agent",
  "license": "MIT"
}
```

`name`/`description` son los unicos campos obligatorios; el resto habilita el flujo de update por version (ver Distribucion). Sin dependencias externas mas alla de curl + jq (instrucciones de instalacion en README para Windows/Git Bash).

## Distribucion (proceso para subirlo y compartirlo)

1. **Publicar**: crear repo privado en GitHub (`gh repo create sispro-bug-agent --private --source=. --push`, o manual + `git remote add origin` + push). Requiere credenciales git funcionando (`gh auth login` ya hecho, segun este entorno).
2. **Habilitar auto-update para el equipo**: correr `gh auth setup-git` una vez (o usar SSH con la key en `ssh-agent`) para que `/plugin marketplace update` no falle por auth en background.
3. **Cada teammate, una sola vez**:
   ```
   /plugin marketplace add <owner>/sispro-bug-agent
   /plugin install sispro-bug-agent@sispro-bug-agent
   ```
   (repo privado → usa las credenciales git/gh que ya tenga configuradas; sin config extra si `gh auth setup-git` corrio del lado del que instala tambien).
4. **Cada teammate, por repo donde lo va a usar** (ej. Clikalo): copiar `config/sispro.env.example` → `config/sispro.env` dentro de ESE repo (no del plugin) y llenar `SISPRO_BASE_URL`/`SISPRO_API_KEY`/`SISPRO_PROJECT_ID`.
5. **Actualizaciones**: el maintainer bumpea `version` en `plugin.json` en cada cambio y hace push. Teammates lo reciben automatico en background (repos privados no traen auto-update prendido por default — documentar en README que corran `/plugin marketplace update sispro-bug-agent` manual si no ven el cambio) o forzando el update manual.
6. Sin `marketplace.json` porque es un solo plugin — si algun dia se agregan mas plugins al mismo repo, ahi si se necesita.

## Fuera de alcance (fase 1)

- Wrapper Python standalone / modo no-interactivo (CI, cron) — la skill asume un humano operando Claude Code interactivamente en cada gate.
- Multi-tenant / multi-cuenta SISPRO simultaneo (una sola `SISPRO_API_KEY` activa a la vez, va atada a un usuario/tenant SISPRO).
- Auto-deteccion de en que repo/proyecto real aplicar el fix — se asume que el dev ya abrio Claude Code dentro del repo correcto antes de correr `/sispro-bugs`.
- Auto-update garantizado sin intervencion — repo privado puede requerir `/plugin marketplace update` manual la primera vez que cada teammate configure sus credenciales.

## Checklist de implementacion

- [x] `.claude-plugin/plugin.json`
- [x] `skills/sispro-bugs/SKILL.md` (flujo completo, gates, manejo de errores)
- [x] `scripts/sispro-list-bugs.sh`
- [x] `scripts/sispro-report-time.sh`
- [x] `config/sispro.env.example`
- [x] `README.md` (instalacion, generacion de API key, uso, troubleshooting 401/403/409, proceso de distribucion/update de la seccion anterior)
- [x] `.gitignore` (`.env`, `config/sispro.env`)
- [x] Prueba manual end-to-end contra SISPRO local (`http://localhost:47566`) con un bug real de Clikalo — `sispro-list-bugs.sh` trajo correctamente los 2 bugs abiertos de PRODYNAMICS-CLIKALO (idProyecto 246). `sispro-report-time.sh` NO se probo contra un bug real (accion irreversible, mueve a Revision + manda correo) — queda para cuando se atienda un bug real por el flujo completo.
- [x] Crear repo privado en GitHub y push inicial — https://github.com/gvelaxzquez/sispro-bug-agent

## Notas de implementacion

- `scripts/_lib.sh` (no listado en la estructura original del spec, agregado durante implementacion): helper compartido por los 2 scripts para cargar/validar `config/sispro.env` — evita duplicar la validacion de las 3 vars en cada script.
- Los scripts imprimen el body de la respuesta SIEMPRE (exito o error), y solo despues evaluan el `http_code` para decidir el exit code — asi la skill (Claude) puede leer el mensaje de error real de SISPRO en vez de un curl `-f` mudo.
- `sispro-report-time.sh` valida `Tiempo > 0` localmente (via `awk`) antes de pegarle a la API, cumpliendo la regla "valida `Tiempo > 0` antes de llamar" del spec.
- Smoke test hecho: argumentos faltantes, `Tiempo` invalido, y `config/sispro.env` faltante — los 3 casos abortan con mensaje claro y exit 1. No se probo contra un SISPRO real (pendiente, ver checklist).
