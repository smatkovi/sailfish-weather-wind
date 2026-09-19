// Headless layout check for the patched forecast delegates.
// Run: QT_LOGGING_TO_CONSOLE=1 QML2_IMPORT_PATH=<dir with patched Sailfish/Weather> qmlscene tests/delegates.qml
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Weather 1.0

ApplicationWindow {
    id: app

    ListModel { id: dailyModel }
    ListModel { id: hourlyModel }
    ListModel { id: plainModel }

    function dumpItem(item, indent) {
        var kids = item.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            var desc = indent + c.toString().split("(")[0] + " visible=" + c.visible + " h=" + Math.round(c.height) + " w=" + Math.round(c.width)
            if (c.text !== undefined) desc += " text='" + c.text + "'"
            if (c.source !== undefined && c.rotation !== undefined) desc += " rot=" + c.rotation + " src=" + c.source
            console.log(desc)
            if (c.text === undefined) dumpItem(c, indent + "  ")
        }
    }
    function dumpList(name, list) {
        console.log("== " + name + " listHeight=" + list.height + " itemHeight=" + list.itemHeight + " itemWidth=" + list.itemWidth + " implicit=" + list.implicitHeight)
        var delegates = list.contentItem.children
        var shown = 0
        for (var i = 0; i < delegates.length && shown < 2; i++) {
            var d = delegates[i]
            if (d.children.length === 0) continue
            shown++
            var col = d.children[0]
            console.log("-- delegate " + i + " column h=" + Math.round(col.height) + " w=" + Math.round(col.width) + " y=" + Math.round(col.y))
            dumpItem(col, "   ")
        }
    }

    Component.onCompleted: {
        var now = new Date(2026, 8, 19, 12, 0, 0)
        for (var i = 0; i < 7; i++) {
            dailyModel.append({ "timestamp": new Date(now.getTime() + i * 86400000), "high": 20 + i, "low": 10 + i,
                                "weatherType": "d200", "description": "x", "accumulatedPrecipitation": 0,
                                "maximumWindSpeed": (i === 3 ? -1 : 3 * i), "windDirection": (i === 4 ? -1 : i * 45) })
            hourlyModel.append({ "timestamp": new Date(now.getTime() + i * 3600000), "temperature": 15 + i,
                                 "relativeTemperature": i / 6, "weatherType": "d200",
                                 "windSpeed": 11 + i, "windDirection": 285.2 + i * 40 })
            plainModel.append({ "timestamp": new Date(now.getTime() + i * 3600000), "temperature": 15 + i,
                                "relativeTemperature": i / 6, "weatherType": "d200" })
        }
    }

    Column {
        width: parent.width
        WeatherForecastList {
            id: dailyList
            columnCount: 6
            model: dailyModel
            delegate: Item {
                property bool showWind: true
                width: dailyList.itemWidth
                height: dailyList.height
                DailyForecastItem {
                    onHeightChanged: if (model.index == 0) dailyList.itemHeight = height
                }
            }
        }
        WeatherForecastList {
            id: hourlyList
            columnCount: 6
            model: hourlyModel
            delegate: Item {
                property bool showWind: true
                width: hourlyList.itemWidth
                height: hourlyList.height
                HourlyForecastItem {
                    onHeightChanged: if (model.index == 0) hourlyList.itemHeight = height
                }
            }
        }
        WeatherForecastList {
            id: plainList
            columnCount: 6
            model: plainModel
            delegate: Item {
                property bool showWind: true
                width: plainList.itemWidth
                height: plainList.height
                HourlyForecastItem {
                    onHeightChanged: if (model.index == 0) plainList.itemHeight = height
                }
            }
        }
        WeatherForecastList {
            id: offList
            columnCount: 6
            model: hourlyModel
            delegate: Item {
                width: offList.itemWidth
                height: offList.height
                HourlyForecastItem {
                    onHeightChanged: if (model.index == 0) offList.itemHeight = height
                }
            }
        }
    }

    Timer {
        interval: 2500; running: true
        onTriggered: {
            console.log("locale", Qt.locale().name, "screen", Screen.width)
            dumpList("daily (wind)", dailyList)
            dumpList("hourly (wind)", hourlyList)
            dumpList("hourly (model without wind roles)", plainList)
            dumpList("hourly (showWind off)", offList)
            Qt.quit()
        }
    }
}
