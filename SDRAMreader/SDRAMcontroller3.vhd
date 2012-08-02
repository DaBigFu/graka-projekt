---ließt 800*600 words aus SDRAM, puffert sie im FPGA, zeigt sie per VGA an.	-	geht nicht, zu wenig platz auf FPGA

--Takt: 50MHz
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

ENTITY SDRAMcontroller3 IS
	PORT(
		clk, reset:	IN STD_LOGIC;
		Vcnt:			IN STD_LOGIC_VECTOR(9 downto 0);
		Hcnt: 		IN STD_LOGIC_VECTOR(10 downto 0);
		
		DRAM_DQ:		INOUT STD_LOGIC_VECTOR(15 downto 0);
		
		DRAM_ADDR:	OUT STD_LOGIC_VECTOR(12 downto 0);
		BA:			OUT STD_LOGIC_VECTOR(1 downto 0);
		LDQM, UDQM, nWE, nCAS, nRAS, nCS, nCKE, status_LED:			OUT STD_LOGIC;
		pixel:		OUT STD_LOGIC_VECTOR(15 downto 0)
		);
END SDRAMcontroller3;

ARCHITECTURE beh of SDRAMcontroller3 IS

	TYPE pic_array IS ARRAY(0 to 31, 0 to 15) OF STD_LOGIC_VECTOR(11 downto 0);
	
	SIGNAL iDQ:		STD_LOGIC_VECTOR(15 downto 0) := "0000000000000000";
	SIGNAL iADDR:	STD_LOGIC_VECTOR(12 downto 0) := "0000000000000";
	SIGNAL iBA:		STD_LOGIC_VECTOR(1 downto 0) := "00";
	SIGNAL iLDQM, iUDQM, iWE, iCAS, iRAS, iCKE:	STD_LOGIC := '0';
	SIGNAL iCS:	STD_LOGIC := '1';
	SIGNAL ipixel:	STD_LOGIC_VECTOR(15 downto 0) := "0000000000000000";
	SIGNAL picture:	pic_array;
	SIGNAL iLED:	STD_LOGIC := '1';
	
	ATTRIBUTE ramstyle: string;
	ATTRIBUTE ramstyle OF beh : ARCHITECTURE IS "M9K";
	
