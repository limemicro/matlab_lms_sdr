# LMS SDR

This is a plugin for Matlab to work with Lime Microsystems boards.

Currently it's designed to work with *EVB7+Stream* board combination.

## Features:
* RF samples receiving
* RF samples transmitting
* Rx/Tx center frequency configuring
* Read/Write SPI to LMS7002 registers
    
## Performance:
* Highly dependant from host PC configuration and Matlab implementation.
* Cannot guarantee real-time performance.

## Additional software
Base configuration files used to initialize LMS7002 settings can be created by
using [lms7suite](https://github.com/limemicro/lms7suite/raw/master/build/bin/Release/lms7suite.exe)