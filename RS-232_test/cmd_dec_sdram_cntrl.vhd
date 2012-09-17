--SDRAM controller als FSM realisiert
--schreibt das dekodierte Bild vom JPG-decoder in den RAM und zeigt es anschliessend an
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.graka_pack.all;

entity cmd_dec_sdram_cntrl is

    port(
        clk, reset                 : in STD_LOGIC;
        Vcnt                       : in STD_LOGIC_VECTOR(9 downto 0);
        Hcnt                       : in STD_LOGIC_VECTOR(10 downto 0);
        DRAM_DQ                    : inout STD_LOGIC_VECTOR(15 downto 0);
        DRAM_ADDR                  : out STD_LOGIC_VECTOR(12 downto 0);
        BA, DQM                    : out STD_LOGIC_VECTOR(1 downto 0);
        nWE, nCAS, nRAS, nCS, nCKE : out STD_LOGIC;
        pixel                      : out STD_LOGIC_VECTOR(15 downto 0);

        data_in  : in std_logic_vector(7 downto 0);
        data_out : out std_logic_vector(7 downto 0);
        TX_start : out std_logic;
        rx_busy  : in std_logic;
        tx_busy  : in std_logic;
		  
		  dbg_state : out STD_LOGIC_VECTOR(3 downto 0);
		  dbg_page_count : out integer range 0 to 1874;
		  dbg_byte_count : out integer range 0 to 255
		  
    );

end entity cmd_dec_sdram_cntrl;

architecture beh of cmd_dec_sdram_cntrl is

    -- interne States
    type states is (s_ram_init, s_ram_idle, s_ram_rd, s_ram_fullpagewrite, s_wait_for_com, s_transmit_response, s_wait_for_tx, s_receive_pic);
    signal current_state, next_state : states;

     --interne Signale fuer Ausgangspins
    --signal   iDQ                   : STD_LOGIC_VECTOR(15 downto 0) := "ZZZZZZZZZZZZZZZZ";
    signal   iADDR                 : STD_LOGIC_VECTOR(12 downto 0) := "0000000000000";
    signal   iBA, iDQM             : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal   iWE, iCAS, iRAS, iCKE : STD_LOGIC := '0';
    signal   iCS                   : STD_LOGIC := '1';
    signal   ipixel                : STD_LOGIC_VECTOR(15 downto 0) := x"0000";

    -- Buffer fuer 8 Zeilen des anzuzeigenden Bildes
    type pic_array is array (0 to 799) of std_logic_vector(11 downto 0);
    signal pic_buf0, pic_buf1, pic_buf2, pic_buf3, pic_buf4, pic_buf5, pic_buf6, pic_buf7 : pic_array ;

    --iterne Signale fuer Kommunikation zwischen den Prozessen
    signal  initialized, rd_done, rd_req : STD_LOGIC := '0';
    signal buf_y                         : STD_LOGIC_VECTOR(9 downto 0) := "0000000111"; --speichert global die Nummer der letzten gepufferten Bildzeile
    signal  rx_busy_last                 : std_logic := '0';
	 signal pic_received : STD_LOGIC := '0';
	 signal rx_cmd : t_rx_com := unidentified;
	 signal tx_cmd : t_tx_com := unidentified;
	 
	 signal page_received : STD_LOGIC := '0';

    -- temporaere signale
    signal farbelinks  : STD_LOGIC_VECTOR(11 downto 0) := x"FF0";
    signal farberechts : std_logic_vector(11 downto 0) := x"0FF";
    --attribute ramstyle        : string;
    --attribute ramstyle of beh : architecture is "M9K";
	 
	 --buffers counters etc für bildempfang
	 signal rec_buff : t_rec_buff;
	 signal page_counter : INTEGER range 0 to 1874 := 0;
	 signal byte_counter : INTEGER range 0 to 255 := 0;
	 signal byte_toggle : STD_LOGIC := '0';

