#!/bin/sh
# Runs tests/backends.qml against src/backends on a Sailfish OS device.
# Needs a MET Norway sample as tests/met.js ("var METJSON = {...};"), for example:
#   (printf 'var METJSON = '; curl -s -A 'sailfish-weather-wind test' \
#     'https://api.met.no/weatherapi/locationforecast/2.0/complete?lat=48.21&lon=16.37'; printf ';\n') > tests/met.js
set -e
cd "$(dirname "$0")/.."
work=$(mktemp -d)
cp /usr/share/sailfish-weather/backends/*.js "$work"/
# ForecaToken.js is only installed with the Foreca backend; the copy in tests/ is upstream 1.3.11
[ -f "$work/ForecaToken.js" ] || cp tests/ForecaToken.js "$work"/
cp src/backends/*.qml tests/backends.qml tests/met.js "$work"/
QT_LOGGING_TO_CONSOLE=1 qmlscene "$work/backends.qml" 2>&1 | grep -v 'library\|namespace\|MEMPROF\|large_page\|Wayland-EGL\|invalid handle\|EGL' \
    | sed 's/^\[D\] [a-zA-Z]*:[0-9]* - //'
rm -rf "$work"
