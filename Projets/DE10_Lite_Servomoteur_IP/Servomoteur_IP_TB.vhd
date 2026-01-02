library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Servomoteur_IP_TB is
end entity Servomoteur_IP_TB;

architecture sim of Servomoteur_IP_TB is

    component Servomoteur_IP
        port (
            clk      : in  std_logic;
            Rst_n    : in  std_logic;
            position : in  std_logic_vector(9 downto 0);
            commande : out std_logic
        );
    end component;

    signal clk_tb   : std_logic := '0';
    signal rst_n_tb : std_logic := '0';
    signal pos_tb   : std_logic_vector(9 downto 0) := (others => '0');
    signal pwm_tb   : std_logic;

    constant CLK_PERIOD : time := 20 ns;

begin

    DUT : Servomoteur_IP
        port map (
            clk      => clk_tb,
            Rst_n    => rst_n_tb,
            position => pos_tb,
            commande => pwm_tb
        );

    clk_tb <= not clk_tb after CLK_PERIOD/2;

    stim_proc : process
    begin
        rst_n_tb <= '0';
        pos_tb   <= (others => '0');
        wait for 200 ns;

        rst_n_tb <= '1';
        wait for 5 ms;

        report "Case 1: position = 0 (minimum pulse)";
        pos_tb <= std_logic_vector(to_unsigned(0, 10));
        wait for 30 ms;

        report "Case 2: position = 1023 (maximum pulse)";
        pos_tb <= std_logic_vector(to_unsigned(1023, 10));
        wait for 30 ms;

        assert false report "End of simulation" severity failure;
    end process;

end architecture sim;
