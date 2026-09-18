// SPDX-FileCopyrightText: 2015 - 2023 Jolla Ltd.
// SPDX-FileCopyrightText: 2024 - 2025 Jolla Mobile Ltd
//
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Weather 1.0

Column {
    property bool highlighted
    // sailfish-weather-wind: show wind speed and direction below the forecast
    property bool showWind
    readonly property bool _hasWindSpeed: showWind && model.maximumWindSpeed !== undefined
                                          && model.maximumWindSpeed >= 0
    readonly property bool _hasWindDirection: showWind && model.windDirection !== undefined
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
    anchors.centerIn: parent

    Label {
        property bool truncate: implicitWidth > parent.width - Theme.paddingSmall

        x: truncate ? Theme.paddingSmall : parent.width/2 - width/2
        // Difficult layout due to limited horizontal space
        // Fade truncation overflows slightly to the adjacent delegate,
        // but should be ok since there is horizontal padding
        width: truncate ? parent.width : implicitWidth
        truncationMode: truncate ? TruncationMode.Fade : TruncationMode.None
        text: model.index === 0
              ? //% "Today"
                qsTrId("weather-la-today")
              : //% "ddd"
                Qt.formatDateTime(timestamp, qsTrId("weather-la-date_pattern_shortweekdays"))
        color: highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
        font.pixelSize: Theme.fontSizeSmall
    }
    Label {
        text: TemperatureConverter.format(model.high)
        anchors.horizontalCenter: parent.horizontalCenter
    }
    Image {
        property string prefix: "image://theme/icon-" + (Screen.sizeCategory >= Screen.Large ? "l" : "m")

        anchors.horizontalCenter: parent.horizontalCenter
        source: model.weatherType.length > 0 ? prefix + "-weather-" + model.weatherType
                                               + (highlighted ? "?" + Theme.highlightColor : "")
                                             : ""
    }
    Label {
        text: TemperatureConverter.format(model.low)
        anchors.horizontalCenter: parent.horizontalCenter
        color: highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
    }
    Label {
        // Maximum wind speed of the day
        visible: _hasWindSpeed
        anchors.horizontalCenter: parent.horizontalCenter
        //: Meters per second, short form
        //% "m/s"
        text: _hasWindSpeed ? model.maximumWindSpeed + " " + qsTrId("weather-la-m_per_s") : ""
        color: highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
        font.pixelSize: Theme.fontSizeExtraSmall
    }
    Row {
        visible: _hasWindDirection
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
