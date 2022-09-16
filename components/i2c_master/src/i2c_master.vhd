library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_master is
    port (
        clk : in std_logic;
        srst : in std_logic;
        clken : in std_logic;

        scl_drive : out std_logic;
        scl_sense : in std_logic;
        sda_drive : out std_logic;
        sda_sense : in std_logic;

        txn_req : in std_logic;
        txn_ack : out std_logic;

        data_ack : out std_logic;

        data_tx : in std_logic_vector(7 downto 0);
        data_tx_req : in std_logic;
        data_tx_ack : out std_logic;

        data_rx : out std_logic_vector(7 downto 0);
        data_rx_req : in std_logic;
        data_rx_ack : out std_logic
    );
end i2c_master;

architecture impl1 of i2c_master is
    type state_t is (
        IDLE,
        START, STOP, TRANSACTION,
        RECEIVING, TRANSMITTING,
        DONE
    );
    signal state : state_t := IDLE;

    subtype clock_phase_counter_t is natural range 0 to 3; -- 4 phases
    signal clock_phase_counter          : clock_phase_counter_t;
    constant clock_counter_last_phase   : clock_phase_counter_t := 3;

    signal bit_counter          : unsigned(4 downto 0); -- 0 to 7 = data, 8 = ACK

    signal data_shiftreg : std_logic_vector(7 downto 0);
begin

sync: process(clk) is
begin
    if rising_edge(clk) then

        if srst = '1' then
            state <= IDLE;
            clock_phase_counter <= 0;
        elsif clken = '1' then
            if clock_phase_counter = clock_counter_last_phase then
                clock_phase_counter <= 0;
            else
                clock_phase_counter <= clock_phase_counter + 1;
            end if;

            case state is
                when IDLE =>
                    sda_drive   <= '1'; -- release the bus
                    scl_drive   <= '1'; -- release the bus
                    data_rx_ack <= '0';
                    data_tx_ack <= '0';
                    txn_ack     <= '0';

                    if clock_phase_counter = clock_counter_last_phase then --transitions state on last phase, meaning TX/RX starts on zero
                        -- TODO: Sense the bus is actually free
                        if txn_req = '1' then
                            state <= START;
                        end if;
                    end if;

                when START =>
                    if clock_phase_counter < 2 then
                        scl_drive <= '1'; -- release
                        sda_drive <= '1'; -- release
                    else
                        scl_drive <= '1'; -- release
                        sda_drive <= '0'; -- hold low

                        state <= TRANSACTION;
                    end if;

                when STOP =>
                    if clock_phase_counter < 2 then
                        scl_drive <= '1'; -- release
                        sda_drive <= '0'; -- hold low
                    else
                        scl_drive <= '1'; -- release
                        sda_drive <= '1'; -- release

                        state <= IDLE;
                    end if;
                    
                when TRANSACTION =>
                    txn_ack <= '1';
                    if clock_phase_counter = clock_counter_last_phase then --transitions state on last phase, meaning TX/RX starts on zero
                        if txn_req = '0' then
                            state <= STOP;
                        end if;
                        if data_tx_req = '1' and data_rx_req = '0' then
                            state <= TRANSMITTING;

                            data_shiftreg <= data_tx;
                            bit_counter <= (others => '0');
                        end if;
                        if data_rx_req = '1' and data_tx_req = '0' then
                            state <= RECEIVING;
                            
                            bit_counter <= (others => '0');
                        end if;
                    end if;

                when TRANSMITTING =>
                    data_tx_ack <= '1';
                    case clock_phase_counter is
                        when 0 =>
                            scl_drive <= '0'; -- hold low

                        when 1 =>
                            -- shift data out
                            if bit_counter <= 7 then
                                sda_drive <= data_shiftreg(7);
                                data_shiftreg(7 downto 1) <= data_shiftreg(6 downto 0);
                                data_shiftreg(0) <= '0'; --something.
                            else
                                sda_drive <= '1'; -- release for the ACK bit
                            end if;
                                
                            if bit_counter = 9 then
                                if data_tx_req = '0' and data_rx_req = '0' then 
                                    data_tx_ack <= '0';
                                    state <= TRANSACTION;
                                else
                                    state <= DONE;
                                end if;
                            end if;

                        when 2 =>
                            scl_drive <= '1'; -- release, data valid
                        
                        when 3 =>
                            if scl_sense = '0' then
                                clock_phase_counter <= clock_phase_counter; -- hold your horses, we're being clock-stretched!
                            else
                                bit_counter <= bit_counter + 1;
                                if bit_counter = 8 then
                                    data_ack <= not sda_sense; -- latch ACK signal
                                end if;
                            end if;
                    end case;

                when RECEIVING =>
                    data_rx_ack <= '1';
                    case clock_phase_counter is
                        when 0 =>
                            scl_drive <= '0'; -- hold low

                        when 1 =>
                            if bit_counter = 9 then
                                if data_tx_req = '0' and data_rx_req = '0' then 
                                    data_rx_ack <= '0';
                                    state <= TRANSACTION;
                                else
                                    state <= DONE;
                                end if;
                            end if;

                        when 2 =>
                            scl_drive <= '1'; -- release, data valid
                        
                        when 3 =>
                            if scl_sense = '0' then
                                clock_phase_counter <= clock_phase_counter; -- hold your horses, we're being clock-stretched!
                            else
                                if bit_counter <= 7 then
                                    data_shiftreg(7 downto 1) <= data_shiftreg(6 downto 0);
                                    data_shiftreg(0) <= sda_sense; -- shift data in
                                end if;    

                                bit_counter <= bit_counter + 1;
                                if bit_counter = 8 then
                                    data_ack <= not sda_sense; -- latch ACK signal

                                    data_rx <= data_shiftreg; -- output read-in data
                                end if;
                            end if;
                    end case;

                when DONE =>
                    if data_tx_req = '0' and data_rx_req = '0' then 
                        data_tx_ack <= '0';
                        data_rx_ack <= '0';
                        state <= TRANSACTION;
                    end if;
            end case;
        end if;
    end if;
end process;



end architecture;