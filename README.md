# fpga286r2
80286 Retro computer board with FPGA

### Tested software
* MSDOS 3.3 / 4.0 / 6.22

### Some tested games
* Some old CGA games
* Prince of Persia (CGA and VGA mode)

### BIOS
Please use this compact BIOS:

https://github.com/b-dmitry1/BIOS

### PCB
P-CAD 2006, Sprint Layout 6, and prepared for manufacturing Gerber files could be found in a "pcb" directory.

![top](pictures/board.jpg)
![top](pictures/top.jpg)
![bottom](pictures/bottom.jpg)

### Compiling on Windows

Please use Altera Quartus II 13.0sp1 to compile the project.

### Using disk images
Please use disk images from my e86r project:

https://github.com/b-dmitry1/e86r

Just write a FreeDos or an empty image to a SD card, mount it and add your files using File Explorer.

### Known problems
* USB support is in progress. Working USB module could be found in my "V188" project.
* No return from protected mode due to absence of 70h port emulation.
* VGA virtual resolution (panning) calculation may be wrong for some games.

### Disclaimer
The project is provided "as is" without any warranty. Use at your own risk.
