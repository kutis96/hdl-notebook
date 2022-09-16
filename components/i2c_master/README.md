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
        - must come in at 4× the I2C transfer speed
            - = 400kHz for 100kHz transmissions
- I2C wiring
    - out `scl_drive`
        - When low, SCL must be driven low
        - When low, SCL must be left in Hi-Z
    - out `sda_drive`
        - When low, SDA must be driven low
        - When high, SDA must be left in Hi-Z
    - in `scl_sense`
        - Senses the state of the external SCL line
        - Not synchronized. Add external synchronizers.
    - in `sda_sense`
        - Senses the state of the external SDA line
        - Not synchronized. Add external synchronizers.
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
    - in `data_tx[7..0]`
        - Input data to be transmitted
    - out `data_rx[7..0]`
        - Output of the data received
            - Valid when `data_rx_ack = 0` after a RX cycle
    - out `data_ack`
        - Last ACK/NAK state (ack = high, nak = low)
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

### State diagram


### Usage

This I2C master only handles the basic line framing, such as the START and STOP states, byte transmission and ACK readback.

To actually read or write data from an I2C device, you have to implement a higher level controller/sequencer on top of this one.


#### To write N bytes to a device:
- Start transaction
    - when `txn_ack = 0`, set `txn_req = 1`
    - wait until `txn_ack = 1`
- Send address/RW byte
    - set `data_tx = address[6..0] & '0'` 
    - when `data_tx_ack = 0`, set `data_tx_req = 1`
    - when `data_tx_ack = 1`, set `data_tx_req = 0`
    - wait until `data_tx_ack = 0`
- Repeat N times
    - Send data
        - set `data_tx = data[n]` 
        - when `data_tx_ack = 0`, set `data_tx_req = 1`
        - when `data_tx_ack = 1`, set `data_tx_req = 0`
        - wait until `data_tx_ack = 0`
- Stop transaction
    - when `data_tx_ack = 0` and `txn_ack = 1`, set `txn_req = 0`

#### To read N bytes from a device:
- Start transaction
    - when `txn_ack = 0`, set `txn_req = 1`
    - wait until `txn_ack = 1`
- Send address/RW byte
    - set `data_tx = address[6..0] & '1'` 
    - when `data_tx_ack = 0`, set `data_tx_req = 1`
    - when `data_tx_ack = 1`, set `data_tx_req = 0`
    - wait until `data_tx_ack = 0`
- Repeat N times
    - Receive data
        - when `data_rx_ack = 0`, set `data_rx_req = 1`
        - when `data_rx_ack = 1`, set `data_rx_req = 0`
        - when `data_rx_ack = 0`, read data from `data_rx`
- Stop transaction
    - when `data_tx_ack = 0` and `txn_ack = 1`, set `txn_req = 0`
