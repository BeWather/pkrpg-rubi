@echo off
REM Construye el APK firmado de Pokemon Rubi.
REM Doble-click para buildear; el APK queda en B:\godot\exportados\
REM Requisito: Godot 4.7.1 estable instalado en C:\Godot\Godot-4.7.1-stable\
REM Requisito: keystore debug en C:\Users\Terraplanista\.android\debug.keystore

setlocal

set "GODOT_BIN=C:\Godot\Godot-4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe"
set "PROJECT_PATH=%~dp0"
set "APK_PATH=B:\godot\exportados\Pokemon Rubi v0.2.0b-debug.apk"
set "LOG_PATH=%PROJECT_PATH%exportados\export.log"

echo === Pokemon Rubi - APK Build ===
echo Godot:   %GODOT_BIN%
echo Proyecto: %PROJECT_PATH%
echo APK:     %APK_PATH%
echo.

if not exist "%GODOT_BIN%" (
    echo ERROR: Godot no encontrado en %GODOT_BIN%
    pause
    exit /b 1
)

if not exist "%PROJECT_PATH%project.godot" (
    echo ERROR: project.godot no encontrado en %PROJECT_PATH%
    pause
    exit /b 1
)

if not exist "%USERPROFILE%\.android\debug.keystore" (
    echo ADVERTENCIA: keystore debug no encontrado en %USERPROFILE%\.android\debug.keystore
    echo El APK no se podra firmar. Ver docs\android-export.md.
    echo.
)

echo Iniciando export...
"%GODOT_BIN%" --headless --path "%PROJECT_PATH%" --export-debug "Android Debug" --no-header 2>&1 | tee "%LOG_PATH%"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo === Resultado ===
if %EXIT_CODE% NEQ 0 (
    echo BUILD FAILED ^(exit %EXIT_CODE%^)
    echo Log completo: %LOG_PATH%
) else (
    if exist "%APK_PATH%" (
        for %%I in ("%APK_PATH%") do echo BUILD OK ^(%%~zI bytes^)
        echo APK: %APK_PATH%
    ) else (
        echo BUILD OK pero APK no encontrado en la ruta esperada
        echo Log: %LOG_PATH%
    )
)

echo.
pause