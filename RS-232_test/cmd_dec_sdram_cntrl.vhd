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
        pixel                      : out STD_LOGIC_VECTOR(23 downto 0);

        data_in  : in std_logic_vector(7 downto 0);
        data_out : out std_logic_vector(7 downto 0);
        TX_start : out std_logic;
        rx_busy  : in std_logic;
        tx_busy  : in std_logic;

        dbg_state      : out STD_LOGIC_VECTOR(3 downto 0);
        dbg_page_count : out integer range 0 to 1874;
        dbg_byte_count : out integer range 0 to 255;
        dbg_cyc_count  : out std_logic_vector(27 downto 0);
		  dbg_refresh_cyc: out std_logic_vector(15 downto 0);
		  dbg_switch : in STD_LOGIC

    );

end entity cmd_dec_sdram_cntrl;

architecture beh of cmd_dec_sdram_cntrl is

    -- interne States
    type states is (s_ram_init, s_ram_rd, s_ram_fullpagewrite, s_ram_refresh, s_wait_for_com, s_transmit_response, s_wait_for_tx, s_receive_pic, s_brightness);
    signal current_state, next_state : states;

     --interne Signale fuer Ausgangspins
    --signal   iDQ                   : STD_LOGIC_VECTOR(15 downto 0) := "ZZZZZZZZZZZZZZZZ";
    signal   iADDR                 : STD_LOGIC_VECTOR(12 downto 0) := "0000000000000";
    signal   iBA, iDQM		        : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal   iWE, iCAS, iRAS, iCKE : STD_LOGIC := '0';
    signal   iCS                   : STD_LOGIC := '1';
    signal   ipixel                : STD_LOGIC_VECTOR(23 downto 0) := x"000000";

    -- Buffer fuer 8 Zeilen des anzuzeigenden Bildes
    type rg_array is array (integer range 0 to 255) of std_logic_vector(15 downto 0);
    signal rg_buf0, rg_buf1, rg_buf2, rg_buf3, rg_process : rg_array := (others => x"0000") ;
	 type b_array is array(integer range 0 to 255) of std_LOGIC_VECTOR(7 downto 0);
	 signal b_buf0, b_buf1, b_buf2, b_buf3, b_process: b_array := (others => x"00");

    --iterne Signale fuer Kommunikation zwischen den Prozessen
    signal  initialized, rd_done, rd_req, wr_done, refreshed, brightness : STD_LOGIC := '0';
    signal buf_y                                             : STD_LOGIC_VECTOR(9 downto 0) := "0000000000"; --speichert global die Nummer der letzten gepufferten Bildzeile
    signal  rx_busy_last                                     : std_logic := '0';
    signal pic_received                                      : STD_LOGIC := '0';
    signal rx_cmd                                            : t_rx_com := unidentified;
    signal tx_cmd                                            : t_tx_com := unidentified;

    signal page_received : STD_LOGIC := '0';

    -- temporaere signale
    
	 
    attribute ramstyle        : string;
    attribute ramstyle of beh : architecture is "M9K";

     --buffers counters etc fÃƒÆ’Ã‚Â¼r bildempfang
    signal rec_buff_rg     : t_rec_buff_rg := (others => x"0000");
	 signal rec_buff_b		: t_rec_buff_b  := (others => x"00");
    signal page_counter : INTEGER range 0 to 3072 := 0;
    signal pixel_counter : INTEGER range 0 to 256 := 0;
    signal byte_toggle  : STD_LOGIC_VECTOR(1 downto 0) := "00";

