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

        dbg_state       : out STD_LOGIC_VECTOR(3 downto 0);
        dbg_page_count  : out integer range 0 to 1874;
        dbg_byte_count  : out integer range 0 to 255;
        dbg_cyc_count   : out std_logic_vector(27 downto 0);
        dbg_refresh_cyc : out std_logic_vector(15 downto 0)
    );

end entity cmd_dec_sdram_cntrl;

architecture beh of cmd_dec_sdram_cntrl is

    -- interne States
    type states is (s_ram_init, s_ram_rd, s_ram_fullpagewrite, s_wait_for_com, s_transmit_response, s_wait_for_tx, s_receive_pic, s_brightness, s_write_cont_lut, s_cont);
    signal current_state, next_state : states;

    --interne Signale fuer Ausgangspins
    --signal   iDQ                   : STD_LOGIC_VECTOR(15 downto 0) := "ZZZZZZZZZZZZZZZZ";
    signal   iADDR                 : STD_LOGIC_VECTOR(12 downto 0) := "0000000000000";
    signal   iBA, iDQM             : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal   iWE, iCAS, iRAS, iCKE : STD_LOGIC := '0';
    signal   iCS                   : STD_LOGIC := '1';
    signal   ipixel                : STD_LOGIC_VECTOR(23 downto 0) := x"000000";

    -- Buffer fuer 8 Zeilen des anzuzeigenden Bildes
    --type rg_array is array (integer range 0 to 255) of std_logic_vector(15 downto 0);
    --signal rg_buf0, rg_buf1, rg_buf2, rg_buf3, rg_process : rg_array := (others => x"0000") ;
    --type b_array is array(integer range 0 to 255) of std_LOGIC_VECTOR(7 downto 0);
    --signal b_buf0, b_buf1, b_buf2, b_buf3, b_process : b_array := (others => x"00");
    type color_array is array (0 to 255) of std_logic_vector(7 downto 0);
    signal r_buf0, r_buf1, r_buf2, r_buf3, g_buf0, g_buf1, g_buf2, g_buf3, b_buf0, b_buf1, b_buf2, b_buf3 : color_array := (others => x"00");

    --iterne Signale fuer Kommunikation zwischen den Prozessen
    signal  initialized, rd_done, rd_req, wr_done, brightness, contrast: STD_LOGIC := '0';
    signal buf_y                                              : STD_LOGIC_VECTOR(9 downto 0) := "0000000000"; --speichert global die Nummer der letzten gepufferten Bildzeile
    signal  rx_busy_last                                      : std_logic := '0';
    signal pic_received                                       : STD_LOGIC := '0';
    signal rx_cmd                                             : t_rx_com := unidentified;
    signal tx_cmd                                             : t_tx_com := unidentified;

    signal page_received : STD_LOGIC := '0';

    -- temporaere signale


    attribute ramstyle        : string;
    attribute ramstyle of beh : architecture is "M9K";

     --buffers counters etc fuer bildempfang
    signal rec_buff_rg   : t_rec_buff_rg := (others => x"0000");
    signal rec_buff_b    : t_rec_buff_b  := (others => x"00");
    signal page_counter  : INTEGER range 0 to 3072 := 0;
    signal pixel_counter : INTEGER range 0 to 511 := 0;
    signal byte_toggle   : STD_LOGIC_VECTOR(1 downto 0) := "00";

    signal ram0, ram5 , ram1 : t_cram := c_cram_empty;
    signal ram2, ram3, ram4  : t_dpram := c_dpram_empty;

    signal filter_set : t_filter_set := c_filter_set_empty;

