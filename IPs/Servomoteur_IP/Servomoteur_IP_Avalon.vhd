library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Servomoteur_IP_Avalon is
    generic (
        CLK_FREQ_HZ : integer := 100_000_000
    );
    port (
        clk        : in  std_logic;
        reset_n    : in  std_logic;

        chipselect : in  std_logic;
        write_n    : in  std_logic;
        writedata  : in  std_logic_vector(31 downto 0);

        commande   : out std_logic
    );
end entity Servomoteur_IP_Avalon;


architecture Behavioral of Servomoteur_IP_Avalon is

    signal position_reg : std_logic_vector(9 downto 0) := (others => '0');

begin

    ServoCore : entity work.Servomoteur_IP
		generic map (
			CLK_FREQ_HZ => CLK_FREQ_HZ
		)
		port map (
			clk      => clk,
			Rst_n    => reset_n,
			position => position_reg,
			commande => commande
		);

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            position_reg <= (others => '0');

        elsif rising_edge(clk) then
            if (chipselect = '1') and (write_n = '0') then
                position_reg <= writedata(9 downto 0);
            end if;
        end if;
    end process;

end architecture Behavioral;
