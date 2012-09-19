library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.graka_pack.all;

entity dbg_decoder is
port(
dbg_state		: in integer range 0 to 15;
dbg_page_count : in integer range 0 to 1874;
dbg_byte_count : in integer range 0 to 255;
dbg_cyc_count  : in std_logic_vector(27 downto 0);
dbg_refresh_cyc: in std_logic_vector(15 downto 0);

switch : in std_logic_vector(1 downto 0);

hex : out std_logic_vector(15 downto 0)
);

end entity dbg_decoder;

architecture beh of dbg_decoder is
begin
with switch select
	hex <= std_logic_vector( to_unsigned(dbg_state,4) ) & "0000" & std_logic_vector( to_unsigned(dbg_byte_count,8) ) when "00",
			 std_logic_vector( to_unsigned(dbg_state,4) ) & '0' & std_logic_vector( to_unsigned(dbg_page_count,11) ) when "01",
			 dbg_cyc_count(27 downto 12) when "10",
			 dbg_refresh_cyc when "11";
			 
end architecture beh;