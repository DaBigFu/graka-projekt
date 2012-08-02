LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY SDRAM_tb IS
END ENTITY SDRAM_tb;

ARCHITECTURE stimulus OF SDRAM_tb IS
--Komponente Zaehlertest deklarieren
COMPONENT SDRAMcontroller
PORT(
		clk, reset:	IN STD_LOGIC;
		Vcnt:			IN STD_LOGIC_VECTOR(9 downto 0);
		Hcnt: 		IN STD_LOGIC_VECTOR(10 downto 0);
		
		DRAM_DQ:		INOUT STD_LOGIC_VECTOR(15 downto 0);
		
		DRAM_ADDR:	OUT STD_LOGIC_VECTOR(12 downto 0);
		BA:			OUT STD_LOGIC_VECTOR(1 downto 0);
		LDQM, UDQM, nWE, nCAS, nRAS, nCS, nCKE:			OUT STD_LOGIC;
		pixel:		OUT STD_LOGIC_VECTOR(15 downto 0)
		);
END COMPONENT;

--interne Signale deklarieren
	CONSTANT period: TIME := 20 ns;
	SIGNAL clk: 	STD_LOGIC:='1';
	SIGNAL reset:	STD_LOGIC := '1';
	SIGNAL Vcnt:	STD_LOGIC_VECTOR(9 downto 0) := "0000000000";
	SIGNAL Hcnt: 	STD_LOGIC_VECTOR(10 downto 0) := "00000000000";
	SIGNAL DRAM_DQ: STD_LOGIC_VECTOR(15 downto 0) := "0000000000000000";
	SIGNAL DRAM_ADDR:	STD_LOGIC_VECTOR(12 downto 0) := "0000000000000";
	SIGNAL BA:			STD_LOGIC_VECTOR(1 downto 0) := "00";
	SIGNAL LDQM, UDQM, nWE, nCAS, nRAS, nCS, nCKE: STD_LOGIC := '0';
	SIGNAL pixel:		STD_LOGIC_VECTOR(15 downto 0) := "0000000000000000";	
	
BEGIN
	DUT: SDRAMcontroller
		PORT MAP(clk, reset, Vcnt, Hcnt, DRAM_DQ, DRAM_ADDR, BA, LDQM, UDQM, nWE, nCAS, nRAS, nCS, nCKE, pixel);
		
	generate_clock: PROCESS (clk)
	BEGIN
		clk <= NOT clk AFTER period/2;
	END PROCESS;
		
		reset <= '0', '1' AFTER 10 ns;
		
END ARCHITECTURE stimulus;