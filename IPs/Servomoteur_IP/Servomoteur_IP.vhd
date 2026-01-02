library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Servomoteur_IP is
    generic (
        CLK_FREQ_HZ : integer := 50_000_000
    );
    port (
        clk      : in  std_logic;
        Rst_n    : in  std_logic;
        position : in  std_logic_vector(9 downto 0);
        commande : out std_logic
    );
end entity Servomoteur_IP;


architecture Behavioral of Servomoteur_IP is

    constant PERIOD_20MS : integer := CLK_FREQ_HZ / 50;
    constant PULSE_MIN   : integer := CLK_FREQ_HZ / 1850;
    constant PULSE_MAX   : integer := CLK_FREQ_HZ / 458;

    signal counter     : integer := 0;
    signal pulse_width : integer := PULSE_MIN;

begin

    process(clk, Rst_n)
        variable pos_i     : integer;
        variable angle_deg : integer;
    begin
        if Rst_n = '0' then
            counter     <= 0;
            pulse_width <= PULSE_MIN;
            commande    <= '0';

        elsif rising_edge(clk) then

            if counter = 0 then
                pos_i := to_integer(unsigned(position));
                angle_deg := (pos_i * 180) / 1023;
                pulse_width <= PULSE_MIN + (angle_deg * (PULSE_MAX - PULSE_MIN)) / 180;
            end if;

            if counter < pulse_width then
                commande <= '1';
            else
                commande <= '0';
            end if;

            if counter = PERIOD_20MS - 1 then
                counter <= 0;
            else
                counter <= counter + 1;
            end if;

        end if;
    end process;

end architecture Behavioral;
