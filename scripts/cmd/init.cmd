@rem Session-only initialization. Native emits safely escaped cmd assignments.
@rem Keep this directory ahead of bin: nvm.exe cannot change its parent PATH.
@if "!"=="" goto znvm_delayed_expansion_error
@"%~dp0nvm.cmd" env --shell cmd
@exit /b %errorlevel%
:znvm_delayed_expansion_error
@echo nvm: cmd delayed expansion must be disabled. Start cmd /V:OFF. 1>&2
@exit /b 55
