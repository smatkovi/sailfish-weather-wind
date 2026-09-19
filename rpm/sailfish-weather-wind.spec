Name:       sailfish-weather-wind
Version:    0.1.0
Release:    1
Summary:    Wind speed and direction in the Events view weather forecast
License:    BSD-3-Clause
URL:        https://github.com/smatkovi/sailfish-weather-wind
Source0:    %{name}-%{version}.tar.gz
BuildArch:  noarch
Requires:   patch
Requires:   sailfish-components-weather-qt5
Requires(post):   patch
Requires(preun):  patch

%description
The weather widget of the Sailfish OS Events view shows temperature and a
weather symbol for the coming days or hours. This package adds a line with
the wind speed in m/s and a line with the wind direction (arrow and compass
point) below each forecast column, in the daily as well as in the hourly
forecast.

The package does not need Patchmanager. It ships small diffs against the
QML files of Jolla's weather components and backends (sailfish-weather
1.3.11) and applies them with patch when it is installed. Removing the
package restores the original files. Restart the home screen after
installing or removing it.

%prep
%setup -q

%install
install -D -m 0755 %{name} %{buildroot}%{_bindir}/%{name}
install -d %{buildroot}%{_datadir}/%{name}/patches
install -m 0644 patches/*.diff %{buildroot}%{_datadir}/%{name}/patches/
install -d %{buildroot}%{_localstatedir}/lib/%{name}/applied
install -D -m 0644 README.md %{buildroot}%{_datadir}/doc/%{name}/README.md

%post
%{_bindir}/%{name} apply || :
cat << EOM
sailfish-weather-wind: restart the home screen to see the change, for example
with Sailfish Utilities (Restart home screen) or with
    systemctl --user restart lipstick
Running apps are closed by that. Rebooting works as well.
EOM

# On an upgrade %post still sees the previous version's diffs; %posttrans runs
# after they are gone and reverts diffs this version no longer ships
%posttrans
%{_bindir}/%{name} apply || :

%preun
if [ "$1" = 0 ]; then
    %{_bindir}/%{name} remove || :
    echo "sailfish-weather-wind: restart the home screen to finish removing the change."
fi

# Re-apply after Jolla's packages were updated (files are replaced by an update)
%triggerin -- sailfish-components-weather-qt5 sailfish-weather-backend-metnorway sailfish-weather-backend-openweather sailfish-weather-backend-openmeteo sailfish-weather-backend-foreca
%{_bindir}/%{name} apply || :

%triggerpostun -- sailfish-components-weather-qt5 sailfish-weather-backend-metnorway sailfish-weather-backend-openweather sailfish-weather-backend-openmeteo sailfish-weather-backend-foreca
%{_bindir}/%{name} apply || :

%files
%license LICENSE
%{_bindir}/%{name}
%{_datadir}/%{name}
%dir %{_localstatedir}/lib/%{name}
%dir %{_localstatedir}/lib/%{name}/applied
%{_datadir}/doc/%{name}

%changelog
* Sat Sep 19 2026 smatkovi <smatkovi@users.noreply.github.com> 0.1.0-1
- First version: wind speed and direction below the daily and hourly
  forecast of the Events view weather widget
