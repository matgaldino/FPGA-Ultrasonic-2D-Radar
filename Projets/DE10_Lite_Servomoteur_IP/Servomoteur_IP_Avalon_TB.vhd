library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Servomoteur_IP_Avalon_TB is
end entity Servomoteur_IP_Avalon_TB;

architecture sim of Servomoteur_IP_Avalon_TB is

    component Servomoteur_IP_Avalon
        port (
            clk        : in  std_logic;
            reset_n    : in  std_logic;
            chipselect : in  std_logic;
            write_n    : in  std_logic;
            writedata  : in  std_logic_vector(31 downto 0);
            commande   : out std_logic
        );
    end component;

    signal clk_tb        : std_logic := '0';
    signal reset_n_tb    : std_logic := '0';
    signal chipselect_tb : std_logic := '0';
    signal write_n_tb    : std_logic := '1';
    signal writedata_tb  : std_logic_vector(31 downto 0) := (others => '0');
    signal commande_tb   : std_logic;

    constant CLK_PERIOD : time := 20 ns;

begin

    DUT : Servomoteur_IP_Avalon
        port map (
            clk        => clk_tb,
            reset_n    => reset_n_tb,
            chipselect => chipselect_tb,
            write_n    => write_n_tb,
            writedata  => writedata_tb,
            commande   => commande_tb
        );

    clk_tb <= not clk_tb after CLK_PERIOD/2;

    stim_proc : process
        variable t_rise : time;
        variable t_fall : time;

        procedure measure_high_time(variable th : out time) is
        begin
            wait until commande_tb = '1';
            t_rise := now;
            wait until commande_tb = '0';
            t_fall := now;
            th := t_fall - t_rise;
        end procedure;

        procedure do_write(value : integer; cs : std_logic; wn : std_logic) is
        begin
            chipselect_tb <= cs;
            write_n_tb    <= wn;
            writedata_tb  <= std_logic_vector(to_unsigned(value, 32));
            wait for CLK_PERIOD;
            chipselect_tb <= '0';
            write_n_tb    <= '1';
        end procedure;

        variable th_ref : time;
        variable th_new : time;

    begin
        reset_n_tb    <= '0';
        chipselect_tb <= '0';
        write_n_tb    <= '1';
        writedata_tb  <= (others => '0');
        wait for 200 ns;

        reset_n_tb <= '1';
        wait for 2 ms;

        report "Write valid: position = 0 (initialize)";
        do_write(0, '1', '0');
        measure_high_time(th_ref);

        report "Write invalid (chipselect=0): attempt position = 1023, PWM must not change";
        do_write(1023, '0', '0');
        measure_high_time(th_new);
        assert th_new = th_ref
            report "ERROR: PWM changed with chipselect=0"
            severity error;

        report "Write invalid (write_n=1): attempt position = 1023, PWM must not change";
        do_write(1023, '1', '1');
        measure_high_time(th_new);
        assert th_new = th_ref
            report "ERROR: PWM changed with write_n=1"
            severity error;

        report "Write valid: position = 1023, PWM must change";
        do_write(1023, '1', '0');
        measure_high_time(th_new);
        assert th_new /= th_ref
            report "ERROR: PWM did not change with valid write"
            severity error;

        assert false report "End of simulation" severity failure;
    end process;

end architecture sim;
