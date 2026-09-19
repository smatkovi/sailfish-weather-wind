// SPDX-FileCopyrightText: 2025 Jolla Mobile Ltd
//
// SPDX-License-Identifier: BSD-3-Clause
//
// @author Anton Turko <turok@duck.com>

import QtQuick 2.6
import "BackendUtils.js" as BackendUtils

QtObject {
    readonly property string openWeatherApi: "https://api.openweathermap.org/data/2.5/"

    function providerId() {
        return "open_weather"
    }

    function providerTitle() {
        //% "Open Weather"
        return qsTrId("weather_settings-me-open-weather")
    }

    function requiresApiKey() {
        return true
    }

    function apiKeyInstructions() {
        //: Step by step instruction how to obtain api key for OpenWeather provider.
        //: Where %1 gets replaced by sign up url and %2 by api key page
        //% "To obtain your API key:"
        //% "<ol><li>Register an account."
        //% "<p>Go to <b><a href='%1'>OpenWeatherMap</a></b> and create an account.</p></li>"
        //% "<li>Generate your API key"
        //% "<p>After logging in, navigate to the <b><a href='%2'>API keys</a></b> section and generate a new API key.</p></li>"
        //% "<li>Enter the API key<p>Copy and paste the API key in the <b>API Key</b> field above.</p></li></ol>"
        return qsTrId("weather_settings-open-weather-instruction")
                .arg("https://home.openweathermap.org/users/sign_up")
                .arg("https://home.openweathermap.org/api_keys")
    }

    function fetchToken(weatherRequest, apiKey) {
        weatherRequest.token = apiKey ? apiKey : ""
        return true
    }

    function currentWeatherUrl(weather) {
        return openWeatherApi + 'weather?units=metric&lat=' + weather.latitude + "&lon=" + weather.longitude + getAuthParams()
    }

    function latestObservationUrl(weather) {
        return currentWeatherUrl(weather)
    }

    function forecastUrl(weather, isHourly) {
        return openWeatherApi + 'forecast?units=metric&lat=' + weather.latitude + "&lon=" + weather.longitude
            + (isHourly ? "&cnt=7" : "") + getAuthParams()
    }

    function searchLocationUrl(filter, language) {
        return "https://api.openweathermap.org/geo/1.0/direct?limit=20&q=" + encodeURIComponent(filter.toLowerCase()) + getAuthParams()
    }

    function handleCurrentWeatherResult(result) {
        if (result === undefined || result.main === undefined || result.main.temp === "") {
            return undefined
        }

        var weather = getWeatherData(result)
        weather.latitude = result.coord.lat
        weather.longitude = result.coord.lon
        weather.timestamp = new Date(result.dt * 1000)
        weather.temperature = result.main.temp
        weather.feelsLikeTemperature = result.main.feels_like
        return weather
    }

    function handleForecastResult(result, hourly, visibleCount, minimumHourlyRange) {
        var forecast = result.list
        if (result.length === 0 || forecast.length === 0) {
            return undefined
        }

        var weatherData = []
        for (var i = 0; i < forecast.length; i++) {
            var data = forecast[i]
            var weather = getWeatherData(data)
            weather.timestamp = new Date(data.dt * 1000)
            weather.temperature = data.main.temp

            if (!hourly) {
                weather.accumulatedPrecipitation = data.rain === undefined ? (data.snow === undefined ? 0 : data.snow["3h"])
                                                                           : data.rain["3h"]
                weather.maximumWindSpeed = Math.round(data.wind.speed)
                weather.windDirection = data.wind.deg
                weather.high = data.main.temp_max
                weather.low = data.main.temp_min
            } else {
                weather.windSpeed = data.wind && data.wind.speed != null ? Math.round(data.wind.speed) : -1
                weather.windDirection = data.wind && data.wind.deg != null ? data.wind.deg : -1
            }
            weatherData[weatherData.length] = weather
        }

        if (hourly) {
            return BackendUtils.normalizeHourlyTemperatures(
                        weatherData, visibleCount, minimumHourlyRange, true)
        } else {
            var groupedByDay = weatherData.reduce(function(container, weather) {
                var timestamp = weather.timestamp
                var year = timestamp.getFullYear()
                var month = timestamp.getMonth()
                var day = timestamp.getDate()
                var key = [year, month, day].join("-")
                if (!container[key]) {
                    container[key] = []
                }
                container[key].push(weather)
                return container
            }, {})

            var weatherDayByDay = []
            for (var date in groupedByDay) {
                var weathers = groupedByDay[date]
                var weather = weathers[0]
                var precipitation = weather.accumulatedPrecipitation
                var minimumTemperature = weather.temperature
                var maximumTemperature = weather.temperature
                var middayDate = new Date(weather.timestamp)
                middayDate.setHours(12)
                middayDate.setMinutes(0)
                var dateDiff = Math.abs(weather.timestamp - middayDate)

                for (var weatherIndex = 1; weatherIndex < weathers.length; weatherIndex++) {
                    precipitation += weather.accumulatedPrecipitation
                    var temperature = weathers[weatherIndex].temperature
                    minimumTemperature = Math.min(minimumTemperature, temperature)
                    maximumTemperature = Math.max(maximumTemperature, temperature)
                    var diff = Math.abs(weathers[weatherIndex].timestamp - middayDate)
                    if (diff < dateDiff) {
                        weather = weathers[weatherIndex]
                        dateDiff = diff
                    }
                }
                weather.accumulatedPrecipitation = precipitation
                weather.high = Math.floor(maximumTemperature)
                weather.low = Math.round(minimumTemperature)
                weatherDayByDay[weatherDayByDay.length] = weather
            }

            weatherData = weatherDayByDay
        }

        return weatherData
    }

    function hashLatLon(lat, lon, precisionBits) {
        precisionBits = precisionBits || 16

        var latScaled = Math.floor(((lat + 90) / 180) * (1 << precisionBits))
        var lonScaled = Math.floor(((lon + 180) / 360) * (1 << precisionBits))

        return (latScaled << precisionBits) | lonScaled
    }

    function handleSearchLocationResult(result) {
        if (result === undefined || result === null) {
            return undefined
        }

        var locations = result
        if (locations.length === 0) {
            return []
        }

        for (var i = 0; i < locations.length; i++) {
            var location = locations[i]
            location.id = hashLatLon(location.lat, location.lon, 15)
            location.adminArea = location.state
            location.latitude = location.lat
            location.longitude = location.lon
        }
        return locations
    }

    function handleObservationResult(result) {
        if (result === undefined) {
            return ""
        }

        return result.name
    }

    function externalUrl(weather) {
        return ''
    }

    function providerImage() {
        return  "image://theme/open-weather?"
    }

    function smallProviderImage() {
        return "image://theme/open-weather-small?"
    }

    function weatherTypeFromOpenWeather(openWeatherId) {
        switch(openWeatherId) {
            case 800: return "000" // Clear
            case 801: return "100" // Mostly clear
            case 802: return "200" // Partly cloudy
            case 803: return "300" // Cloudy
            case 804: return "400" // Overcast
            case 701: return "600" // Fog
            case 711: return "600" // Fog
            case 721: return "600" // Fog
            case 731: return "600" // Fog
            case 741: return "600" // Fog
            case 751: return "600" // Fog
            case 761: return "600" // Fog
            case 762: return "600" // Fog
            case 771: return "600" // Fog
            case 781: return "600" // Fog
            case 600: return "212" // Partly cloudy and light snow
            case 601: return "312" // Cloudy and light snow
            case 602: return "412" // Overcast and light snow
            case 611: return "211" // sleet
            case 612: return "311" // light shower sleet
            case 613: return "411" // shower sleet
            case 615: return "221" // light rain and snow
            case 616: return "421" // rain and snow
            case 620: return "222" // Partly cloudy and snow showers
            case 621: return "322" // Cloudy and snow showers
            case 622: return "422" // Overcast and snow showers
            case 500: return "210" // Partly cloudy and light rain
            case 501: return "310" // Cloudy and light rain
            case 502: return "410" // Overcast and light rain
            case 503: return "410" // Overcast and rain
            case 504: return "420" // Overcast and light rain
            case 511: return "410" // Overcast and light rain
            case 520: return "220" // Partly cloudy and showers
            case 521: return "320" // Cloudy and showers
            case 522: return "420" // Overcast and showers
            case 531: return "430" // Cloudy and showers
            case 300: return "420" // Overcast and light rain
            case 301: return "430" // Overcast and light rain
            case 302: return "440" // Overcast and light rain
            case 310: return "420" // Overcast and light rain
            case 311: return "430" // Overcast and light rain
            case 312: return "440" // Overcast and light rain
            case 313: return "420" // Overcast and light rain
            case 314: return "430" // Overcast and light rain
            case 321: return "440" // Overcast and light rain
            case 200: return "240" // Partly cloudy, possible thunderstorms with rain
            case 201: return "340" // Cloudy, thunderstorms with rain
            case 202: return "440" // Overcast, thunderstorms with rain
            case 210: return "240" // Overcast, thunderstorms with rain
            case 211: return "340" // Overcast, thunderstorms with rain
            case 212: return "440" // Overcast, thunderstorms with rain
            case 221: return "240" // Overcast, thunderstorms with rain
            case 230: return "240" // Overcast, thunderstorms with rain
            case 231: return "240" // Overcast, thunderstorms with rain
            case 232: return "440" // Overcast, thunderstorms with rain
            default: {
                console.log("Mapping not found for openWeatherId: ", openWeatherId)
                return null // No mapping found
            }
        }
    }

    function getWeatherData(weather) {
        var id = weather.weather[0].id
        var timeSymbol = weather.weather[0].icon.charAt(2)
        var symbol = timeSymbol + weatherTypeFromOpenWeather(id)

        var data = {
            "description": description(id),
            "weatherType": weatherType(symbol),
            "cloudiness": weather.clouds.all
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
        var localizations = {
          //% "Thunderstorm with light rain"
          "200": qsTrId("weather-la-description-thunderstorm_with_light_rain"),
          //% "Thunderstorm with rain"
          "201": qsTrId("weather-la-description-thunderstorm_with_rain"),
          //% "Thunderstorm with heavy rain"
          "202": qsTrId("weather-la-description-thunderstorm_with_heavy_rain"),
          //% "Light thunderstorm"
          "210": qsTrId("weather-la-description-light_thunderstorm"),
          //% "Thunderstorm"
          "211": qsTrId("weather-la-description-thunderstorm"),
          //% "Heavy thunderstorm"
          "212": qsTrId("weather-la-description-heavy_thunderstorm"),
          //% "Ragged thunderstorm"
          "221": qsTrId("weather-la-description-ragged_thunderstorm"),
          //% "Thunderstorm with light drizzle"
          "230": qsTrId("weather-la-description-thunderstorm_with_light_drizzle"),
          //% "Thunderstorm with drizzle"
          "231": qsTrId("weather-la-description-thunderstorm_with_drizzle"),
          //% "Thunderstorm with heavy drizzle"
          "232": qsTrId("weather-la-description-thunderstorm_with_heavy_drizzle"),
          //% "Light intensity drizzle"
          "300": qsTrId("weather-la-description-light_intensity_drizzle"),
          //% "Drizzle"
          "301": qsTrId("weather-la-description-drizzle"),
          //% "Heavy intensity drizzle"
          "302": qsTrId("weather-la-description-heavy_intensity_drizzle"),
          //% "Light intensity drizzle rain"
          "310": qsTrId("weather-la-description-light_intensity_drizzle_rain"),
          //% "Drizzle rain"
          "311": qsTrId("weather-la-description-drizzle_rain"),
          //% "Heavy intensity drizzle rain"
          "312": qsTrId("weather-la-description-heavy_intensity_drizzle_rain"),
          //% "Shower rain and drizzle"
          "313": qsTrId("weather-la-description-shower_rain_and_drizzle"),
          //% "Heavy shower rain and drizzle"
          "314": qsTrId("weather-la-description-heavy_shower_rain_and_drizzle"),
          //% "Shower drizzle"
          "321": qsTrId("weather-la-description-shower_drizzle"),
          //% "Light rain"
          "500": qsTrId("weather-la-description-light_rain"),
          //% "Moderate rain"
          "501": qsTrId("weather-la-description-moderate_rain"),
          //% "Heavy intensity rain"
          "502": qsTrId("weather-la-description-heavy_intensity_rain"),
          //% "Very heavy rain"
          "503": qsTrId("weather-la-description-very_heavy_rain"),
          //% "Extreme rain"
          "504": qsTrId("weather-la-description-extreme_rain"),
          //% "Freezing rain"
          "511": qsTrId("weather-la-description-freezing_rain"),
          //% "Light intensity shower rain"
          "520": qsTrId("weather-la-description-light_intensity_shower_rain"),
          //% "Shower rain"
          "521": qsTrId("weather-la-description-shower_rain"),
          //% "Heavy intensity shower rain"
          "522": qsTrId("weather-la-description-heavy_intensity_shower_rain"),
          //% "Ragged shower rain"
          "531": qsTrId("weather-la-description-ragged_shower_rain"),
          //% "Light snow"
          "600": qsTrId("weather-la-description-light_snow"),
          //% "Snow"
          "601": qsTrId("weather-la-description-snow"),
          //% "Heavy snow"
          "602": qsTrId("weather-la-description-heavy_snow"),
          //% "Sleet"
          "611": qsTrId("weather-la-description-sleet"),
          //% "Light shower sleet"
          "612": qsTrId("weather-la-description-light_shower_sleet"),
          //% "Shower sleet"
          "613": qsTrId("weather-la-description-shower_sleet"),
          //% "Light rain and snow"
          "615": qsTrId("weather-la-description-light_rain_and_snow"),
          //% "Rain and snow"
          "616": qsTrId("weather-la-description-rain_and_snow"),
          //% "Light shower snow"
          "620": qsTrId("weather-la-description-light_shower_snow"),
          //% "Shower snow"
          "621": qsTrId("weather-la-description-shower_snow"),
          //% "Heavy shower snow"
          "622": qsTrId("weather-la-description-heavy_shower_snow"),
          //% "Mist"
          "701": qsTrId("weather-la-description-mist"),
          //% "Smoke"
          "711": qsTrId("weather-la-description-smoke"),
          //% "Haze"
          "721": qsTrId("weather-la-description-haze"),
          //% "Sand/dust whirls"
          "731": qsTrId("weather-la-description-sand_dust_whirls"),
          //% "Fog"
          "741": qsTrId("weather-la-description-fog"),
          //% "Sand"
          "751": qsTrId("weather-la-description-sand"),
          //% "Dust"
          "761": qsTrId("weather-la-description-dust"),
          //% "Volcanic ash"
          "762": qsTrId("weather-la-description-volcanic_ash"),
          //% "Squalls"
          "771": qsTrId("weather-la-description-squalls"),
          //% "Tornado"
          "781": qsTrId("weather-la-description-tornado"),
          //% "Clear sky"
          "800": qsTrId("weather-la-description-clear_sky"),
          //% "Few clouds"
          "801": qsTrId("weather-la-description-few_clouds"),
          //% "Scattered clouds"
          "802": qsTrId("weather-la-description-scattered_clouds"),
          //% "Broken clouds"
          "803": qsTrId("weather-la-description-broken_clouds"),
          //% "Overcast clouds"
          "804": qsTrId("weather-la-description-overcast_clouds")
        }

        return localizations[code]
    }

    function getAuthParams() {
        return "&appid="
    }
}
