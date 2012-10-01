LIBRARY ieee;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

ENTITY ss_decoder IS
    PORT
        (
        decin:     IN STD_LOGIC_VECTOR (3 downto 0);
        decout:     OUT STD_LOGIC_VECTOR (7 downto 0)
        );
END ENTITY ss_decoder;

ARCHITECTURE beh OF ss_decoder IS
    SIGNAL intout: STD_LOGIC_VECTOR (7 downto 0);
    
    BEGIN
    
    WITH decin SELECT
        intout <=     "11000000" WHEN "0000",--0
                        "11111001" WHEN "0001",--1
                        "10100100" WHEN "0010",--2
                        "10110000" WHEN "0011",--3
                        "10011001" WHEN "0100",--4
                        "10010010" WHEN "0101",--5
                        "10000010" WHEN "0110",--6
                        "11111000" WHEN "0111",--7
                        "10000000" WHEN "1000",--8
                        "10010000" WHEN "1001",--9
                        "10001000" WHEN "1010",--10A
                        "10000011" WHEN "1011",--11B
                        "11000110" WHEN "1100",--12C
                        "10100001" WHEN "1101",--13D
                        "10000110" WHEN "1110",--14E
                        "10001110" WHEN "1111",--15F
                        "11111111" WHEN OTHERS;


    decout <= intout;
    END beh;