begin

    dbg_byte_count <= pixel_counter;
    dbg_page_count <= page_counter;

    with current_state select
        dbg_state <= x"1" when s_wait_for_com,
        x"2" when s_receive_pic,
        x"3" when s_ram_fullpagewrite,
        x"4" when s_transmit_response,
        x"5" when s_wait_for_tx,
        x"6" when s_ram_refresh,
        x"8" when s_ram_rd,
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
    next_state_logic : process (clk, reset, current_state, rd_req, rd_done, wr_done, initialized, refreshed, rx_busy, rx_busy_last, data_in, tx_busy, rx_cmd, pic_received, page_counter, page_received)
    begin

        case current_state is

                ---------------------------------------------------------------------------------------
                -- Paas stuff -------------------------------------------------------------------------
                -- get this shiat done ----------------------------------------------------------------
                ---------------------------------------------------------------------------------------
            when s_wait_for_com =>
                if rx_busy = '0' and rx_cmd = check_com then
                    next_state <= s_transmit_response;
                elsif rx_busy = '0' and rx_cmd = rec_pic then
                    next_state <= s_receive_pic;
                elsif rd_req = '1' then
                    next_state <= s_ram_rd;
					 elsif dbg_switch = '1' and brightness='0' then
						  next_state <= s_brightness;
					 else
                    next_state <= s_wait_for_com;
                end if;

            when s_transmit_response =>
                next_state <= s_wait_for_tx;


            when s_wait_for_tx =>
                if tx_busy = '1' then
                    next_state <= s_wait_for_tx;
					 elsif tx_busy = '0' and pic_received = '1' then
						  next_state <= s_wait_for_com;
                elsif tx_busy = '0' and page_counter > 0 then
                    next_state <= s_receive_pic;
                else
                    next_state <= s_wait_for_com;
                end if;

            when s_receive_pic =>
                if page_received = '1' then
                    next_state <= s_ram_fullpagewrite;
                elsif pic_received = '1' then
                    next_state <= s_ram_fullpagewrite;
                else
                    next_state <= s_receive_pic;
                end if;

            when s_ram_fullpagewrite =>
                if wr_done = '1' then
                    next_state <= s_ram_refresh;
                else
                    next_state <= s_ram_fullpagewrite;
                end if;


            when s_ram_refresh =>
                if refreshed = '1' then
                    next_state <= s_transmit_response;
                else
                    next_state <= s_ram_refresh;
                end if;

				when s_brightness =>
					if brightness = '1' then
						next_state <= s_wait_for_tx;
					else
						next_state <= s_brightness;
					end if;

                ---------------------------------------------------------------------------------------
                -- SDRAM stuff ------------------------------------------------------------------------
                -- joh --------------------------------------------------------------------------------
                ---------------------------------------------------------------------------------------
            when s_ram_init =>
                if initialized = '1' then
                    next_state <= s_wait_for_com;
						  --next_state<=s_ram_idle;
                else
                    next_state <= s_ram_init;
                end if;

            when s_ram_rd =>
                if rd_done = '1' then
                    next_state <= s_wait_for_com;
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
    output_logic : process (clk, reset, current_state, iADDR, iBA, iDQM, iWE, iCAS, iRAS, iCKE, iCS, buf_y, rx_busy, byte_toggle, pixel_counter, page_counter, data_in, rec_buff_b, rec_buff_rg)

        variable cnt1              : integer range 0 to 36000 := 0;
        variable cnt2              : integer range 0 to 31 := 0;
        variable init              : integer range 0 to 15 := 0;
        variable pic_x             : integer range 0 to 2047 := 0;
        variable bf_y              : integer range 0 to 524287 := 0; --speichert letzten Zeile des picture arrays zum Vergleich mit VGA-Modul
        variable rd_cnt            : integer range 0 to 31 := 0;
        variable row               : integer range 0 to 4095 := 4;
        variable rd                : integer range 0 to 31 := 0;
        variable cnt3              : integer range 0 to 511 := 0;
        variable dbg_cyc_count_int : integer := 0;
        variable wr                : integer range 0 to 31 := 0;
        variable page_to_write     : integer range 0 to 4095 := 0;
        variable refresh           : integer range 0 to 15 := 2;
        variable refresh_cnt       : integer range 0 to 8191 := 0;
		  variable dbg_refresh_int : integer range 0 to 65000 := 0;
		  variable brgt_cnt : integer range 0 to 4095 := 0;
		  variable br : integer range 0 to 31 := 0;
		  variable i : integer range 0 to 511 := 0;
		  variable bank : integer range 0 to 3 := 0;

          --variable received_pic_counter : integer range 0 to 7 := 0;

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
            buf_y <= "0000000000";
				byte_toggle<= "00";
				bank<="00";

            initialized  <= '0';
            rd_req       <= '0';
            rd_done      <= '0';
            rx_busy_last <= '0';
            rx_cmd       <= unidentified;
            pic_received <= '0';
            refreshed    <= '0';
				brightness	 <= '0';

            pixel_counter <= 0;
            page_counter <= 0;


            cnt1          := 0;
            cnt2          := 0;
            init          := 0;
            pic_x         := 0;
            bf_y          := 0; --speichert letzten Zeile des picture arrays zum Vergleich mit VGA-Modul
            rd_cnt        := 0;
            row           := 0;
            rd            := 0;
            cnt3          := 0;
            wr            := 0;
            page_to_write := 0;
            refresh       := 2;
            refresh_cnt   := 0;
                --received_pic_counter := 0;

        elsif (clk'EVENT and clk = '1') then
				
				 
				 
            case current_state is

                ---------------------------------------------------------------------------------------
                -- Paas stuff -------------------------------------------------------------------------
                -- get this shiat done ----------------------------------------------------------------
                ---------------------------------------------------------------------------------------
                when s_wait_for_com =>
                    pic_received <= '0';
                    data_out     <= x"00";
                    TX_start     <= '0';
                    if rx_busy = '1' then
                        rx_busy_last <= '1';
                    elsif rx_busy = '0' and rx_busy_last = '1' then
                        rx_busy_last <= '0';
                        rx_cmd_var := get_rx_command(data_in);
                        rx_cmd <= rx_cmd_var;
                        if rx_cmd_var = check_com then
                            tx_cmd <= board_ack;
                        else
                            tx_cmd <= unidentified;
                        end if;
                    end if;
						  
						  --previous s_sram_idle
						  rd_done <= '0';
                    iADDR   <= "1111111111111"; iBA <= "11"; iDQM <= "11"; iCKE <= '1'; iCS <= '1'; iRAS <= '1'; iCAS <= '1'; iWE <= '1'; --alles auf High, kein Befehl ausfuehren
			
						  pic_x:=to_integer(unsigned(Hcnt));
			  
                    if pic_x = 455 and Vcnt=buf_y then          
                        rd_req <= '1';
                    end if;

                when s_transmit_response =>
                    refreshed    <= '0';
                    rx_cmd       <= unidentified;
                    data_out     <= get_tx_command(tx_cmd);
                    TX_start     <= '1';
                    rx_busy_last <= '0';

                when s_wait_for_tx =>
                    TX_start     <= '0';
                    rx_busy_last <= '0';

                when s_receive_pic =>
                    dbg_cyc_count_int := dbg_cyc_count_int+1;
						  
						  
						  outer_if : if pixel_counter = 256 then
                                    -- page done
                        dbg_cyc_count <= std_logic_vector(to_unsigned(dbg_cyc_count_int, 28));
                        dbg_cyc_count_int := 0;
                        pixel_counter  <= 0;
                        byte_toggle   <= "00";
                        page_counter  <= page_counter + 1;
                        page_received <= '1';

                    elsif page_counter = 3072 then --3072
                                    --done
                        pixel_counter <= 0;
                        byte_toggle  <= "00";
                        pic_received <= '1';

                    elsif rx_busy = '1' then						  
                        rx_busy_last <= '1';
                    elsif rx_busy = '0' and rx_busy_last = '1' then
                        rx_busy_last <= '0';                        

                        inner_if : if byte_toggle = "00" then
                                    --write upper 4 bit
                            --rec_buff_b(pixel_counter) <= data_in;
									 rec_buff_rg(pixel_counter)(15 downto 8) <= data_in;
                            byte_toggle                         <= "01";

                        elsif byte_toggle = "01" then
                                    --write lower 8 bit
                            rec_buff_rg(pixel_counter)(7 downto 0) <= data_in;
                            byte_toggle                        <= "10";
                                                        
                        elsif byte_toggle = "10" then
                            --rec_buff_rg(pixel_counter)(15 downto 8) <= data_in;
									 rec_buff_b(pixel_counter) <= data_in;
                            byte_toggle                        <= "00";                            
                            pixel_counter <= pixel_counter + 1;

                        end if inner_if;
                    end if outer_if;

                ---------------------------------------------------------------------------------------------------------------------------------------------------
                -- Fullpage-Write ---------------------------------------------------------------------------------------------------------------------------------
                -- beschreibt eine Zeile (page)des SDRAM mit den Daten im rs_232-Puffer ---------------------------------------------------------------------------
                ---------------------------------------------------------------------------------------------------------------------------------------------------
                when s_ram_fullpagewrite =>
                    tx_cmd        <= end_of_block;
                    page_received <= '0';

                    if wr = 0 then          --bank active
                        iADDR <= std_LOGIC_VECTOR(to_unsigned((page_to_write), iADDR'length)); iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                        wr := wr+1;

                    elsif wr = 1 then       --tRCD
                        iCS <= '1';
                        if cnt2 < 2 then
                            cnt2 := cnt2+1;
                        else
                           
                            cnt2 := 0;
                            wr   := wr+1;
                        end if;

                    elsif wr = 2 then       --write
                        iADDR   <= "0000000000000"; iBA <= "00"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '0';
                        DRAM_DQ <= rec_buff_rg(cnt3);
                        cnt3 := cnt3+1;
                        wr   := wr+1;

                   
                        
                    elsif wr = 3 then       --write die restlichen 255 words
                        iCS <= '1';
                        if cnt3 < 256 then
                           DRAM_DQ <= rec_buff_rg(cnt3);
									cnt3 := cnt3+1;
                        else
                            iRAS<='1'; iCAS<='1'; iWE<='0'; iCS<='0';   --burststop
                            cnt3 := 0;
                            wr   := wr+1;
                        end if;

                    elsif wr = 4 then       --tRDL
                        iCS<='1';
                        if cnt3 < 1 then
                            cnt3 := cnt3+1;
                        else
                            cnt3 := 0;
                            wr   := wr+1;
                        end if;

                    elsif wr = 5 then       --precharge
                        iADDR <= "0010000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                        wr := wr+1;

                    elsif wr = 6 then       --tRP
                        iCS <= '1';
                        if cnt2 < 9 then
                            cnt2 := cnt2+1;
                        else
									cnt2 := 0;
									wr   := wr+1;
									 
                        end if;

							elsif wr = 7 then          --bank active
                        iADDR <= std_LOGIC_VECTOR(to_unsigned((page_to_write), iADDR'length)); iBA <= "01"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                        wr := wr+1;

                    elsif wr = 8 then       --tRCD
                        iCS <= '1';
                        if cnt2 < 2 then
                            cnt2 := cnt2+1;
                        else
                           
                            cnt2 := 0;
                            wr   := wr+1;
                        end if;

                    elsif wr = 9 then       --write
                        iADDR   <= "0000000000000"; iBA <= "01"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '0';
                        DRAM_DQ <= rec_buff_b(cnt3)&x"00";
                        cnt3 := cnt3+1;
                        wr   := wr+1;

                   
                        
                    elsif wr = 10 then       --write die restlichen 255 words
                        iCS <= '1';
                        if cnt3 < 256 then
                           DRAM_DQ <= rec_buff_b(cnt3)&x"00";
									cnt3 := cnt3+1;
                        else
                            iRAS<='1'; iCAS<='1'; iWE<='0'; iCS<='0';   --burststop
                            cnt3 := 0;
                            wr   := wr+1;
                        end if;

                    elsif wr = 11 then       --tRDL
                        iCS<='1';
                        if cnt3 < 1 then
                            cnt3 := cnt3+1;
                        else
                            cnt3 := 0;
                            wr   := wr+1;
                        end if;

                    elsif wr = 11 then       --precharge
                        iADDR <= "0010000000000"; iBA <= "01"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                        wr := wr+1;

                    elsif wr = 12 then       --tRP
                        iCS <= '1';
                        if cnt2 < 2 then
                            cnt2 := cnt2+1;
                        else
									page_to_write := page_to_write +1;
									wr_done <= '1';
									cnt2 := 0;
									wr   := 0;
									 
                        end if;

                    else
                        wr := 0;

                    end if;

                ---------------------------------------------------------------------------------------------------------------------------------------------------
                -- RAM - refresh ----------------------------------------------------------------------------------------------------------------------------------
                -- refresht Bank 0, damit keine Daten verloren gehen ----------------------------------------------------------------------------------------------
                --------------------------------------------------------------------------------------------------------------------------------------------------- 
                when s_ram_refresh =>
                    wr_done <= '0';
						  
						  
                    if refresh = 0 then     --PALL
                        iADDR <= "0010000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                        refresh := refresh+1;
                         
                    elsif refresh = 1 then
                        iCS <= '1';
                        
                        if cnt2 < 2 then
                            cnt2 := cnt2+1;
                        else
                            refresh := refresh+1;
                            cnt2    := 0;
                        end if;

                    elsif refresh = 2 then   --auto refresh
                        iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '0'; iWE <= '1';
                        refresh := refresh+1;
                        
                    elsif refresh =3 then --tARFC
                        iCS <= '1';
								
								if cnt2 < 9 then
                            cnt2 := cnt2+1;
                        else
                            refresh := refresh+1;
                            cnt2    := 0;
                        end if;
                        
                    elsif refresh = 4 then
                        refresh_cnt := refresh_cnt+1;
                        if refresh_cnt < 4096 then
									
                            refresh := 2;
                        else
                            refresh:=2;
                            refreshed <= '1';
                            refresh_cnt := 0;
                           
                            
                        end if;
                    else
                        refresh := 0;
                    end if;

                ---------------------------------------------------------------------------------------------------------------------------------------------------
                -- Initialisierung --------------------------------------------------------------------------------------------------------------------------------
                -- Durchlaeuft die Initialisierungssequenz laut Datenblatt und wechselt anschliessend in den Zustand s_ram_idle -----------------------------------
                --------------------------------------------------------------------------------------------------------------------------------------------------- 
                when s_ram_init =>
                    DRAM_DQ <= "ZZZZZZZZZZZZZZZZ";

                    if init = 0 then          --power-up
                        iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '1'; iRAS <= '0'; iCAS <= '0'; iWE <= '0';
                        if cnt1 < 33200 then  --200us delay
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
                        if cnt2 < 2 then
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
                        if cnt2 < 9 then
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
                        if cnt2 < 9 then
                            cnt2 := cnt2+1;
                        else
                            cnt2 := 0;
                            init := init+1;
                        end if;

                    elsif init = 7 then         --MRS, full page
                        iADDR <= "0000000110111"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '0'; iWE <= '0';
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
                -- rd 1 y-line ------------------------------------------------------------------------------------------------------------------------------------
                -- fuehrt 4 full page rds durch, um eine Zeile des displays zu puffern ----------------------------------------------------------------------------
                --------------------------------------------------------------------------------------------------------------------------------------------------- 
                when s_ram_rd =>
                    rd_req  <= '0';
                    DRAM_DQ <= "ZZZZZZZZZZZZZZZZ";
						  
						  dbg_refresh_int:=dbg_refresh_int+1;

                    if rd_cnt < 4 then           --fuehrt 4 full page rds durch
                        if rd = 0 then              --Bank Active (ACT) + row auf adresspin
                            iADDR <= std_logic_vector(to_unsigned(row, iADDR'length)); iBA <= std_logic_vector(to_unsigned(bank, iBA'length)); iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                            rd := rd+1;

                        elsif rd = 1 then           --tRCD
                            iCS <= '1';
                            if cnt2 < 2 then
                                cnt2 := cnt2+1;
                            else
                                cnt2 := 0;
                                rd   := rd+1;
                            end if;

                        elsif rd = 2 then           --rd  w/o precharge command + column auf Adresspin
                            iADDR <= "0000000000000"; iBA <= std_logic_vector(to_unsigned(bank, iBA'length)); iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '1';
                            rd := rd+1;

                        elsif rd = 3 then           --CAS latency
                            iCS <= '1';
                            if cnt2 < 2 then
                                cnt2 := cnt2+1;
                            else
                                rd   := rd+1;
                                cnt2 := 0;
                                cnt3:=0;
                            end if;

                        elsif rd = 4 then           --einlesen der naechsten 256 Werte auf dem DQ-Bus
                            if cnt3 < 256 then
                              
											if rd_cnt=0 then
												rg_buf0(cnt3)<=DRAM_DQ;
												--rg_buf0(cnt3)<=x"0000";
											elsif rd_cnt=1 then
												rg_buf1(cnt3)<=DRAM_DQ;
												--rg_buf1(cnt3)<=x"0000";
											ELSIF rd_cnt = 2 then	
												rg_buf2(cnt3)<=DRAM_DQ;
												--rg_buf2(cnt3)<=x"0000";
											ELSIF rd_cnt = 3 then	
												rg_buf3(cnt3)<=DRAM_DQ;
												--rg_buf3(cnt3)<=x"0000";
											end if;
										
											
											cnt3 := cnt3+1;
                            else
                                
                                rd   := rd+1;
                                cnt3 := 0;
                            end if;


                        elsif rd = 5 then         --precharge
                            iADDR <= "0010000000000"; iBA <= std_logic_vector(to_unsigned(bank, iBA'length)); iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            rd := rd+1;

                        elsif rd = 6 then         --trp
                            iCS <= '1';
                            if cnt2 < 9 then
                                cnt2 := cnt2+1;
                            else
												rd   := rd+1;
												cnt2 := 0;
										  
                            end if;
									 
								elsif rd = 7 then              --Bank Active (ACT) + row auf adresspin
                            iADDR <= std_logic_vector(to_unsigned(row, iADDR'length)); iBA <= std_logic_vector(to_unsigned((bank+1), iBA'length)); iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                            --iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                            rd := rd+1;

                        elsif rd = 8 then           --tRCD
                            iCS <= '1';
                            if cnt2 < 2 then
                                cnt2 := cnt2+1;
                            else
                                cnt2 := 0;
                                rd   := rd+1;
                            end if;

                        elsif rd = 9 then           --rd  w/o precharge command + column auf Adresspin
                            iADDR <= "0000000000000"; iBA <= std_logic_vector(to_unsigned((bank+1), iBA'length)); iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '1';
                            rd := rd+1;

                        elsif rd = 10 then           --CAS latency
                            iCS <= '1';
                            if cnt2 < 2 then
                                cnt2 := cnt2+1;
                            else
                                rd   := rd+1;
                                cnt2 := 0;
                                cnt3:=0;
                            end if;

                        elsif rd = 11 then           --einlesen der naechsten 256 Werte auf dem DQ-Bus
                            if cnt3 < 256 then
                              
											if rd_cnt=0 then
												b_buf0(cnt3)<=DRAM_DQ(15 downto 8);
												--b_buf0(cnt3)<=x"00";
											elsif rd_cnt=1 then
												b_buf1(cnt3)<=DRAM_DQ(15 downto 8);
												--b_buf1(cnt3)<=x"00";
											ELSIF rd_cnt = 2 then	
												b_buf2(cnt3)<=DRAM_DQ(15 downto 8);
												--b_buf2(cnt3)<=x"00";
											ELSIF rd_cnt = 3 then	
												b_buf3(cnt3)<=DRAM_DQ(15 downto 8);
												--b_buf3(cnt3)<=x"00";
											end if;
										
											
											cnt3 := cnt3+1;
                            else
                                
                                rd   := rd+1;
                                cnt3 := 0;
                            end if;


                        elsif rd = 12 then         --precharge
                            iADDR <= "0010000000000"; iBA <= std_logic_vector(to_unsigned((bank+1), iBA'length)); iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            rd := rd+1;

                        elsif rd = 13 then         --trp
                            iCS <= '1';
                            if cnt2 < 2 then
                                cnt2 := cnt2+1;
                            else
												rd_cnt := rd_cnt+1;
												row    := row+1;
												if row > 3071 then
													row := 0;
												end if;
												rd   := 0;
												cnt2 := 0;
										  
                            end if;
                        else
                            rd := 0;
                        end if;

                    else
                        
								bf_y:=bf_y+1;
								if bf_y>767 then
									bf_y:=0;
								end if;
								buf_y<=std_LOGIC_VECTOR(to_unsigned(bf_y, buf_y'length));
								
								dbg_refresh_cyc <= std_LOGIC_VECTOR(to_unsigned(dbg_refresh_int, 16));
								dbg_refresh_int:=0;

                        rd_cnt := 0;
                        rd_done <= '1';                                             --wieder in den Zustand s_ram_idle versetzen
								
                    end if;


					 --#######################################################################################################################
					 -- s_brightness #########################################################################################################
					 -- veraendert jeden Farbkanal um den uebergebenen Wert ##################################################################
					 --#######################################################################################################################
					 when s_brightness=>
					 if brgt_cnt<3072 then
								if br = 0 then              --Bank Active (ACT) + brgt_cnt auf adresspin
									 DRAM_DQ <= "ZZZZZZZZZZZZZZZZ";
                            iADDR <= std_logic_vector(to_unsigned(brgt_cnt, iADDR'length)); iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                            br := br+1;

                        elsif br = 1 then           --tRCD
                            iCS <= '1';
                            if cnt2 < 2 then
                                cnt2 := cnt2+1;
                            else
                                cnt2 := 0;
                                br   := br+1;
                            end if;

                        elsif br = 2 then           --rd  w/o precharge command + column auf Adresspin
                            iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '1';
                            br := br+1;

                        elsif br = 3 then           --CAS latency
                            iCS <= '1';
                            if cnt2 < 2 then
                                cnt2 := cnt2+1;
                            else
                                br   := br+1;
                                cnt2 := 0;
                                cnt3 :=0;
                            end if;

                        elsif br = 4 then           --einlesen der naechsten 256 Werte auf dem DQ-Bus
                            if cnt3 < 256 then
                              
											rg_process(cnt3)<=DRAM_DQ;
											cnt3 := cnt3+1;
                            else
                                
                                br   := br+1;
                                cnt3 := 0;
                            end if;


                        elsif br = 5 then         --precharge
                            iADDR <= "0010000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            br := br+1;

                        elsif br = 6 then         --trp
                            iCS <= '1';
                            if cnt2 < 9 then
                                cnt2 := cnt2+1;
                            else
												br   := br+1;
												cnt2 := 0;
										  
                            end if;
									 
								elsif br = 7 then              --Bank Active (ACT) + row auf adresspin
                            iADDR <= std_logic_vector(to_unsigned(brgt_cnt, iADDR'length)); iBA <= "01"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                            br := br+1;

                        elsif br = 8 then           --tRCD
                            iCS <= '1';
                            if cnt2 < 2 then
                                cnt2 := cnt2+1;
                            else
                                cnt2 := 0;
                                br   := br+1;
                            end if;

                        elsif br = 9 then           --rd  w/o precharge command + column auf Adresspin
                            iADDR <= "0000000000000"; iBA <= "01"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '1';
                            br := br+1;

                        elsif br = 10 then           --CAS latency
                            iCS <= '1';
                            if cnt2 < 2 then
                                cnt2 := cnt2+1;
                            else
                                br   := br+1;
                                cnt2 := 0;
                                cnt3:=0;
                            end if;

                        elsif br = 11 then           --einlesen der naechsten 256 Werte auf dem DQ-Bus
                            if cnt3 < 256 then
                              
											b_process<=DRAM_DQ;
											
											cnt3 := cnt3+1;
                            else
                                
                                br   := br+1;
                                cnt3 := 0;
                            end if;


                        elsif br = 12 then         --precharge
                            iADDR <= "0010000000000"; iBA <= "01"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            br := br+1;

                        elsif br = 13 then         --trp
                            iCS <= '1';
                            if cnt2 < 2 then
                                cnt2 := cnt2+1;
                            else
											br   := br+1;
											cnt2 := 0;
										  
                            end if;
									 
								elsif br=14 then
									while i<256 loop
										rg_process(i)<=rg_process(i)+8224;
										b_process(i)<=b_process(i)+32;
										i:=i+1;
									end loop;
									br:=br+1;
									
								elsif br=15 then		--bank active
									iADDR <= std_LOGIC_VECTOR(to_unsigned((brgt_cnt), iADDR'length)); iBA <= "10"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
									wr := wr+1;

								elsif br = 16 then       --tRCD
									iCS <= '1';
									if cnt2 < 2 then
										cnt2 := cnt2+1;
									else
										cnt2 := 0;
										br   := br+1;
									end if;

								elsif br = 17 then       --write
									iADDR   <= "0000000000000"; iBA <= "10"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '0';
									DRAM_DQ <= rg_process(cnt3);
									cnt3 := cnt3+1;
									br   := br+1;

                   
                        
								elsif br = 18 then       --write die restlichen 255 words
									iCS <= '1';
									if cnt3 < 256 then
										DRAM_DQ <= rg_process(cnt3);
										cnt3 := cnt3+1;
									else
										iRAS<='1'; iCAS<='1'; iWE<='0'; iCS<='0';   --burststop
										cnt3 := 0;
										br   := br+1;
									end if;

								elsif br = 19 then       --tRDL
									iCS<='1';
									if cnt3 < 1 then
										cnt3 := cnt3+1;
									else
										cnt3 := 0;
										br   := br+1;
									end if;

								elsif br = 20 then       --precharge
									iADDR <= "0010000000000"; iBA <= "10"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
									br := br+1;

								elsif wr = 21 then       --tRP
									iCS <= '1';
									if cnt2 < 9 then
										cnt2 := cnt2+1;
									else
										cnt2 := 0;
										br   := br+1;
									 
									end if;

								elsif br = 22 then          --bank active
									iADDR <= std_LOGIC_VECTOR(to_unsigned((brgt_cnt), iADDR'length)); iBA <= "11"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
									br := br+1;

								elsif br = 23 then       --tRCD
									iCS <= '1';
									if cnt2 < 2 then
                            cnt2 := cnt2+1;
									else
                           
                            cnt2 := 0;
                            br   := br+1;
									end if;

								elsif br = 24 then       --write
									iADDR   <= "0000000000000"; iBA <= "11"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '0';
									DRAM_DQ <= b_process(cnt3)&x"00";
									cnt3 := cnt3+1;
									br   := br+1;

								elsif br = 25 then       --write die restlichen 255 words
									iCS <= '1';
									if cnt3 < 256 then
										DRAM_DQ <= b_process(cnt3)&x"00";
										cnt3 := cnt3+1;
									else
										iRAS<='1'; iCAS<='1'; iWE<='0'; iCS<='0';   --burststop
										cnt3 := 0;
										br   := br+1;
									end if;

								elsif br = 26 then       --tRDL
									iCS<='1';
									if cnt3 < 1 then
                            cnt3 := cnt3+1;
									else
                            cnt3 := 0;
                            br   := br+1;
									end if;

								elsif br = 27 then       --precharge
									iADDR <= "0010000000000"; iBA <= "11"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
									br := br+1;

								elsif wr = 12 then       --tRP
									iCS <= '1';
									if cnt2 < 2 then
                            cnt2 := cnt2+1;
									else
										brgt_cnt := brgt_cnt +1;
										cnt2 := 0;
										br   := 0;
									 
									end if;
								
								else
                           br := 0;
								end if;
						else
							brightness<='1';
							bank:=2;
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
    VGA_out : process (clk, reset, current_state, ipixel, Hcnt, Vcnt, buf_y, rg_buf0, rg_buf1, rg_buf2, rg_buf3, b_buf0, b_buf1, b_buf2, b_buf3)

        variable pic_x : integer range 0 to 2045 := 0;

    begin
        if (reset = '0') then

            ipixel <= x"000000";

        elsif (clk'EVENT and clk = '1') then
            case current_state is

                when s_ram_init =>
                    ipixel <= x"FFFFFF";

                when s_wait_for_com =>
                    
						  pic_x := to_integer(unsigned(Hcnt(10 downto 0)));

					
							if pic_x<256 then
								ipixel<=rg_buf0(pic_x)&b_buf0(pic_x);
							elsif pic_x>255 and pic_x<512 then
								ipixel<=rg_buf1(pic_x-256)&b_buf1(pic_x-256);
						   elsif pic_x>511 and pic_x<768 then
								ipixel<=rg_buf2(pic_x-512)&b_buf2(pic_x-512);
							else
								ipixel<=rg_buf3(pic_x-768)&b_buf3(pic_x-768);
							end if;		                    


                when s_ram_rd =>
                    pic_x := to_integer(unsigned(Hcnt(10 downto 0)));
							
							if pic_x<256 then
								ipixel<=rg_buf0(pic_x)&b_buf0(pic_x);
							elsif pic_x>255 and pic_x<512 then
								ipixel<=rg_buf1(pic_x-256)&b_buf1(pic_x-256);
						   elsif pic_x>511 and pic_x<768 then
								ipixel<=rg_buf2(pic_x-512)&b_buf2(pic_x-512);
							else
								ipixel<=rg_buf3(pic_x-768)&b_buf3(pic_x-768);
							end if;
						

                when others =>
                    null;
            end case;
        end if;

        pixel <= ipixel;

    end process VGA_out;



end beh;
