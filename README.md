# Toit driver for AMS AS5600 I2C magnetic rotation Hall-Effect Sensor

The AS5600 is a programmable Hall-based rotary magnetic position sensor with a
high-resolution 12-bit analog, or PWM output, for contactless potentiometers.
Based on planar Hall technology, this device measures the orthogonal component
of the flux density (Bz) from an external magnet while rejecting stray magnetic
fields. [Datasheet](https://files.seeedstudio.com/wiki/Grove-12-bit-Magnetic-Rotary-Position-Sensor-AS5600/res/Magnetic%20Rotary%20Position%20Sensor%20AS5600%20Datasheet.pdf)

![Front and back of a module with a BH1750](images/as5600.png)

## Features:

### I2C mode:
Using the I2C Interface, all functions of the AS5600 can be configured and
(permanently**) programmed. Additionally the output and a raw angle (unmodified
value) can be read from the output registers.

With VCC/GND and OUT, PWM data can be sent to the ESP32 alongside the data
obtainable using I2C.

### 3-wire mode
The Datsheet describes a way of configuring/programming the device without I2C.
Please see the datasheet for this information.

### Reduced Resolution
The default range of the output is between 0 to 4095 units. That said, the full
resolution of the device can be applied to smaller range by programming a zero
angle (start position) and maximum angle (stop position).

## Pins
- DIR: Direction (clockwise vs. counterclockwise): If DIR is connected to GND
  (DIR = 0) a clockwise rotation viewed from the top will generate an increment
  of the calculated angle. If the DIR pin is connected to VDD (DIR = 1) an
  increment of the calculated angle will happen with counterclockwise rotation.
  This could be set dynamically using the ESP32.
```

```

### Permanent programming
The device has a limited number of permanently written save slots.  These are 3,
in the case of Start Position and Stop Position, but only one in the case of
the wider settings.  The functions in the library have an 'are you sure' switch,
but have not been tested for lack of sacrificial test units.

## Links
- [Device Datasheet](https://files.seeedstudio.com/wiki/Grove-12-bit-Magnetic-Rotary-Position-Sensor-AS5600/res/Magnetic%20Rotary%20Position%20Sensor%20AS5600%20Datasheet.pdf)

## Issues
If there are any issues, changes, or any other kind of feedback, please
[raise an issue](https://github.com/milkmansson/toit-as5600/issues). Feedback is
welcome and appreciated!

## Disclaimer
- This driver has been written and tested with an unbranded module as pictured.
- Writing to OTP memory has not been tested, I didn't have test units to
  sacrifice.
- All trademarks belong to their respective owners.
- No warranties for this work, express or implied.

## Credits
- AI has been used for reviews, analysing & compiling data/results, and
  assisting with ensuring accuracy.
- [Florian](https://github.com/floitsch) for the tireless help and encouragement
- The wider Toit developer team (past and present) for a truly excellent product

## About Toit
One would assume you are here because you know what Toit is.  If you dont:
> Toit is a high-level, memory-safe language, with container/VM technology built
> specifically for microcontrollers (not a desktop language port). It gives fast
> iteration (live reloads over Wi-Fi in seconds), robust serviceability, and
> performance that’s far closer to C than typical scripting options on the
> ESP32. [[link](https://toitlang.org/)]
- [Review on Soracom](https://soracom.io/blog/internet-of-microcontrollers-made-easy-with-toit-x-soracom/)
- [Review on eeJournal](https://www.eejournal.com/article/its-time-to-get-toit)
