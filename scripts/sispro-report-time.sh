#!/usr/bin/env bash
# Reporta tiempo invertido en un bug y lo manda a Revision.
# Uso: sispro-report-time.sh <IdActividad> <Tiempo> ["Comentario"]
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/_lib.sh"
sispro_load_config

id_actividad="${1:-}"
tiempo="${2:-}"
comentario="${3:-Registrado por Agente IA}"

if [ -z "$id_actividad" ] || [ -z "$tiempo" ]; then
  echo "Uso: $0 <IdActividad> <Tiempo> [\"Comentario\"]" >&2
  exit 1
fi

if ! awk "BEGIN{exit !($tiempo > 0)}"; then
  echo "Error: Tiempo debe ser > 0 (recibido: $tiempo)" >&2
  exit 1
fi

json_escape() {
  # Escapa backslash y comillas dobles para meter el string en un literal JSON.
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

body="{\"IdActividad\": $id_actividad, \"Tiempo\": $tiempo, \"Comentario\": \"$(json_escape "$comentario")\"}"

http_code=$(curl -sS -o /tmp/sispro-report-time.$$.json -w '%{http_code}' \
  -X POST \
  -H "X-Api-Key: $SISPRO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$body" \
  "$SISPRO_BASE_URL/AgenteIA/ReportarTiempo")

cat "/tmp/sispro-report-time.$$.json"
rm -f "/tmp/sispro-report-time.$$.json"

if [ "$http_code" != "200" ]; then
  echo "" >&2
  echo "Error: SISPRO respondio HTTP $http_code" >&2
  exit 1
fi
