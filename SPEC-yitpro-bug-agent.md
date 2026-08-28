# SPEC: yitpro-bug-agent (Claude Code Plugin)

> v2 — renombrado de `sispro-bug-agent`. SISPRO era nombre legacy; el sistema
> real se llama **YITPRO**. Reescrito contra el instructivo actualizado
> (endpoints con `Clave`/`Repositorios`, `ReportarTiempo` ahora liga commit).
> El repo de GitHub se renombra in-place (`gh repo rename`), no se crea uno
> nuevo — conserva historial/estrellas, GitHub redirige la URL vieja solo.
>
> v2.1 — cada bug atendido escribe su propio spec en
> `mds/bugfix/<IdActividad>.md` del repo destino (causa raiz, plan aprobado
> en el gate 2, solucion implementada), commiteado SIEMPRE junto con el
> codigo que lo resuelve, nunca en un commit separado. Nace de atender el
> bug real 361937: resulto tener dos causas raiz distintas en el mismo
> reporte (perdida de `ProfilePicturePath` en updates sin foto nueva, y
> cache-by-URL sin invalidar tras el update) — el gate 2 ahora deja explicito
> que "un bug" puede requerir documentar mas de una causa.

## Proposito

Plugin de Claude Code, instalable por cualquier miembro del equipo, que:
1. Consulta bugs asignados en YITPRO (`GET /AgenteIA/ConsultarBugs`).
2. Deja elegir un bug (gate 1).
3. Lee el `Markdown` del bug, hace preguntas de aclaracion si algo no esta claro, propone un mini-plan/spec de la correccion (gate 2 — aprobacion antes de tocar codigo, replicando el flujo de `CLAUDE.md`).
4. Implementa el fix en el repo donde se invoco el plugin (el repo del proyecto real, ej. Clikalo).
5. Antes de reportar tiempo y mover el bug a Revision, pide confirmacion final (gate 3 — accion irreversible: **ademas de tiempo/estatus, ahora hace el `git commit` del fix y liga su hash**, dispara correo, cambia estatus).
6. Llama `POST /AgenteIA/ReportarTiempo` con el commit ya hecho.

No es un script Python standalone: es una **skill de Claude Code** (slash command) que usa `Bash`/`curl` para hablar con la API YITPRO directamente. Empaquetado como plugin (`.claude-plugin/plugin.json`).

## Estructura del repo

```
yitpro-bug-agent/
├── .claude-plugin/
│   └── plugin.json              # manifest del plugin
├── skills/
│   └── yitpro-bugs/
│       └── SKILL.md             # instrucciones de la skill (el "cerebro" del flujo)
├── scripts/
│   ├── _lib.sh                  # carga/valida .yitpro.env del repo actual
│   ├── yitpro-list-bugs.sh      # curl GET ConsultarBugs, wrapper delgado
│   └── yitpro-report-time.sh    # curl POST ReportarTiempo, wrapper delgado
├── .yitpro.env.example          # plantilla de config, para setup manual/local
├── README.md
└── LICENSE
```

