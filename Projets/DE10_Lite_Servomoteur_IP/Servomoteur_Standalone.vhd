library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Servomoteur_Standalone is
    Port (
        CLOCK_50 : in  std_logic;
        SW       : in  std_logic_vector(9 downto 0);
        SERVO_PWM : out std_logic        -- este é o sinal que você liga no pino V10
    );
end Servomoteur_Standalone;

architecture Behavioral of Servomoteur_Standalone is

    signal servo_pwm_sig : std_logic;

    component Servomoteur_IP
        Port (
            clk      : in  std_logic;
            Rst_n    : in  std_logic;
            position : in  std_logic_vector(9 downto 0);
            commande : out std_logic
        );
    end component;

begin

    ServoCore : Servomoteur_IP
        port map(
            clk      => CLOCK_50,
            Rst_n    => '1',
            position => SW,
            commande => servo_pwm_sig
        );

    SERVO_PWM <= servo_pwm_sig;

end Behavioral;
