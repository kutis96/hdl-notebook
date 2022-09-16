library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_i2c_master is
    -- nothing
end entity;

architecture test1 of tb_i2c_master is
    signal clk          : std_logic;
    signal srst         : std_logic;
    signal clken        : std_logic;
    signal scl_drive    : std_logic;
    signal scl_sense    : std_logic;
    signal sda_drive    : std_logic;
    signal sda_sense    : std_logic;
    signal txn_req      : std_logic := '0';
    signal txn_ack      : std_logic;
    signal data_ack     : std_logic;
    signal data_tx      : std_logic_vector(7 downto 0);
    signal data_tx_req  : std_logic := '0';
    signal data_tx_ack  : std_logic;
    signal data_rx      : std_logic_vector(7 downto 0);
    signal data_rx_req  : std_logic := '0';
    signal data_rx_ack  : std_logic;

    signal slave_scl_drive    : std_logic := '1';
    signal slave_scl_sense    : std_logic;
    signal slave_sda_drive    : std_logic := '1';
    signal slave_sda_sense    : std_logic;

    shared variable slave_device_storage : std_logic_vector(7 downto 0);

    constant t : time     :=  20 ns; -- main clock period (50 MHz)
    constant t_i2c : time := 100 ns; -- I2C clock period (100 kHz)
    
    procedure start_transaction(
        signal txn_req : out std_logic;
        signal txn_ack : in std_logic
    ) is
    begin
        txn_req <= '1';
        wait until txn_ack = '1';  
    end procedure;

    procedure stop_transaction(
        signal txn_req : out std_logic;
        signal txn_ack : in std_logic
    ) is
    begin
        txn_req <= '0';
        wait until txn_ack = '0';
    end procedure;

    procedure transmit_byte(
        signal data_tx      : out std_logic_vector(7 downto 0);
        signal data_tx_req  : out std_logic;
        signal data_tx_ack  : in  std_logic;
        data                : in std_logic_vector(7 downto 0)
    ) is
    begin
        data_tx <= data;
        data_tx_req <= '1';
        wait until data_tx_ack = '1';
        data_tx <= (others => 'U');
        data_tx_req <= '0';
        wait for t;
        wait until data_tx_ack = '0';
    end procedure;

    procedure receive_byte(
        signal data_rx      : in  std_logic_vector(7 downto 0);
        signal data_rx_req  : out std_logic;
        signal data_rx_ack  : in  std_logic;
        data                : out std_logic_vector(7 downto 0)
    ) is
    begin
        data_rx_req <= '1';
        wait until data_rx_ack = '1';
        data_rx_req <= '0';
        wait until data_rx_ack = '0';
        data := data_rx;
    end procedure;

begin

    assert t_i2c >= 4 * t
        report "Configured I2C time period must be at least 4x that of the main clock"
        severity failure;

    assert (data_tx_req and data_rx_req) = '0'
        report "TX and RX requests enabled simultaneously!"
        severity warning;
    
    assert txn_ack = '1' or (txn_ack = '0' and (data_tx_req or data_rx_req) = '0')
        report "TX or RX requested without active transaction"
        severity warning;

dut: entity work.i2c_master
    port map (
        clk => clk,
        srst => srst,
        clken => clken,
        scl_drive => scl_drive,
        scl_sense => scl_sense,
        sda_drive => sda_drive,
        sda_sense => sda_sense,
        txn_req => txn_req,
        txn_ack => txn_ack,
        data_ack => data_ack,
        data_tx => data_tx,
        data_tx_req => data_tx_req,
        data_tx_ack => data_tx_ack,
        data_rx => data_rx,
        data_rx_req => data_rx_req,
        data_rx_ack => data_rx_ack
    );

main: process is
    variable transmitted_data : std_logic_vector(7 downto 0) := "01110101";
    variable received_data : std_logic_vector(7 downto 0);
begin
    wait until srst = '0';
    wait for 10 * t;

    -- Write data to device
    start_transaction(txn_req, txn_ack);
    transmit_byte(data_tx, data_tx_req, data_tx_ack,
        "0110101" & '0' -- write
    );
    transmit_byte(data_tx, data_tx_req, data_tx_ack,
        transmitted_data
    );
    stop_transaction(txn_req, txn_ack);

    wait for 5 * t_i2c; -- just because

    -- Read data from device
    start_transaction(txn_req, txn_ack);
    transmit_byte(data_tx, data_tx_req, data_tx_ack,
        "0110101" & '1' -- read
    );
    receive_byte(data_rx, data_rx_req, data_rx_ack,
        received_data
    );
    stop_transaction(txn_req, txn_ack);

    report "Transmitted data: " & integer'image(to_integer(unsigned(transmitted_data))) severity note;
    report "Received data:    " & integer'image(to_integer(unsigned(received_data))) severity note;
    assert received_data = transmitted_data report "Loopback failed, received data don't match transmitted data" severity failure;

    wait;
