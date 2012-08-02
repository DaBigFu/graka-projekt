library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

ENTITY VGA IS
	PORT(
		clk, reset:							IN STD_LOGIC;
		pixel:								IN STD_LOGIC_VECTOR(15 downto 0);
		
		red_out, green_out, blue_out: OUT STD_LOGIC_VECTOR(3 downto 0);
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
		VARIABLE red, green, blue: integer range 0 to 15 := 0;
	
		BEGIN
			IF reset = '0' THEN
				red_out<="0000";
				green_out<="0000";
				blue_out<="0000";
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
				
				IF hcount<800 THEN
					red := to_integer(unsigned(pixel(11 downto 8)));
					green:= to_integer(unsigned(pixel(7 downto 4)));
					blue:= to_integer(unsigned(pixel(3 downto 0)));
					intHsync <= '0';
				ELSIF hcount>799 AND hcount<856 THEN 
					red := 0;
					green:= 0;
					blue:= 0;
					intHsync <= '0';
				ELSIF hcount>855 AND hcount<976 THEN 
					red := 0;
					green:= 0;
					blue:= 0;
					intHsync <= '1';
				ELSIF hcount>975 THEN
					red := 0;
					green:= 0;
					blue:= 0;
					intHsync <= '0';
				END IF;
				
				hcount:=hcount+1;
				
				--neue Zeile
				IF hcount>1039 THEN
					hcount:=0;
					vcount:=vcount+1;
				END IF;
				
				IF vcount<600 THEN
					intVsync<='0';
				ELSIF vcount>599 AND vcount<637 THEN
					red := 0;
					green:= 0;
					blue:= 0;
					intVsync<='0';
				ELSIF vcount>636 AND vcount<643 THEN
					red := 0;
					green:= 0;
					blue:= 0;
					intVsync<='1';
				ELSIF vcount>642 THEN
					red := 0;
					green:= 0;
					blue:= 0;
					intVsync<='0';
				END IF;
				
				IF vcount>665 THEN
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
				