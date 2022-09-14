library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- TODO: Generify for a number of LED layers
-- TODO: Generify for different widths

-- Notes:
-- This code currently contains several cardinal sins, including directly latching input pins without prior synchronization
-- -> This may lead to metastability issues.
-- -> The whole switch sampling bit seems quite fishy! The switch states should only be registered once in this cycle!
-- This code was written several years ago, and may not be up to my current level of snuff.
-- -> It is there as an idea only, to show off the possibility of such pin-saving measures.
-- -> I will update it at _some point_ to fix it up, I promise :)
-- -> If not, you're free to submit a PR!

entity led_switch_mux is
    generic (
        led_period      : natural := 50_000;  -- 1 ms
        switch_period   : natural :=  5_000   -- 0.1 ms 
    );
    port (
        clk             : in    std_logic;  -- 50MHz (20ns period)
        srst            : in    std_logic;  -- synchronous reset
        
        switches        : out   std_logic_vector(7 downto 0);   -- last read switch states
        leds            : in    std_logic_vector(15 downto 0);  -- LED signals to output
        
        ledsw           : inout std_logic_vector(7 downto 0);   -- combined LED/switch in/out; see schematic in docs
        led_en          : out   std_logic_vector(1 downto 0)    -- LED driver enable pins; see schematic in docs
    );
end led_switch_mux;

architecture impl1 of led_switch_mux is
    
    type state_t is (SW, LED0, LED1);
    signal state : state_t := SW;
    
    signal counter : natural := 0;
    
begin

    MAIN:
    process (clk) is
    begin
        if rising_edge(clk) then
            if srst = '1' then
                state <= SW;
                counter <= 0;
            else
                case state is
                    when SW =>
                        ledsw <= (others => 'Z');
                        led_en <= "00";
                        
                        if counter = switch_period then
                            counter <= 0;
                            state <= LED0;
                            switches <= ledsw; 
                        else
                            counter <= counter + 1;
                        end if;
                    when LED0 =>
                        ledsw <= leds(7 downto 0);
                        led_en <= "01";
                        
                        if counter = led_period then
                            counter <= 0;
                            state <= LED1;
                        else
                            counter <= counter + 1;
                        end if;
                    when LED1 =>
                        ledsw <= leds(15 downto 8);
                        led_en <= "10";
                        
                        if counter = led_period then
                            counter <= 0;
                            state <= SW;
                        else
                            counter <= counter + 1;
                        end if;
                    when others =>
                        state <= SW;
                        counter <= 0;
                end case;
            end if;
        end if;      
    end process;
end impl1;