end process;

reset: process is
begin
    srst <= '1';
    wait for 10 * t;
    srst <= '0';
    wait;
end process;

clock_main: process is
begin
    clk <= '0';
    wait for t/2;
    clk <= '1';
    wait for t/2;
end process;

clocken_i2c: process is
begin
    clken <= '0';
    wait for t_i2c - t;
    clken <= '1';
    wait for t;
end process;

i2c_device: process is
    procedure i2c_device_receive(
        signal sda_sense   : in std_logic;
        signal scl_sense   : in std_logic;
        signal sda_drive   : out std_logic;
        signal scl_drive   : out std_logic;
        data               : out std_logic_vector(7 downto 0)
    ) is
    begin
        for I in 7 downto 0 loop
            wait until rising_edge(scl_sense);
            data(I) := slave_sda_sense;
            wait until falling_edge(scl_sense);
        end loop;
    end procedure;

    procedure i2c_device_transmit(
        signal sda_sense   : in std_logic;
        signal scl_sense   : in std_logic;
        signal sda_drive   : out std_logic;
        signal scl_drive   : out std_logic;
        data               : in std_logic_vector(7 downto 0)
    ) is
    begin
        for I in 7 downto 0 loop
            wait until rising_edge(scl_sense);
            sda_drive <= data(I);
            wait until falling_edge(scl_sense);
        end loop;
        sda_drive <= '1';
    end procedure;

    procedure i2c_device_ack(
        signal sda_sense   : in std_logic;
        signal scl_sense   : in std_logic;
        signal sda_drive   : out std_logic;
        signal scl_drive   : out std_logic;
        ack : in std_logic
    ) is
    begin
        sda_drive <= ack;
        wait until slave_scl_sense = '1';
        wait until slave_scl_sense = '0';
        sda_drive <= '1';
    end procedure;

    constant address : std_logic_vector(6 downto 0) := "0110101";
    variable data : std_logic_vector(7 downto 0);
begin
    report "Device: I am a teapot!" severity note;

    -- Wait for start condition
    wait until falling_edge(slave_sda_sense) and slave_scl_sense = '1';
    report "Device: Transaction started" severity note;
    
    -- Address + R/W byte
    i2c_device_receive(
        slave_sda_sense, slave_scl_sense, slave_sda_drive, slave_scl_drive,
        data
    );
    report "Device: Received address: " & integer'image(to_integer(unsigned(data(7 downto 1)))) severity note;
    report "Device: Mine is address: " & integer'image(to_integer(unsigned(address))) severity note;

    -- Read/Write
    if(data(7 downto 1) = address) then
        report "Device: This message is for me!" severity note;
        i2c_device_ack(
            slave_sda_sense, slave_scl_sense, slave_sda_drive, slave_scl_drive,
            '0' -- good
        );

        if(data(0) = '0') then
            -- write to device
            i2c_device_receive(
                slave_sda_sense, slave_scl_sense, slave_sda_drive, slave_scl_drive,
                slave_device_storage
            );

            report "Device: Writing a value: " & integer'image(to_integer(unsigned(slave_device_storage))) severity note;

            i2c_device_ack(
                slave_sda_sense, slave_scl_sense, slave_sda_drive, slave_scl_drive,
                '0' -- good
            );
        else
            -- read from device

            report "Device: Reading a value: " & integer'image(to_integer(unsigned(slave_device_storage))) severity note;

            i2c_device_transmit(
                slave_sda_sense, slave_scl_sense, slave_sda_drive, slave_scl_drive,
                slave_device_storage
            );
            i2c_device_ack(
                slave_sda_sense, slave_scl_sense, slave_sda_drive, slave_scl_drive,
                '0' -- good
            );
        end if;
    else
        report "Device: Not processing - this message is not for me!" severity note;
    end if;

    -- Wait for stop condition
    wait until rising_edge(slave_sda_sense) and slave_scl_sense = '1';
    report "Device: Transaction ended" severity note;
end process;


sda_sense <= sda_drive and slave_sda_drive;
slave_sda_sense <= sda_drive and slave_sda_drive;

scl_sense <= scl_drive and slave_scl_drive;
slave_scl_sense <= scl_drive and slave_scl_drive;

end architecture;