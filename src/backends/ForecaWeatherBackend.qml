// SPDX-FileCopyrightText: 2014 - 2023 Jolla Ltd.
// SPDX-FileCopyrightText: 2024 - 2025 Jolla Mobile Ltd
//
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.6
import "ForecaToken.js" as ForecaToken
import "BackendUtils.js" as BackendUtils
import "WeatherTypeDescriptions.js" as WeatherTypeDescriptions

QtObject {
    function providerId() {
        return "foreca"
    }

    function providerTitle() {
        //% "Foreca"
        return qsTrId("weather_settings-me-foreca")
    }

    function requiresApiKey() {
        return false
    }

    function apiKeyInstructions() {
        return ""
    }

    function fetchToken(weatherRequest, apiKey) {
        return ForecaToken.fetchToken(weatherRequest)
    }

    function canLoadWeather(weather) {
        return !!weather && Number(weather.locationId) > 0
    }

    function currentWeatherUrl(weather) {
        return 'https://pfa.foreca.com/api/v1/current/' + weather.locationId + authParam()
    }

    function latestObservationUrl(weather) {
        return "https://pfa.foreca.com/api/v1/observation/latest/" + weather.locationId + authParam()
    }

    function forecastUrl(weather, isHourly) {
        return 'https://pfa.foreca.com/api/v1/forecast/' + (isHourly ? "hourly/" : "daily/") + weather.locationId + authParam()
    }

    function searchLocationUrl(filter, language) {
        return "https://pfa.foreca.com/api/v1/location/search/" + filter.toLowerCase() + "&lang=" + language + authParam()
    }

    function reverseLocationResponseType() {
        return "text"
    }

    function reverseLocationUrl(latitude, longitude, language) {
        var roundedLongitude = reverseLookupCoordinate(longitude)
        var roundedLatitude = reverseLookupCoordinate(latitude)

        return "http://fnw-jll.foreca.com/findloc.php"
                + "?lon=" + roundedLongitude
                + "&lat=" + roundedLatitude
                + "&format=xml/jolla-sep13fi"
                + "&radius=10"
    }

    function handleCurrentWeatherResult(result) {

        var current = result["current"]
        if (result.length === 0 || current.temperature === "") {
            return undefined
        }

        var weather = getWeatherData(current)
        weather.timestamp =  new Date(current.time)
        weather.temperature = current.temperature
        weather.feelsLikeTemperature = current.feelsLikeTemp
        return weather
    }


    function handleObservationResult(result) {
        var observations = result["observations"]
        if (observations.length > 0) {
            return observations[0].station
        }

        return ""
    }

    function handleForecastResult(result, hourly, visibleCount, minimumHourlyRange) {
        var forecast = result["forecast"]
        if (result.length === 0 || forecast.length === 0) {
            return undefined
        }

        var weatherData = []
        for (var i = 0; i < forecast.length; i++) {
            var data = forecast[i]
            var weather = getWeatherData(data)
            if (hourly) {
                if (i % 3 !== 0) continue
                weather.timestamp =  new Date(data.time)
                weather.temperature = data.temperature
                weather.windSpeed = data.windSpeed != null ? Math.round(data.windSpeed) : -1
                weather.windDirection = data.windDir != null ? data.windDir : -1
            } else {
                var dateArray = data.date.split("-")
                weather.timestamp = new Date(parseInt(dateArray[0]),
                                             parseInt(dateArray[1] - 1),
                                             parseInt(dateArray[2]))
                weather.accumulatedPrecipitation = data.precipAccum
                weather.maximumWindSpeed = data.maxWindSpeed
                weather.windDirection = data.windDir
                weather.high = data.maxTemp
                weather.low = data.minTemp
            }
            weatherData[weatherData.length] = weather
        }

        if (hourly) {
            return BackendUtils.normalizeHourlyTemperatures(
                        weatherData, visibleCount, minimumHourlyRange, false)
        }

        return weatherData
    }

    function handleSearchLocationResult(result) {
        if (result === undefined || result === null) {
            return undefined
        }

        var locations = result["locations"]
        if (locations === undefined || locations === null) {
            return undefined
        }

        return locations
    }

    function handleReverseLocationResult(result, latitude, longitude) {
        if (result === undefined || result === null || result.length === 0) {
            return undefined
        }

        var firstLocation = firstXmlElement(result, "location")
        if (firstLocation.length === 0) {
            return undefined
        }

        var locationId = firstXmlTagValue(firstLocation, "id")
        var city = firstXmlTagValue(firstLocation, "name")
        if (locationId.length === 0 || city.length === 0) {
            return undefined
        }

        return {
            "id": parseInt(locationId, 10),
            "locationId": parseInt(locationId, 10),
            "name": city,
            "city": city,
            "country": "",
            "state": "",
            "adminArea": "",
            "adminArea2": "",
            "latitude": latitude,
            "longitude": longitude
        }
    }

    function externalUrl(weather) {
        return "https://foreca.mobi/spot.php?l=" + weather.locationId
    }

    function providerImage() {
        return "image://theme/graphic-foreca-large?"
    }

    function smallProviderImage() {
        return "image://theme/graphic-foreca-small?"
    }

    function getWeatherData(weather) {
        var data = {
            "description": description(weather.symbol),
            "weatherType": weatherType(weather.symbol),
            "cloudiness": (100 * parseInt(weather.symbol.charAt(1)) / 4)
        }
        return data
    }

    function weatherType(code) {
        // just direct mapping, but ensure we receive valid data
        if (code.length === 4) {
            return code
        } else {
            console.warn("Invalid weather code")
            return ""
        }
    }

    function description(code) {
        return WeatherTypeDescriptions.description(code)
    }

    function authParam() {
        return '&token='
    }

    function reverseLookupCoordinate(value) {
        var angle = Number(value)
        var integer = Math.floor(angle)
        var decimal = 2 * Math.round(50 * (angle - integer))
        if (decimal === 100) {
            integer = Math.floor(angle + 1)
            decimal = 0
        }
        return integer.toString() + "." + (decimal < 10 ? "0" : "") + decimal.toString()
    }

    function firstXmlElement(xml, elementName) {
        var match = xml.match(new RegExp("<" + elementName + "[^>]*>([\\s\\S]*?)</" + elementName + ">", "i"))
        return match && match.length > 0 ? match[0] : ""
    }

    function firstXmlTagValue(xml, tagName) {
        var match = xml.match(new RegExp("<" + tagName + ">([\\s\\S]*?)</" + tagName + ">", "i"))
        return match && match.length > 1 ? decodeXmlEntities(match[1]) : ""
    }

    function decodeXmlEntities(value) {
        return value.replace(/&amp;/g, "&")
                    .replace(/&lt;/g, "<")
                    .replace(/&gt;/g, ">")
                    .replace(/&quot;/g, "\"")
                    .replace(/&apos;/g, "'")
    }
}
