@echo off

call ..\quartusdir.bat
if not exist %quartusdir%/quartus_cdb.exe echo "Can't find Quartus compiler in %quartusdir%" && exit /b

for %%I in (.) do set "d1=%%~nxI"

cd ..

%quartusdir%quartus_pgm -c usb-blaster -m JTAG -o p;output_files\Main.sof
if errorlevel 1 goto error

cd %d1%
exit /b

:error
cd %d1%
exit /b 1
