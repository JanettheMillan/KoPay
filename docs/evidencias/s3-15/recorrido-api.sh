#!/bin/bash
# S3-15 · Recorrido de acceso contra la API real (contrato §2 y §3).
# Uso: con la API corriendo (npm run migrate && npm start) y una base vacía:
#   API_URL=http://localhost:3000 bash docs/evidencias/s3-15/recorrido-api.sh
F=$(mktemp)
B=${API_URL:-http://localhost:3000}/api
j(){ curl -s -o "$F" -w "%{http_code}" "$@"; }
c(){ printf "%-58s %s  %s\n" "$1" "$2" "$(head -c 150 "$F")"; }
s=$(j -X POST $B/auth/register -H 'Content-Type: application/json' -d '{"name":"Ana López","email":"ana.e2e@mail.com","password":"kopay2026"}'); c "register válido (201)" $s
s=$(j -X POST $B/auth/register -H 'Content-Type: application/json' -d '{"name":"Ana","email":"ana.e2e@mail.com","password":"kopay2026"}'); c "register correo repetido (409 EMAIL_TAKEN)" $s
s=$(j -X POST $B/auth/register -H 'Content-Type: application/json' -d '{"name":"","email":"x","password":"1"}'); c "register inválido (400 VALIDATION_FAILED)" $s
s=$(j -X POST $B/auth/register -H 'Content-Type: application/json' -d '{"name":'); c "JSON roto (400 INVALID_JSON)" $s
s=$(j -X POST $B/auth/login -H 'Content-Type: application/json' -d '{"email":"ana.e2e@mail.com","password":"mala"}'); c "login contraseña mala (401 INVALID_CREDENTIALS)" $s
s=$(j -X POST $B/auth/login -H 'Content-Type: application/json' -d '{"email":"nadie@mail.com","password":"mala"}'); c "login correo inexistente (401 mismo cuerpo)" $s
s=$(j -X POST $B/auth/login -H 'Content-Type: application/json' -d '{"email":"ANA.e2e@mail.com","password":"kopay2026"}'); c "login correcto, correo en mayúsculas (200)" $s
AT=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["accessToken"])' "$F"); RT=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["refreshToken"])' "$F")
s=$(j $B/auth/me -H "Authorization: Bearer $AT"); c "me con token (200)" $s
s=$(j $B/auth/me); c "me sin token (401 UNAUTHENTICATED)" $s
s=$(j -X POST $B/movements -H "Authorization: Bearer $AT" -H 'Content-Type: application/json' -d '{"amount":-150.5,"description":"Café","category":"Comida","date":"2026-11-26"}'); c "crear movimiento (201)" $s
s=$(j -X POST $B/incomes -H "Authorization: Bearer $AT" -H 'Content-Type: application/json' -d '{"name":"Nómina","amount":12500,"date":"2026-11-15"}'); c "crear ingreso (201)" $s
s=$(j -X POST $B/auth/refresh -H 'Content-Type: application/json' -d "{\"refreshToken\":\"$RT\"}"); c "refresh (200, tokens nuevos)" $s
AT2=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["accessToken"])' "$F")
s=$(j -X POST $B/auth/refresh -H 'Content-Type: application/json' -d "{\"refreshToken\":\"$RT\"}"); c "refresh reusado (401)" $s
s=$(j $B/auth/me -H "Authorization: Bearer $AT"); c "token anterior al refresh (401)" $s
s=$(j $B/movements -H "Authorization: Bearer $AT2"); c "listar movimientos con token nuevo (200)" $s
s=$(j -X POST $B/auth/logout -H "Authorization: Bearer $AT2"); c "logout (204)" $s
s=$(j $B/auth/me -H "Authorization: Bearer $AT2"); c "me tras logout (401)" $s
s=$(j $B/clients -H "Authorization: Bearer $AT2"); c "clients sin sesión (401)" $s
s=$(j $B/no-existe); c "ruta inexistente (404 NOT_FOUND)" $s
for i in $(seq 1 10); do j -X POST $B/auth/login -H 'Content-Type: application/json' -d '{"email":"ana.e2e@mail.com","password":"mala"}' >/dev/null; done
s=$(j -X POST $B/auth/login -H 'Content-Type: application/json' -d '{"email":"ana.e2e@mail.com","password":"kopay2026"}'); c "11.º intento tras 10 fallos (429 TOO_MANY_ATTEMPTS)" $s
