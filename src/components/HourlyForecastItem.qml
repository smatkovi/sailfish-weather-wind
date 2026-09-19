// SPDX-FileCopyrightText: 2020 - 2023 Jolla Ltd.
// SPDX-FileCopyrightText: 2024 - 2025 Jolla Mobile Ltd
//
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Weather 1.0

Column {
    property bool highlighted
    property int hourMode: DateTime.TwentyFourHours
    // sailfish-weather-wind: show wind speed and direction below the forecast.
    // Switched on by a showWind property on the parent item (the Events view banner does that)
    property bool showWind: parent && parent.showWind === true
    // The model has wind roles at all (all rows of a model have them or none, so columns stay equal)
    readonly property bool _hasWindRoles: showWind && model.windSpeed !== undefined
    readonly property bool _hasWindSpeed: _hasWindRoles && typeof model.windSpeed === "number"
                                          && model.windSpeed >= 0
    readonly property bool _hasWindDirection: _hasWindRoles && typeof model.windDirection === "number"
                                              && model.windDirection >= 0

    // Compass point the wind blows from, abbreviated in the UI language
    function compassPoint(degrees) {
        var points = {
            "de": ["N", "NO", "O", "SO", "S", "SW", "W", "NW"],
            "nl": ["N", "NO", "O", "ZO", "Z", "ZW", "W", "NW"],
            "fr": ["N", "NE", "E", "SE", "S", "SO", "O", "NO"],
            "es": ["N", "NE", "E", "SE", "S", "SO", "O", "NO"],
            "it": ["N", "NE", "E", "SE", "S", "SO", "O", "NO"],
            "ca": ["N", "NE", "E", "SE", "S", "SO", "O", "NO"],
            "pt": ["N", "NE", "L", "SE", "S", "SO", "O", "NO"],
            "fi": ["P", "KO", "I", "KA", "E", "LO", "L", "LU"],
            "sv": ["N", "NO", "O", "SO", "S", "SV", "V", "NV"],
            "nb": ["N", "NØ", "Ø", "SØ", "S", "SV", "V", "NV"],
            "da": ["N", "NØ", "Ø", "SØ", "S", "SV", "V", "NV"],
            "cs": ["S", "SV", "V", "JV", "J", "JZ", "Z", "SZ"],
            "sk": ["S", "SV", "V", "JV", "J", "JZ", "Z", "SZ"],
            "sl": ["S", "SV", "V", "JV", "J", "JZ", "Z", "SZ"],
            "lt": ["Š", "ŠR", "R", "PR", "P", "PV", "V", "ŠV"],
            "lv": ["Z", "ZA", "A", "DA", "D", "DR", "R", "ZR"],
            "hu": ["É", "ÉK", "K", "DK", "D", "DNy", "Ny", "ÉNy"],
            "tr": ["K", "KD", "D", "GD", "G", "GB", "B", "KB"],
            "ru": ["С", "СВ", "В", "ЮВ", "Ю", "ЮЗ", "З", "СЗ"],
            "el": ["Β", "ΒΑ", "Α", "ΝΑ", "Ν", "ΝΔ", "Δ", "ΒΔ"]
        }
        var names = points[Qt.locale().name.substr(0, 2)] || ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return names[Math.round((((degrees % 360) + 360) % 360) / 45) % 8]
    }

    width: parent.width

    Item {
        property int padding: Theme.paddingSmall

        width: temperatureLabel.width
        height: temperatureGraph.height + temperatureLabel.height + padding
        anchors.horizontalCenter: parent.horizontalCenter

        Label {
            id: temperatureLabel

            text: TemperatureConverter.format(model.temperature)
            y: (1 - model.relativeTemperature) * temperatureGraph.height - parent.padding
        }
    }

    Image {
        property string prefix: "image://theme/icon-" + (Screen.sizeCategory >= Screen.Large ? "l" : "m")

        anchors.horizontalCenter: parent.horizontalCenter
        source: model.weatherType.length > 0 ? prefix + "-weather-" + model.weatherType
                                               + (highlighted ? "?" + Theme.highlightColor : "")
                                             : ""
    }

    Row {
        id: timeRow

        anchors.horizontalCenter: parent.horizontalCenter
        Label {
            id: timeLabel

            text: {
                if (hourMode === DateTime.TwentyFourHours) {
                    return Format.formatDate(model.timestamp, Format.TimeValueTwentyFourHours)
                } else {
                    var hours = model.timestamp.getHours()
                    if (hours === 0) {
                        hours = 12
                    } else if (hours > 12) {
                        hours -= 12
                    }

                    //% "h"
                    //: Pattern for 12h time, should be either "h" or "hh", latter with optional 0 at the start (like "03")
                    var result = qsTrId("weather-la-12h_time_pattern_without_ap")
                    var zero = 0

                    if (result.indexOf("hh") !== -1) {
                        var hourString = ""

                        if (hours < 10) {
                            hourString = zero.toLocaleString()
                        }
                        hourString += hours.toLocaleString()

                        result = result.replace("hh", hourString)
                    } else {
                        result = result.replace("h", hours.toLocaleString())
                    }

                    return result
                }
            }
            font.pixelSize: hourMode === DateTime.TwentyFourHours ? Theme.fontSizeSmall : Theme.fontSizeMedium
        }
        Label {
            visible: hourMode === DateTime.TwelveHours
            text: model.timestamp.getHours() < 12
                  ? //: Short postfix shown behind hours in twelve hour mode, e.g. time is 8am
                    //: Align with jolla-clock-la-am
                    //% "AM"
                    qsTrId("weather-la-hourmode_am")
                  : //: Short postfix shown behind hours in twelve hour mode, e.g. 3pm time
                    //: Align with jolla-clock-la-pm
                    //% "PM"
                    qsTrId("weather-clock-la-hourmode_pm")
            color: highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            font.pixelSize: Theme.fontSizeTiny
            anchors.baseline: timeLabel.baseline
        }
    }

    Label {
        // Wind speed at that hour
        visible: _hasWindRoles
        opacity: _hasWindSpeed ? 1.0 : 0.0
        anchors.horizontalCenter: parent.horizontalCenter
        //: Meters per second, short form
        //% "m/s"
        text: _hasWindSpeed ? model.windSpeed + " " + qsTrId("weather-la-m_per_s") : " "
        color: highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
        font.pixelSize: Theme.fontSizeExtraSmall
    }
    Row {
        visible: _hasWindRoles
        opacity: _hasWindDirection ? 1.0 : 0.0
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.paddingSmall

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconSizeExtraSmall
            height: Theme.iconSizeExtraSmall
            sourceSize.width: Theme.iconSizeExtraSmall
            sourceSize.height: Theme.iconSizeExtraSmall
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: "image://theme/icon-direction-forward?"
                    + (highlighted ? Theme.highlightColor : Theme.primaryColor)
            // The arrow points where the wind blows to, like the wind graphic in the Weather app
            rotation: _hasWindDirection ? model.windDirection + 180 : 0
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: _hasWindDirection ? compassPoint(model.windDirection) : ""
            color: highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            font.pixelSize: Theme.fontSizeExtraSmall
        }
    }
}
