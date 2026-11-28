#!/usr/bin/env bash
# Corre ZAP contra la API sin token y con el token de cada rol.
# Antes: docker compose up -d api nginx-tls
#
# Nota: /auth/logout se saca del openapi.json que escanea ZAP, porque la API
# invalida el token al cerrar sesion y el resto del escaneo saldria en 401.
 
NET=sonrisas-cristal-backend_sonrisas-network
PASS='Test1234!'
SPEC=zap-reports/openapi_sin_logout.json
 
mkdir -p zap-reports
chmod 777 zap-reports 2>/dev/null
 
# Copia del openapi.json sin /auth/logout y con el servidor interno de docker
curl -sk https://localhost/openapi.json | python3 -c '
import sys, json
d = json.load(sys.stdin)
d["paths"].pop("/auth/logout", None)
d["servers"] = [{"url": "http://api:8000"}]
json.dump(d, open("'"$SPEC"'", "w"))
'
[ -s "$SPEC" ] || { echo "No pude bajar el openapi.json (¿nginx arriba?)"; exit 1; }
chmod 644 "$SPEC"
 
# Login por nginx y regresa solo el token
token() {
  curl -sk https://localhost/auth/login -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$PASS\"}" |
    python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])' 2>/dev/null
}
 
# Lanza ZAP en un contenedor aparte.
# $1 = nombre del reporte, $2 = token (vacio = sin autenticar)
zap() {
  local auth=()
  [ -n "${2:-}" ] && auth=(-e "ZAP_AUTH_HEADER_VALUE=Bearer $2")
 
  docker run --rm --network $NET --memory 3g -e HOME=/tmp \
    "${auth[@]}" \
    -v "$PWD/zap-reports:/zap/wrk:rw" \
    ghcr.io/zaproxy/zaproxy:stable \
    zap-api-scan.py -t /zap/wrk/openapi_sin_logout.json -f openapi \
    -r "report_$1.html" -J "report_$1.json" -I
}
 
# Escanea con el token de un usuario (avisa y salta si el login falla)
con_rol() {
  local rol="$1" correo="$2" t
  echo "--- $rol"
  t=$(token "$correo")
  if [ -z "$t" ]; then
    echo "No pude sacar el token de $correo. Salto este rol."
    return
  fi
  zap "$rol" "$t"
}
 
echo "--- Sin token"
zap anonimo ""
 
con_rol director  laura.gomez@sonrisascristal.com
con_rol staff     marta.perez@sonrisascristal.com
con_rol encargado diego.hernandez@sonrisascristal.com
 
echo "Reportes en zap-reports/"