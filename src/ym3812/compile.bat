@echo off

SetLocal EnableExtensions EnableDelayedExpansion

set "c="
for %%f in ("lib\*.c") do (
  set c=!c!%%f 
)

for %%f in ("*.c") do (
  set c=!c!%%f 
)

for %%f in ("*.S") do (
  set c=!c!%%f 
)

riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -mcmodel=medany -O2 -nostartfiles -I. -Ilib -Tlib\riscv.ld lib\vectors.S !c!
if errorlevel 1 goto error
riscv64-unknown-elf-objcopy -O binary a.out firmware.bin
if errorlevel 1 goto error

if exist a.out del a.out

bin2mif 32 firmware.bin
move firmware.mif ../ym3812-firmware.mif
exit /b

:error
exit /b 1
