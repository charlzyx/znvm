@rem Persistent tail: delete the completed response, never this running batch.
@if "!"=="" exit /b 55
@if "%~1"=="" exit /b 57
@if not "%~x1"==".cmd" exit /b 57
@if "%~2"=="0" goto znvm_finish_success
@if not "%~2"=="1" exit /b 57
@del /q "%~1" >nul 2>&1
@if exist "%~1" exit /b 57
@exit /b 1
:znvm_finish_success
@del /q "%~1" >nul 2>&1
@if exist "%~1" exit /b 57
@exit /b 0
