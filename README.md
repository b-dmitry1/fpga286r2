# fpga286r2
80286 Retro computer board with FPGA

### Tested software
* MSDOS 3.3 / 4.0 / 6.22
* Windows 2.0 in CGA mode

### Some tested games
* Some old CGA games
* Prince of Persia (CGA and VGA mode)

## New USB host controller is almost done!

Currently only keyboards are supported, only 1 button press at a time is possible.
This is enough for work with some apps, but not enough for games.

I tried to keep the design as simple as possible - only 2 files (about 300 lines each) with 2 FSMs, total about 420 LEs.
These FSMs make it easy to add new USB commands or to work with additional device's endpoints.

To test it:
* Connect your keyboard to an upper USB (only low-speed and no hubs/radio, sorry!).
* Start the DOS or 16-bit Minix and try some commands like "cd" or "dir" ("ls").
* Connect headphones to audio jack.
* Every time you push buttons on a keyboard you'll hear bleeps - thus the controller
lets you know that a device's report has been received. Each key will have unique sound frequency which depends on a key's scancode.

"ACK" response on "GET DESCRIPTOR" command:

![top](pictures/usb_osc.jpg)

"NAK" response:

![top](pictures/usb_nak.png)

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

It is safe to increase hole size to 0.3 mm, via to 0.63mm, and track width to 0.15 mm.

All the electronic components including FPGA (EP4CE15F23C8N) and CPU (80c286) could be found on AliExpress.

FPGA pin test is included. Check the fpga_pin_test project.

![top](pictures/board.jpg)

Top view:

![top](pictures/top.gif)

Bottom view:

![bottom](pictures/bottom.gif)

Simplified schematic diagram:

![top](pictures/sch1.png)

## Compiling on Windows

Please use Altera Quartus II 13.0sp1 to compile the project.

## Using disk images
Please use disk images from my e86r project:

https://github.com/b-dmitry1/e86r

Just write a FreeDos or an empty image to a SD card, mount it and add your files using File Explorer.

## Docs and manuals

* Electrical schematic diagram is in "sch" directory.
* Please check the "doc" directory.

## Disclaimer
The project is provided "as is" without any warranty. Use at your own risk.
