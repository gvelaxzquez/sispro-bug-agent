#!/usr/bin/env bash
# Trae los bugs asignados (Abierto/Progreso) del proyecto configurado en .yitpro.env.
# Salida en stdout: el JSON crudo de /AgenteIA/ConsultarBugs. Si el HTTP status no es 200,
# igual imprime el body (para que la skill vea el mensaje de error) y sale con codigo 1.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/_lib.sh"
yitpro_load_config

http_code=$(curl -sS -o /tmp/yitpro-list-bugs.$$.json -w '%{http_code}' \
  -H "X-Api-Key: $YITPRO_API_KEY" \
  "$YITPRO_BASE_URL/AgenteIA/ConsultarBugs?proyecto=$YITPRO_PROJECT")

cat "/tmp/yitpro-list-bugs.$$.json"
rm -f "/tmp/yitpro-list-bugs.$$.json"

if [ "$http_code" != "200" ]; then
  echo "" >&2
  echo "Error: YITPRO respondio HTTP $http_code" >&2
  exit 1
fi
