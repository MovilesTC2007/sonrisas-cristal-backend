#!/usr/bin/env bash
# Corre ZAP contra la API sin token y con el token de cada rol.

NET=sonrisas-cristal-backend_sonrisas-network
PASS='Test1234!'

mkdir -p zap-reports

# Login por nginx y regresa solo el token
token() {
  curl -sk https://localhost/auth/login -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$PASS\"}" |
    python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])'
}

# Lanza ZAP en un contenedor aparte (los argumentos extra se agregan al final)
zap() {
  docker run --rm --network $NET --memory 3g -e HOME=/tmp \
    -v "$PWD/zap-reports:/zap/wrk:rw" \
    ghcr.io/zaproxy/zaproxy:stable \
    zap-api-scan.py -t http://api:8000/openapi.json -f openapi -I "$@"
}

# Escanea con el token de un usuario (le pone el header Authorization a todo)
con_token() {
  zap -r "report_$1.html" -z "-config replacer.full_list(0).description=auth \
-config replacer.full_list(0).enabled=true \
-config replacer.full_list(0).matchtype=REQ_HEADER \
-config replacer.full_list(0).matchstring=Authorization \
-config replacer.full_list(0).regex=false \
-config replacer.full_list(0).replacement=Bearer\ $2"
}

echo "--- Sin token";  zap -r report_anonimo.html
echo "--- Director";   con_token director  "$(token laura.gomez@sonrisascristal.com)"
echo "--- Staff";      con_token staff     "$(token marta.perez@sonrisascristal.com)"
echo "--- Encargado";  con_token encargado "$(token diego.hernandez@sonrisascristal.com)"

echo "Reportes en zap-reports/"