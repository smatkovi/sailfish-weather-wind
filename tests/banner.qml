// Headless check of the installed Sailfish.Weather.WeatherBanner with live data
// (the component the Events view uses). Needs a saved weather location and network.
// Run: QT_LOGGING_TO_CONSOLE=1 qmlscene tests/banner.qml
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Weather 1.0 as Weather

ApplicationWindow {
    id: app

    function walk(item, indent, out) {
        var kids = item.children
        if (!kids) return
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            var type = c.toString().split("(")[0]
            if (type.indexOf("WeatherForecastList") === 0) {
                // Without a visible window nothing polishes the view, so fill it by hand
                c.forceLayout()
                out.push(indent + type + " height=" + Math.round(c.height) + " itemHeight=" + c.itemHeight
                         + " itemWidth=" + c.itemWidth + " width=" + Math.round(c.width) + " count=" + c.count
                         + " delegates=" + c.contentItem.children.length)
            }
            if (c.text !== undefined && c.text !== "") {
                out.push(indent + type + " '" + c.text + "' w=" + Math.round(c.width))
            } else if (c.source !== undefined && ("" + c.source).indexOf("direction") >= 0) {
                out.push(indent + type + " rot=" + c.rotation.toFixed(1) + " visible=" + c.visible + " size=" + Math.round(c.width))
            }
            if (c.text === undefined) walk(c, indent + " ", out)
        }
    }

    function dump(label) {
        var m = banner.forecastModel
        console.log("== " + label + " hourly=" + banner.hourly + " enabled=" + banner.enabled + " bannerHeight=" + Math.round(banner.height)
                    + " contentHeight=" + Math.round(banner.contentHeight) + " appWidth=" + app.width
                    + " status=" + (m ? m.status : "-") + " count=" + (m ? m.count : "-")
                    + " city=" + (banner.weather ? banner.weather.city : "-"))
        if (!m) return
        for (var i = 0; i < m.count; i++) {
            var r = m.get(i)
            console.log("  row " + i + ": t=" + r.temperature + " high=" + r.high + " windSpeed=" + r.windSpeed
                        + " maximumWindSpeed=" + r.maximumWindSpeed + " windDirection=" + r.windDirection)
        }
        var out = []
        walk(banner, "  ", out)
        for (i = 0; i < out.length; i++) console.log(out[i])
    }

    Weather.WeatherBanner {
        id: banner

        width: parent.width
        autoRefresh: true
        active: true
        expanded: true
        showExpand: false
    }

    // Toggling the mode writes /sailfish/weather/forecast_mode, so put it back at the end
    property bool initialHourly

    Timer {
        id: first
        interval: 12000; running: true
        onTriggered: {
            initialHourly = banner.hourly
            dump("first mode")
            banner.hourly = !banner.hourly
            second.start()
        }
    }
    Timer {
        id: second
        interval: 12000
        onTriggered: {
            dump("second mode")
            banner.hourly = initialHourly
            Qt.quit()
        }
    }
}
