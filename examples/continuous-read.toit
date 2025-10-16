
// Copyright (C) 2025 Toit Contributors
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import gpio
import i2c
import as5600 show *

sda-pin-number := 19    // please set these correctly for your device
scl-pin-number := 20    // please set these correctly for your device

main:
  // Enable and drive I2C:
  frequency := 400_000
  sda-pin := gpio.Pin sda-pin-number
  scl-pin := gpio.Pin scl-pin-number
  bus := i2c.Bus --sda=sda-pin --scl=scl-pin --frequency=frequency

  if not bus.test As5600.I2C_ADDRESS:
    print " No AS5600 device found"
    return

  print " Found AS5600 on 0x$(%02x As5600.I2C_ADDRESS)"
  device := bus.device As5600.I2C_ADDRESS
  driver := As5600 device

  300.repeat:
    print " - Raw Angle $it: $(%3.2f driver.read-angle --steps=360)  $(driver.read-raw-angle)"
    sleep --ms=100
