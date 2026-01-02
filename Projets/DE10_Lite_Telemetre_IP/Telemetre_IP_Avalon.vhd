library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Telemetre_IP_Avalon is
    port (
        clk        : in  std_logic;
        Rst_n      : in  std_logic;
        echo       : in  std_logic;

        trig       : out std_logic;
        Dist_cm    : out std_logic_vector(9 downto 0);

        Read_n     : in  std_logic;
        chipselect : in  std_logic;
        readdata   : out std_logic_vector(31 downto 0)
    );
end entity Telemetre_IP_Avalon;

architecture Behavioral of Telemetre_IP_Avalon is

    signal dist_int : std_logic_vector(9 downto 0);

begin

    Telemetre_core : entity work.Telemetre_IP
        port map (
            clk     => clk,
            Rst_n   => Rst_n,
            echo    => echo,
            trig    => trig,
            Dist_cm => dist_int
        );

    Dist_cm <= dist_int;

    process(clk, Rst_n)
    begin
        if Rst_n = '0' then
            readdata <= (others => '0');
        elsif rising_edge(clk) then
            if (chipselect = '1') and (Read_n = '0') then
                readdata <= (others => '0');
                readdata(9 downto 0) <= dist_int;
            end if;
        end if;
    end process;

end architecture Behavioral;
