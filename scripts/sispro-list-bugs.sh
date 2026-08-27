#!/usr/bin/env bash
# Trae los bugs asignados (Abierto/Progreso) del proyecto configurado en config/sispro.env.
# Salida en stdout: el JSON crudo de /AgenteIA/ConsultarBugs. Si el HTTP status no es 200,
# igual imprime el body (para que la skill vea el mensaje de error) y sale con codigo 1.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/_lib.sh"
sispro_load_config

http_code=$(curl -sS -o /tmp/sispro-list-bugs.$$.json -w '%{http_code}' \
  -H "X-Api-Key: $SISPRO_API_KEY" \
  "$SISPRO_BASE_URL/AgenteIA/ConsultarBugs?idProyecto=$SISPRO_PROJECT_ID")

cat "/tmp/sispro-list-bugs.$$.json"
rm -f "/tmp/sispro-list-bugs.$$.json"

if [ "$http_code" != "200" ]; then
  echo "" >&2
  echo "Error: SISPRO respondio HTTP $http_code" >&2
  exit 1
fi
