library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Telemetre_IP is
	generic (
		CLK_FREQ_HZ : integer := 50000000
	);
    port (
        clk     : in  std_logic;
        Rst_n   : in  std_logic;
        echo    : in  std_logic;
        trig    : out std_logic;
        Dist_cm : out std_logic_vector(9 downto 0)
    );
end entity Telemetre_IP;

architecture Behavioral of Telemetre_IP is

    constant TRIG_PULSE_US         : integer := 10;
    constant TRIG_PULSE_CYCLES     : integer := (CLK_FREQ_HZ / 1000000) * TRIG_PULSE_US;

    constant MEASURE_PERIOD_MS     : integer := 60;
    constant MEASURE_PERIOD_CYCLES : integer := (CLK_FREQ_HZ / 1000) * MEASURE_PERIOD_MS;

    constant CYCLES_PER_CM         : integer := ( (CLK_FREQ_HZ / 1_000_000) * 58 ) + ( ((CLK_FREQ_HZ mod 1_000_000) * 58 + 500_000) / 1_000_000 );
    constant MAX_DISTANCE_CM       : integer := 400;

    type state_t is (IDLE, TRIG_PULSE, WAIT_ECHO, MEASURE_ECHO, WAIT_BETWEEN);
    signal state : state_t := IDLE;

    signal trig_r : std_logic := '0';

    signal trig_cnt   : unsigned(12 downto 0) := (others => '0');
    signal echo_cnt   : unsigned(21 downto 0) := (others => '0');
    signal period_cnt : unsigned(22 downto 0) := (others => '0');

    signal dist_r : unsigned(9 downto 0) := (others => '0');

    signal echo_ff1  : std_logic := '0';
    signal echo_ff2  : std_logic := '0';
    signal echo_prev : std_logic := '0';

    signal echo_rise : std_logic;
    signal echo_fall : std_logic;

    function sat_distance_cm(x : integer) return unsigned is
        variable y : integer := x;
    begin
        if y < 0 then
            y := 0;
        elsif y > MAX_DISTANCE_CM then
            y := 0;
        end if;
        return to_unsigned(y, 10);
    end function;

begin

    trig    <= trig_r;
    Dist_cm <= std_logic_vector(dist_r);

    echo_rise <= '1' when (echo_prev = '0' and echo_ff2 = '1') else '0';
    echo_fall <= '1' when (echo_prev = '1' and echo_ff2 = '0') else '0';

    process (clk, Rst_n)
        variable dist_i : integer;
    begin
        if Rst_n = '0' then
            state      <= IDLE;
            trig_r     <= '0';

            trig_cnt   <= (others => '0');
            echo_cnt   <= (others => '0');
            period_cnt <= (others => '0');

            dist_r     <= (others => '0');

            echo_ff1   <= '0';
            echo_ff2   <= '0';
            echo_prev  <= '0';

        elsif rising_edge(clk) then
            echo_ff1  <= echo;
            echo_ff2  <= echo_ff1;
            echo_prev <= echo_ff2;

            case state is

                when IDLE =>
                    trig_r     <= '0';
                    trig_cnt   <= (others => '0');
                    echo_cnt   <= (others => '0');
                    period_cnt <= (others => '0');
                    state      <= TRIG_PULSE;

                when TRIG_PULSE =>
                    trig_r <= '1';

                    if trig_cnt = to_unsigned(TRIG_PULSE_CYCLES - 1, trig_cnt'length) then
                        trig_r   <= '0';
                        trig_cnt <= (others => '0');
                        state    <= WAIT_ECHO;
                    else
                        trig_cnt <= trig_cnt + 1;
                    end if;

                when WAIT_ECHO =>
                    if echo_rise = '1' then
                        echo_cnt <= (others => '0');
                        state    <= MEASURE_ECHO;
                    end if;

                when MEASURE_ECHO =>
                    if echo_ff2 = '1' then
                        echo_cnt <= echo_cnt + 1;
                    end if;

                    if echo_fall = '1' then
                        dist_i := (to_integer(echo_cnt) + (CYCLES_PER_CM / 2)) / CYCLES_PER_CM;
                        dist_r <= sat_distance_cm(dist_i);
                        period_cnt <= (others => '0');
                        state <= WAIT_BETWEEN;
                    end if;

                when WAIT_BETWEEN =>
                    if period_cnt = to_unsigned(MEASURE_PERIOD_CYCLES - 1, period_cnt'length) then
                        period_cnt <= (others => '0');
                        state <= TRIG_PULSE;
                    else
                        period_cnt <= period_cnt + 1;
                    end if;

            end case;
        end if;
    end process;

end architecture Behavioral;