# fpga286r2
80286 Retro computer board with FPGA

### Tested software
* MSDOS 3.3 / 4.0 / 6.22
* Windows 2.0 in CGA mode

### Some tested games
* Some old CGA games
* Prince of Persia (CGA and VGA mode)

## New USB host controller is almost done!

My new plug-and-play low-speed USB HOST controller is now successfully initializing keyboards and mouses.
I tried to keep it as simple as possible - now it consists only 322 lines of PHY code, and 192 lines of HID controller code (total about 350 LEs).

To test it:
* Connect your mouse or keyboard to an upper USB (only low-speed and no hubs for now, sorry!).
* Connect headphones to audio jack.
* Every time you'll move you mouse or push buttons on a keyboard you'll hear clicks and bleeps - thus the controller
lets you know that a device's report has been received.

The goal is to create a fully plug-and-play HID host controller that will automatically parse device reports and
provide keydown/keyup codes and mouse events.

"ACK" response on "GET DESCRIPTOR" command:

![top](pictures/usb_osc.jpg)

## BIOS
Please use this compact BIOS:

https://github.com/b-dmitry1/BIOS

## PCB
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

## Compiling on Windows

Please use Altera Quartus II 13.0sp1 to compile the project.

## Using disk images
Please use disk images from my e86r project:

https://github.com/b-dmitry1/e86r

Just write a FreeDos or an empty image to a SD card, mount it and add your files using File Explorer.

## Docs and manuals

* Please check the "doc" directory.

## Disclaimer
The project is provided "as is" without any warranty. Use at your own risk.

Due to lack of time, I made the PCB without any schematic diagrams, sorry.
If you really need schematic diagram - contact me and I'll create it.
