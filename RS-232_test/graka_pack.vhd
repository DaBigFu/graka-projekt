-- Christoph Paa

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

package graka_pack is

--###########################################################################
--constants
constant c_COM_LENGTH : integer range 0 to 16 := 8;

--###########################################################################
--types
type t_rx_com is (rec_pic, end_pic, check_com, unidentified);
type t_tx_com is (board_ack, end_of_block, unidentified);
type t_command_array is ARRAY(0 to 2) of std_logic_vector(c_COM_LENGTH-1 downto 0);
type t_rec_buff is ARRAY(0 to 255) of std_logic_vector(11 downto 0);

--###########################################################################
--constants
constant c_rx_com_arr : t_command_array := (x"02", x"03",x"05");
constant c_tx_com_arr : t_command_array := (x"06", x"17", x"00");


--###########################################################################
--functions
function get_tx_command(com_in : t_tx_com) return STD_LOGIC_VECTOR;

function get_rx_command(com_in : STD_LOGIC_VECTOR(c_COM_LENGTH-1 downto 0)) return t_rx_com;

end package graka_pack;

package body graka_pack is

function get_tx_command(com_in : t_tx_com) return STD_LOGIC_VECTOR is
	begin
		return c_tx_com_arr(t_tx_com'POS(com_in));
end function get_tx_command;

function get_rx_command(com_in : STD_LOGIC_VECTOR(c_COM_LENGTH-1 downto 0)) return t_rx_com is
	begin
		case com_in is
			when c_rx_com_arr(0) =>
				return t_rx_com'VAL(0);
			when c_rx_com_arr(1) =>
				return t_rx_com'VAL(1);
			when c_rx_com_arr(2) =>
				return t_rx_com'VAL(2);
			when others =>
				return t_rx_com'right;
		end case;
end function get_rx_command;
				


end package body graka_pack;