BEGIN

	PROCESS(clk, reset, Vcnt, Hcnt, DRAM_DQ, iDQ, iADDR, iBA, iLDQM, iUDQM, iWE, iCAS, iRAS, iCS, iCKE, ipixel)
		
		VARIABLE poweredup:		integer range 0 to 1 := 0;
		VARIABLE initialized:	integer range 0 to 15 := 0;
		VARIABLE delay_cnt1:		integer range 0 to 3 := 0;
		VARIABLE init_cnt:		integer range 0 to 16383 := 0;
		VARIABLE read_state:		integer range 0 to 7 := 0;
		VARIABLE index:			integer range 0 to 255 := 0;
		VARIABLE column:			integer range 0 to 2047 := 0;
		VARIABLE	y,x,row:			integer range 0 to 1023 := 0;
		VARIABLE rd_cycles:		integer range 0 to 2047 := 0;
	
	BEGIN
		IF reset='0' THEN
			iDQ<= "0000000000000000";
			iADDR<= "0000000000000";
			iBA<= "00";
			iLDQM<='0';
			iUDQM<='0';
			iWE<='0';
			iCAS<='0';
			iRAS<='0';
			iCKE<= '0';
			iCS<= '1';
			ipixel<="0000000000000000";
			iLED<='1';
			
			poweredup:= 0;
			initialized:=0;
			delay_cnt1:=0;
			init_cnt:=0;
			read_state:=0;
			index:=0;
			x:=0;
			y:=0;
			rd_cycles:=0;
			row:=0;
			column:=0;
			
		ELSIF falling_edge(clk) THEN
			DRAM_DQ<="ZZZZZZZZZZZZZZZZ";
			-------- Power-up sequence -------------------
			IF poweredup=0 THEN
				iCKE<='1';
				iLDQM<='1';
				iUDQM<='1';
				poweredup:=1;
			END IF;
			
			-------- Initialization sequence -------------
			IF initialized = 0 AND poweredup=1 THEN	
				IF init_cnt<10000 THEN
					init_cnt:=init_cnt+1;	--200us delay
				ELSE
					init_cnt:=0;
					initialized:= 1;
				END IF;
				
			ELSIF initialized=1 THEN		--PALL
				iCKE<='1';
				iCS<='0';
				iRAS<='0';
				iCAS<='1';
				iWE<='0';
				iADDR(10)<='1';
				initialized:=initialized+1;
			
			ELSIF initialized=2 THEN		--tRP
				iCS<='1';
				initialized:=initialized+1;
				
			ELSIF initialized=3 THEN		--REF
				iCKE<='1';
				iCS<='0';
				iRAS<='0';
				iCAS<='0';
				iWE<='1';
				
				initialized:=initialized+1;
				
			ELSIF initialized=4 THEN		--tARFC
				iCS<='1';
				IF delay_cnt1<3 THEN			
					delay_cnt1:=delay_cnt1+1;
				ELSE
					delay_cnt1:=0;
					initialized:=initialized+1;
				END IF;
			
			ELSIF initialized=5 THEN		--REF2
				iCKE<='1';
				iCS<='0';
				iRAS<='0';
				iCAS<='0';
				iWE<='1';
				
				initialized:=initialized+1;
				
			ELSIF initialized=6 THEN		--tARFC2
				iCS<='1';
				IF delay_cnt1<3 THEN			
					delay_cnt1:=delay_cnt1+1;
				ELSE
					delay_cnt1:=0;
					initialized:=initialized+1;
				END IF;
			
			ELSIF initialized=7 THEN		--MRS
				iCKE<='1';
				iCS<='0';
				iRAS<='0';
				iCAS<='0';
				iWE<='0';
				iBA<="00";
				iADDR<="0000000100111";
				
				initialized:=initialized+1;
				
			ELSIF initialized=8 THEN		--tMRD
				iCS<='1';
				IF delay_cnt1<2 THEN			
					delay_cnt1:=delay_cnt1+1;
				ELSE
					delay_cnt1:=0;
					initialized:=initialized+1;
				END IF;
				
			ELSE
				initialized:=initialized;
					
			END IF;
			
			--------- Normalbetrieb ----------------------
			IF initialized=9 THEN
				IF rd_cycles<1875 THEN --1875 fullpage reads noetig um 800x600 bild einzulesen
					IF read_state=0 THEN				--ACT
					iCKE<='1';
					iCS<='0';
					iRAS<='0';
					iCAS<='1';
					iWE<='1';
					iBA<="00";
					iADDR<=std_logic_vector(to_unsigned(rd_cycles, iADDR'length)); --rd_cycles geben gleichzeitig row an.
					
					read_state:=read_state+1;
					
					ELSIF read_state=1 THEN			--tRCD
						iCS<='1';
						read_state:=read_state+1;
				
					ELSIF read_state=2 THEN			--Read without precharge
						iCKE<='1';
						iCS<='0';
						iRAS<='1';
						iCAS<='0';
						iWE<='1';
						iBA<="00";
						iADDR<="0000000000000";		--column=0
						iLDQM<='0';
						iUDQM<='0';
					
						read_state:=read_state+1;
				
					ELSIF read_state=3 THEN			--CAS latency = 2
						iCS<='1';
						read_state:=read_state+1;
					
					ELSIF read_state=4 THEN			--CAS latency = 2
						iCS<='1';
						read_state:=read_state+1;
						index:=0;
					
					ELSIF read_state=5 THEN			--full page read burst
						IF index<255 THEN
							picture(x,y)<=DRAM_DQ(11 downto 0);
							index:=index+1;
						ELSE
							picture(x,y)<=DRAM_DQ(11 downto 0);
							read_state:=read_state+1;
						END IF;
					
						x:=x+1;
						IF x>799 THEN
							x:=0;
							y:=y+1;
						END IF;
					
					ELSIF read_state=6 THEN			--precharge
						iUDQM<='1';
						iLDQM<='1';
						iCKE<='1';
						iCS<='0';
						iRAS<='0';
						iCAS<='1';
						iWE<='0';
						iBA<="00";
						iADDR<="0000000000000";		--column=0
					
						read_state:=read_state+1;
				
					ELSIF read_state=7 THEN			--tRP
						iCS<='0';
						rd_cycles:=rd_cycles+1;
						read_state:=0;					--wieder lesen
					
					
					ELSE
						read_state:=6;
					
					END IF;
				
				ELSE
					row:=to_integer(unsigned(Vcnt(9 downto 0)));
					column:=to_integer(unsigned(Hcnt(10 downto 0)));
					
					ipixel<="0000"&picture(column, row);
					
				END IF;
				
			END IF;
			
		END IF;
	
		--DRAM_DQ<=iDQ;
		DRAM_ADDR<=iADDR;
		BA<=iBA;
		LDQM<=iLDQM;
		UDQM<=iUDQM;
		nWE<=iWE;
		nCAS<=iCAS;
		nRAS<=iRAS;
		nCS<=iCS;
		nCKE<=iCKE;
		pixel<=ipixel;
		status_LED<=iLED;
		
	END PROCESS ;
		
	
	END beh;		
				