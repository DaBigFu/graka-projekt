library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.graka_pack.all;

entity dbg_decoder is
port(
dbg_page_count : in integer range 0 to 1874;
dbg_byte_count : in integer range 0 to 255;

switch : in std_logic;

hex : out std_logic_vector(11 downto 0)
);

end entity dbg_decoder;

architecture beh of dbg_decoder is
begin
with switch select
	hex <= "0000" & std_logic_vector( to_unsigned(dbg_byte_count,8) ) when '0',
			 '0' & std_logic_vector( to_unsigned(dbg_page_count,11) ) when '1';
			 
end architecture beh;