begin

    ram_comp_0 : single_port_ram generic map(8, 8) port map(clk, ram0.addr, ram0.data_r, ram0.we_r, ram0.q_r);
    ram_comp_1 : single_port_ram generic map(8, 8) port map(clk, ram0.addr, ram0.data_g, ram0.we_g, ram0.q_g);
    ram_comp_2 : single_port_ram generic map(8, 8) port map(clk, ram0.addr, ram0.data_b, ram0.we_b, ram0.q_b);

    ram_comp_12 : single_port_ram generic map(8, 8) port map(clk, ram1.addr, ram1.data_r, ram1.we_r, ram1.q_r);
    ram_comp_13 : single_port_ram generic map(8, 8) port map(clk, ram1.addr, ram1.data_g, ram1.we_g, ram1.q_g);
    ram_comp_14 : single_port_ram generic map(8, 8) port map(clk, ram1.addr, ram1.data_b, ram1.we_b, ram1.q_b);

    ram_comp_15 : single_port_ram generic map(8, 8) port map(clk, ram5.addr, ram5.data_r, ram5.we_r, ram5.q_r);
    ram_comp_16 : single_port_ram generic map(8, 8) port map(clk, ram5.addr, ram5.data_g, ram5.we_g, ram5.q_g);
    ram_comp_17 : single_port_ram generic map(8, 8) port map(clk, ram5.addr, ram5.data_b, ram5.we_b, ram5.q_b);
	 
	 lut_cont_0 : single_port_ram generic map(8, 8) port map(clk, filter_set.cont_ram.addr_r, filter_set.cont_ram.data, filter_set.cont_ram.we, filter_set.cont_ram.q_r);
	 lut_cont_1 : single_port_ram generic map(8, 8) port map(clk, filter_set.cont_ram.addr_g, filter_set.cont_ram.data, filter_set.cont_ram.we, filter_set.cont_ram.q_g);
	 lut_cont_2 : single_port_ram generic map(8, 8) port map(clk, filter_set.cont_ram.addr_b, filter_set.cont_ram.data, filter_set.cont_ram.we, filter_set.cont_ram.q_b);

    dbg_byte_count <= pixel_counter;
    dbg_page_count <= page_counter;

    with current_state select
        dbg_state <= x"1" when s_wait_for_com,
        x"2" when s_receive_pic,
        x"3" when s_ram_fullpagewrite,
        x"4" when s_transmit_response,
        x"5" when s_wait_for_tx,
        x"8" when s_ram_rd,
		  x"9" when s_brightness,
		  x"a" when s_write_cont_lut,
		  x"b" when s_cont,
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
    next_state_logic : process (clk, filter_set, reset, current_state, rd_req, rd_done, wr_done, initialized, rx_busy, rx_busy_last, data_in, tx_busy, rx_cmd, pic_received, page_counter, page_received, contrast, brightness)
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
					 elsif rx_busy = '0' and rx_cmd = filter_move_hist and brightness = '0' then
                    next_state <= s_brightness;
					 elsif rx_busy = '0' and rx_cmd = filter_spread_hist and contrast = '0' then
                    next_state <= s_write_cont_lut;						  
                elsif rd_req = '1' then
                    next_state <= s_ram_rd;
                else
                    next_state <= s_wait_for_com;
                end if;
					 
				when s_write_cont_lut =>
					if filter_set.status = '1' then
						next_state <= s_cont;
					else
						next_state <= s_write_cont_lut;
					end if;
					
				when s_cont =>
					if contrast = '1' then
						next_state <= s_wait_for_com;
					else
						next_state <= s_cont;
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
                    next_state <= s_transmit_response;
                else
                    next_state <= s_ram_fullpagewrite;
                end if;

            when s_brightness =>
                if brightness = '1' then
                    next_state <= s_wait_for_com;
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
    output_logic : process (clk, reset, current_state, iADDR, iBA, iDQM, iWE, iCAS, iRAS, iCKE, iCS, buf_y, rx_busy, byte_toggle, pixel_counter, page_counter, data_in, rec_buff_b, rec_buff_rg, ram0)

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
        variable dbg_refresh_int   : integer range 0 to 65000 := 0;
        variable brgt_cnt          : integer range 0 to 4095 := 0;
        variable br                : integer range 0 to 31 := 0;
        variable i                 : integer range 0 to 511 := 0;
        variable bank              : integer range 0 to 3 := 0;
        
		variable cont_rec		   : integer range 0 to 3 := 0;
		variable cont_lut_addr	   : integer range 0 to 256 := 0;
		variable cont_lut_cnt	   : integer range 0 to 10 := 0;
		variable cont_state        : integer range 0 to 31 := 0;
		variable cont_cnt          : integer range 0 to 4095 := 0;
		variable cont_i            : integer range 0 to 511 := 0;
		variable cont_cnt2         : integer range 0 to 31 := 0;
		variable cont_cnt3         : integer range 0 to 511 := 0;
          --variable received_pic_counter : integer range 0 to 7 := 0;

        variable rx_cmd_var : t_rx_com := unidentified;

    begin
        if (reset = '0') then
            --iDQ      <= "ZZZZZZZZZZZZZZZZ";
            iADDR       <= "0000000000000";
            iBA         <= "00";
            iDQM        <= "00";
            iWE         <= '0';
            iCAS        <= '0';
            iRAS        <= '0';
            iCKE        <= '0';
            iCS         <= '1';
            buf_y       <= "0000000001";
            byte_toggle <= "00";
            bank := 0;

            initialized  <= '0';
            rd_req       <= '0';
            rd_done      <= '0';
            rx_busy_last <= '0';
            rx_cmd       <= unidentified;
            pic_received <= '0';
            brightness   <= '0';
				contrast		 <= '0';

            pixel_counter <= 0;
            page_counter  <= 0;
				
				filter_set.status <= '0';

            ram0.we_r <= '0';
            ram0.we_g <= '0';
            ram0.we_b <= '0';
            ram1.we_r <= '0';
            ram1.we_g <= '0';
            ram1.we_b <= '0';
            ram5.we_r <= '0';
            ram5.we_g <= '0';
            ram5.we_b <= '0';

            cnt1          := 0;
            cnt2          := 0;
            init          := 0;
            pic_x         := 0;
            bf_y          := 0; --speichert letzten Zeile des picture arrays zum Vergleich mit VGA-Modul
            rd_cnt        := 0;
            row           := 4;
            rd            := 0;
            cnt3          := 0;
            wr            := 0;
            page_to_write := 0;
            bank          := 0;
            brgt_cnt      := 0;
            br            := 0;
            i             := 0;
                --received_pic_counter := 0;

        elsif (clk'EVENT and clk = '1') then



            case current_state is

                ---------------------------------------------------------------------------------------
                -- Paas stuff -------------------------------------------------------------------------
                -- get this shiat done ----------------------------------------------------------------
                ---------------------------------------------------------------------------------------
                when s_wait_for_com =>
                    wr_done      <= '0';
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
						  
						  --filter_set.status <= '0';

                          --previous s_sram_idle
                    rd_done <= '0';
                    iADDR   <= "1111111111111"; iBA <= "11"; iDQM <= "11"; iCKE <= '1'; iCS <= '1'; iRAS <= '1'; iCAS <= '1'; iWE <= '1'; --alles auf High, kein Befehl ausfuehren

                    pic_x := to_integer(unsigned(Hcnt));

                    if pic_x = 455 and Vcnt = buf_y then
                        rd_req <= '1';
                    end if;

                when s_transmit_response =>
                    rx_cmd       <= unidentified;
                    data_out     <= get_tx_command(tx_cmd);
                    TX_start     <= '1';
                    rx_busy_last <= '0';

                when s_wait_for_tx =>
                    TX_start     <= '0';
                    rx_busy_last <= '0';

                when s_receive_pic =>
                          --ram0.we <= '0';
                    wr_done <= '0';

                    outer_if : if pixel_counter = 256 then
                                    -- page done
                        pixel_counter <= 0;
                        byte_toggle   <= "00";
                        page_counter  <= page_counter + 1;
                        page_received <= '1';
                        ram0.we_r       <= '0';
                        ram0.we_g       <= '0';
                        ram0.we_b       <= '0';

                    elsif page_counter = 3072 then --3072
                                    --done
                        pixel_counter <= 0;
                        byte_toggle   <= "00";
                        pic_received  <= '1';
                        ram0.we_r       <= '0';
                        ram0.we_g       <= '0';
                        ram0.we_b       <= '0';

                    elsif rx_busy = '1' then
                        rx_busy_last <= '1';
                    elsif rx_busy = '0' and rx_busy_last = '1' then
                        rx_busy_last <= '0';
                        ram0.we_r       <= '1';
                        ram0.we_g       <= '1';
                        ram0.we_b       <= '1';

                        inner_if : if byte_toggle = "00" then
                            ram0.addr   <= pixel_counter;
                            ram0.data_r <= data_in;
                            byte_toggle <= "01";

                        elsif byte_toggle = "01" then
                            ram0.addr   <= pixel_counter;
                            ram0.data_g <= data_in;
                            byte_toggle <= "10";

                        elsif byte_toggle = "10" then
                            ram0.addr     <= pixel_counter;
                            ram0.data_b   <= data_in;
                            byte_toggle   <= "00";
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
                        wr   := wr+1;
                        cnt3 := 0;

                    elsif wr = 1 then       --tRCD
                        iCS <= '1';
                        if cnt2 = 0 then
                            cnt2 := cnt2+1;

                        elsif cnt2 = 1 then
                            cnt2 := cnt2+1;
                            ram0.addr <= cnt3;
                            cnt3 := cnt3+1;
                        else
                            ram0.addr <= cnt3;
                            cnt3 := cnt3+1;
                            cnt2 := 0;
                            wr   := wr+1;
                        end if;


                    elsif wr = 2 then       --write
                        iADDR     <= "0000000000000"; iBA <= "00"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '0';
                        ram0.addr <= cnt3;
                        DRAM_DQ   <= ram0.q_r & ram0.q_g;
                        cnt3 := cnt3+1;
                        wr   := wr+1;



                    elsif wr = 3 then       --write die restlichen 255 words
                        iCS <= '1';
                        if cnt3 < 259 then
                            ram0.addr <= cnt3;
                            DRAM_DQ   <= ram0.q_r & ram0.q_g;
                            cnt3 := cnt3+1;
                        else
                            iRAS <= '1'; iCAS <= '1'; iWE <= '0'; iCS <= '0';   --burststop
                            cnt3 := 0;
                            wr   := wr+1;
                        end if;

                    elsif wr = 4 then       --tRDL
                        iCS <= '1';
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
                        wr   := wr+1;
                        cnt3 := 0;

                    elsif wr = 8 then       --tRCD
                        iCS <= '1';
                        if cnt2 = 0 then
                            cnt2 := cnt2+1;

                        elsif cnt2 = 1 then
                            cnt2 := cnt2+1;
                            ram0.addr <= cnt3;
                            cnt3 := cnt3+1;
                        else
                            ram0.addr <= cnt3;
                            cnt3 := cnt3+1;
                            cnt2 := 0;
                            wr   := wr+1;
                        end if;

                    elsif wr = 9 then       --write
                        iADDR     <= "0000000000000"; iBA <= "01"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '0';
                        ram0.addr <= cnt3;
                        DRAM_DQ   <= ram0.q_b & x"00";
                        cnt3 := cnt3+1;
                        wr   := wr+1;



                    elsif wr = 10 then       --write die restlichen 255 words
                        iCS <= '1';
                        if cnt3 < 259 then
                            ram0.addr <= cnt3;
                            DRAM_DQ   <= ram0.q_b & x"00";
                            cnt3 := cnt3+1;
                        else
                            iRAS <= '1'; iCAS <= '1'; iWE <= '0'; iCS <= '0';   --burststop
                            cnt3 := 0;
                            wr   := wr+1;
                        end if;

                    elsif wr = 11 then       --tRDL
                        iCS <= '1';
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
                        if cnt2 < 9 then
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
                            if cnt2 < 3 then
                                cnt2 := cnt2+1;
                            else
                                rd   := rd+1;
                                cnt2 := 0;
                                cnt3 := 0;
                            end if;

                        elsif rd = 4 then           --einlesen der naechsten 256 Werte auf dem DQ-Bus
                            if cnt3 < 256 then

                                if rd_cnt = 0 then
                                    r_buf0(cnt3) <= DRAM_DQ(15 downto 8);
                                    g_buf0(cnt3) <= DRAM_DQ(7 downto 0);

                                elsif rd_cnt = 1 then
                                    r_buf1(cnt3) <= DRAM_DQ(15 downto 8);
                                    g_buf1(cnt3) <= DRAM_DQ(7 downto 0);

                                elsif rd_cnt = 2 then
                                    r_buf2(cnt3) <= DRAM_DQ(15 downto 8);
                                    g_buf2(cnt3) <= DRAM_DQ(7 downto 0);

                                elsif rd_cnt = 3 then
                                    r_buf3(cnt3) <= DRAM_DQ(15 downto 8);
                                    g_buf3(cnt3) <= DRAM_DQ(7 downto 0);

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
                            if cnt2 < 3 then
                                cnt2 := cnt2+1;
                            else
                                rd   := rd+1;
                                cnt2 := 0;
                                cnt3 := 0;
                            end if;

                        elsif rd = 11 then           --einlesen der naechsten 256 Werte auf dem DQ-Bus
                            if cnt3 < 256 then

                                if rd_cnt = 0 then
                                    b_buf0(cnt3) <= DRAM_DQ(15 downto 8);

                                elsif rd_cnt = 1 then
                                    b_buf1(cnt3) <= DRAM_DQ(15 downto 8);

                                elsif rd_cnt = 2 then
                                    b_buf2(cnt3) <= DRAM_DQ(15 downto 8);

                                elsif rd_cnt = 3 then
                                    b_buf3(cnt3) <= DRAM_DQ(15 downto 8);

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

                        bf_y := bf_y+1;
                        if bf_y > 767 then
                            bf_y := 0;
                        end if;
                        buf_y <= std_LOGIC_VECTOR(to_unsigned(bf_y, buf_y'length));



                        rd_cnt := 0;
                        rd_done <= '1';                                             --wieder in den Zustand s_ram_idle versetzen

                    end if;


                     --#######################################################################################################################
                     -- s_brightness #########################################################################################################
                     -- veraendert jeden Farbkanal um den uebergebenen Wert ##################################################################
                     --#######################################################################################################################
                when s_brightness =>
                    dbg_refresh_int := dbg_refresh_int+1;
						  if rx_busy = '1' then
                        rx_busy_last <= '1';
                    elsif rx_busy = '0' and rx_busy_last = '1' then
							   filter_set.move_hist <= signed(data_in);
								filter_set.status <= '1';
								rx_busy_last <= '0';
                    elsif brgt_cnt < 3072 and filter_set.status = '1' then
                        if br = 0 then              --Bank Active (ACT) + brgt_cnt auf adresspin
                            DRAM_DQ <= "ZZZZZZZZZZZZZZZZ";
                            iADDR   <= std_logic_vector(to_unsigned(brgt_cnt, iADDR'length)); iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
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
                            if cnt2 < 3 then
                                cnt2 := cnt2+1;
                            else
                                br   := br+1;
                                cnt2 := 0;
                                cnt3 := 0;
                            end if;

                        elsif br = 4 then           --einlesen der naechsten 256 Werte auf dem DQ-Bus
                            if cnt3 < 256 then
                                ram5.we_r     <= '1';
                                ram5.we_g     <= '1';
                                ram5.addr   <= cnt3;
                                ram5.data_r <= DRAM_DQ(15 downto 8);
                                ram5.data_g <= DRAM_DQ(7 downto 0);
                                cnt3 := cnt3+1;
                            else
                                ram5.we_r     <= '0';
                                ram5.we_g     <= '0';
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
                            if cnt2 < 3 then
                                cnt2 := cnt2+1;
                            else
                                br   := br+1;
                                cnt2 := 0;
                                cnt3 := 0;
                            end if;

                        elsif br = 11 then           --einlesen der naechsten 256 Werte auf dem DQ-Bus
                            if cnt3 < 256 then
                                ram5.we_b     <= '1';
                                ram5.addr   <= cnt3;
                                ram5.data_b <= DRAM_DQ(15 downto 8);
                                cnt3 := cnt3+1;
                            else
                                ram5.we_b <= '0';
                                br   := br+1;
                                cnt3 := 0;
                            end if;


                        elsif br = 12 then         --precharge
                            iADDR <= "0010000000000"; iBA <= "01"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            br := br+1;

                        elsif br = 13 then         --trp
                            iCS <= '1';
                            if cnt2 = 0 then
                                cnt2 := cnt2+1;
                                cnt3 := 0;
                            elsif cnt2 = 1 then
                                cnt2 := cnt2+1;
                                ram5.addr <= cnt3;
                                cnt3:= cnt3+1;
                            else
                                ram5.addr <= cnt3;
                                cnt3 := cnt3+1;
                                cnt2 := 0;
                                br   := br+1;
                            end if;

                        elsif br = 14 then
                            if i < 256 then
                                ram1.we_r <= '1';
                                ram1.we_g <= '1';
                                ram1.we_b <= '1';
                                          -- do magic here
                                ram1.addr <= i;
                                ram1.data_r <= std_logic_vector(capped_add_8(unsigned(ram5.q_r), filter_set.move_hist));
                                ram1.data_g <= std_logic_vector(capped_add_8(unsigned(ram5.q_g), filter_set.move_hist));
                                ram1.data_b <= std_logic_vector(capped_add_8(unsigned(ram5.q_b), filter_set.move_hist));
                                ram5.addr <= cnt3;
                                cnt3 := cnt3+1;                              
                                i := i+1;
                            else
                                ram1.we_r <= '0';
                                ram1.we_g <= '0';
                                ram1.we_b <= '0';
                                br := br+1;
                                i  := 0;
                            end if;
                            
                        elsif br = 15 then        --bank active
                            iADDR <= std_LOGIC_VECTOR(to_unsigned((brgt_cnt), iADDR'length)); iBA <= "10"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                            br := br+1;

                        elsif br = 16 then       --tRCD
                            iCS <= '1';
                            if cnt2 = 0 then
                                cnt2 := cnt2+1;
                                cnt3 := 0;
                            elsif cnt2 = 1 then
                                cnt2 := cnt2+1;
                                ram1.addr <= cnt3;
                                cnt3:= cnt3+1;
                            else
                                ram1.addr <= cnt3;
                                cnt3 := cnt3+1;
                                cnt2 := 0;
                                br   := br+1;
                            end if;

                        elsif br = 17 then       --write
                            iADDR     <= "0000000000000"; iBA <= "10"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '0';
                            ram1.addr <= cnt3;
                            DRAM_DQ   <= ram1.q_r & ram1.q_g;
                            cnt3 := cnt3+1;
                            br   := br+1;



                        elsif br = 18 then       --write die restlichen 255 words
                            iCS <= '1';
                            if cnt3 < 259 then
                                ram1.addr <= cnt3;
                                DRAM_DQ   <= ram1.q_r & ram1.q_g;
                                cnt3 := cnt3+1;
                            else
                                iRAS <= '1'; iCAS <= '1'; iWE <= '0'; iCS <= '0';   --burststop
                                cnt3 := 0;
                                br   := br+1;
                            end if;

                        elsif br = 19 then       --tRDL
                            iCS <= '1';
                            if cnt3 < 1 then
                                cnt3 := cnt3+1;
                            else
                                cnt3 := 0;
                                br   := br+1;
                            end if;

                        elsif br = 20 then       --precharge
                            iADDR <= "0010000000000"; iBA <= "10"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            br := br+1;

                        elsif br = 21 then       --tRP
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
                            if cnt2 = 0 then
                                cnt2 := cnt2+1;
                                cnt3 := 0;
                            elsif cnt2 = 1 then
                                cnt2 := cnt2+1;
                                ram1.addr <= cnt3;
                                cnt3:= cnt3+1;
                            else
                                ram1.addr <= cnt3;
                                cnt3 := cnt3+1;
                                cnt2 := 0;
                                br   := br+1;
                            end if;

                        elsif br = 24 then       --write
                            iADDR     <= "0000000000000"; iBA <= "11"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '0';
                            ram1.addr <= cnt3;
                            DRAM_DQ   <= ram1.q_b & x"00";
                            cnt3 := cnt3+1;
                            br   := br+1;

                        elsif br = 25 then       --write die restlichen 255 words
                            iCS <= '1';
                            if cnt3 < 259 then
                                ram1.addr <= cnt3;
                                DRAM_DQ   <= ram1.q_b & x"00";
                                cnt3 := cnt3+1;
                            else
                                iRAS <= '1'; iCAS <= '1'; iWE <= '0'; iCS <= '0';   --burststop
                                cnt3 := 0;
                                br   := br+1;
                            end if;

                        elsif br = 26 then       --tRDL
                            iCS <= '1';
                            if cnt3 < 1 then
                                cnt3 := cnt3+1;
                            else
                                cnt3 := 0;
                                br   := br+1;
                            end if;

                        elsif br = 27 then       --precharge
                            iADDR <= "0010000000000"; iBA <= "11"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            br := br+1;

                        elsif br = 28 then       --tRP
                            iCS <= '1';
                            if cnt2 < 2 then
                                cnt2 := cnt2+1;
                            else
                                dbg_refresh_cyc <= std_LOGIC_VECTOR(to_unsigned(dbg_refresh_int, 16));
                                dbg_refresh_int := 0;
                                brgt_cnt        := brgt_cnt +1;
                                cnt2            := 0;
                                br              := 0;

                            end if;
                        else
                            br := 0;
                        end if;
                    elsif filter_set.status = '1' then
                        brightness <= '1';
								--rx_cmd <= unidentified;
                        bank := 2;
								filter_set.status <= '0';
                    end if;
						  
					 when s_write_cont_lut =>
                          --write look-up table for histogramm spreading in ram
                          cont_if_1 : if rx_busy = '1' then
                              rx_busy_last <= '1';
                          elsif rx_busy = '0' and rx_busy_last = '1' then
                              cont_if_2 : if cont_rec = 0 then
                                  filter_set.cont_g_min <= unsigned(data_in);
                              elsif cont_rec = 1 then
                                  filter_set.cont_g_max <= unsigned(data_in);
                              end if cont_if_2;
                              cont_rec := cont_rec + 1;
                              rx_busy_last <= '0';
                              cont_lut_addr := 0;

                          elsif cont_lut_addr = 256 then
                                --calculation done, moving on
                              filter_set.status <= '1';
                              cont_rec      := 0;
                              cont_lut_addr := 0;
                              cont_lut_cnt  := 0;
                              filter_set.cont_ram.we <= '0';

                          elsif cont_rec = 2 then
                              filter_set.cont_ram.we <= '1';
                               --min and max values recieved, calculating LUT
                              filter_set.cont_ram.addr_r <= cont_lut_addr;
                              filter_set.cont_ram.addr_g <= cont_lut_addr;
                              filter_set.cont_ram.addr_b <= cont_lut_addr;
                              if cont_lut_cnt < 6 then
                                  filter_set.cont_ram.data <= std_logic_vector(hist_stretch_calc(to_unsigned(cont_lut_addr, 8), unsigned(filter_set.cont_g_min), unsigned(filter_set.cont_g_max)));
                                  cont_lut_cnt := cont_lut_cnt + 1;
                              else
                                  cont_lut_addr := cont_lut_addr + 1;
                                  cont_lut_cnt  := 0;
                              end if;

                          end if cont_if_1;

							
							
							
                    when s_cont =>
                          dbg_refresh_int := dbg_refresh_int+1;
                    if cont_cnt < 3072  then
                        if cont_state = 0 then              --Bank Active (ACT) + cont_cnt auf adresspin
                            DRAM_DQ <= "ZZZZZZZZZZZZZZZZ";
                            iADDR   <= std_logic_vector(to_unsigned(cont_cnt, iADDR'length)); iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                            cont_state := cont_state+1;

                        elsif cont_state = 1 then           --tRCD
                            iCS <= '1';
                            if cont_cnt2 < 2 then
                                cont_cnt2 := cont_cnt2+1;
                            else
                                cont_cnt2       := 0;
                                cont_state := cont_state+1;
                            end if;

                        elsif cont_state = 2 then           --rd  w/o precharge command + column auf Adresspin
                            iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '1';
                            cont_state := cont_state+1;

                        elsif cont_state = 3 then           --CAS latency
                            iCS <= '1';
                            if cont_cnt2 < 3 then
                                cont_cnt2 := cont_cnt2+1;
                            else
                                cont_state := cont_state+1;
                                cont_cnt2       := 0;
                                cont_cnt3       := 0;
                            end if;

                        elsif cont_state = 4 then           --einlesen der naechsten 256 Werte auf dem DQ-Bus
                            if cont_cnt3 < 256 then
                                ram5.we_r   <= '1';
                                ram5.we_g   <= '1';
                                ram5.addr   <= cont_cnt3;
                                ram5.data_r <= DRAM_DQ(15 downto 8);
                                ram5.data_g <= DRAM_DQ(7 downto 0);
                                cont_cnt3 := cont_cnt3+1;
                            else
                                ram5.we_r <= '0';
                                ram5.we_g <= '0';
                                cont_state := cont_state+1;
                                cont_cnt3       := 0;
                            end if;


                        elsif cont_state = 5 then         --precharge
                            iADDR <= "0010000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            cont_state := cont_state+1;

                        elsif cont_state = 6 then         --trp
                            iCS <= '1';
                            if cont_cnt2 < 9 then
                                cont_cnt2 := cont_cnt2+1;
                            else
                                cont_state := cont_state+1;
                                cont_cnt2       := 0;

                            end if;

                        elsif cont_state = 7 then              --Bank Active (ACT) + row auf adresspin
                            iADDR <= std_logic_vector(to_unsigned(cont_cnt, iADDR'length)); iBA <= "01"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                            cont_state := cont_state+1;

                        elsif cont_state = 8 then           --tRCD
                            iCS <= '1';
                            if cont_cnt2 < 2 then
                                cont_cnt2 := cont_cnt2+1;
                            else
                                cont_cnt2       := 0;
                                cont_state := cont_state+1;
                            end if;

                        elsif cont_state = 9 then           --rd  w/o precharge command + column auf Adresspin
                            iADDR <= "0000000000000"; iBA <= "01"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '1';
                            cont_state := cont_state+1;

                        elsif cont_state = 10 then           --CAS latency
                            iCS <= '1';
                            if cont_cnt2 < 3 then
                                cont_cnt2 := cont_cnt2+1;
                            else
                                cont_state := cont_state+1;
                                cont_cnt2       := 0;
                                cont_cnt3       := 0;
                            end if;

                        elsif cont_state = 11 then           --einlesen der naechsten 256 Werte auf dem DQ-Bus
                            if cont_cnt3 < 256 then
                                ram5.we_b   <= '1';
                                ram5.addr   <= cont_cnt3;
                                ram5.data_b <= DRAM_DQ(15 downto 8);
                                cont_cnt3 := cont_cnt3+1;
                            else
                                ram5.we_b <= '0';
                                cont_state := cont_state+1;
                                cont_cnt3       := 0;
                            end if;


                        elsif cont_state = 12 then         --precharge
                            iADDR <= "0010000000000"; iBA <= "01"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            cont_state := cont_state+1;

                        elsif cont_state = 13 then         --trp
                            iCS <= '1';
                            if cont_cnt2 = 0 then
                                cont_cnt2 := cont_cnt2+1;
                                cont_cnt3 := 0;
                            elsif cont_cnt2 = 1 then
                                cont_cnt2 := cont_cnt2+1;
                                ram5.addr <= cont_cnt3;
                                cont_cnt3 := cont_cnt3+1;
                            else
                                ram5.addr <= cont_cnt3;
                                cont_cnt3       := cont_cnt3+1;
                                cont_cnt2       := 0;
                                cont_state := cont_state+1;
                            end if;

                        elsif cont_state = 14 then
                            ram1.we_r <= '1';
                            ram1.we_g <= '1';
                            ram1.we_b <= '1';
                                          -- do magic here
                            ram1.addr <= cont_i;
                            if cont_lut_cnt = 0 and cont_i = 256 then
									     --done
                                cont_state := cont_state +1;
                                ram1.we_r <= '0';
                                ram1.we_g <= '0';
                                ram1.we_b <= '0';										  
									 elsif cont_lut_cnt = 0 then
									     --write adresses to filter lut
                                filter_set.cont_ram.addr_r <= to_integer(unsigned(ram5.q_r));
                                filter_set.cont_ram.addr_g <= to_integer(unsigned(ram5.q_g));
                                filter_set.cont_ram.addr_b <= to_integer(unsigned(ram5.q_b));
                                ram5.addr                  <= cont_i;
                                cont_lut_cnt := cont_lut_cnt + 1;
                            elsif cont_lut_cnt < 2 then
									     -- wait 2 cycles
                                cont_lut_cnt := cont_lut_cnt + 1;
                            elsif cont_lut_cnt = 2 then
									     -- write data of lut into ram, increment adress counters
                                ram1.data_r <= filter_set.cont_ram.q_r;
                                ram1.data_g <= filter_set.cont_ram.q_g;
                                ram1.data_b <= filter_set.cont_ram.q_b;
                                cont_cnt3         := cont_cnt3+1;
                                cont_lut_cnt := 0;
                                cont_i            := cont_i+1;
                            end if;

                        elsif cont_state = 15 then        --bank active
                            iADDR <= std_LOGIC_VECTOR(to_unsigned((cont_cnt), iADDR'length)); iBA <= "10"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                            cont_state := cont_state+1;

                        elsif cont_state = 16 then       --tRCD
                            iCS <= '1';
                            if cont_cnt2 = 0 then
                                cont_cnt2 := cont_cnt2+1;
                                cont_cnt3 := 0;
                            elsif cont_cnt2 = 1 then
                                cont_cnt2 := cont_cnt2+1;
                                ram1.addr <= cont_cnt3;
                                cont_cnt3 := cont_cnt3+1;
                            else
                                ram1.addr <= cont_cnt3;
                                cont_cnt3       := cont_cnt3+1;
                                cont_cnt2       := 0;
                                cont_state := cont_state+1;
                            end if;

                        elsif cont_state = 17 then       --write
                            iADDR     <= "0000000000000"; iBA <= "10"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '0';
                            ram1.addr <= cont_cnt3;
                            DRAM_DQ   <= ram1.q_r & ram1.q_g;
                            cont_cnt3       := cont_cnt3+1;
                            cont_state := cont_state+1;



                        elsif cont_state = 18 then       --write die restlichen 255 words
                            iCS <= '1';
                            if cont_cnt3 < 259 then
                                ram1.addr <= cont_cnt3;
                                DRAM_DQ   <= ram1.q_r & ram1.q_g;
                                cont_cnt3 := cont_cnt3+1;
                            else
                                iRAS <= '1'; iCAS <= '1'; iWE <= '0'; iCS <= '0';   --burststop
                                cont_cnt3       := 0;
                                cont_state := cont_state+1;
                            end if;

                        elsif cont_state = 19 then       --tRDL
                            iCS <= '1';
                            if cont_cnt3 < 1 then
                                cont_cnt3 := cont_cnt3+1;
                            else
                                cont_cnt3       := 0;
                                cont_state := cont_state+1;
                            end if;

                        elsif cont_state = 20 then       --precharge
                            iADDR <= "0010000000000"; iBA <= "10"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            cont_state := cont_state+1;

                        elsif cont_state = 21 then       --tRP
                            iCS <= '1';
                            if cont_cnt2 < 9 then
                                cont_cnt2 := cont_cnt2+1;
                            else
                                cont_cnt2       := 0;
                                cont_state := cont_state+1;

                            end if;

                        elsif cont_state = 22 then          --bank active
                            iADDR <= std_LOGIC_VECTOR(to_unsigned((cont_cnt), iADDR'length)); iBA <= "11"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                            cont_state := cont_state+1;

                        elsif cont_state = 23 then       --tRCD
                            iCS <= '1';
                            if cont_cnt2 = 0 then
                                cont_cnt2 := cont_cnt2+1;
                                cont_cnt3 := 0;
                            elsif cont_cnt2 = 1 then
                                cont_cnt2 := cont_cnt2+1;
                                ram1.addr <= cont_cnt3;
                                cont_cnt3 := cont_cnt3+1;
                            else
                                ram1.addr <= cont_cnt3;
                                cont_cnt3       := cont_cnt3+1;
                                cont_cnt2       := 0;
                                cont_state := cont_state+1;
                            end if;

                        elsif cont_state = 24 then       --write
                            iADDR     <= "0000000000000"; iBA <= "11"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '0';
                            ram1.addr <= cont_cnt3;
                            DRAM_DQ   <= ram1.q_b & x"00";
                            cont_cnt3       := cont_cnt3+1;
                            cont_state := cont_state+1;

                        elsif cont_state = 25 then       --write die restlichen 255 words
                            iCS <= '1';
                            if cont_cnt3 < 259 then
                                ram1.addr <= cont_cnt3;
                                DRAM_DQ   <= ram1.q_b & x"00";
                                cont_cnt3 := cont_cnt3+1;
                            else
                                iRAS <= '1'; iCAS <= '1'; iWE <= '0'; iCS <= '0';   --burststop
                                cont_cnt3       := 0;
                                cont_state := cont_state+1;
                            end if;

                        elsif cont_state = 26 then       --tRDL
                            iCS <= '1';
                            if cont_cnt3 < 1 then
                                cont_cnt3 := cont_cnt3+1;
                            else
                                cont_cnt3       := 0;
                                cont_state := cont_state+1;
                            end if;

                        elsif cont_state = 27 then       --precharge
                            iADDR <= "0010000000000"; iBA <= "11"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            cont_state := cont_state+1;

                        elsif cont_state = 28 then       --tRP
                            iCS <= '1';
                            if cont_cnt2 < 2 then
                                cont_cnt2 := cont_cnt2+1;
                            else
                                dbg_refresh_cyc <= std_LOGIC_VECTOR(to_unsigned(dbg_refresh_int, 16));
                                dbg_refresh_int := 0;
                                cont_cnt        := cont_cnt +1;
                                cont_cnt2            := 0;
                                cont_state      := 0;

                            end if;
                        else
                            cont_state := 0;
                        end if;
                    else
                        contrast <= '1';
                        bank := 2;
                        filter_set.status <= '0';
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
    VGA_out : process (clk, reset, current_state, ipixel, Hcnt, Vcnt, buf_y, r_buf0, r_buf1, r_buf2, r_buf3, g_buf0, g_buf1, g_buf2, g_buf3, b_buf0, b_buf1, b_buf2, b_buf3)

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

                    if pic_x < 256 then
                        ipixel <= r_buf0(pic_x) & g_buf0(pic_x) & b_buf0(pic_x);
                    elsif pic_x > 255 and pic_x < 512 then
                        ipixel <= r_buf1(pic_x-256) & g_buf1(pic_x-256) & b_buf1(pic_x-256);
                    elsif pic_x > 511 and pic_x < 768 then
                        ipixel <= r_buf2(pic_x-512) & g_buf2(pic_x-512) & b_buf2(pic_x-512);
                    else
                        ipixel <= r_buf3(pic_x-768) & g_buf3(pic_x-768) & b_buf3(pic_x-768);
                    end if;


                when s_ram_rd =>
                    pic_x := to_integer(unsigned(Hcnt(10 downto 0)));

                    if pic_x < 256 then
                        ipixel <= r_buf0(pic_x) & g_buf0(pic_x) & b_buf0(pic_x);
                    elsif pic_x > 255 and pic_x < 512 then
                        ipixel <= r_buf1(pic_x-256) & g_buf1(pic_x-256) & b_buf1(pic_x-256);
                    elsif pic_x > 511 and pic_x < 768 then
                        ipixel <= r_buf2(pic_x-512) & g_buf2(pic_x-512) & b_buf2(pic_x-512);
                    else
                        ipixel <= r_buf3(pic_x-768) & g_buf3(pic_x-768) & b_buf3(pic_x-768);
                    end if;



                when s_brightness =>
                    ipixel <= x"00FFFF";
						  
					 when s_cont =>
                    ipixel <= x"00FFFF";

                when others =>
                    null;
            end case;
        end if;

        pixel <= ipixel;

    end process VGA_out;



end beh;
