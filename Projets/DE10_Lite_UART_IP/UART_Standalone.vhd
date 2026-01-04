library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_Standalone is
  port (
    CLOCK_50 : in  std_logic;
    KEY      : in  std_logic_vector(0 downto 0);

    GPIO_2   : out std_logic;  -- uart_tx
    GPIO_4   : in  std_logic   -- uart_rx (não usado no TX-only)
  );
end entity;

architecture rtl of UART_Standalone is

  signal reset_n  : std_logic;

  signal tx_start : std_logic := '0';
  signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_busy  : std_logic;

  signal rx_data  : std_logic_vector(7 downto 0);
  signal rx_valid : std_logic;
  signal rx_ack   : std_logic := '0';

  constant MSG_LEN : integer := 7;
  type msg_t is array (0 to MSG_LEN-1) of std_logic_vector(7 downto 0);
  constant MSG : msg_t := (
    x"48", -- H
    x"45", -- E
    x"4C", -- L
    x"4C", -- L
    x"4F", -- O
    x"0D", -- \r
    x"0A"  -- \n
  );

  signal msg_idx : integer range 0 to MSG_LEN-1 := 0;

  constant GAP_CYCLES : integer := 50_000_000; -- 1s @ 50 MHz
  signal gap_cnt : integer range 0 to GAP_CYCLES := 0;

  type st_t is (S_IDLE, S_LOAD, S_PULSE, S_WAIT_BUSY, S_GAP);
  signal st : st_t := S_IDLE;

begin

  reset_n <= KEY(0);

  u_uart : entity work.UART_IP
    generic map (
      CLK_FREQ_HZ => 50_000_000,
      BAUD_RATE   => 115_200
    )
    port map (
      clk      => CLOCK_50,
      reset_n  => reset_n,

      rx       => GPIO_4,
      tx       => GPIO_2,

      tx_start => tx_start,
      tx_data  => tx_data,
      tx_busy  => tx_busy,

      rx_data  => rx_data,
      rx_valid => rx_valid,
      rx_ack   => rx_ack
    );

  process(CLOCK_50)
  begin
    if rising_edge(CLOCK_50) then
      if reset_n = '0' then
        tx_start <= '0';
        tx_data  <= (others => '0');
        rx_ack   <= '0';
        msg_idx  <= 0;
        gap_cnt  <= 0;
        st       <= S_IDLE;
      else
        tx_start <= '0';
        rx_ack   <= '0';

        case st is
          when S_IDLE =>
            msg_idx <= 0;
            st <= S_LOAD;

          when S_LOAD =>
            if tx_busy = '0' then
              tx_data <= MSG(msg_idx);   -- 1) carrega o byte
              st <= S_PULSE;
            end if;

          when S_PULSE =>
            tx_start <= '1';             -- 2) pulso no ciclo seguinte (tx_data já está estável)
            st <= S_WAIT_BUSY;

          when S_WAIT_BUSY =>
            if tx_busy = '0' then
              if msg_idx = MSG_LEN-1 then
                gap_cnt <= 0;
                st <= S_GAP;
              else
                msg_idx <= msg_idx + 1;
                st <= S_LOAD;
              end if;
            end if;

          when S_GAP =>
            if gap_cnt = GAP_CYCLES then
              st <= S_IDLE;
            else
              gap_cnt <= gap_cnt + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture;
