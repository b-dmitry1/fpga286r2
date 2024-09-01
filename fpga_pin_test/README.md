# fpga286r2 pin test

This test is designed to check the quality of FPGA pins connection.

Test procedure:
* After soldering the board do not install the CPU and do not connect SD-card, USB and a floppy drive.
* Powerup the board, write this test program to FPGA, then use a LED with a series 1 KOhm resistor connected to +3.3V to test all the interfaces.
* Touch CPU, SRAM, SDRAM, USB, SD-card, Expansion and floppy drive interface pins. The LED should blink on all the output and bidirectional pins. Use precautions to avoid damaging the device with electrostatic discharge.
* Test the VGA interface: you will see a moving RGB stripes (4096 different colors).
* Test 3.5 mm audio connector with headphones: you'll hear a loud beeps.
* Test the UART: connect USB type-A cable, open a Terminal program, set the port to 115200 baud rate, 8 data bits, 1 stop bit, no parity, no flow control. You will see a "Test" text message.
