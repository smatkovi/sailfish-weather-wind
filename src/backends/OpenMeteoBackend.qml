// SPDX-FileCopyrightText: 2026 Jolla Mobile Ltd
//
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.6
import "BackendUtils.js" as BackendUtils
import "WeatherTypeDescriptions.js" as WeatherTypeDescriptions

QtObject {
    readonly property string openMeteoForecastApi: "https://api.open-meteo.com/v1/forecast"
    readonly property string openMeteoGeocodingApi: "https://geocoding-api.open-meteo.com/v1/search"

    function providerId() {
        return "open_meteo"
    }

    function providerTitle() {
        //% "Open-Meteo"
        return qsTrId("weather_settings-me-open-meteo")
    }

    function requiresApiKey() {
        return false
    }

    function apiKeyInstructions() {
        return ""
    }

    function attributionText() {
        //% "Weather data from <a href='https://open-meteo.com/'>Open-Meteo</a>."
        return qsTrId("weather_settings-open-meteo-attribution")
    }

    function shortAttributionText() {
        //% "Weather data from Open-Meteo"
        return qsTrId("weather-la-open-meteo-attribution-short")
    }

    function fetchToken(weatherRequest, apiKey) {
        weatherRequest.token = ""
        return true
    }

    function requestHeaders() {
        return {
            "Accept": "application/json"
        }
    }

    function forecastBaseUrl(weather) {
        return openMeteoForecastApi
                + "?latitude=" + weather.latitude
                + "&longitude=" + weather.longitude
                + "&timezone=auto"
                + "&timeformat=unixtime"
                + "&temperature_unit=celsius"
                + "&wind_speed_unit=ms"
                + "&precipitation_unit=mm"
    }

    function currentWeatherUrl(weather) {
        return forecastBaseUrl(weather)
                + "&current=temperature_2m,apparent_temperature,weather_code,cloud_cover,is_day"
    }

    function latestObservationUrl(weather) {
        return currentWeatherUrl(weather)
    }

    function forecastUrl(weather, isHourly) {
        var variables = isHourly
                ? "temperature_2m,weather_code,cloud_cover,is_day,wind_speed_10m,wind_direction_10m"
                : "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,wind_direction_10m_dominant"

        return forecastBaseUrl(weather)
                + (isHourly ? "&forecast_hours=7" : "&forecast_days=7")
                + (isHourly ? "&hourly=" : "&daily=") + variables
    }

    function searchLocationUrl(filter, language) {
        return openMeteoGeocodingApi + "?count=20&name="
                + encodeURIComponent(filter.toLowerCase())
                + (language && language.length > 0 ? "&language=" + encodeURIComponent(language) : "")
    }

    function handleCurrentWeatherResult(result) {
        if (!result || !result.current || result.current.temperature_2m === undefined) {
            return undefined
        }

        var current = result.current
        var weather = getWeatherData(current.weather_code, current.cloud_cover, current.is_day)
        weather.timestamp = new Date(current.time * 1000)
        weather.temperature = current.temperature_2m
        weather.feelsLikeTemperature = current.apparent_temperature
        return weather
    }

    function handleForecastResult(result, hourly, visibleCount, minimumHourlyRange) {
        if (!result) {
            return undefined
        }

        return hourly ? handleHourlyForecastResult(result, visibleCount, minimumHourlyRange)
                      : handleDailyForecastResult(result)
    }

    function handleHourlyForecastResult(result, visibleCount, minimumHourlyRange) {
        var hourly = result.hourly
        if (!hourly || !hourly.time || hourly.time.length === 0) {
            return undefined
        }

        var weatherData = []
        for (var i = 0; i < hourly.time.length && weatherData.length < visibleCount + 1; i++) {
            if (hourly.temperature_2m[i] === undefined || hourly.weather_code[i] === undefined) {
                continue
            }

            var weather = getWeatherData(
                        hourly.weather_code[i],
                        hourly.cloud_cover ? hourly.cloud_cover[i] : undefined,
                        hourly.is_day ? hourly.is_day[i] : undefined)
            weather.timestamp = new Date(hourly.time[i] * 1000)
            weather.temperature = hourly.temperature_2m[i]
            weather.windSpeed = hourly.wind_speed_10m && hourly.wind_speed_10m[i] !== undefined
                    ? Math.round(hourly.wind_speed_10m[i]) : -1
            weather.windDirection = hourly.wind_direction_10m && hourly.wind_direction_10m[i] !== undefined
                    ? hourly.wind_direction_10m[i] : -1
            weatherData[weatherData.length] = weather
        }

        return BackendUtils.normalizeHourlyTemperatures(
                    weatherData, visibleCount, minimumHourlyRange, true)
    }

    function handleDailyForecastResult(result) {
        var daily = result.daily
        if (!daily || !daily.time || daily.time.length === 0) {
            return undefined
        }

        var weatherData = []
        for (var i = 0; i < daily.time.length; i++) {
            if (daily.weather_code[i] === undefined
                    || daily.temperature_2m_max[i] === undefined
                    || daily.temperature_2m_min[i] === undefined) {
                continue
            }

            var weather = getWeatherData(daily.weather_code[i], undefined, 1)
            weather.timestamp = new Date(daily.time[i] * 1000)
            weather.accumulatedPrecipitation = daily.precipitation_sum && daily.precipitation_sum[i] !== undefined
                    ? daily.precipitation_sum[i]
                    : 0
            weather.maximumWindSpeed = daily.wind_speed_10m_max && daily.wind_speed_10m_max[i] !== undefined
                    ? Math.round(daily.wind_speed_10m_max[i])
                    : 0
            weather.windDirection = daily.wind_direction_10m_dominant && daily.wind_direction_10m_dominant[i] !== undefined
                    ? daily.wind_direction_10m_dominant[i]
                    : 0
            weather.high = Math.floor(daily.temperature_2m_max[i])
            weather.low = Math.round(daily.temperature_2m_min[i])
            weatherData[weatherData.length] = weather
        }

        return weatherData.length > 0 ? weatherData : undefined
    }

    function handleSearchLocationResult(result) {
        if (!result || !result.results) {
            return undefined
        }
        if (result.results.length === 0) {
            return []
        }

        var locations = []
        for (var i = 0; i < result.results.length; i++) {
            var location = result.results[i]
            var lat = parseFloat(location.latitude)
            var lon = parseFloat(location.longitude)
            if (isNaN(lat) || isNaN(lon)) {
                continue
            }
            var locationId = parseInt(location.id, 10)
            if (!isFinite(locationId) || locationId <= 0) {
                locationId = hashLatLon(lat, lon, 15, 0x4f4d45)
            }

            var admin1 = location.admin1 || ""
            var admin2 = location.admin2 || ""
            var admin3 = location.admin3 || ""
            var admin4 = location.admin4 || ""
            locations[locations.length] = {
                "id": locationId,
                "name": location.name || "",
                "state": admin1,
                "country": location.country || "",
                "adminArea": admin1,
                "adminArea2": admin2 || admin3 || admin4,
                "latitude": lat,
                "longitude": lon
            }
        }

        return locations.length > 0 ? locations : undefined
    }

    function handleObservationResult(result) {
        return ""
    }

    function externalUrl(weather) {
        return "https://open-meteo.com/"
    }

    function providerImage() {
        return "image://theme/open-meteo?"
    }

    function smallProviderImage() {
        return "image://theme/open-meteo-small?"
    }

    function getWeatherData(wmoCode, cloudiness, isDay) {
        var weatherTypeCode = weatherTypeFromWmoCode(wmoCode, cloudiness)
        var timePrefix = isDay === 0 ? "n" : "d"
        return {
            "description": WeatherTypeDescriptions.description(timePrefix + weatherTypeCode),
            "weatherType": weatherType(timePrefix + weatherTypeCode),
            "cloudiness": cloudiness !== undefined ? cloudiness : cloudinessFromWmoCode(wmoCode)
        }
    }

    function weatherTypeFromWmoCode(wmoCode, cloudiness) {
        switch (wmoCode) {
        case 0:
            return "000"
        case 1:
            return "100"
        case 2:
            return "200"
        case 3:
            return "400"
        case 45:
        case 48:
            return "600"
        case 51:
        case 53:
            return cloudVariant(cloudiness, "210", "310", "410")
        case 55:
            return cloudVariant(cloudiness, "220", "320", "430")
        case 56:
            return cloudVariant(cloudiness, "211", "311", "411")
        case 57:
            return cloudVariant(cloudiness, "221", "321", "431")
        case 61:
            return cloudVariant(cloudiness, "210", "310", "410")
        case 63:
            return cloudVariant(cloudiness, "220", "320", "430")
        case 65:
            return cloudVariant(cloudiness, "220", "320", "430")
        case 66:
            return cloudVariant(cloudiness, "211", "311", "411")
        case 67:
            return cloudVariant(cloudiness, "221", "321", "431")
        case 71:
        case 73:
            return cloudVariant(cloudiness, "212", "312", "412")
        case 75:
        case 77:
            return cloudVariant(cloudiness, "222", "322", "432")
        case 80:
            return cloudVariant(cloudiness, "220", "320", "420")
        case 81:
        case 82:
            return cloudVariant(cloudiness, "220", "320", "430")
        case 85:
        case 86:
            return cloudVariant(cloudiness, "222", "322", "422")
        case 95:
        case 96:
        case 99:
            return cloudVariant(cloudiness, "240", "340", "440")
        default:
            return cloudinessCode(cloudiness)
        }
    }

    function cloudinessFromWmoCode(wmoCode) {
        switch (wmoCode) {
        case 0:
            return 0
        case 1:
            return 25
        case 2:
            return 50
        case 3:
        case 45:
        case 48:
            return 100
        default:
            return 100
        }
    }

    function cloudVariant(cloudiness, partlyCloudyCode, cloudyCode, overcastCode) {
        if (cloudiness === undefined || cloudiness === null) {
            return overcastCode
        }
        if (cloudiness < 30) {
            return partlyCloudyCode
        }
        if (cloudiness < 70) {
            return cloudyCode
        }
        return overcastCode
    }

    function cloudinessCode(cloudiness) {
        if (cloudiness === undefined || cloudiness === null) {
            return "400"
        }
        if (cloudiness < 20) {
            return "000"
        }
        if (cloudiness < 45) {
            return "100"
        }
        if (cloudiness < 75) {
            return "200"
        }
        if (cloudiness < 95) {
            return "300"
        }
        return "400"
    }

    function weatherType(code) {
        if (code.length === 4) {
            return code
        }

        console.warn("Invalid weather code")
        return ""
    }

    function hashLatLon(lat, lon, precisionBits, seed) {
        precisionBits = precisionBits || 16
        seed = seed || 0

        var latScaled = Math.floor(((lat + 90) / 180) * (1 << precisionBits))
        var lonScaled = Math.floor(((lon + 180) / 360) * (1 << precisionBits))
        var hash = ((latScaled << precisionBits) | lonScaled) ^ seed
        hash = hash & 0x7fffffff
        return hash > 0 ? hash : 1
    }
}
