--SDRAM controller als FSM realisiert
--beschreibt den RAM mit einem Testbild und zeigt dieses anschließend an
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SDRAM_FSM5 is

    port(
        clk, reset                 : in STD_LOGIC;
        Vcnt                       : in STD_LOGIC_VECTOR(9 downto 0);
        Hcnt                       : in STD_LOGIC_VECTOR(10 downto 0);
        DRAM_DQ                    : inout STD_LOGIC_VECTOR(15 downto 0);
        DRAM_ADDR                  : out STD_LOGIC_VECTOR(12 downto 0);
        BA, DQM                    : out STD_LOGIC_VECTOR(1 downto 0);
        nWE, nCAS, nRAS, nCS, nCKE : out STD_LOGIC;
        pixel                      : out STD_LOGIC_VECTOR(15 downto 0)
    );

end entity SDRAM_FSM5;

architecture beh of SDRAM_FSM5 is

    -- interne States
    type states is (s_init, s_idle, s_rd, s_wr);
    signal current_state, next_state : states;

     --interne Signale fuer Ausgangspins
    signal   iDQ                   : STD_LOGIC_VECTOR(15 downto 0) := "ZZZZZZZZZZZZZZZZ";
    signal   iADDR                 : STD_LOGIC_VECTOR(12 downto 0) := "0000000000000";
    signal   iBA, iDQM             : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal   iWE, iCAS, iRAS, iCKE : STD_LOGIC := '0';
    signal   iCS                   : STD_LOGIC := '1';
    signal   ipixel                : STD_LOGIC_VECTOR(15 downto 0) := x"0000";

    -- Buffer fuer 8 Zeilen des anzuzeigenden Bildes
    type pic_array is array (0 to 799) of std_logic_vector(11 downto 0);
    signal pic_buf0, pic_buf1, pic_buf2, pic_buf3, pic_buf4, pic_buf5, pic_buf6, pic_buf7 : pic_array ;

    --iterne Signale fuer Kommunikation zwischen den Prozessen
    signal  initialized, rd_done, rd_req, wr_done : STD_LOGIC := '0';
    signal buf_y                         : STD_LOGIC_VECTOR(9 downto 0) := "0000000111"; --speichert global die Nummer der letzten gepufferten Bildzeile

    --attribute ramstyle        : string;
    --attribute ramstyle of beh : architecture is "M9K";

