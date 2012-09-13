-- dedoces commands passes data on
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graka_pack.all;

entity command_decoder is
	Generic (data_width : integer := 8
	);
	
	Port (
		clk		: in std_logic;
		data_in	: in std_logic_vector(data_width-1 downto 0);
		data_out : out std_logic_vector(data_width-1 downto 0);
		TX_start : out std_logic;
		reset		: in std_logic;
		rx_busy	: in std_logic;
		tx_busy	: in std_logic
	);
end entity command_decoder;

architecture beh of command_decoder is
type states is (s_wait_for_com, s_com_check, s_data_transfer, s_transmit_response);
signal current_state, next_state : states;
signal decoded_com : t_rec_com := unidentified;
signal rx_busy_last : std_logic := '0';
BEGIN

	next_state_register : PROCESS (clk, reset)
	BEGIN
		IF (Reset = '1') THEN
			current_state <= s_wait_for_com;
		ELSIF (clk'EVENT AND clk = '1') THEN
			current_state <= next_state;
		END IF;
	END PROCESS next_state_register;
				
	
	next_state_logc : PROCESS (current_state, rx_busy, data_in, rx_busy_last)
	BEGIN
		CASE current_state IS
			when s_wait_for_com =>
				if rx_busy = '0' AND rx_busy_last = '1' then
					if data_in = x"05" then
						decoded_com <= check_com;
					else
						decoded_com <= unidentified;
					end if;
					next_state <= s_transmit_response;
				else
					next_state <= s_wait_for_com;
				end if;
				rx_busy_last <= rx_busy;
				
			when s_transmit_response =>
				if tx_busy = '1' then
					next_state <= s_transmit_response;
				else
					next_state <= s_wait_for_com;
				end if;
				
			when others =>
		END CASE;
	END PROCESS next_state_logc;

	
	output_logic : PROCESS (current_state, decoded_com)
	BEGIN
	TX_start <= '0';
		CASE current_state IS
			WHEN s_transmit_response =>
				CASE decoded_com IS
					WHEN check_com =>
						data_out <= x"41";
						TX_start <= '1';
					WHEN others =>
				end CASE;	
				
			when others =>
		end case;
	end process output_logic;

end architecture beh;