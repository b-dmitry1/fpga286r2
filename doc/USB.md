# USB host

* Fully automatic LS USB host controller.
* Configurable delays.
* Automatic ACK on DATA0 and DATA1.
* Automatic reset and re-init on STALL and on connection loss.
* Automatic HID device initialization.
* Automatic periodic report requests.

If you want to use it in your project:
* Copy USB_LS_PHY.v and USB_LS_HID.v files.
* Provide 50 MHz clock and reset (active 0) signals.
* Connect USB d-/d+ signals.
* Add your code to USB_LS_HID.v to parse your device's reports the way you need it.
