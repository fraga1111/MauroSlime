@echo off
rem ================================================================
rem  MAURO OF DUTY - avvia il gioco
rem
rem  Funziona in due modi:
rem   - accanto alla cartella StanzaFPS (chi sviluppa il gioco): usa quella;
rem   - DA SOLO, in qualsiasi cartella (es. per gli amici): a ogni avvio scarica
rem     da GitHub l'ultima versione del gioco, e la prima volta anche Godot.
rem  Il gioco viene preparato e avviato da %LOCALAPPDATA%\MauroSlime.
rem ================================================================
setlocal
set "TAR=%SystemRoot%\System32\tar.exe"
set "CURL=%SystemRoot%\System32\curl.exe"
cd /d "%~dp0"
set "REPO=fraga1111/MauroSlime"
set "GV=4.7.2"
set "CASA=%LOCALAPPDATA%\MauroSlime"
set "LOCALE=%CASA%\StanzaFPS"
if not exist "%CASA%" mkdir "%CASA%"
echo.
echo   MAURO OF DUTY

rem ---- Godot: quello accanto a questo file, oppure scaricato una volta sola
set "GDIR=%~dp0Godot"
if not exist "%GDIR%\Godot_v%GV%-stable_win64.exe" set "GDIR=%CASA%\Godot"
if not exist "%GDIR%\Godot_v%GV%-stable_win64.exe" (
	echo   Prima volta: scarico Godot %GV% ^(circa 85 MB^)...
	if not exist "%GDIR%" mkdir "%GDIR%"
	"%CURL%" -L --fail -o "%CASA%\godot.zip" "https://github.com/godotengine/godot/releases/download/%GV%-stable/Godot_v%GV%-stable_win64.exe.zip" || goto errore
	"%TAR%" -xf "%CASA%\godot.zip" -C "%GDIR%" || goto errore
	del "%CASA%\godot.zip"
)
set "GODOT=%GDIR%\Godot_v%GV%-stable_win64.exe"
set "GODOTC=%GDIR%\Godot_v%GV%-stable_win64_console.exe"

rem ---- il gioco: la cartella StanzaFPS qui accanto, oppure l'ultima versione da GitHub
set "SORGENTE=%~dp0StanzaFPS"
if exist "%SORGENTE%\project.godot" goto copia
echo   Scarico l'ultima versione del gioco da GitHub...
if exist "%CASA%\scarico" rmdir /s /q "%CASA%\scarico"
mkdir "%CASA%\scarico"
"%CURL%" -L --fail -o "%CASA%\gioco.zip" "https://github.com/%REPO%/archive/refs/heads/main.zip" || goto offline
"%TAR%" -xf "%CASA%\gioco.zip" -C "%CASA%\scarico" || goto offline
del "%CASA%\gioco.zip"
for /d %%D in ("%CASA%\scarico\*") do set "SORGENTE=%%D\StanzaFPS"

:copia
echo   Aggiorno i file del gioco...
robocopy "%SORGENTE%" "%LOCALE%" /MIR /XD .godot tools archivio_nemici archivio_personaggi_cubetti /NFL /NDL /NJH /NJS /NP >nul
goto avvia

:offline
echo   Non riesco a scaricare l'aggiornamento: avvio l'ultima versione scaricata.
if not exist "%LOCALE%\project.godot" goto errore

:avvia
if not exist "%LOCALE%\.godot" echo   Prima volta: preparo i file del gioco ^(ci vuole un minuto^)...
"%GODOTC%" --headless --path "%LOCALE%" --import >nul 2>&1
start "" "%GODOT%" --path "%LOCALE%"
exit /b 0

:errore
echo.
echo   Qualcosa e' andato storto (internet?). Riprova tra poco.
pause
exit /b 1
