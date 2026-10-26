@if "!"=="" goto znvm_delayed_expansion_error
@setlocal DisableDelayedExpansion
@set "ERRORLEVEL="
@set "ZNVM_SHELL=cmd"
@set "ZNVM_CMD_ENV_FILE=%TEMP%\znvm-env-%RANDOM%-%RANDOM%-%RANDOM%.cmd"
@if exist "%ZNVM_CMD_ENV_FILE%" goto znvm_response_collision
@"%~dp0..\bin\nvm.exe" %*
@set "_znvm_status=%errorlevel%"
@if not "%_znvm_status%"=="0" goto znvm_native_error
@if not exist "%ZNVM_CMD_ENV_FILE%" goto znvm_no_delta
@rem Carry only the filename across ENDLOCAL. Direct chaining avoids CALL's
@rem second expansion of percent signs. The generated file returns to our caller.
@for %%F in ("%ZNVM_CMD_ENV_FILE%") do (
    @endlocal
    @"%%~fF"
)
@exit /b 0
:znvm_no_delta
@endlocal & exit /b 0
:znvm_native_error
@rem Native exclusively owns its response file and removes partial files.
@endlocal & exit /b %_znvm_status%
:znvm_delayed_expansion_error
@echo nvm: cmd delayed expansion must be disabled. Start cmd /V:OFF. 1>&2
@exit /b 55
:znvm_response_collision
@echo nvm: response file collision; retry the command. 1>&2
@endlocal & exit /b 56
