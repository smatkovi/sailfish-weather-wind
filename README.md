# sailfish-weather-wind

The weather widget of the Sailfish OS Events view shows the temperature and
a weather symbol for the next days or hours. This package adds two lines
below every forecast column: the wind speed in m/s and the wind direction,
in the daily as well as in the hourly forecast.

```
 Today    Sun     Mon     Tue     Wed     Thu
  21°     19°     18°     20°     22°     23°
  ☀       ⛅      🌧       ⛅      ☀       ☀
  10°     11°     12°     10°     11°     13°
 3 m/s   5 m/s   8 m/s   5 m/s   3 m/s   2 m/s
 ↓ N     ↖ SE    ↘ NW    ↘ NW    ↙ NE    ↑ S
```

* **Speed** in m/s. The daily view shows the maximum of the day, the same
  value the Weather app shows on its detail page, with the direction of the
  entry nearest to midday (Open-Meteo: the dominant direction of the day);
  the hourly view shows speed and direction at that hour.
* **Direction** as an arrow and a compass point. The arrow points where the
  wind blows to, the same convention as the wind graphic in the Weather app.
  The letters name the direction the wind comes from, as in weather reports
  ("NW" is wind from the north-west). They are abbreviated in the language of
  the phone (German, Dutch, French, Spanish, Italian, Catalan, Portuguese,
  Finnish, Swedish, Norwegian, Danish, Czech, Slovak, Slovenian, Lithuanian,
  Latvian, Hungarian, Turkish, Russian and Greek; everything else gets
  N, NE, E, SE, S, SW, W, NW).
* The Weather app itself is not changed. Its forecast page keeps the fixed
  height it has, so the wind lines are switched on only in the Events view:
  the forecast items show them when their parent item carries a `showWind`
  property, which only the Events view banner has.

Tested on Sailfish OS 5.2.0.17 with sailfish-weather 1.3.11.

## Installation

Download the RPM from the [releases](https://github.com/smatkovi/sailfish-weather-wind/releases)
and install it, for example

```
devel-su pkcon install-local sailfish-weather-wind-*.noarch.rpm
```

Afterwards **restart the home screen**: Sailfish Utilities → Restart home
screen, or in a terminal

```
systemctl --user restart lipstick
```

Running apps are closed by that. A reboot works as well.

To remove the change, uninstall the package (`devel-su pkcon remove
sailfish-weather-wind`) and restart the home screen again.

## How it works

This is not a Patchmanager patch and Patchmanager is not needed. The
package ships small unified diffs against QML files of Jolla's weather
packages and applies them with `patch` when it is installed (if a
Patchmanager patch has one of these files mounted, that file is skipped and
the rest is applied):

| File | Package | Change |
| --- | --- | --- |
| `/usr/lib64/qt5/qml/Sailfish/Weather/DailyForecastItem.qml` | sailfish-components-weather-qt5 | wind lines, shown only under a parent with `showWind` |
| `/usr/lib64/qt5/qml/Sailfish/Weather/HourlyForecastItem.qml` | sailfish-components-weather-qt5 | wind lines, shown only under a parent with `showWind` |
| `/usr/lib64/qt5/qml/Sailfish/Weather/WeatherBanner.qml` | sailfish-components-weather-qt5 | `showWind` on the delegate items of the Events view |
| `/usr/share/sailfish-weather/backends/MetNorwayBackend.qml` | sailfish-weather-backend-metnorway | wind in the hourly data |
| `/usr/share/sailfish-weather/backends/OpenWeatherBackend.qml` | sailfish-weather-backend-openweather | wind in the hourly data |
| `/usr/share/sailfish-weather/backends/OpenMeteoBackend.qml` | sailfish-weather-backend-openmeteo | wind in the hourly request and data |
| `/usr/share/sailfish-weather/backends/ForecaWeatherBackend.qml` | sailfish-weather-backend-foreca | wind in the hourly data |

On 32-bit devices the QML files live under `/usr/lib/qt5/qml` instead; the
script finds them there. Backends that are not installed are skipped. The
daily data already contained the wind, only the hourly data needed it.

Every applied diff is recorded under `/var/lib/sailfish-weather-wind/`, so
uninstalling restores the original files. `rpm -V` of Jolla's packages
reports the patched files as modified while this package is installed;
that is expected.

**OS updates** replace the files. RPM triggers re-apply the diffs after
Jolla's packages were updated. A diff is applied only where all of its
context lines still match (`patch -F0`); if a new version of a file changed
those lines, the diff is skipped with a message and that file stays
unpatched until this package is updated. Every file is patched on its own,
and each change is safe alone: unpatched forecast items simply show no wind
lines, an unpatched banner switches none on, and an unpatched backend
delivers no hourly wind. The widget itself keeps working in every
combination.

The script can also be run by hand (`status` works as a normal user, the
other two need root):

```
sailfish-weather-wind status            # patched / not patched per file
devel-su sailfish-weather-wind apply
devel-su sailfish-weather-wind remove
```

`apply` and `remove` exit with 1 when something could not be done.

## Data providers

All four backends of sailfish-weather 1.3.11 are covered: MET Norway (the
default), OpenWeather, Open-Meteo and Foreca. MET Norway was tested with
live data; OpenWeather, Open-Meteo and Foreca were tested with synthetic
responses shaped like their APIs. The Foreca hourly field names
(`windSpeed`, `windDir`) come from Foreca's API documentation and were not
checked against the live service. A missing wind value hides the wind lines
for that column instead of showing a wrong number.

## Development

* `src/` holds the complete modified files, based on sailfish-weather 1.3.11.
* `patches/` holds the diffs the package installs; `tools/make-patches.sh`
  regenerates them from `src/` against the pristine files of the release.
* `tests/delegates.qml` checks the layout of the patched delegates without a
  visible window (`QML2_IMPORT_PATH` pointing to a copy of the module with
  the patched files, `QT_LOGGING_TO_CONSOLE=1 qmlscene tests/delegates.qml`).
* `tests/run-backends.sh` runs the patched backend parsers against a MET
  Norway response and synthetic responses of the other providers.
* `tests/banner.qml` instantiates the installed `WeatherBanner` with live
  data and prints the forecast rows and wind labels of both modes.
* `tools/build-rpm.sh` builds the noarch RPM on a Linux box with `rpmbuild`.

## License

BSD-3-Clause, the license of sailfish-weather. The modified files keep
Jolla's copyright notices.
