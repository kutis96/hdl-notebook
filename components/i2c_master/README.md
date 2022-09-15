# i2c_master

A simple I2C master.

It still needs additional logic to be able to actually send data to devices.

But adding that Should™ be easy.

## How it will work

An informal spec of the component's function

### Signals

- Clocking/housekeeping
    - in `clk`
        - main clock
    - in `srst`
        - synchronous reset
    - in `clken`
        - clock enable pulses
        - must take at most one clk cycle per pulse
        - must come in at 2× the I2C transfer speed
            - = 200kHz for 100kHz transmissions
- I2C wiring
    - out scl_drive
        - When high, SCL must be driven low
    - out sda_drive
        - When high, SDA must be driven low
    - in scl_sense
    - in sda_sense
- Transaction
    - in `txn_req`
        - on transition from low to high:
            - initiates a `START` condition on the I2C bus
        - on transition from high to low:
            - initiates a `STOP` contion on the I2C bus
    - out `txn_ack`
        - goes high after the `START` condition on the I2C bus
            - signals that byte transfers are now ready
        - goes low after the `STOP` condition on the I2C bus
            - signals that a new transaction may be started
- Byte RX/TX
    - in `data_wr[7..0]`
        - Input data to be written
    - out `data_rd[7..0]`
        - Output data to be written
            - Valid when `data_rx_ack = 0` after a RX cycle
    - out `data_ack`
        - Last ACK/NAK state (ack = high, nak = low)
            - Valid when `data_tx_ack = 0` and `data_rx_ack = 0`
    - in `data_tx_req`
        - on transition from low to high:
            - initiates a byte transfer on the I2C bus, latching `data_wr`
            - this transition may only happen when
                `data_tx_ack = 0` and `data_rx_ack = 0` and `data_rx_req = 0`
    - out `data_tx_ack`
        - goes high after the byte transfer has been initiated
        - goes low after the data has been transmitted
    - in `data_rx_req`
        - on transition from low to high:
            - initiates a byte transfer from the I2C bus
            - this transition may only happen when
                `data_tx_ack = 0` and `data_rx_ack = 0` and `data_rx_req = 0`
    - out `data_rx_ack`
        - goes high after the byte transfer has been initiated
        - goes low after after the data has been transmitted (and the data on `data_rd` is valid)