library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Telemetre_IP_TB is
end entity;

architecture Behavioral of Telemetre_IP_TB is

    component Telemetre_IP is
        port (
            clk     : in  std_logic;
            Rst_n   : in  std_logic;
            echo    : in  std_logic;
            trig    : out std_logic;
            Dist_cm : out std_logic_vector(9 downto 0)
        );
    end component;

    signal clk_tb   : std_logic := '0';
    signal Rst_n_tb : std_logic := '0';
    signal echo_tb  : std_logic := '0';
    signal trig_tb  : std_logic;
    signal dist_tb  : std_logic_vector(9 downto 0);

    constant CLK_PERIOD : time := 20 ns;

    constant ECHO_TIME_20  : time := 1160 us;   -- 20  cm  (20 * 58 us)
    constant ECHO_TIME_100 : time := 5800 us;   -- 100 cm  (100 * 58 us)
    constant ECHO_TIME_350 : time := 20300 us;  -- 350 cm  (350 * 58 us)
    constant ECHO_TIME_450 : time := 26100 us;  -- 450 cm  (450 * 58 us)

    constant POST_TRIG_DELAY : time := 200 us;

begin

    clk_process : process
    begin
        clk_tb <= '0';
        wait for CLK_PERIOD/2;
        clk_tb <= '1';
        wait for CLK_PERIOD/2;
    end process;

    UUT : Telemetre_IP
        port map (
            clk     => clk_tb,
            Rst_n   => Rst_n_tb,
            echo    => echo_tb,
            trig    => trig_tb,
            Dist_cm => dist_tb
        );

    stim_proc : process
    begin
        Rst_n_tb <= '0';
        echo_tb  <= '0';
        wait for 200 ns;
        Rst_n_tb <= '1';

        wait until rising_edge(trig_tb);
        wait until falling_edge(trig_tb);
        wait for POST_TRIG_DELAY;
        echo_tb <= '1';
        wait for ECHO_TIME_20;
        echo_tb <= '0';

        wait until rising_edge(trig_tb);
        wait until falling_edge(trig_tb);
        wait for POST_TRIG_DELAY;
        echo_tb <= '1';
        wait for ECHO_TIME_100;
        echo_tb <= '0';

        wait until rising_edge(trig_tb);
        wait until falling_edge(trig_tb);
        wait for POST_TRIG_DELAY;
        echo_tb <= '1';
        wait for ECHO_TIME_350;
        echo_tb <= '0';

        wait until rising_edge(trig_tb);
        wait until falling_edge(trig_tb);
        wait for POST_TRIG_DELAY;
        echo_tb <= '1';
        wait for ECHO_TIME_450;
        echo_tb <= '0';

        wait for 20 ms;
		
		assert false
			report "End of simulation"
			severity failure;
    end process;

end architecture Behavioral;
