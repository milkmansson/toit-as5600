// Copyright (C) 2025 Toit Contributors
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.   This file also includes derivative
// work from other authors and sources with permission.  See README.md.

import log
import binary
import math show *
import serial.device as serial
import serial.registers as registers

class As5600:
  /**  Default $I2C-ADDRESS is 0x36  */
  static I2C-ADDRESS ::= 0x36

  static DEFAULT-REGISTER-WIDTH_ ::= 16 // bits

  // Most of the 16 bit registers are 12 bit - masked
  static TWELVE-BIT-MASK_ ::= 0b00001111_11111111

  static REG-CONF-ZMCO_ ::= 0x00    // !! 8 BIT
  static CONF-ZMCO-MASK_  ::= 0b00000011

  static REG-CONF-START-POS_ ::= 0x01 // high=0x01, low=0x02, 12 bits total (ZPOS)
  static REG-CONF-STOP-POS_  ::= 0x03 // high=0x03, low=0x04, 12 bits total (MPOS)
  static REG-CONF-MAX-ANGLE_ ::= 0x05 // high=0x05, low=0x06, 12 bits total (MANG)

  static REG-CONF-CONF_  ::= 0x07 // high=0x07, low=0x08
  static CONF-WATCHDOG-MASK_          ::= 0b00100000_00000000
  static CONF-FAST-FILTER-THOLD-MASK_ ::= 0b00011100_00000000
  static CONF-SLOW-FILTER-MASK_       ::= 0b00000011_00000000
  static CONF-PWM-FREQ-MASK_          ::= 0b00000000_11000000
  static CONF-OUTPUT-STAGE-MASK_      ::= 0b00000000_00110000
  static CONF-HYSTERESIS-MASK_        ::= 0b00000000_00001100
  static CONF-POWER-MODE-MASK_        ::= 0b00000000_00000011

  static OUTPUT-STAGE-ANALOG_  ::= 0b00 // analog (full range from 0% to 100% between GND and VDD
  static OUTPUT-STAGE-REDUCED_ ::= 0b01 // analog (reduced range from 10% to 90% between GND and VDD
  static OUTPUT-STAGE-DIGITAL_ ::= 0b10 // digital PWM

  // Fast Filter Thresholds - in LSBs
  static FAST-FILTER-TH-SLOW-ONLY ::= 0b000 // slow filter only
  static FAST-FILTER-TH-6-LSBS    ::= 0b001 // 6 LSBs
  static FAST-FILTER-TH-7-LSBS    ::= 0b010 // 7 LSBs
  static FAST-FILTER-TH-9-LSBS    ::= 0b011 // 9 LSBs
  static FAST-FILTER-TH-18-LSBS   ::= 0b100 // 18 LSBs
  static FAST-FILTER-TH-21-LSBS   ::= 0b101 // 21 LSBs
  static FAST-FILTER-TH-24-LSBS   ::= 0b110 // 24 LSBs
  static FAST-FILTER-TH-10-LSBS   ::= 0b111 // 10 LSBs

  static SLOW-FILTER-16X  ::= 0b00 // 16x
  static SLOW-FILTER-8X   ::= 0b01 // 8x
  static SLOW-FILTER-4X   ::= 0b10 // 4x
  static SLOW-FILTER-2X   ::= 0b11 // 2x

  static PWM-FREQ-115HZ ::= 0b00 // 115 Hz
  static PWM-FREQ-230HZ ::= 0b01 // 230 Hz
  static PWM-FREQ-460HZ ::= 0b10 // 460 Hz
  static PWM-FREQ-920HZ ::= 0b11 // 920 Hz

  static POWER-MODE-NOM ::= 0b00 // NOM
  static POWER-MODE-LPM1 ::= 0b01 // LPM1
  static POWER-MODE-LPM2 ::= 0b10 // LPM2
  static POWER-MODE-LPM3 ::= 0b11 // LPM3

  static HYSTERESIS-OFF ::= 0b00 // OFF
  static HYSTERESIS-1LSB ::= 0b01 // 1 LSB
  static HYSTERESIS-2LSB ::= 0b10 // 2 LSBs
  static HYSTERESIS-3LSB ::= 0b11 // 3 LSBs

  static REG-STATUS-STATUS_  ::= 0x0b  // !! 8 BIT
  static STATUS-MAGNET-DETECT-MASK_ ::= 0b00100000 // Magnet detected
  static STATUS-MAGNET-LOW-MASK_    ::= 0b00010000 // Magnet too weak
  static STATUS-MAGNET-HIGH-MASK_   ::= 0b00001000 // Magnet too strong

  static REG-STATUS-AGC_     ::= 0x1a  // !! 8 BIT
  static REG-STATUS-MAGNITUDE_ ::= 0x1b // high=0x1b, low=0x1c, 12 bits total

  // in 5V operation, the AGC range is 0-255 counts. The AGC range
  // is reduced to 0-128 counts in 3.3V mode

  static REG-RAW-ANGLE_ ::= 0x0c // high=0x0c, low=0x0d, 12 bits total
  static REG-ANGLE_     ::= 0x0e // high=0x0e, low=0x0f, 12 bits total

  static REG-BURN_     ::= 0xff
  static BURN-ANGLE_   ::= 0x80
  static BURN-SETTING_ ::= 0x40

  // Globals
  reg_/registers.Registers := ?
  logger_/log.Logger := ?

  /** Class Constructor:  */
  constructor
      device/serial.Device
      --logger/log.Logger=log.default:
    logger_ = logger.with-name "as5600"
    reg_ = device.registers


  /**
  Sets output stage to Analog. (Full range from 0% to 100% between GND and VDD)
  */
  set-output-stage-analog -> none:
    write-register_ REG-CONF-CONF_ OUTPUT-STAGE-ANALOG_ --mask=CONF-OUTPUT-STAGE-MASK_

  /**
  Sets output stage to Analog but reduced from 10% to 90% between GND & VDD.
  */
  set-output-stage-reduced-analog -> none:
    write-register_ REG-CONF-CONF_ OUTPUT-STAGE-REDUCED_ --mask=CONF-OUTPUT-STAGE-MASK_

  /**
  Sets output stage to Digital PWM.
  */
  set-output-stage-digital -> none:
    write-register_ REG-CONF-CONF_ OUTPUT-STAGE-DIGITAL_ --mask=CONF-OUTPUT-STAGE-MASK_

  /**
  Reads raw angle.

  Shows what the sensor reads, without adjustment from any configurable
   filtering, hysteresis, range mapping etc.  Until these are configured,
   returns the same value as $read-angle.
  */
  read-raw-angle -> int:
    raw := read-register_ REG-RAW-ANGLE_ --mask=TWELVE-BIT-MASK_ --width=16
    return raw

  /**
  Reads angle, and optionally scale to a target range.

  Angle as passed through the configuration pipeline:
  - Start, end and max angle registers - adjusting usable range.
  - Output stage including hysteresis and filtering.

  If --steps is supplied, results in a value (0 <= x <= steps) with one full
   revolution divided up into x sectors.
  */
  read-angle --steps/float=0.0 -> float:
    raw := read-register_ REG-ANGLE_ --mask=TWELVE-BIT-MASK_
    if steps == 0.0:
      return raw.to-float
    else:
      return (raw.to-float * steps) / 4096.0

  /**
  Gets start position configuration from the IC.
  */
  get-start-position -> int:
    return read-register_ REG-CONF-START-POS_ --mask=TWELVE-BIT-MASK_

  /**
  Sets start position configuration from the IC.
  */
  set-start-position value/int -> none:
    assert: 0 < value <= 4095
    write-register_ REG-CONF-START-POS_ value --mask=TWELVE-BIT-MASK_

  /**
  Gets stop position configuration from the IC.
  */
  get-stop-position -> int:
    return read-register_ REG-CONF-STOP-POS_ --mask=TWELVE-BIT-MASK_

  /**
  Sets stop position configuration from the IC.
  */
  set-stop-position value/int -> none:
    assert: 0 < value <= 4095
    write-register_ REG-CONF-STOP-POS_ value --mask=TWELVE-BIT-MASK_

  /**
  Gets Max Angle configuration from the IC.
  */
  get-max-angle-position -> int:
    return read-register_ REG-CONF-MAX-ANGLE_ --mask=TWELVE-BIT-MASK_

  /**
  Sets Max Angle configuration from the IC.
  */
  set-max-angle-position value/int -> none:
    assert: 0 < value <= 4095
    write-register_ REG-CONF-MAX-ANGLE_ value --mask=TWELVE-BIT-MASK_

  /**
  Enable Watchdog.

  The watchdog timer allows power saving by switching into LPM3 if the angle
  stays within the watchdog threshold of 4 LSB for at least one minute.
  */
  enable-watchdog -> none:
    write-register_ REG-CONF-CONF_ 1 --mask=CONF-WATCHDOG-MASK_

  /**
  Disable Watchdog.

  The watchdog timer allows power saving by switching into LPM3 if the angle
  stays within the watchdog threshold of 4 LSB for at least one minute.
  */
  disable-watchdog -> none:
    write-register_ REG-CONF-CONF_ 0 --mask=CONF-WATCHDOG-MASK_

  /**
  Returns if the Watchdog is enabled.

  The watchdog timer allows power saving by switching into LPM3 if the angle
  stays within the watchdog threshold of 4 LSB for at least one minute.
  */
  watchdog-enabled -> bool:
    raw := read-register_ REG-CONF-CONF_ --mask=CONF-WATCHDOG-MASK_
    return raw == 1

  /**
  Gets Fast Filter Threshold.

  Returns one of FAST-FILTER-TH-* constants.
  */
  get-fast-filter-threshold -> int:
    return read-register_ REG-CONF-CONF_ --mask=CONF-FAST-FILTER-THOLD-MASK_

  /**
  Gets Fast Filter Threshold.

  Uses one of FAST-FILTER-TH-* constants.
  */
  set-fast-filter-threshold value/int -> none:
    assert: 0 <= value <= 7
    write-register_ REG-CONF-CONF_ value --mask=CONF-FAST-FILTER-THOLD-MASK_

  /**
  Gets Slow Filter.

  Returns one of SLOW-FILTER-* constants.
  */
  get-slow-filter -> int:
    return read-register_ REG-CONF-CONF_ --mask=CONF-SLOW-FILTER-MASK_

  /**
  Sets Slow Filter.

  Uses one of SLOW-FILTER-* constants.
  */
  set-slow-filter value/int -> none:
    assert: 0 <= value <= 3
    write-register_ REG-CONF-CONF_ value --mask=CONF-SLOW-FILTER-MASK_

  /**
  Gets PWM Frequency.

  Returns one of PWM-FREQ-* constants.
  */
  get-pwm-frequency -> int:
    return read-register_ REG-CONF-CONF_ --mask=CONF-PWM-FREQ-MASK_

  /**
  Sets PWM Frequency.

  Uses one of PWM-FREQ-* constants.
  */
  set-pwm-frequency value/int -> none:
    assert: 0 <= value <= 3
    write-register_ REG-CONF-CONF_ value --mask=CONF-PWM-FREQ-MASK_

  /**
  Sets Hysteresis Configuration (in LSBs).

  Returns one of HYSTERESIS-* constants.
  */
  get-hysteresis-lsbs -> int:
    return read-register_ REG-CONF-CONF_ --mask=CONF-HYSTERESIS-MASK_

  /**
  Sets Hysteresis Configuration (in LSBs).

  Uses one of HYSTERESIS-* constants.
  */
  set-hysteresis-lsbs value/int -> none:
    assert: 0 <= value <= 3
    write-register_ REG-CONF-CONF_ value --mask=CONF-HYSTERESIS-MASK_

  /**
  Gets Power Mode.

  Returns one of POWER-MODE-* constants.
  */
  get-power-mode -> int:
    return read-register_ REG-CONF-CONF_ --mask=CONF-POWER-MODE-MASK_

  /**
  Sets Power Mode.

  Uses one of POWER-MODE-* constants.
  */
  set-power-mode value/int -> none:
    assert: 0 <= value <= 3
    write-register_ REG-CONF-CONF_ value --mask=CONF-POWER-MODE-MASK_

  /**
  Read "Magnet Detected" status.
  */
  is-magnet-there -> bool:
    raw := read-register_ REG-STATUS-STATUS_ --mask=STATUS-MAGNET-DETECT-MASK_ --width=8
    return raw == 1

  /**
  Read "Magnet Too Strong" status.
  */
  is-magnet-too-strong -> bool:
    raw := read-register_ REG-STATUS-STATUS_ --mask=STATUS-MAGNET-HIGH-MASK_ --width=8
    return raw == 1

  /**
  Read "Magnet Too Weak" status.
  */
  is-magnet-too-weak -> bool:
    raw := read-register_ REG-STATUS-STATUS_ --mask=STATUS-MAGNET-LOW-MASK_ --width=8
    return raw == 1

  /**
  Reads magnitude.
  */
  read-magnitude -> int:
    return read-register_ REG-STATUS-MAGNITUDE_ --mask=TWELVE-BIT-MASK_

  /**
  Reads Auto Gain Control register.
  */
  read-agc -> int:
    return read-register_ REG-STATUS-AGC_ --width=8

  /**
  Gets Previous Burns.

  The number of permanent writes is limited to three.  This returns how many
   times ZPOS and MPOS have been permanently written.
  */
  get-previous-burns -> int:
    return read-register_ REG-CONF-ZMCO_ --mask=CONF-ZMCO-MASK_ --width=8

  /**
  Burns angle configuration (ZPOS & MPOS) into non-volatile memory on the IC.
  */
  burn-angle-config --sure=false -> none:
    if not is-magnet-there:
      logger_.warn "burn-angle-config: cannot write.  Magnet missing."
      return
    if sure:
      write-register_ REG-BURN_ BURN-ANGLE_ --width=8
      logger_.warn "burn-angle-config: burned. Previous burns: $get-previous-burns"
    else:
      logger_.warn "burn-angle-config: NOT burned. Previous burns: $get-previous-burns"

  /**
  Burns setting (MANG and CONFIG) configuration into non-volatile memory on the IC.

  MANG can be written only if ZPOS and MPOS have never been permanently written
   (eg get-previous-burns = 00). The $burn-settings command can be performed
   only one time.
  */
  burn-settings --sure=false -> none:
    previous-burns := get-previous-burns
    if previous-burns > 0:
      logger_.warn "burn-angle-config: cannot write MANG and CONF. Previously burned ($previous-burns)."
      return
    if sure:
      write-register_ REG-BURN_ BURN-SETTING_ --width=8
      logger_.warn "burn-settings: burned. Previous burns: $get-previous-burns"
    else:
      logger_.warn "burn-settings: NOT burned. Previous burns: $get-previous-burns"


  read-register_
      register/int
      --mask/int?=null
      --offset/int?=null
      --width/int=DEFAULT-REGISTER-WIDTH_
      --signed/bool=false -> any:
    assert: (width == 8) or (width == 16)
    if mask == null:
      mask = (width == 16) ? 0xFFFF : 0xFF
    if offset == null:
      offset = mask.count-trailing-zeros

    register-value/int? := null
    if width == 8:
      if signed:
        register-value = reg_.read-i8 register
      else:
        register-value = reg_.read-u8 register
    if width == 16:
      if signed:
        register-value = reg_.read-i16-be register
      else:
        register-value = reg_.read-u16-be register

    if register-value == null:
      logger_.error "read-register_: Read failed."
      throw "read-register_: Read failed."

    if ((mask == 0xFFFF) or (mask == 0xFF)) and (offset == 0):
      return register-value
    else:
      masked-value := (register-value & mask) >> offset
      return masked-value

  write-register_
      register/int
      value/any
      --mask/int?=null
      --offset/int?=null
      --width/int=DEFAULT-REGISTER-WIDTH_
      --signed/bool=false -> none:
    assert: (width == 8) or (width == 16)
    if mask == null:
      mask = (width == 16) ? 0xFFFF : 0xFF
    if offset == null:
      offset = mask.count-trailing-zeros

    field-mask/int := (mask >> offset)
    assert: ((value & ~field-mask) == 0)  // fit check

    // Full-width direct write
    if ((width == 8)  and (mask == 0xFF)  and (offset == 0)) or
      ((width == 16) and (mask == 0xFFFF) and (offset == 0)):
      if width == 8:
        signed ? reg_.write-i8 register (value & 0xFF) : reg_.write-u8 register (value & 0xFF)
      else:
        signed ? reg_.write-i16-be register (value & 0xFFFF) : reg_.write-u16-be register (value & 0xFFFF)
      return

    // Read Reg for modification
    old-value/int? := null
    if width == 8:
      if signed :
        old-value = reg_.read-i8 register
      else:
        old-value = reg_.read-u8 register
    else:
      if signed :
        old-value = reg_.read-i16-be register
      else:
        old-value = reg_.read-u16-be register

    if old-value == null:
      logger_.error "write-register_: Read existing value (for modification) failed."
      throw "write-register_: Read failed."

    new-value/int := (old-value & ~mask) | ((value & field-mask) << offset)

    if width == 8:
      signed ? reg_.write-i8 register new-value : reg_.write-u8 register new-value
      return
    else:
      signed ? reg_.write-i16-be register new-value : reg_.write-u16-be register new-value
      return

    throw "write-register_: Unhandled Circumstance."

  /**
  Clamps the supplied value to specified limit.
  */
  clamp-value_ value/any --upper/any?=null --lower/any?=null -> any:
    if upper != null: if value > upper:  return upper
    if lower != null: if value < lower:  return lower
    return value

  /**
  Provides strings to display bitmasks nicely when testing.
  */
  bits-grouped_ x/int
      --min-display-bits/int=0
      --group-size/int=8
      --sep/string="."
      -> string:

    assert: x >= 0
    assert: group-size > 0

    // raw binary
    bin := "$(%b x)"

    // choose target width: at least min-display-bits, then round up to a full group
    groups := 0
    leftover := 0
    width := bin.size
    if min-display-bits > width:
      width = min-display-bits
    if group-size > width:
      width = group-size
    leftover = width % group-size
    if leftover > 0:
      width = width + (group-size - leftover)

    // left-pad to target width
    bin = bin.pad --left width '0'

    // group left->right
    out := ""
    i := 0
    while i < bin.size:
      if i > 0: out = "$(out)$(sep)"
      j := i + group-size
      if j > bin.size: j = bin.size
      out = "$(out)$(bin[i..j])"
      i = j

    return out