begin

    --------------------------------------------------------------------
    --------------------------------------------------------------------
    --------------------------------------------------------------------
    next_state_register : process(clk, reset, next_state)
    begin
        if (reset = '0') then
            current_state <= s_init;
        elsif (clk'EVENT and clk = '1') then
            current_state <= next_state;
        end if;
    end process next_state_register;


    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    next_state_logic : process (current_state, rd_req, rd_done, wr_done, initialized)
    begin
        case current_state is
            when s_init =>
                if initialized = '1' then
                    next_state <= s_wr;
                else
                    next_state <= s_init;
                end if;
					 
				when s_wr =>
					if wr_done='1' then
						next_state<=s_idle;
					else
						next_state<=s_wr;
					END IF;

            when s_idle =>
                if  rd_req = '1' then
                    next_state <= s_rd;
                else
                    next_state <= s_idle;
                end if;

            when s_rd =>
                if rd_done = '1' then
                    next_state <= s_idle;
                else
                    next_state <= s_rd;
                end if;

            when others =>
                next_state <= s_init;
        end case;
    end process next_state_logic;


    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    output_logic : process (clk, reset, current_state, iDQ, iADDR, iBA, iDQM, iWE, iCAS, iRAS, iCKE, iCS, buf_y)

        variable cnt1             : integer range 0 to 32767 := 0;
        variable cnt2             : integer range 0 to 4 := 0;
        variable init             : integer range 0 to 15 := 0;
        variable pic_y            : integer range 0 to 1023 := 0;
        variable pic_x            : integer range 0 to 2047 := 0;
        variable bf_y             : integer range 0 to 1023 := 7; --speichert letzten Zeile des picture arrays zum Vergleich mit VGA-Modul
        variable pic_cnt, cyc_cnt : integer range 0 to 127 := 0;
        variable rd_cnt           : integer range 0 to 31 := 0;
        variable color            : integer range 0 to 4095 := 3456;
        variable row              : integer range 0 to 2047 := 25;
        variable rd, wr               : integer range 0 to 15 := 0;
        variable array_x          : integer range 0 to 1023 := 0;
        variable array_y          : integer range 0 to 7 := 0;
        variable cnt3             : integer range 0 to 511 := 0;
        variable row2: integer range 0 to 2047 := 0;

    begin
        if (reset = '0') then
            iDQ   <= "ZZZZZZZZZZZZZZZZ";
            iADDR <= "0000000000000";
            iBA   <= "00";
            iDQM  <= "00";
            iWE   <= '0';
            iCAS  <= '0';
            iRAS  <= '0';
            iCKE  <= '0';
            iCS   <= '1';
            buf_y <= "0000000111";

            initialized <= '0';
            rd_req      <= '0';
            rd_done     <= '0';

            cnt1    := 0;
            cnt2    := 0;
            init    := 0;
            bf_y    := 7;
            pic_cnt := 0;
            cyc_cnt := 0;
            rd_cnt  := 0;
            color   := 0;
            row     := 25;
            rd      := 0;
            array_x := 0;
            array_y := 0;
            cnt3    := 0;
            wr:= 0;
            row:=0;

        elsif (clk'EVENT and clk = '1') then
            case current_state is

                ---------------------------------------------------------------------------------------------------------------------------------------------------
                -- Initialisierung --------------------------------------------------------------------------------------------------------------------------------
                -- Durchlaeuft die Initialisierungssequenz laut Datenblatt und wechselt anschliessend in den Zustand s_idle ---------------------------------------
                --------------------------------------------------------------------------------------------------------------------------------------------------- 
                when s_init =>
                    DRAM_DQ <= "ZZZZZZZZZZZZZZZZ";

                    if init = 0 then          --power-up
                        iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '1'; iRAS <= '0'; iCAS <= '0'; iWE <= '0';
                        if cnt1 < 20000 then  --200us delay
                            cnt1 := cnt1+1;
                        else
                            cnt1 := 0;
                            init := init+1;
                        end if;

                    elsif init = 1 then         --PALL
                        iADDR <= "0010000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                        init := init+1;

                    elsif init = 2 then         --tRP
                        iCS <= '1';
                        if cnt2 < 1 then
                            cnt2 := cnt2+1;
                        else
                            init := init+1;
                            cnt2 := 0;
                        end if;

                    elsif init = 3 then         --REF1
                        iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '0'; iWE <= '1';
                        init := init+1;

                    elsif init = 4 then         --tARFC1
                        iCS <= '1';
                        if cnt2 < 5 then
                            cnt2 := cnt2+1;
                        else
                            cnt2 := 0;
                            init := init+1;
                        end if;

                    elsif init = 5 then         --REF2
                        iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '0'; iWE <= '1';
                        init := init+1;

                    elsif init = 6 then         --tARFC2
                        iCS <= '1';
                        if cnt2 < 5 then
                            cnt2 := cnt2+1;
                        else
                            cnt2 := 0;
                            init := init+1;
                        end if;

                    elsif init = 7 then         --MRS
                        iADDR <= "0000000100111"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '0'; iWE <= '0';
                        init := init+1;

                    elsif init = 8 then         --tMRD
                        iCS <= '1';
                        if cnt2 < 1 then
                            cnt2 := cnt2+1;
                        else
                            cnt2 := 0;
                            init := init+1;
                        end if;

                    elsif init = 9 then           --initialized
                        initialized <= '1';

                    else
                        init := 0;

                    end if;


                ---------------------------------------------------------------------------------------------------------------------------------------------------
                -- Write ------------------------------------------------------------------------------------------------------------------------------------------
                -- beschreibt den Speicher mit 120 Zeilen weiss (FFFF), schwarz (0000), rot (0F00), gruen (00F0), blau (000F) -------------------------------------
                ---------------------------------------------------------------------------------------------------------------------------------------------------
                when s_wr =>
                    IF wr = 0 THEN          --bank active
                        iADDR <= std_logic_vector(to_unsigned(row2, iADDR'length)); iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                        wr := wr+1;
                        
                    elsif wr = 1 then       --tRCD
                        iCS <= '1';
                        if cnt2 < 1 then
                            cnt2 := cnt2+1;
                        else
                            cnt2 := 0;
                            wr   := wr+1;
                        end if;
                        
                    elsif wr = 2 then       --write
                        iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '0';
                        IF row2<375 THEN
                            iDQ<=x"FFFF";
                        ELSIF row2>374 AND row2<750 THEN
                            iDQ<=x"0000";
                        ELSIF row2>749 AND row2<1125 THEN
                            iDQ<=x"0F00";
                        ELSIF row2>1124 AND row2<1500 THEN
                            iDQ<=x"00F0";
                        ELSE
                            iDQ<=x"000F";
                        END IF;
                        DRAM_DQ<=iDQ;
                        cnt3:=1;
                        wr:=wr+1;
                                               
                        
                    elsif wr = 3 then       --write die restlichen 255 words
                        iCS<='1';
                        IF cnt3<255 THEN
                            IF row2<375 THEN
                                iDQ<=x"FFFF";
                            ELSIF row2>374 AND row2<750 THEN
                                iDQ<=x"0000";
                            ELSIF row2>749 AND row2<1125 THEN
                                iDQ<=x"0F00";
                            ELSIF row2>1124 AND row2<1500 THEN
                                iDQ<=x"00F0";
                            ELSE
                                iDQ<=x"000F";
                            END IF;
                            DRAM_DQ<=iDQ;
                            cnt3:=cnt3+1;
                        ELSE
                            cnt3:=0;
                            wr:=wr+1;
                        END IF;
                        
                    elsif wr = 4 then       --tRDL
                        IF cnt3<1 THEN
                            cnt3:=cnt3+1;
                        ELSE
                            cnt3:=0;
                            wr:=wr+1;
                        END IF;
                        
                    elsif wr = 5 then       --precharge
                        iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                        wr := wr+1;
                        
                    elsif wr = 6 then       --tRP
                        iCS <= '1';
                        if cnt2 < 1 then
                            cnt2 := cnt2+1;
                        else
                            row2:=row2+1;
                            IF row2 = 1875 THEN
                                wr:=0;
                                wr_done<='1';
                            ELSE
                                wr:=0;
                            END IF;
                            
                            cnt2:=0;
                        end if;
                        
                    ELSE
                        wr:=0;
                        
                    END IF;
                    
                    
                ---------------------------------------------------------------------------------------------------------------------------------------------------
                -- Idle -------------------------------------------------------------------------------------------------------------------------------------------
                -- Wartet darauf, dass das VGA-Modul anfaengt die letzte gepufferte Zeile zu lesen und wechselt dann in den Zustand s_rd ------------------------
                --------------------------------------------------------------------------------------------------------------------------------------------------- 
                when s_idle =>
                    rd_done <= '0';
                    iADDR   <= "1111111111111"; iBA <= "11"; iDQM <= "11"; iCKE <= '1'; iCS <= '1'; iRAS <= '1'; iCAS <= '1'; iWE <= '1'; --alles auf High, kein Befehl ausfuehren

                    pic_x := to_integer(unsigned(Hcnt(10 downto 0)));
                    pic_y := to_integer(unsigned(Vcnt(9 downto 0)));
                    bf_y  := to_integer(unsigned(buf_y(9 downto 0)));

                    if pic_x = 1 and bf_y = pic_y then          --wenn VGA-Modul anfaengt die letzten gepufferte Zeile zu lesen
                        rd_req <= '1';
                    end if;


                ---------------------------------------------------------------------------------------------------------------------------------------------------
                -- rd 8 y-lines ---------------------------------------------------------------------------------------------------------------------------------
                -- fuehrt 25 full page rds durch, um 8 Zeilen des displays zu puffern ---------------------------------------------------------------------------
                --------------------------------------------------------------------------------------------------------------------------------------------------- 
                when s_rd =>
                    rd_req  <= '0';
                    DRAM_DQ <= "ZZZZZZZZZZZZZZZZ";
                    bf_y := to_integer(unsigned(buf_y(9 downto 0)));

                    if rd_cnt < 25 then           --fuehrt 25 full page rds durch
                        if rd = 0 then              --Bank Active (ACT) + row auf adresspin
                            iADDR <= std_logic_vector(to_unsigned(row, iADDR'length)); iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                            rd := rd+1;

                        elsif rd = 1 then           --tRCD
                            iCS <= '1';
                            if cnt2 < 1 then
                                cnt2 := cnt2+1;
                            else
                                cnt2 := 0;
                                rd   := rd+1;
                            end if;

                        elsif rd = 2 then           --rd  w/o precharge command + column auf Adresspin
                            iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '1';
                            rd := rd+1;

                        elsif rd = 3 then           --CAS latency
                            iCS <= '1';
                            if cnt2 < 1 then
                                cnt2 := cnt2+1;
                            else
                                rd   := rd+1;
                                cnt2 := 0;
                            end if;

                        elsif rd = 4 then           --einlesen der naechsten 256 Werte auf dem DQ-Bus
                            if cnt3 < 256 then
                                if array_y = 0 then
                                    pic_buf0(array_x) <= DRAM_DQ(11 downto 0);
                                elsif array_y = 1 then
                                    pic_buf1(array_x) <= DRAM_DQ(11 downto 0);
                                elsif array_y = 2 then
                                    pic_buf2(array_x) <= DRAM_DQ(11 downto 0);
                                elsif array_y = 3 then
                                    pic_buf3(array_x) <= DRAM_DQ(11 downto 0);
                                elsif array_y = 4 then
                                    pic_buf4(array_x) <= DRAM_DQ(11 downto 0);
                                elsif array_y = 5 then
                                    pic_buf5(array_x) <= DRAM_DQ(11 downto 0);
                                elsif array_y = 6 then
                                    pic_buf6(array_x) <= DRAM_DQ(11 downto 0);
                                else
                                    pic_buf7(array_x) <= DRAM_DQ(11 downto 0);
                                end if;

                                array_x := array_x+1;
                                if array_x > 799 then
                                    array_x := 0;
                                    array_y := array_y+1;
                                end if;
                                cnt3 := cnt3+1;
                            else
                                rd   := rd+1;
                                cnt3 := 0;
                            end if;


                        elsif rd = 5 then         --precharge
                            iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            rd := rd+1;

                        elsif rd = 6 then         --trp
                            iCS <= '1';
                            if cnt2 < 1 then
                                cnt2 := cnt2+1;
                            else
                                rd_cnt := rd_cnt+1;
                                row    := row+1;
                                if row > 1874 then
                                    row := 0;
                                end if;
                                rd   := 0;
                                cnt2 := 0;
                            end if;
                        else
                            rd := 0;
                        end if;

                    else
                        array_x := 0;
                        array_y := 0;


                        bf_y := bf_y+8;            --nach 25 rds ist die naechste Startzeile 8 Zeilen weiter
                        if bf_y > 599 then         --falls ausserhalb des darstellbaren Bereichs, fangen wir wieder bi 7 an
                            bf_y := 7;
                        end if;

                        buf_y <= std_logic_vector(to_unsigned(bf_y, buf_y'length)); --wird weiter an globalen Speicher gegeben
                        rd_cnt := 0;
                        rd_done <= '1';                                             --wieder in den Zustand s_idle versetzen
                    end if;



                when others =>
                    null;
            end case;
        end if;

        DRAM_ADDR <= iADDR;
        BA        <= iBA;
        DQM       <= iDQM;
        nWE       <= iWE;
        nCAS      <= iCAS;
        nRAS      <= iRAS;
        nCKE      <= iCKE;
        nCS       <= iCS;

    end process output_logic;


    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    VGA_out : process (clk, reset, current_state,ipixel)

        variable cnt1  : integer range 0 to 150000000 := 0;
        variable pic_y : integer range 0 to 1023 := 0;
        variable pic_x : integer range 0 to 1023 := 0;
        variable bf_y  : integer range 0 to 1023 := 7;
        variable arr_y : integer range 0 to 7 := 0;

    begin
        if (reset = '0') then

            ipixel <= x"0000";

            cnt1 := 0;

        elsif (clk'EVENT and clk = '1') then
            case current_state is
                when s_init =>
                    ipixel <= x"FFFF";

                when s_idle =>
                    pic_x := to_integer(unsigned(Hcnt(9 downto 0)));
                    pic_y := to_integer(unsigned(Vcnt(9 downto 0)));
                    bf_y  := to_integer(unsigned(buf_y(9 downto 0)));

                    arr_y := (pic_y-bf_y);

                    if arr_y = 0 then
                        ipixel <= "0000" & pic_buf7(pic_x);
                    elsif arr_y = 1 then
                        ipixel <= "0000" & pic_buf6(pic_x);
                    elsif arr_y = 2 then
                        ipixel <= "0000" & pic_buf5(pic_x);
                    elsif arr_y = 3 then
                        ipixel <= "0000" & pic_buf4(pic_x);
                    elsif arr_y = 4 then
                        ipixel <= "0000" & pic_buf3(pic_x);
                    elsif arr_y = 5 then
                        ipixel <= "0000" & pic_buf2(pic_x);
                    elsif arr_y = 6 then
                        ipixel <= "0000" & pic_buf1(pic_x);
                    else
                        ipixel <= "0000" & pic_buf0(pic_x);
                    end if;

                when s_rd =>
                    pic_x := to_integer(unsigned(Hcnt(10 downto 0)));
                    pic_y := to_integer(unsigned(Vcnt(9 downto 0)));
                    bf_y  := to_integer(unsigned(buf_y(9 downto 0)));

                    arr_y := (pic_y-bf_y);

                    if arr_y = 0 then
                        ipixel <= "0000" & pic_buf7(pic_x);
                    elsif arr_y = 1 then
                        ipixel <= "0000" & pic_buf6(pic_x);
                    elsif arr_y = 2 then
                        ipixel <= "0000" & pic_buf5(pic_x);
                    elsif arr_y = 3 then
                        ipixel <= "0000" & pic_buf4(pic_x);
                    elsif arr_y = 4 then
                        ipixel <= "0000" & pic_buf3(pic_x);
                    elsif arr_y = 5 then
                        ipixel <= "0000" & pic_buf2(pic_x);
                    elsif arr_y = 6 then
                        ipixel <= "0000" & pic_buf1(pic_x);
                    else
                        ipixel <= "0000" & pic_buf0(pic_x);
                    end if;

                when others =>
                    null;
            end case;
        end if;

        pixel <= ipixel;

    end process VGA_out;


end beh;
