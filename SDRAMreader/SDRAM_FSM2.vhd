LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY SDRAM_FSM2 IS

	PORT(
		Clk, Reset, X0, X1: IN STD_LOGIC;
		Z0, Z1: OUT STD_LOGIC
	);
	
END ENTITY SDRAM_FSM2;

ARCHITECTURE beh OF SDRAM_FSM2 IS
	
	TYPE states IS (s0,s1,s2,s3);
	SIGNAL current_state, next_state: states;
	
	BEGIN
	
		next_state_register: PROCESS(Clk, Reset)
		BEGIN
			IF (Reset='1') THEN
				current_state<=s0;
			ELSIF (Clk'EVENT AND Clk='1') THEN
				current_state <= next_state;
			END IF;
		END PROCESS next_state_register;
		
	next_state_logic: PROCESS (X0, X1, current_state)
	BEGIN
		CASE current_state IS
			WHEN S0 =>
				IF (X0='1') THEN
					next_state<=s1;
				ELSIF (X1='1') THEN
					next_state <= s2;
				ELSE
					next_state <= s0;
				END IF;
			WHEN s1 =>
				IF X0='1' THEN
					next_state <= s2;
				ELSIF X1='1' THEN
					next_state<=s3;
				ELSE
					next_state <= s1;
				END IF;
			WHEN s2 =>
				next_state <= s0;
				
			WHEN s3 =>
				IF X0='1' THEN
					next_state <=s2;
				ELSIF X1='1' AND X0='0' THEN
					next_state <= s0;
				ELSE
					next_state <= s3;
				END IF;
			
			
			WHEN OTHERS =>
				next_state<=s0;
		END CASE;
	END PROCESS next_state_logic;
	
	output_logic: PROCESS (current_state)
	BEGIN
		Z0 <= '0';
		Z1 <= '0';
		
		CASE current_state IS
			WHEN s1=>
				Z0 <='1';
			WHEN s2=>
				Z1<='1';
			WHEN s3=>
				Z0<='1';
				Z1<='1';
			WHEN OTHERS =>
				NULL;
		END CASE;
	END PROCESS output_logic;
	
END beh;