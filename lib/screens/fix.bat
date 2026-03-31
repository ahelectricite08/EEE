@echo off
setlocal enabledelayedexpansion
cd /d C:\Users\axeld\Music\dvcr_appli\lib\screens
del home_screen.dart
copy home_screen_new.dart home_screen.dart
for /f %%A in ('find /c /v "" home_screen.dart') do (
    echo Final line count: %%A
)
