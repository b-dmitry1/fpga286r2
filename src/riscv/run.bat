@echo off

call compile.bat
if errorlevel 1 goto :error
call write.bat
if errorlevel 1 goto :error

exit /b

:error
pause
exit /b
