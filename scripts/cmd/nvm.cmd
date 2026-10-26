@if "!"=="" goto znvm_delayed_expansion_error
@setlocal DisableDelayedExpansion
@if not exist "%~dp0finish.cmd" goto znvm_missing_finish
@set "ERRORLEVEL="
@set "ZNVM_SHELL=cmd"
@set "ZNVM_CMD_ENV_FILE=%TEMP%\znvm-env-%RANDOM%-%RANDOM%-%RANDOM%.cmd"
@if exist "%ZNVM_CMD_ENV_FILE%" goto znvm_response_collision
@"%~dp0..\bin\nvm.exe" %*
@set "_znvm_status=%errorlevel%"
@if not "%_znvm_status%"=="0" goto znvm_native_error
@if not exist "%ZNVM_CMD_ENV_FILE%" goto znvm_no_delta
@rem Expand the quoted filename before ENDLOCAL, then directly chain outside
@rem any FOR/block context. No CALL: literal percent data is not re-expanded.
@endlocal & "%ZNVM_CMD_ENV_FILE%" "%~dp0finish.cmd"
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
:znvm_missing_finish
@echo nvm: incomplete package; cmd\finish.cmd is missing. 1>&2
@endlocal & exit /b 57
