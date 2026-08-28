# yitpro-bug-agent

Plugin de Claude Code que consulta tus bugs asignados en YITPRO y los atiende
uno a la vez con tres gates de aprobacion humana: elegir bug, aprobar el plan
antes de tocar codigo, y aprobar el cierre (commit + tiempo + reporte, en una
sola accion — irreversible, mueve el bug a Revision y dispara un correo).

> Renombrado de `sispro-bug-agent` — SISPRO era el nombre legacy del sistema,
> ahora es YITPRO. Ver "Migrando de sispro-bug-agent" abajo si ya lo tenias
> instalado.

Ver `SPEC-yitpro-bug-agent.md` para el diseno completo.

## Instalacion (equipo)

Requiere `curl` y `git`/`gh` con credenciales ya configuradas. En Windows,
usa Git Bash (el shell de este entorno).

```
/plugin marketplace add gvelaxzquez/yitpro-bug-agent
/plugin install yitpro-bug-agent@yitpro-bug-agent
```

## Migrando de sispro-bug-agent

Si ya tenias instalado el plugin viejo:
```
/plugin uninstall sispro-bug-agent@sispro-bug-agent
/plugin marketplace remove sispro-bug-agent
/plugin marketplace add gvelaxzquez/yitpro-bug-agent
/plugin install yitpro-bug-agent@yitpro-bug-agent
```
Y en cada repo donde lo usabas, mueve tu config de `config/sispro.env` a
`.yitpro.env` en la raiz (ver siguiente seccion — las variables tambien
cambiaron de nombre).

## Configuracion (por cada repo donde lo vayas a usar)

El plugin lee la config **del repo del proyecto real** (ej. Clikalo), no de
si mismo, y **de la raiz de ese repo**, no de una subcarpeta.

1. Ve a tu Dashboard YITPRO → boton **"Agente IA de Bugs"** en el header del
   perfil → sigue el wizard de 3 pasos (genera tu API key, instala el
   plugin, descarga tu config). El wizard te da el archivo `.yitpro.env`
   ya lleno para el proyecto/repo que elijas — suelta ese archivo directo en
   la raiz del repo.
2. Alternativa manual: copia `.yitpro.env.example` (de este plugin) a
   `.yitpro.env` en la raiz del repo del proyecto y llena:
   - `YITPRO_BASE_URL` — dominio de YITPRO en tu ambiente.
   - `YITPRO_API_KEY` — key generada en el wizard (Paso 1). Se muestra una
     sola vez; si la pierdes, genera otra (invalida la anterior).
   - `YITPRO_PROJECT` — la `Clave` del proyecto (ej. `CLIKALOV2`), no un id
     numerico.
   - `YITPRO_REPOSITORY` — el `Nombre` del repositorio dentro de ese
     proyecto (ej. `clikaloV2`). Debe matchear exacto del lado de YITPRO
     para poder ligar commits al reportar tiempo.
3. `.yitpro.env` ya esta en `.gitignore` de este plugin, pero agregalo
   tambien al `.gitignore` del repo del proyecto si no esta.

Si un proyecto no aparece en el selector del wizard (Paso 3), le falta
alguna de estas 3 condiciones en YITPRO: asignado a ti, estatus **Progreso**,
y al menos un repositorio configurado — resuelvelo ahi, no es algo que este
plugin pueda arreglar.

## Uso

Desde la raiz del repo del proyecto, en una sesion de Claude Code:

```
/yitpro-bug-agent:yitpro-bugs
```

El flujo completo esta descrito en `skills/yitpro-bugs/SKILL.md`. A
diferencia de v1, el cierre de un bug incluye hacer el `git commit` del fix
como parte del gate de aprobacion final — YITPRO liga commit + tiempo +
cambio de estatus en una sola llamada.

## Troubleshooting

| Error | Causa |
|---|---|
| `no existe .yitpro.env` | Falta el paso de configuracion, ver arriba. |
| `faltan variables en .yitpro.env` | Alguno de los 4 campos quedo vacio. |
| HTTP 401 | API key invalida o inactiva. Regenerala en tu Dashboard YITPRO. |
| HTTP 403 (al reportar tiempo) | El `IdActividad` no existe, no es un bug, o no esta asignado a tu usuario en YITPRO. |
| HTTP 409 (al reportar tiempo) | El bug ya no esta en Abierto/Progreso (ya esta en Revision/Validacion/Rechazado/Liberado); no se puede volver a mandar a revision. |
| HTTP 400 (`Tiempo` invalido) | Debe ser numero > 0. |
| HTTP 400 (`NombreRepositorio` no matchea) | `YITPRO_REPOSITORY` en tu `.yitpro.env` no es el que YITPRO espera para ese proyecto — revisalo/redescargalo del wizard. |
| HTTP 500 | Error del backend YITPRO (visto en la practica, no documentado oficialmente). Suele ser transitorio — reintenta una vez; si persiste, es un bug de YITPRO, no del plugin. |

## Actualizaciones (para el equipo)

El maintainer bumpea `version` en `.claude-plugin/plugin.json` en cada
cambio y hace push. Si no te llega automatico en background, corre:
```
/plugin marketplace update yitpro-bug-agent
```

## Fuera de alcance (fase 1)

- No hay wrapper Python ni modo no interactivo — asume un humano operando
  Claude Code en cada gate.
- Una sola `YITPRO_API_KEY`/tenant activo a la vez.
- No detecta solo en que repo aplicar el fix — corre
  `/yitpro-bug-agent:yitpro-bugs` desde el repo correcto.
- Un `.yitpro.env` maneja un solo repo destino a la vez — si un proyecto
  YITPRO tiene varios repositorios, cada uno necesita su propio
  `.yitpro.env` con su propio `YITPRO_REPOSITORY`.
