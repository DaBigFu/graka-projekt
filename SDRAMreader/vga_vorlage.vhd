library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

ENTITY VGA_vorlage IS
	PORT(
		clk:	IN STD_LOGIC;
		red_out, green_out, blue_out: OUT STD_LOGIC_VECTOR(3 downto 0);
		hsync, vsync:		OUT STD_LOGIC
		);
END VGA_vorlage;

ARCHITECTURE beh of VGA_vorlage IS

	SIGNAL intHsync, intVsync: STD_LOGIC := '0';
	SIGNAL row:	STD_LOGIC_VECTOR(9 downto 0);
	SIGNAL column: STD_LOGIC_VECTOR(10 downto 0);
	SIGNAL color:	STD_LOGIC_VECTOR(11 downto 0);
	
BEGIN

	drawing: PROCESS(clk, intHsync, intVsync, color, row, column)
	
		VARIABLE hcount:	integer range 0 to 2047 := 0;
		VARIABLE vcount:	integer range 0 to 1023 := 0;
		VARIABLE red, green, blue: integer range 0 to 15 := 0;
	
		BEGIN
			IF clk'EVENT AND clk='1' THEN
				
				IF hcount<800 THEN
					red := to_integer(unsigned(color(11 downto 8)));
					green:= to_integer(unsigned(color(7 downto 4)));
					blue:= to_integer(unsigned(color(3 downto 0)));
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
			column<=std_logic_vector(to_unsigned(hcount, column'length));
			row<=std_logic_vector(to_unsigned(vcount, row'length));
			hsync<=intHsync;
			vsync<=intVsync;
			
		END PROCESS drawing;
		
		
		picgen: PROCESS(clk, row, column, color, intVsync)
		
			VARIABLE col_int:				integer range 0 to 4095 := 0;
			VARIABLE hcount:				integer range 0 to 2047 := 0;
			VARIABLE green_left:			integer range 0 to 2047 := 0;
			VARIABLE green_right:		integer range 0 to 2047 := 50;
			VARIABLE vcount:				integer range 0 to 1023 := 0;
			VARIABLE red_high:			integer range 0 to 1023 := 0;
			VARIABLE red_low:				integer range 0 to 1023 := 50;
			VARIABLE newpic_appeared:	integer range 0 to 1 := 0;
		
			BEGIN
			
			IF clk'EVENT AND clk='1' THEN
			
				hcount:= to_integer(unsigned(column(10 downto 0)));
				vcount:= to_integer(unsigned(row(9 downto 0)));
				
				-- Farbausgabe
					--rote Linie
				IF vcount<(red_low - 1) AND vcount>(red_high + 1)  THEN				
					col_int:=2048;
				ELSIF red_low<red_high AND vcount>(red_high+1) THEN
					col_int:=2048;
				ELSIF red_low<red_high AND vcount<(red_low-1) THEN
					col_int:=2048;
				ELSE
					col_int:=0;
				END IF;
					--gruene Linie
				IF hcount<(green_right+1) AND hcount>(green_left - 1)  THEN				
					col_int:=col_int+128;
				ELSIF green_right<green_left AND hcount>(green_left-1) THEN
					col_int:=col_int+128;
				ELSIF green_right<green_left AND hcount<(green_right+1) THEN
					col_int:=col_int+128;
				END IF;		
				
				
				-- newpicture
				IF newpic_appeared=0 AND intVsync='1' THEN
					newpic_appeared:=1;
					red_low:=red_low+1;
					red_high:=red_high+1;
					green_left:=green_left+1;
					green_right:=green_right+1;
				ELSIF newpic_appeared=1 AND intVsync='0' THEN
					newpic_appeared:=0;
				END IF;
				
				IF red_low>599 THEN
					red_low:=0;
				END IF;
				IF red_high>599 THEN
					red_high:=0;
				END IF;
				IF green_left>799 THEN
					green_left:=0;
				END IF;
				IF green_right>799 THEN
					green_right:=0;
				END IF;
				
			END IF;
			
			color<=std_logic_vector(to_unsigned(col_int, color'length));
			
		END PROCESS picgen;	
		
		
		
	END beh;		
				