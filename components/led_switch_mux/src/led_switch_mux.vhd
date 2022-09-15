library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Notes:
-- This code currently contains several cardinal sins, including directly latching input pins without prior synchronization
-- -> This may lead to metastability issues.
-- This code was written several years ago, and may not be up to my current level of snuff.
-- -> It is there as an idea only, to show off the possibility of such pin-saving measures.
-- -> I will update it at _some point_ to fix it up, I promise :)
-- -> If not, you're free to submit a PR!

entity led_switch_mux is
    generic (
        led_rows        : natural := 2;
        led_columns     : natural := 8;
        led_period      : natural := 50_000;  -- 1 ms
        switch_period   : natural :=  5_000   -- 0.1 ms 
    );
    port (
        clk             : in    std_logic;  -- 50MHz (20ns period)
        srst            : in    std_logic;  -- synchronous reset
        
        switches        : out   std_logic_vector(led_columns - 1 downto 0);             -- last read switch states
        leds            : in    std_logic_vector(led_columns * led_rows - 1 downto 0);  -- LED signals to output
        
        ledsw           : inout std_logic_vector(led_columns - 1 downto 0);   -- combined LED/switch in/out; see schematic in docs
        leden           : out   std_logic_vector(led_rows - 1 downto 0)    -- LED driver enable pins; see schematic in docs
    );
end led_switch_mux;

architecture impl1 of led_switch_mux is
    
    type state_t is (SW, LED);
    signal state : state_t := SW;
    
    signal delay_counter : natural := 0;
    signal led_counter : natural := 0;
    
begin

main: process (clk) is
    begin
        if rising_edge(clk) then
            if srst = '1' then
                state <= SW;
                delay_counter <= 0;
            else
                -- default behaviors overriden within the case statement
                delay_counter <= delay_counter + 1;
                leden <= (others => '0');

                case state is
                    when SW =>
                        ledsw <= (others => 'Z');
                        
                        if delay_counter >= switch_period then
                            delay_counter <= 0;
                            led_counter <= 0;
                            state <= LED;
                            switches <= ledsw; -- TODO: Add a synchronizer
                        end if;

                    when LED =>
                        ledsw <= leds(7 + led_counter*8 downto led_counter*8);
                        leden(led_counter) <= '1'; -- others are zeroes, see defaults

                        if delay_counter >= led_period then
                            delay_counter <= 0;
                            led_counter <= led_counter + 1;

                            if led_columns >= led_rows - 1 then
                                state <= SW;
                            end if;
                        end if;
                end case;
            end if;
        end if;      
    end process;
end impl1;