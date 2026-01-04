library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_IP_Avalon is
    generic (
        CLK_FREQ_HZ : integer := 100_000_000;
        BAUD_RATE   : integer := 115_200
    );
    port (
        clk        : in  std_logic;
        reset_n    : in  std_logic;

        chipselect : in  std_logic;
        read_n     : in  std_logic;
        write_n    : in  std_logic;
        address    : in  std_logic_vector(1 downto 0);
        writedata  : in  std_logic_vector(31 downto 0);
        readdata   : out std_logic_vector(31 downto 0);

        uart_rx    : in  std_logic;
        uart_tx    : out std_logic
    );
end entity UART_IP_Avalon;

architecture Behavioral of UART_IP_Avalon is

    signal tx_start_pulse : std_logic := '0';
    signal tx_data_reg    : std_logic_vector(7 downto 0) := (others => '0');

    signal rx_ack_pulse   : std_logic := '0';

    signal tx_busy_s      : std_logic;
    signal rx_data_s      : std_logic_vector(7 downto 0);
    signal rx_valid_s     : std_logic;

    signal readdata_r     : std_logic_vector(31 downto 0) := (others => '0');

begin

    readdata <= readdata_r;

    UART_CORE : entity work.UART_IP
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            BAUD_RATE   => BAUD_RATE
        )
        port map (
            clk      => clk,
            reset_n  => reset_n,

            rx       => uart_rx,
            tx       => uart_tx,

            tx_start => tx_start_pulse,
            tx_data  => tx_data_reg,
            tx_busy  => tx_busy_s,

            rx_data  => rx_data_s,
            rx_valid => rx_valid_s,
            rx_ack   => rx_ack_pulse
        );

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            tx_start_pulse <= '0';
            tx_data_reg    <= (others => '0');
            rx_ack_pulse   <= '0';
            readdata_r     <= (others => '0');

        elsif rising_edge(clk) then
            tx_start_pulse <= '0';
            rx_ack_pulse   <= '0';

            if (chipselect = '1') and (write_n = '0') then
                case address is
                    when "00" =>
                        if tx_busy_s = '0' then
                            tx_data_reg    <= writedata(7 downto 0);
                            tx_start_pulse <= '1';
                        end if;

                    when "01" =>
                        if writedata(0) = '1' then
                            rx_ack_pulse <= '1';
                        end if;

                    when others =>
                        null;
                end case;
            end if;

            if (chipselect = '1') and (read_n = '0') then
                case address is
                    when "00" =>
                        readdata_r <= (others => '0');
                        readdata_r(7 downto 0) <= rx_data_s;

                    when "01" =>
                        readdata_r <= (others => '0');
                        readdata_r(0) <= rx_valid_s;
                        readdata_r(1) <= tx_busy_s;

                    when others =>
                        readdata_r <= (others => '0');
                end case;
            end if;
        end if;
    end process;

end architecture Behavioral;
