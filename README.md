# Toit driver for AMS AS5600 I2C magnetic rotation Hall-Effect Sensor

The AS5600 is a programmable Hall-based rotary magnetic position sensor with a
high-resolution 12-bit analog, or PWM output, for contactless potentiometers.
Based on planar Hall technology, this device measures the orthogonal component
of the flux density (Bz) from an external magnet while rejecting stray magnetic
fields.

The default range of the output is 0 to 360 degrees, but the full resolution of
the device can be applied to smaller range by programming a zero angle (start
position) and maximum angle (stop position).


## Modes:
### 3-wire mode:
With VCC/GND and OUT, PWM data can be sent to the ESP32.

### I2C mode:
Using the I2C Interface, all functions of the AS5600 can be configured and
(permanently) programmed. Additionally the output and a raw angle (unmodified
value) can be read from the output registers.

The device can run as master and slave on the I2C bus and manage transmission of data


## Pins
- DIR: Direction (clockwise vs. counterclockwise): If DIR is connected to GND
  (DIR = 0) a clockwise rotation viewed from the top will generate an increment
  of the calculated angle. If the DIR pin is connected to VDD (DIR = 1) an
  increment of the calculated angle will happen with counterclockwise rotation.
  This could be set dynamically using the ESP32.
```

```
