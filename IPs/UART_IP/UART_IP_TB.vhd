library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_IP_TB is
end entity;

architecture tb of UART_IP_TB is

  constant CLK_FREQ_HZ : integer := 50_000_000;
  constant BAUD_RATE   : integer := 115_200;

  constant CLK_PERIOD  : time := 20 ns;
  constant BIT_PERIOD  : time := 1 sec / BAUD_RATE;

  constant TEST_BYTE   : std_logic_vector(7 downto 0) := x"41"; -- 'A'
  constant TIMEOUT_T   : time := 5 ms;

  signal clk     : std_logic := '0';
  signal reset_n : std_logic := '0';

  signal rx       : std_logic := '1';
  signal tx       : std_logic;

  signal tx_start : std_logic := '0';
  signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_busy  : std_logic;

  signal rx_data  : std_logic_vector(7 downto 0);
  signal rx_valid : std_logic;
  signal rx_ack   : std_logic := '0';

  procedure wait_until_level(signal s : in std_logic;
                             constant level : std_logic;
                             constant timeout : time;
                             constant msg : string) is
    variable elapsed : time := 0 ns;
  begin
    while (s /= level) loop
      wait for 1 us;
      elapsed := elapsed + 1 us;
      if elapsed >= timeout then
        assert false report msg severity failure;
      end if;
    end loop;
  end procedure;

  procedure uart_drive_byte(signal rx_line : out std_logic;
                            constant b     : std_logic_vector(7 downto 0)) is
  begin
    rx_line <= '1';
    wait for BIT_PERIOD;

    rx_line <= '0';  -- start
    wait for BIT_PERIOD;

    for i in 0 to 7 loop
      rx_line <= b(i); -- LSB first
      wait for BIT_PERIOD;
    end loop;

    rx_line <= '1';  -- stop
    wait for BIT_PERIOD;

    rx_line <= '1';
    wait for BIT_PERIOD;
  end procedure;

  procedure uart_capture_byte(signal tx_line : in std_logic;
                              variable b      : out std_logic_vector(7 downto 0)) is
  begin
    wait_until_level(tx_line, '0', TIMEOUT_T, "Timeout waiting TX start bit");

    wait for BIT_PERIOD + BIT_PERIOD/2;  -- center of bit0

    for i in 0 to 7 loop
      b(i) := tx_line;
      wait for BIT_PERIOD;
    end loop;

    wait for BIT_PERIOD; -- stop
  end procedure;

begin

  clk <= not clk after CLK_PERIOD/2;

  dut : entity work.UART_IP
    generic map (
      CLK_FREQ_HZ => CLK_FREQ_HZ,
      BAUD_RATE   => BAUD_RATE
    )
    port map (
      clk      => clk,
      reset_n  => reset_n,
      rx       => rx,
      tx       => tx,
      tx_start => tx_start,
      tx_data  => tx_data,
      tx_busy  => tx_busy,
      rx_data  => rx_data,
      rx_valid => rx_valid,
      rx_ack   => rx_ack
    );

  stim : process
    variable cap : std_logic_vector(7 downto 0);
  begin
    reset_n <= '0';
    rx <= '1';
    tx_start <= '0';
    tx_data <= (others => '0');
    rx_ack <= '0';
    wait for 200 ns;
    reset_n <= '1';
    wait for 200 ns;

    report "TX test: sending 'A'";

    wait until rising_edge(clk);
    tx_data  <= TEST_BYTE;
    tx_start <= '1';
    wait until rising_edge(clk);
    tx_start <= '0';

    uart_capture_byte(tx, cap);

    assert cap = TEST_BYTE
      report "TX mismatch"
      severity failure;

    report "RX test: injecting 'A'";

    uart_drive_byte(rx, TEST_BYTE);

    wait_until_level(rx_valid, '1', TIMEOUT_T, "Timeout waiting RX valid");

    assert rx_data = TEST_BYTE
      report "RX mismatch"
      severity failure;

    wait until rising_edge(clk);
    rx_ack <= '1';
    wait until rising_edge(clk);
    rx_ack <= '0';

    wait for 200 us;

    assert false
      report "End of simulation"
      severity failure;
  end process;

end architecture;
