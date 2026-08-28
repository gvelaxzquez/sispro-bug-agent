#!/usr/bin/env bash
# Cargado por los demas scripts de yitpro-bug-agent. No se ejecuta solo.
set -euo pipefail

yitpro_load_config() {
  local config_file=".yitpro.env"

  if [ ! -f "$config_file" ]; then
    echo "Error: no existe $config_file en la raiz del repo actual." >&2
    echo "Descargalo del wizard en tu Dashboard YITPRO (\"Agente IA de Bugs\" -> Paso 3)" >&2
    echo "o copia .yitpro.env.example (del plugin) a $config_file y llenalo a mano." >&2
    exit 1
  fi

  set -a
  # shellcheck disable=SC1090
  source "$config_file"
  set +a

  local missing=()
  [ -z "${YITPRO_BASE_URL:-}" ] && missing+=("YITPRO_BASE_URL")
  [ -z "${YITPRO_API_KEY:-}" ] && missing+=("YITPRO_API_KEY")
  [ -z "${YITPRO_PROJECT:-}" ] && missing+=("YITPRO_PROJECT")
  [ -z "${YITPRO_REPOSITORY:-}" ] && missing+=("YITPRO_REPOSITORY")

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Error: faltan variables en $config_file: ${missing[*]}" >&2
    exit 1
  fi
}
