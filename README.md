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

Technology:
* 4-layer PCB.
* 100x100 mm size.
* 0.2 mm min hole.
* 0.46 mm min via diameter.
* 0.127 mm min track.

I have paid only $7 for 5 PCBs on jlcpcb.com.
It is safe to increase hole size to 0.3 mm, via to 0.63mm, and track width to 0.15 mm.

All the electronic components including FPGA (EP4CE15F23C8N) and CPU (80c286) could be found on AliExpress.

![top](pictures/board.jpg)

Top view:

![top](pictures/top.jpg)

Bottom view:

![bottom](pictures/bottom.jpg)

Simplified schematic diagram:

![top](pictures/sch1.png)

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

Due to lack of time, I made the PCB without any schematic diagrams, sorry.
If you really need schematic diagram - contact me and I'll create it.
