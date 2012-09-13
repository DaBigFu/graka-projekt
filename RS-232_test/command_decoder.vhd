-- dedoces commands passes data on
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.graka_pack.all;

entity command_decoder is
    generic (data_width : integer := 8
    );

    port (
        clk            : in std_logic;
        data_in     : in std_logic_vector(data_width-1 downto 0);
        data_out : out std_logic_vector(data_width-1 downto 0);
        TX_start : out std_logic;
        reset          : in std_logic;
        rx_busy     : in std_logic;
        tx_busy     : in std_logic
    );
end entity command_decoder;

architecture beh of command_decoder is

    -- interne States
    type states is (s_wait_for_com, s_com_check, s_data_transfer, s_transmit_response);
    signal current_state, next_state : states := s_wait_for_com;

     --interne Signale
    signal   decoded_com : t_rec_com := unidentified;
    signal  rx_busy_last : std_logic := '0';

begin

    --------------------------------------------------------------------
    --------------------------------------------------------------------
    --------------------------------------------------------------------
    next_state_register : process(clk, reset, next_state)
    begin
        if (reset = '0') then
            current_state <= s_wait_for_com;
        elsif (clk'EVENT and clk = '1') then
            current_state <= next_state;
        end if;
    end process next_state_register;


    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    next_state_logic : process (current_state, rx_busy, rx_busy_last)
    begin
        case current_state is
            when s_wait_for_com =>
                if rx_busy = '0' and rx_busy_last = '1' then
                    next_state <= s_transmit_response;
                else
                    next_state <= s_wait_for_com;
                end if;

                rx_busy_last <= rx_busy;

            when s_transmit_response =>
                next_state <= s_transmit_response;

            when others =>
                next_state <= s_wait_for_com;

        end case;
    end process next_state_logic;


    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    output_logic : process (clk, reset, current_state)

    begin
        if (reset = '0') then
            TX_start <= '0';

        elsif (clk'EVENT and clk = '1') then
            case current_state is
                when s_wait_for_com =>
                    TX_start <= '0';
                when s_transmit_response =>
                    TX_start <= '0';
                when others =>

            end case;
        end if;



    end process output_logic;





end beh;
