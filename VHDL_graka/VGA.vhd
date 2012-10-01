library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

ENTITY VGA IS
	PORT(
		clk, reset:							IN STD_LOGIC;
		pixel:								IN STD_LOGIC_VECTOR(23 downto 0);
		
		red_out, green_out, blue_out: OUT STD_LOGIC_VECTOR(7 downto 0);
		hsync, vsync:						OUT STD_LOGIC;
		Vcnt:									OUT STD_LOGIC_VECTOR(9 downto 0);
		Hcnt:									OUT STD_LOGIC_VECTOR(10 downto 0)
		);
END VGA;

ARCHITECTURE beh of VGA IS

	SIGNAL intHsync, intVsync: STD_LOGIC := '0';
	
BEGIN

	drawing: PROCESS(clk, reset, intHsync, intVsync, pixel)
	
		VARIABLE hcount:	integer range 0 to 2047 := 0;
		VARIABLE vcount:	integer range 0 to 1023 := 0;
		VARIABLE red, green, blue: integer range 0 to 255 := 0;
	
		BEGIN
			IF reset = '0' THEN
				red_out<=x"00";
				green_out<=x"00";
				blue_out<=x"00";
				hsync<='0';
				vsync<='0';
				Vcnt<="0000000000";
				Hcnt<="00000000000";
				hcount := 0;
				vcount := 0;
				red := 0;
				green := 0;
				blue := 0;
				intHsync <= '0';
				intVsync <= '0';
				
			ELSIF clk'EVENT AND clk='1' THEN
				
				IF hcount<1024 THEN
					red := to_integer(unsigned(pixel(23 downto 16)));
					green:= to_integer(unsigned(pixel(15 downto 8)));
					blue:= to_integer(unsigned(pixel(7 downto 0)));
					intHsync <= '0';
				ELSIF hcount>1023 AND hcount<1048 THEN 
					red := 0;
					green:= 0;
					blue:= 0;
					intHsync <= '0';
				ELSIF hcount>1047 AND hcount<1184 THEN 
					red := 0;
					green:= 0;
					blue:= 0;
					intHsync <= '1';
				ELSIF hcount>1183 THEN
					red := 0;
					green:= 0;
					blue:= 0;
					intHsync <= '0';
				END IF;
				
				hcount:=hcount+1;
				
				--neue Zeile
				IF hcount>1343 THEN
					hcount:=0;
					vcount:=vcount+1;
				END IF;
				
				IF vcount<768 THEN
					intVsync<='0';
				ELSIF vcount>767 AND vcount<771 THEN
					red := 0;
					green:= 0;
					blue:= 0;
					intVsync<='0';
				ELSIF vcount>770 AND vcount<777 THEN
					red := 0;
					green:= 0;
					blue:= 0;
					intVsync<='1';
				ELSIF vcount>776 THEN
					red := 0;
					green:= 0;
					blue:= 0;
					intVsync<='0';
				END IF;
				
				IF vcount>805 THEN
					vcount:=0;
				END IF;
			END IF;
			
			red_out<=std_logic_vector(to_unsigned(red, red_out'length));
			green_out<=std_logic_vector(to_unsigned(green, green_out'length));
			blue_out<=std_logic_vector(to_unsigned(blue, blue_out'length));
			Hcnt<=std_logic_vector(to_unsigned(hcount, Hcnt'length));
			Vcnt<=std_logic_vector(to_unsigned(vcount, Vcnt'length));
			hsync<=intHsync;
			vsync<=intVsync;
			
		END PROCESS drawing;		
	END beh;		
				