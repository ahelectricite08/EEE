@echo off
cd /d C:\Users\axeld\Music\dvcr_appli\lib\screens
del home_screen.dart
ren home_screen_temp.dart home_screen.dart
find /c /v "" home_screen.dart
echo Done!
pause
