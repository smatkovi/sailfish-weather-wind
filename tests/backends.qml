// Headless check of the patched backend parsers.
// Run: tests/run-backends.sh (copies the backends next to a MET Norway sample and runs qmlscene)
import QtQuick 2.6
import "met.js" as Data

Item {
    id: root

    property string dir: Qt.resolvedUrl(".").toString()

    function load(name) {
        var c = Qt.createComponent(dir + name)
        if (c.status !== Component.Ready) {
            console.log("LOAD FAIL", name, c.errorString())
            return null
        }
        return c.createObject(root)
    }
    function summarize(name, rows, speedKey) {
        if (rows === undefined) {
            console.log(name, "=> undefined")
            return
        }
        var s = name + " => " + rows.length + " rows:"
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i]
            s += "\n   [" + i + "] " + speedKey + "=" + r[speedKey] + " dir=" + r.windDirection + " t=" + r.temperature
                    + " rel=" + (r.relativeTemperature !== undefined ? r.relativeTemperature.toFixed(2) : "-")
                    + " type=" + r.weatherType + " keys=" + Object.keys(r).sort().join(",")
        }
        console.log(s)
    }

    Component.onCompleted: {
        var met = load("MetNorwayBackend.qml")
        var json = JSON.parse(JSON.stringify(Data.METJSON))
        summarize("met hourly", met.handleForecastResult(json, true, 6, 4), "windSpeed")
        summarize("met daily", met.handleForecastResult(json, false, 6, 4), "maximumWindSpeed")
        var stripped = JSON.parse(JSON.stringify(Data.METJSON))
        delete stripped.properties.timeseries[1].data.instant.details.wind_speed
        delete stripped.properties.timeseries[1].data.instant.details.wind_from_direction
        summarize("met hourly, entry 1 without wind", met.handleForecastResult(stripped, true, 6, 4), "windSpeed")

        var ow = load("OpenWeatherBackend.qml")
        var list = []
        for (var i = 0; i < 8; i++) {
            list.push({ "dt": 1789776000 + i * 10800, "main": { "temp": 10 + i, "temp_max": 12 + i, "temp_min": 8 + i },
                        "weather": [{ "id": 800, "icon": "01d" }], "clouds": { "all": 10 },
                        "wind": { "speed": 2.6 + i, "deg": 30 * i } })
        }
        summarize("openweather hourly", ow.handleForecastResult({ "list": list }, true, 6, 4), "windSpeed")
        summarize("openweather daily", ow.handleForecastResult({ "list": list }, false, 6, 4), "maximumWindSpeed")
        delete list[2].wind
        summarize("openweather hourly, entry 2 without wind", ow.handleForecastResult({ "list": list }, true, 6, 4), "windSpeed")

        var om = load("OpenMeteoBackend.qml")
        console.log("openmeteo hourly url:", om.forecastUrl({ "latitude": 48.2, "longitude": 16.37 }, true))
        console.log("openmeteo daily url:", om.forecastUrl({ "latitude": 48.2, "longitude": 16.37 }, false))
        var h = { "time": [], "temperature_2m": [], "weather_code": [], "cloud_cover": [], "is_day": [],
                  "wind_speed_10m": [], "wind_direction_10m": [] }
        for (i = 0; i < 8; i++) {
            h.time.push(1789776000 + i * 3600); h.temperature_2m.push(10 + i); h.weather_code.push(1)
            h.cloud_cover.push(20); h.is_day.push(1); h.wind_speed_10m.push(1.4 * i); h.wind_direction_10m.push(45 * i)
        }
        summarize("openmeteo hourly", om.handleForecastResult({ "hourly": h }, true, 6, 4), "windSpeed")
        var h2 = { "time": h.time, "temperature_2m": h.temperature_2m, "weather_code": h.weather_code,
                   "cloud_cover": h.cloud_cover, "is_day": h.is_day }
        summarize("openmeteo hourly, no wind arrays", om.handleForecastResult({ "hourly": h2 }, true, 6, 4), "windSpeed")

        var fc = load("ForecaWeatherBackend.qml")
        var f = []
        for (i = 0; i < 24; i++) {
            f.push({ "time": "2026-09-19T" + (i < 10 ? "0" + i : i) + ":00:00+02:00", "temperature": 10 + i,
                     "symbol": "d000", "windSpeed": 3.5 + i, "windDir": 10 * i })
        }
        summarize("foreca hourly", fc.handleForecastResult({ "forecast": f }, true, 6, 4), "windSpeed")
        console.log("DONE")
        Qt.quit()
    }
}
