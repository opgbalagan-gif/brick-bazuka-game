@echo off
setlocal EnableExtensions

set "GODOT_EXE="

for %%G in (godot.exe godot4.exe) do (
    for /f "delims=" %%P in ('where %%G 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%~fP"
)

if defined GODOT_EXE goto found

for /r "%USERPROFILE%\Desktop" %%G in (Godot*.exe) do (
    echo %%~nxG | %SystemRoot%\System32\findstr.exe /i "console" >nul
    if errorlevel 1 if not defined GODOT_EXE set "GODOT_EXE=%%~fG"
)

if defined GODOT_EXE goto found

for /r "%USERPROFILE%\Documents" %%G in (Godot*.exe) do (
    echo %%~nxG | %SystemRoot%\System32\findstr.exe /i "console" >nul
    if errorlevel 1 if not defined GODOT_EXE set "GODOT_EXE=%%~fG"
)

if not defined GODOT_EXE goto missing_godot

:found
if /i "%~1"=="--check" (
    echo %GODOT_EXE%
    exit /b 0
)

pushd "%~dp0"
start "" "%GODOT_EXE%" --path .
popd
exit /b 0

:missing_godot
echo Godot 4 was not found.
echo Open project.godot manually in Godot 4 and press F6.
pause
exit /b 1
