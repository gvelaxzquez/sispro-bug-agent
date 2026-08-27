# sispro-bug-agent

Plugin de Claude Code que consulta tus bugs asignados en SISPRO y los atiende
uno a la vez con tres gates de aprobacion humana: elegir bug, aprobar el plan
antes de tocar codigo, y aprobar antes de reportar tiempo (accion irreversible
que manda el bug a Revision y dispara un correo).

Ver `SPEC-sispro-bug-agent.md` para el diseno completo.

## Instalacion (equipo)

Requiere `curl`, `jq` y `git`/`gh` con credenciales ya configuradas. En
Windows, usa Git Bash (el shell de este entorno).

```
/plugin marketplace add <owner>/sispro-bug-agent
/plugin install sispro-bug-agent@sispro-bug-agent
```

Si es la primera vez que instalas algo de un repo privado tuyo/de tu org,
corre una vez:
```
gh auth setup-git
```
para que las actualizaciones en background no fallen por auth.

## Configuracion (por cada repo donde lo vayas a usar)

El plugin lee la config **del repo del proyecto real** (ej. Clikalo), no de
si mismo. Dentro de ese repo:

1. Copia `config/sispro.env.example` (de este plugin) a `config/sispro.env`
   en la raiz del repo del proyecto.
2. Llena:
   - `SISPRO_BASE_URL` — URL de SISPRO del ambiente que vas a usar.
   - `SISPRO_API_KEY` — genera la tuya en tu Dashboard de SISPRO
     (`/Dashboard/p/{tuClave}` → "Generar API Key Agente IA"). Se muestra
     una sola vez; si la pierdes, genera otra (invalida la anterior).
   - `SISPRO_PROJECT_ID` — el `idProyecto` fijo de ese repo en SISPRO.
3. `config/sispro.env` ya esta en `.gitignore` de este plugin, pero
   agregalo tambien al `.gitignore` del repo del proyecto si no esta.

## Uso

Desde la raiz del repo del proyecto, en una sesion de Claude Code:

```
/sispro-bug-agent:sispro-bugs
```

El flujo completo esta descrito en `skills/sispro-bugs/SKILL.md`.

## Troubleshooting

| Error | Causa |
|---|---|
| `no existe config/sispro.env` | Falta el paso de configuracion, ver arriba. |
| `faltan variables en config/sispro.env` | Alguno de los 3 campos quedo vacio. |
| HTTP 401 | API key invalida o inactiva. Regenerala en tu Dashboard de SISPRO. |
| HTTP 403 (al reportar tiempo) | El `IdActividad` no existe, no es un bug, o no esta asignado a tu usuario en SISPRO. |
| HTTP 409 (al reportar tiempo) | El bug ya no esta en Abierto/Progreso (ya esta en Revision/Validacion/Rechazado/Liberado); no se puede volver a mandar a revision. |
| HTTP 400 (al reportar tiempo) | `Tiempo` invalido (debe ser numero > 0). |

## Actualizaciones (para el equipo)

El maintainer bumpea `version` en `.claude-plugin/plugin.json` en cada
cambio y hace push. Si no te llega automatico en background, corre:
```
/plugin marketplace update sispro-bug-agent
```

## Fuera de alcance (fase 1)

- No hay wrapper Python ni modo no interactivo — asume un humano operando
  Claude Code en cada gate.
- Una sola `SISPRO_API_KEY`/tenant activo a la vez.
- No detecta solo en que repo aplicar el fix — corre `/sispro-bug-agent:sispro-bugs`
  desde el repo correcto.
