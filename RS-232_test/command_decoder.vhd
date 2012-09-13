-- dedoces commands passes data on
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.graka_pack.all;

entity command_decoder is
    generic (data_width : integer := 8
    );

    port (
        clk          : in std_logic;
        data_in     	: in std_logic_vector(data_width-1 downto 0);
        data_out 		: out std_logic_vector(data_width-1 downto 0);
        TX_start 		: out std_logic;
        reset        : in std_logic;
        rx_busy     	: in std_logic;
        tx_busy     	: in std_logic
    );
end entity command_decoder;

architecture beh of command_decoder is

    -- interne States
    type states is (s_wait_for_com, s_com_check, s_data_transfer, s_transmit_response, s_wait_for_tx);
    signal current_state, next_state : states := s_wait_for_com;

     --interne Signale
    signal   decoded_com : t_rec_com := unidentified;
    signal  rx_busy_last : std_logic := '0';

begin

    --------------------------------------------------------------------
    --------------------------------------------------------------------
    --------------------------------------------------------------------
    next_state_register : process(clk, reset)
    begin
        if (reset = '1') then
            current_state <= s_wait_for_com;
        elsif (clk'EVENT and clk = '1') then
            current_state <= next_state;
        end if;
    end process next_state_register;


    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
   next_state_logic : process (current_state, rx_busy, data_in, tx_busy)
   begin
		if clk'event and clk = '1' then
        case current_state is
            when s_wait_for_com =>
					 if rx_busy = '1' then
					 rx_busy_last <= '1';
					 next_state <= s_wait_for_com;
                elsif rx_busy = '0' and rx_busy_last = '1' AND data_in = x"05" then
							decoded_com <= check_com;
							next_state <= s_transmit_response;
							rx_busy_last <= '0';
                else
                    next_state <= s_wait_for_com;
                end if;

				when s_transmit_response =>
               next_state <= s_wait_for_tx;
					
				when s_wait_for_tx =>
					if tx_busy = '1' then
						next_state <= s_wait_for_tx;
					else
						next_state <= s_wait_for_com;
					end if;

            when others =>
                next_state <= s_wait_for_com;

        end case;
		  end if;
    end process next_state_logic;


    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
   output_logic : process (current_state)
	
   begin
	TX_start <= '0';
		case current_state is
			when s_wait_for_com =>
				data_out <= x"00";
				TX_start <= '0';
				
         when s_transmit_response =>
				data_out <= x"06";
				TX_start <= '1';
         when others =>

            end case;
    end process output_logic;





end beh;
