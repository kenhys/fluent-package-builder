@echo off
if "%~nx0" == "td-agent.bat" (
  set "FLUENT_PACKAGE_TOPDIR=%~dp0..\"
) else (
  set "FLUENT_PACKAGE_TOPDIR=%~dp0"
)

@rem Convert path separator from backslash to forwardslash
setlocal enabledelayedexpansion
set FLUENT_PACKAGE_TOPDIR=!FLUENT_PACKAGE_TOPDIR:\=/!

set PATH=%FLUENT_PACKAGE_TOPDIR%bin;%PATH%
set PATH=%FLUENT_PACKAGE_TOPDIR%;%PATH%
set "FLUENT_CONF=%FLUENT_PACKAGE_TOPDIR%etc/fluent/fluentd.conf"
set "FLUENT_PLUGIN=%FLUENT_PACKAGE_TOPDIR%etc/fluent/plugin"
set "FLUENT_PACKAGE_VERSION=%FLUENT_PACKAGE_TOPDIR%bin/fluent-package-version.rb"
set FLUENT_CONF_CLI=
set /a n=0
set /a conf_index=0
for %%p in (%*) do (
    if "%%p"=="--version" (
        ruby "%FLUENT_PACKAGE_VERSION%"
        goto last
    )
    if "%%p"=="-c" (
        set /a conf_index=n+1
    )
    if !n! equ !conf_index! (
        set FLUENT_CONF_CLI="%%p"
    )
    set /a n=n+1
)

@rem Abort if the fluentdwinsvc service is running and conflict with -c ...:
sc query fluentdwinsvc | findstr RUNNING > nul
if !ERRORLEVEL! neq 0 (
    goto noguard
)
@rem extract fluentdopt from registry: (e.g. fluentdopt REG_SZ -c ...)
for /f "usebackq delims=" %%v in (`reg query HKLM\SYSTEM\CurrentControlSet\Services\fluentdwinsvc /v fluentdopt ^| findstr fluentdopt`) do set FLUENTDOPT=%%v
if not "!FLUENT_CONF_CLI!"=="" (
    echo "!FLUENTDOPT:\=/!" | findstr /I /C:!FLUENT_CONF_CLI:\=/! > nul
    if !ERRORLEVEL! equ 0 (
   	    echo Error: can't start duplicate Fluentd instance with same !FLUENT_CONF_CLI!
	    exit /b 2
    )
)
if not "!FLUENT_CONF!"=="" (
    echo "!FLUENTDOPT:\=/!" | findstr /I /C:!FLUENT_CONF! > nul
    if !ERRORLEVEL! equ 0 (
   	    echo Error: can't start duplicate Fluentd instance with same !FLUENT_CONF!
	    exit /b 2
    )
)

:noguard
"%FLUENT_PACKAGE_TOPDIR%/bin/fluentd" %*
endlocal

:last