begin

	dbg_byte_count <= byte_counter;
	dbg_page_count <= page_counter;

	 with current_state select
		dbg_state <= x"1" when s_wait_for_com,
						 x"2" when s_receive_pic,
						 x"3" when s_ram_fullpagewrite,
						 x"4" when s_transmit_response,
						 x"5" when s_wait_for_tx,
						 x"F" when others;

    --------------------------------------------------------------------
    --------------------------------------------------------------------
    --------------------------------------------------------------------
    next_state_register : process(clk, reset, next_state)
    begin
        if (reset = '0') then
            current_state <= s_ram_init;
        elsif (clk'EVENT and clk = '1') then
            current_state <= next_state;
        end if;
    end process next_state_register;


    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    next_state_logic : process (clk, reset, current_state, rd_req, rd_done, initialized, rx_busy, rx_busy_last, data_in, tx_busy, rx_cmd, pic_received)
    begin
        
            case current_state is

                ---------------------------------------------------------------------------------------
                -- Paas stuff -------------------------------------------------------------------------
                -- get this shiat done ----------------------------------------------------------------
                ---------------------------------------------------------------------------------------
                when s_wait_for_com =>
                    if rx_busy = '0' and rx_cmd = check_com then
                        next_state <= s_transmit_response;								
						  elsif rx_busy ='0' and rx_cmd = rec_pic then
								next_state <= s_receive_pic;
                    else
								next_state <= s_wait_for_com;                        
                    end if;

                when s_transmit_response =>
                    next_state <= s_wait_for_tx;


                when s_wait_for_tx =>
						  if tx_busy = '1' then
                        next_state <= s_wait_for_tx;
                    elsif tx_busy = '0' AND page_counter > 0 then
                        next_state <= s_receive_pic;
						  else
								next_state <= s_wait_for_com;
                    end if;

					when s_receive_pic =>
						if page_received = '1' THEN
							next_state<=s_ram_fullpagewrite;
						elsif pic_received = '1' THEN
							next_state <= s_wait_for_com;
						else
							next_state<=s_receive_pic;
						end if;
						
					when s_ram_fullpagewrite =>
						--do your stuff here
						next_state <= s_transmit_response;
						
               
                ---------------------------------------------------------------------------------------
                -- SDRAM stuff ------------------------------------------------------------------------
                -- joh --------------------------------------------------------------------------------
                ---------------------------------------------------------------------------------------
                when s_ram_init =>
                    if initialized = '1' then
                        next_state <= s_wait_for_com;
                    else
                        next_state <= s_ram_init;
                    end if;

                when s_ram_idle =>
                    if  rd_req = '1' then
                        next_state <= s_ram_rd;
                    else
                        next_state <= s_ram_idle;
                    end if;

                when s_ram_rd =>
                    if rd_done = '1' then
                        next_state <= s_ram_idle;
                    else
                        next_state <= s_ram_rd;
                    end if;

                when others =>
                    next_state <= s_ram_init;
            end case;
        
    end process next_state_logic;


    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    output_logic : process (clk, reset, current_state, iADDR, iBA, iDQM, iWE, iCAS, iRAS, iCKE, iCS, buf_y, rx_busy, byte_toggle, byte_counter, page_counter, data_in)

        variable cnt1    : integer range 0 to 36000 := 0;
        variable cnt2    : integer range 0 to 4 := 0;
        variable init    : integer range 0 to 15 := 0;
        variable pic_y   : integer range 0 to 1023 := 0;
        variable pic_x   : integer range 0 to 2047 := 0;
        variable bf_y    : integer range 0 to 1023 := 7; --speichert letzten Zeile des picture arrays zum Vergleich mit VGA-Modul
        variable rd_cnt  : integer range 0 to 31 := 0;
        variable row     : integer range 0 to 2047 := 25;
        variable rd      : integer range 0 to 15 := 0;
        variable array_x : integer range 0 to 1023 := 0;
        variable array_y : integer range 0 to 7 := 0;
        variable cnt3    : integer range 0 to 511 := 0;
		  
		  variable received_pic_counter : integer range 0 to 7 := 0;
		  
		  variable rx_cmd_var : t_rx_com := unidentified;

    begin
        if (reset = '0') then
            --iDQ      <= "ZZZZZZZZZZZZZZZZ";
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
				rx_busy_last<= '0';
				rx_cmd <= unidentified;
				pic_received<= '0';
				farbelinks <= x"000";
				farberechts<= x"000";
				
				byte_counter <= 0;
				page_counter <= 0;
				

            cnt1    := 0;
            cnt2    := 0;
            init    := 0;
            pic_y   := 0;
            pic_x   := 0;
            bf_y    := 7; --speichert letzten Zeile des picture arrays zum Vergleich mit VGA-Modul
            rd_cnt  := 0;
            row     := 25;
            rd      := 0;
            array_x := 0;
            array_y := 0;
            cnt3    := 0;
				received_pic_counter := 0;

        elsif (clk'EVENT and clk = '1') then
            case current_state is

                ---------------------------------------------------------------------------------------
                -- Paas stuff -------------------------------------------------------------------------
                -- get this shiat done ----------------------------------------------------------------
                ---------------------------------------------------------------------------------------
                when s_wait_for_com =>
						  pic_received <= '0';
                    data_out <= x"00";
                    TX_start <= '0';
						  IF rx_busy = '1' THEN
								rx_busy_last <= '1';
						  ELSIF rx_busy = '0' AND rx_busy_last = '1' THEN
						  rx_busy_last <= '0';
						  rx_cmd_var := get_rx_command(data_in);
						  rx_cmd <= rx_cmd_var;
								if rx_cmd_var = check_com then
									tx_cmd <= board_ack;
								else
									tx_cmd <= unidentified;
								end if;	
						  END IF;

                when s_transmit_response =>
						  rx_cmd <= unidentified;
                    data_out <= get_tx_command(tx_cmd);
                    TX_start <= '1';
						  rx_busy_last <= '0';

                when s_wait_for_tx =>
                    TX_start <= '0';
						  rx_busy_last <= '0';
						  
				   when s_receive_pic =>
						outer_if : if rx_busy = '1' then
                        rx_busy_last <= '1';
						ELSIF rx_busy = '0' AND rx_busy_last = '1' THEN
								rx_busy_last <= '0';
								
								inner_if : if page_counter = 1874 then
									--done
									page_counter <= 0;
									byte_counter <= 0;
									byte_toggle <= '0';
									pic_received <= '1';
								
								elsif byte_counter = 255 AND byte_toggle = '1' then
									-- page done
									byte_counter <= 0;
									byte_toggle <= '0';
									page_counter <= page_counter + 1;
									page_received <= '1';
								
								elsif byte_toggle = '0' then
									--write upper 4 bit
									rec_buff(byte_counter)(11 downto 8) <= data_in(3 downto 0);
									byte_toggle <= '1';
									
								elsif byte_toggle = '1' then
									--write lower 8 bit
									rec_buff(byte_counter)(7 downto 0) <= data_in;
									byte_toggle <= '0';
									byte_counter <= byte_counter + 1;
									
								end if inner_if;                       
                end if outer_if;
					 
					 when s_ram_fullpagewrite =>
						--do your magic here
						

						tx_cmd <= end_of_block;
						page_received <= '0';
							

                ---------------------------------------------------------------------------------------------------------------------------------------------------
                -- Initialisierung --------------------------------------------------------------------------------------------------------------------------------
                -- Durchlaeuft die Initialisierungssequenz laut Datenblatt und wechselt anschliessend in den Zustand s_ram_idle ---------------------------------------
                --------------------------------------------------------------------------------------------------------------------------------------------------- 
                when s_ram_init =>
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

                    elsif init = 7 then         --MRS, full page
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
                -- Idle -------------------------------------------------------------------------------------------------------------------------------------------
                -- Wartet darauf, dass das VGA-Modul anfaengt die letzte gepufferte Zeile zu lesen und wechselt dann in den Zustand s_ram_rd ------------------------
                --------------------------------------------------------------------------------------------------------------------------------------------------- 
                when s_ram_idle =>
                    rd_done <= '0';
                    iADDR   <= "1111111111111"; iBA <= "11"; iDQM <= "11"; iCKE <= '1'; iCS <= '1'; iRAS <= '1'; iCAS <= '1'; iWE <= '1'; --alles auf High, kein Befehl ausfuehren

                    pic_x := to_integer(unsigned(Hcnt(10 downto 0)));
                    pic_y := to_integer(unsigned(Vcnt(9 downto 0)));
                    bf_y  := to_integer(unsigned(buf_y(9 downto 0)));

                    if pic_x = 739 and bf_y = (pic_y+4) then          --nach 4900 pixel, oder 98us - also 4 Zeilen und 740 pixel
                        rd_req <= '1';
                    end if;


                ---------------------------------------------------------------------------------------------------------------------------------------------------
                -- rd 8 y-lines ---------------------------------------------------------------------------------------------------------------------------------
                -- fuehrt 25 full page rds durch, um 8 Zeilen des displays zu puffern ---------------------------------------------------------------------------
                --------------------------------------------------------------------------------------------------------------------------------------------------- 
                when s_ram_rd =>
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
                        rd_done <= '1';                                             --wieder in den Zustand s_ram_idle versetzen
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

        variable pic_y : integer range 0 to 1023 := 0;
        variable pic_x : integer range 0 to 1023 := 0;
        variable bf_y  : integer range 0 to 1023 := 7;
        variable arr_y : integer range 0 to 7 := 0;

    begin
        if (reset = '0') then

            ipixel <= x"0000";

        elsif (clk'EVENT and clk = '1') then
            case current_state is
					
                when s_ram_init =>
                    ipixel <= x"FFFF";

                when s_ram_idle =>
                    pic_x := to_integer(unsigned(Hcnt(9 downto 0)));
                    pic_y := to_integer(unsigned(Vcnt(9 downto 0)));
                    bf_y  := to_integer(unsigned(buf_y(9 downto 0)));

                    arr_y := (pic_y-bf_y);

                    if pic_x < 400 then
                        ipixel <= "0000" & farbelinks;
                    else
                        ipixel <= "0000" & farberechts;
                    end if;

                    --if arr_y = 0 then
                    --    ipixel <= "0000" & pic_buf7(pic_x);
                    --elsif arr_y = 1 then
                    --    ipixel <= "0000" & pic_buf6(pic_x);
                    --elsif arr_y = 2 then
                    --    ipixel <= "0000" & pic_buf5(pic_x);
                    --elsif arr_y = 3 then
                    --    ipixel <= "0000" & pic_buf4(pic_x);
                    --elsif arr_y = 4 then
                    --    ipixel <= "0000" & pic_buf3(pic_x);
                    --elsif arr_y = 5 then
                    --    ipixel <= "0000" & pic_buf2(pic_x);
                    --elsif arr_y = 6 then
                    --    ipixel <= "0000" & pic_buf1(pic_x);
                    --else
                    --    ipixel <= "0000" & pic_buf0(pic_x);
                    --end if;

                when s_ram_rd =>
                    pic_x := to_integer(unsigned(Hcnt(10 downto 0)));
                    pic_y := to_integer(unsigned(Vcnt(9 downto 0)));
                    bf_y  := to_integer(unsigned(buf_y(9 downto 0)));

                    arr_y := (pic_y-bf_y);

                    if pic_x < 400 then
                        ipixel <= "0000" & farbelinks;
                    else
                        ipixel <= "0000" & farberechts;
                    end if;

                    --if arr_y = 0 then
                    --    ipixel <= "0000" & pic_buf7(pic_x);
                    --elsif arr_y = 1 then
                    --    ipixel <= "0000" & pic_buf6(pic_x);
                    --elsif arr_y = 2 then
                    --    ipixel <= "0000" & pic_buf5(pic_x);
                    --elsif arr_y = 3 then
                    --    ipixel <= "0000" & pic_buf4(pic_x);
                    --elsif arr_y = 4 then
                    --    ipixel <= "0000" & pic_buf3(pic_x);
                    --elsif arr_y = 5 then
                    --    ipixel <= "0000" & pic_buf2(pic_x);
                    --elsif arr_y = 6 then
                    --    ipixel <= "0000" & pic_buf1(pic_x);
                    --else
                    --    ipixel <= "0000" & pic_buf0(pic_x);
                    --end if;

                when others =>
                    null;
            end case;
        end if;

        pixel <= ipixel;

    end process VGA_out;



end beh;