Cambio vs v1: **ya no existe `config/`**. La config vive suelta en la raiz
del repo destino (ej. raiz de Clikalo), como archivo `.yitpro.env` —
mismo nombre y ubicacion que lo que el wizard de YITPRO (Dashboard → "Agente
IA de Bugs" → Paso 3) descarga directo. Un dev normal ni siquiera copia el
`.example`: descarga el archivo real ya lleno desde su Dashboard y lo suelta
en la raiz.

## Configuracion / credenciales

- Archivo `.yitpro.env` en la **raiz** del repo del proyecto real (ej. raiz
  de Clikalo) — gitignoreado ahi. Se obtiene del wizard del Dashboard YITPRO
  (recomendado, ya viene lleno) o copiando `.yitpro.env.example` (de este
  plugin) a mano.
- Campos, **todos obligatorios** — la skill valida al arrancar que los 4
  esten presentes y no vacios; si falta alguno, aborta con mensaje claro:
  - `YITPRO_BASE_URL` — ej. `http://localhost:47566` (local) / `https://axsis.yitpro.com` (prod/QA segun dominio real del ambiente).
  - `YITPRO_API_KEY` — la key generada en el Dashboard (Paso 1 del wizard). Se muestra una sola vez.
  - `YITPRO_PROJECT` — la **`Clave`** del proyecto (string, ej. `CLIKALOV2`), no un id numerico. Va como query param `proyecto` en `ConsultarBugs`.
  - `YITPRO_REPOSITORY` — el **`Nombre`** del repositorio (ej. `clikaloV2`), tal cual lo entrega el wizard del Dashboard al descargar `.yitpro.env`. `.yitpro.env` es la unica fuente de verdad para este valor — `ConsultarBugs` no trae `Repositorios[]` (ya no aplica, se quito del endpoint), no hay contra-validacion posible contra la API. Va tal cual como `NombreRepositorio` al reportar tiempo — si no matchea del lado de YITPRO, regresa 400 (ver Manejo de errores).
- README explica el flujo completo del wizard (Dashboard → "Agente IA de Bugs" → 3 pasos) y advierte: un proyecto que no aparece en el selector del wizard le falta alguna de las 3 condiciones del Dashboard (asignado a ti, estatus Progreso, al menos un repo configurado) — eso es responsabilidad del Dashboard/admin YITPRO, no de este plugin.

## Slash command: `/yitpro-bugs`

Invocacion: `/yitpro-bugs`, sin argumentos — `YITPRO_PROJECT`/`YITPRO_REPOSITORY` siempre salen de `.yitpro.env`.

### Flujo (definido en `SKILL.md`)

0. **Validar config**: lee `.yitpro.env` en la raiz del repo actual; si no existe o le falta algun campo de los 4, aborta y dice exactamente que falta (y que lo descargue del wizard del Dashboard o copie `.yitpro.env.example`).
1. **Listar**: corre `scripts/yitpro-list-bugs.sh` (usa `YITPRO_PROJECT` como query param `proyecto`), parsea el JSON, muestra tabla resumen (BR / IdActividad / Prioridad / FechaAsignado) del proyecto configurado. Si `Proyectos` viene vacio, informa "sin bugs abiertos" y termina. Sin validacion cruzada de `YITPRO_REPOSITORY` contra la API — `ConsultarBugs` ya no trae `Repositorios[]`, `.yitpro.env` es la unica fuente de verdad para ese valor (si esta mal, el 400 sale hasta el gate 3/paso 7, no antes).
2. **Gate 1 — elegir bug**: igual que v1, pregunta cual `IdActividad` atacar. No elige solo.
3. **Analizar**: igual que v1 — lee el `Markdown`, pregunta lo que falte, explora el repo actual antes de proponer nada.
4. **Gate 2 — mini-plan**: causa raiz sospechada (puede haber mas de una en el mismo reporte, ver `mds/bugfix/361937.md` como ejemplo real de un bug con dos causas), archivos a tocar, approach. Sin aprobacion explicita, no hay codigo. **v2.1**: con el plan aprobado y ANTES de tocar codigo, escribe `mds/bugfix/<IdActividad>.md` en la raiz del repo destino (crea `mds/bugfix/` si no existe) con el reporte original, el analisis y el plan aprobado — el spec del fix, escrito como cualquier spec de este repo, no como changelog posterior.
5. **Implementar**: fix en el repo actual, respetando las convenciones/CLAUDE.md de ESE repo, corre build/tests si existen.
6. **Gate 3 — aprobar cierre (commit + tiempo + reporte, TODO junto)**: antes de ejecutar nada irreversible, muestra en un solo bloque:
   - El **mensaje de commit propuesto** (convenciones del repo destino — para Clikalo, ver reglas de `git commit` en su `CLAUDE.md`: nunca sin pedir, y este gate ES el pedido explicito para este commit puntual). Debe referenciar `mds/bugfix/<IdActividad>.md`.
   - El **`Tiempo`** — pregunta al usuario las horas reales invertidas, no lo inventa.
   - El **`Comentario`** propuesto para la bitacora (el usuario puede ajustarlo).
   - La **`DescripcionCommit`** — si el usuario no da una distinta, usa el subject del commit que se va a hacer (no un valor generico).

   Pide confirmacion explicita de TODO el bloque junto. Si el usuario corrige el mensaje de commit, el tiempo, o el comentario, ajusta y vuelve a mostrar — no ejecuta hasta el OK.
7. **Cerrar**: con el OK del gate 3:
   1. Llena `## Solucion implementada` en `mds/bugfix/<IdActividad>.md` (archivos tocados, que cambio cada uno, si se corrio build/tests o si no se pudo verificar en vivo — decirlo explicito).
   2. `git commit` en el repo actual con el mensaje aprobado, **incluyendo `mds/bugfix/<IdActividad>.md` en el mismo commit que el codigo** (staging igual que cualquier commit normal — revisar `git status`/`git diff` antes, mismas reglas de higiene que el resto del flujo de Claude Code: no `git add -A` ciego; el spec nunca va en un commit separado del fix).
   3. Captura el hash: `git rev-parse HEAD` → hash completo de 40 caracteres (ej. `45175419aa4e36e7d1c6fec05610621343d77b1e`) — **eso exacto es lo que va en `IdLink`**, no un link de Azure/URL, el hash crudo.
   4. Corre:
      ```
      scripts/yitpro-report-time.sh <IdActividad> <Tiempo> <IdLink> ["Comentario"] ["DescripcionCommit"]
      ```
      El script arma el body con `NombreRepositorio` sacado de `YITPRO_REPOSITORY` (config), no como argumento.
   5. Muestra el resultado (`Exito`/`Mensaje`, o el error tal cual).

### Manejo de errores de la API

- `401` → "API key invalida/inactiva, regenera en tu Dashboard YITPRO". No reintenta solo.
- `403` en ReportarTiempo → "el bug no existe o no es tuyo". No reintenta con otro IdActividad sin preguntar.
- `409` → "el bug ya no esta en Abierto/Progreso, no se puede mandar a revision". Informa y no insiste.
- `400` (Tiempo invalido) → el script valida `Tiempo > 0` antes de llamar.
- `400` (falta `NombreRepositorio`/`IdLink`) → no deberia pasar nunca porque el script siempre los manda; si pasa, es bug del plugin, no reintentar ciego.
- `400` (`NombreRepositorio` no matchea el proyecto del bug) → mensaje claro senalando que `YITPRO_REPOSITORY` en `.yitpro.env` no es el que YITPRO espera para ese proyecto — no hay forma de validarlo antes via API (`ConsultarBugs` no expone `Repositorios[]`), asi que el unico chequeo real es este 400; si pasa, revisar el valor descargado del wizard del Dashboard.
- `500` (observado en la practica contra el bug 361994, no documentado en el instructivo — error de EF/LINQ del lado de YITPRO) → informar al usuario que es error del backend YITPRO, ofrecer un reintento (puede ser transitorio), y si persiste, detenerse y no insistir en loop.

## plugin.json (manifest)

```json
{
  "name": "yitpro-bug-agent",
  "description": "Agente que consulta bugs asignados en YITPRO y los atiende con gates de aprobacion (elegir bug, aprobar plan, aprobar commit+reporte final).",
  "version": "2.0.0",
  "author": { "name": "Gerardo Salvador Velazquez Medina" },
  "repository": "yitpro-bug-agent",
  "license": "MIT"
}
```

`version` salta a `2.0.0` (breaking: nombre de comando, config, variables y
firma del script de reporte cambian todos).

## Distribucion (proceso para subirlo y compartirlo)

Repo publico ya existente (`gvelaxzquez/sispro-bug-agent`) se **renombra
in-place**, no se crea uno nuevo:

```
gh repo rename yitpro-bug-agent --repo gvelaxzquez/sispro-bug-agent
```

GitHub deja un redirect automatico de la URL vieja a la nueva (para clones y
`gh`, no para `/plugin marketplace add`, que usa el nombre — ver abajo).

1. **Renombrar** (arriba).
2. **Equipo que ya lo tenia instalado**: el marketplace viejo (`sispro-bug-agent`) sigue apuntando al repo renombrado por el redirect de git, pero el nombre del marketplace/plugin registrado localmente en su Claude Code sigue siendo el viejo — deben:
   ```
   /plugin uninstall sispro-bug-agent@sispro-bug-agent
   /plugin marketplace remove sispro-bug-agent
   /plugin marketplace add gvelaxzquez/yitpro-bug-agent
   /plugin install yitpro-bug-agent@yitpro-bug-agent
   ```
   (documentar esto en el README como "Migrando de sispro-bug-agent" — es breaking para cualquiera que ya lo tenia).
3. **Instalacion nueva** (nadie lo tenia antes):
   ```
   /plugin marketplace add gvelaxzquez/yitpro-bug-agent
   /plugin install yitpro-bug-agent@yitpro-bug-agent
   ```
4. Resto del proceso de updates igual que v1 (bump de `version`, `/plugin marketplace update yitpro-bug-agent`).

## Fuera de alcance (fase 1, sigue igual)

- Wrapper Python standalone / modo no-interactivo (CI, cron).
- Multi-tenant / multi-cuenta YITPRO simultaneo.
- Auto-deteccion de en que repo real aplicar el fix.
- Auto-update garantizado sin intervencion en repos privados (n/a ahora que es publico, pero se documenta igual por si se privatiza despues).
- Multi-repositorio por proyecto en un solo `.yitpro.env` — si un proyecto YITPRO tiene 2+ repos (ver `Repositorios[]`), cada repo real tiene su propio `.yitpro.env` con su propio `YITPRO_REPOSITORY`; el plugin no intenta manejar mas de un repo destino a la vez.

## Checklist de implementacion (v2)

- [x] Renombrar repo GitHub (`gh repo rename`) — https://github.com/gvelaxzquez/yitpro-bug-agent, carpeta local tambien renombrada
- [x] `.claude-plugin/plugin.json` → nombre/version (2.0.0)/descripcion nuevos
- [x] `skills/sispro-bugs/` → `skills/yitpro-bugs/SKILL.md` (flujo v2 completo: query `proyecto`, `.yitpro.env` como unica fuente de `NombreRepositorio` (sin cross-check contra la API), gate 3 con commit+tiempo+reporte juntos, manejo de 400 por repo-mismatch y 500)
- [x] `scripts/_lib.sh` → lee `.yitpro.env` de la raiz (no `config/`), valida 4 vars (`YITPRO_BASE_URL/API_KEY/PROJECT/REPOSITORY`)
- [x] `scripts/sispro-list-bugs.sh` → `scripts/yitpro-list-bugs.sh` (query `proyecto=$YITPRO_PROJECT`)
- [x] `scripts/sispro-report-time.sh` → `scripts/yitpro-report-time.sh` (firma nueva: `<IdActividad> <Tiempo> <IdLink> ["Comentario"] ["DescripcionCommit"]`, agrega `NombreRepositorio` del config al body)
- [x] `config/sispro.env.example` → `.yitpro.env.example` en la raiz del plugin
- [x] `.gitignore` del plugin → ignora `.yitpro.env` (ya no `config/sispro.env`)
- [x] `README.md` → instrucciones v2 completas + seccion "Migrando de sispro-bug-agent"
- [x] En el repo Clikalo: se borro `config/sispro.env` viejo y se actualizo `.gitignore` de Clikalo (`config/sispro.env` → `.yitpro.env`). Pendiente crear el `.yitpro.env` real ahi con `YITPRO_PROJECT`/`YITPRO_REPOSITORY` reales — requiere que el usuario lo descargue del wizard del Dashboard o de los valores reales (no inventados por el agente).
- [x] Prueba manual end-to-end v2 — `.yitpro.env` real ya en la raiz de Clikalo. `yitpro-list-bugs.sh` confirmado contra YITPRO real: trae `Clave` (`PRODX05`), sin `Repositorios[]` (correcto, ya no lo expone el endpoint). Ciclo completo de commit+reporte (Paso 7) aun no probado con un bug real — pendiente para cuando se cierre uno.
