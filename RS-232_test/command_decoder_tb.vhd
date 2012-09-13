LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY command_decoder_tb IS
END ENTITY command_decoder_tb;
ARCHITECTURE stimulus OF command_decoder_tb IS


signal		clk		:  std_logic := '1' ;
signal		data_in	:  std_logic_vector(7 downto 0) := x"00";
signal		data_out :  std_logic_vector(7 downto 0);
signal		TX_start :  std_logic;
signal		reset		:  std_logic;
signal		rx_busy	:  std_logic := '0';
signal		tx_busy	:	std_logic;

CONSTANT period : TIME := 20 ns;
CONSTANT data_width : integer := 8;

COMPONENT command_decoder
	Port (
		clk		: in std_logic;
		data_in	: in std_logic_vector(data_width-1 downto 0);
		data_out : out std_logic_vector(data_width-1 downto 0);
		TX_start : out std_logic;
		reset		: in std_logic;
		rx_busy	: in std_logic;
		tx_busy	: in std_logic
	);
END COMPONENT command_decoder;

BEGIN
DUT : command_decoder PORT MAP (clk => clk, data_in => data_in, data_out => data_out, TX_start => TX_start, reset => reset, rx_busy => rx_busy, tx_busy => tx_busy);

generate_clock : PROCESS (clk)
	BEGIN
			clk <= NOT clk AFTER period/2;
	END PROCESS;
	
reset <= '1', '0' AFTER 60ns;


END ARCHITECTURE stimulus;