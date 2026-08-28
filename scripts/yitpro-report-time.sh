#!/usr/bin/env bash
# Liga un commit, reporta tiempo invertido y manda el bug a Revision (una sola llamada).
# Uso: yitpro-report-time.sh <IdActividad> <Tiempo> <IdLink> ["Comentario"] ["DescripcionCommit"]
# IdLink = hash completo de 40 caracteres del commit (git rev-parse HEAD), no una URL.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/_lib.sh"
yitpro_load_config

id_actividad="${1:-}"
tiempo="${2:-}"
id_link="${3:-}"
comentario="${4:-Registrado por Agente IA}"
descripcion_commit="${5:-Commit ${id_link}}"

if [ -z "$id_actividad" ] || [ -z "$tiempo" ] || [ -z "$id_link" ]; then
  echo "Uso: $0 <IdActividad> <Tiempo> <IdLink> [\"Comentario\"] [\"DescripcionCommit\"]" >&2
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

body="{\"IdActividad\": $id_actividad, \"Tiempo\": $tiempo, \"Comentario\": \"$(json_escape "$comentario")\", \"NombreRepositorio\": \"$(json_escape "$YITPRO_REPOSITORY")\", \"IdLink\": \"$(json_escape "$id_link")\", \"DescripcionCommit\": \"$(json_escape "$descripcion_commit")\"}"

http_code=$(curl -sS -o /tmp/yitpro-report-time.$$.json -w '%{http_code}' \
  -X POST \
  -H "X-Api-Key: $YITPRO_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$body" \
  "$YITPRO_BASE_URL/AgenteIA/ReportarTiempo")

cat "/tmp/yitpro-report-time.$$.json"
rm -f "/tmp/yitpro-report-time.$$.json"

if [ "$http_code" != "200" ]; then
  echo "" >&2
  echo "Error: YITPRO respondio HTTP $http_code" >&2
  exit 1
fi
