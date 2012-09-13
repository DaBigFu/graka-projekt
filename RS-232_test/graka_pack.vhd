-- Christoph Paa

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

package graka_pack is

--###########################################################################
--constants
constant c_COM_LENGTH : integer := 8;

--###########################################################################
--types
type t_rec_com is (start_text, end_text, check_com, unidentified);
type t_command_array is ARRAY(0 to 2) of std_logic_vector(c_COM_LENGTH-1 downto 0);

--###########################################################################
--constants
constant c_com_arr : t_command_array := (x"02", x"03",x"05");


--###########################################################################
--functions
function decode_command(com_in : STD_LOGIC_VECTOR(c_COM_LENGTH-1 downto 0)) return t_rec_com;

function get_command_data(com_req : t_rec_com) return STD_LOGIC_VECTOR;

end package graka_pack;

package body graka_pack is

function decode_command(com_in : STD_LOGIC_VECTOR(c_COM_LENGTH-1 downto 0)) return t_rec_com is
	begin		
			for i in 0 to c_com_arr'length-1 loop
				if com_in = c_com_arr(i) then
					return t_rec_com'val(i);
				end if;
			end loop;
			return t_rec_com'right;
end function decode_command;

function get_command_data(com_req : t_rec_com) return STD_LOGIC_VECTOR is
	begin
		return c_com_arr(t_rec_com'POS(com_req));
end function get_command_data;

end package body graka_pack;