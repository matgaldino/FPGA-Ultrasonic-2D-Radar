library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_IP_Avalon_TB is
end entity;

architecture tb of UART_IP_Avalon_TB is

  constant CLK_FREQ_HZ : integer := 100_000_000;
  constant BAUD_RATE   : integer := 115_200;

  constant CLK_PERIOD  : time := 10 ns;
  constant BIT_TIME    : time := 1 sec / BAUD_RATE;

  signal clk        : std_logic := '0';
  signal reset_n    : std_logic := '0';

  signal chipselect : std_logic := '0';
  signal read_n     : std_logic := '1';
  signal write_n    : std_logic := '1';
  signal address    : std_logic_vector(1 downto 0) := (others => '0');
  signal writedata  : std_logic_vector(31 downto 0) := (others => '0');
  signal readdata   : std_logic_vector(31 downto 0);

  signal uart_rx    : std_logic := '1';
  signal uart_tx    : std_logic;

begin

  clk <= not clk after CLK_PERIOD/2;

  DUT : entity work.UART_IP_Avalon
    generic map (
      CLK_FREQ_HZ => CLK_FREQ_HZ,
      BAUD_RATE   => BAUD_RATE
    )
    port map (
      clk        => clk,
      reset_n    => reset_n,

      chipselect => chipselect,
      read_n     => read_n,
      write_n    => write_n,
      address    => address,
      writedata  => writedata,
      readdata   => readdata,

      uart_rx    => uart_rx,
      uart_tx    => uart_tx
    );

  stim : process
    variable rd : std_logic_vector(31 downto 0);
  begin
    reset_n    <= '0';
    chipselect <= '0';
    read_n     <= '1';
    write_n    <= '1';
    address    <= (others => '0');
    writedata  <= (others => '0');
    uart_rx    <= '1';

    wait for 200 ns;
    wait until rising_edge(clk);
    reset_n <= '1';
    wait for 200 ns;

    -- ==========================
    -- Avalon WRITE addr=0: TX 'A'
    -- ==========================
    address    <= "00";
    writedata  <= x"00000041";
    chipselect <= '1';
    write_n    <= '0';
    wait until rising_edge(clk);

    write_n    <= '1';
    chipselect <= '0';

    -- SEGURA DADO POR +2 CLOCKS (para aparecer no waveform)
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    writedata  <= (others => '0');
    address    <= (others => '0');

    -- espera TX frame terminar
    wait for 12 * BIT_TIME;

    -- ==========================
    -- UART RX: envia 'Z' (0x5A) para uart_rx
    -- ==========================
    uart_rx <= '0';  wait for BIT_TIME;                -- start
    uart_rx <= '0';  wait for BIT_TIME;                -- bit0
    uart_rx <= '1';  wait for BIT_TIME;                -- bit1
    uart_rx <= '0';  wait for BIT_TIME;                -- bit2
    uart_rx <= '1';  wait for BIT_TIME;                -- bit3
    uart_rx <= '1';  wait for BIT_TIME;                -- bit4
    uart_rx <= '0';  wait for BIT_TIME;                -- bit5
    uart_rx <= '1';  wait for BIT_TIME;                -- bit6
    uart_rx <= '0';  wait for BIT_TIME;                -- bit7
    uart_rx <= '1';  wait for BIT_TIME;                -- stop

    wait for 2 * BIT_TIME;

    -- ==========================
    -- Poll STATUS addr=1 até rx_valid=1
    -- ==========================
    for k in 0 to 400 loop
      address    <= "01";
      chipselect <= '1';
      read_n     <= '0';
      wait until rising_edge(clk);
      wait for 1 ns;
      rd := readdata;
      chipselect <= '0';
      read_n     <= '1';

      exit when rd(0) = '1';
      wait for BIT_TIME;
    end loop;

    assert rd(0) = '1'
      report "RX_VALID nao ficou 1"
      severity failure;

    -- ==========================
    -- Avalon READ addr=0: DATA deve ser 0x5A
    -- ==========================
    address    <= "00";
    chipselect <= '1';
    read_n     <= '0';
    wait until rising_edge(clk);
    wait for 1 ns;
    rd := readdata;
    chipselect <= '0';
    read_n     <= '1';

    assert rd(7 downto 0) = x"5A"
      report "RX_DATA diferente do esperado"
      severity failure;

    -- ==========================
    -- Avalon WRITE addr=1: ACK (bit0=1)
    -- ==========================
    address    <= "01";
    writedata  <= x"00000001";
    chipselect <= '1';
    write_n    <= '0';
    wait until rising_edge(clk);

    write_n    <= '1';
    chipselect <= '0';

    -- SEGURA DADO POR +2 CLOCKS (para aparecer no waveform)
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    writedata  <= (others => '0');
    address    <= (others => '0');

    wait for 2 * BIT_TIME;

    -- ==========================
    -- Lê STATUS e garante rx_valid=0
    -- ==========================
    address    <= "01";
    chipselect <= '1';
    read_n     <= '0';
    wait until rising_edge(clk);
    wait for 1 ns;
    rd := readdata;
    chipselect <= '0';
    read_n     <= '1';

    assert rd(0) = '0'
      report "RX_VALID nao limpou apos ACK"
      severity failure;

    assert false
      report "End of simulation"
      severity failure;

    wait;
  end process;

end architecture;
