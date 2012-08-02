--------------------------------------------------------------------------------
-- Entity: SDRAM_SM1
-- Date:2012-07-30  
-- Author: Chris     
--
-- Description ${cursor}
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SDRAM_FSM1 is
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



end SDRAM_FSM1 ;


architecture fsm of SDRAM_FSM1 is
    --TYPE declarations
    type STATE_TYPE is (s0, s1, s2);
    type buffer_array is array(0 to 799, 0 to 7) of STD_LOGIC_VECTOR(11 downto 0);

   -- Declare current and next state signals
    signal current_state : STATE_TYPE;
    signal next_state    : STATE_TYPE;

   -- Declare any pre-registered internal signals
    signal iDQ                   : STD_LOGIC_VECTOR(15 downto 0) := "0000000000000000";
    signal iADDR                 : STD_LOGIC_VECTOR(12 downto 0) := "0000000000000";
    signal iBA, iDQM             : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal iWE, iCAS, iRAS, iCKE : STD_LOGIC := '0';
    signal iCS                   : STD_LOGIC := '1';
    signal ipixel                : STD_LOGIC_VECTOR(15 downto 0) := "0000000000000000";
    signal initialized           : STD_LOGIC := '0';
    signal buffer_8rows          : buffer_array;
    signal row_buf               : STD_LOGIC_VECTOR(9 downto 0) := "0000001001";
    signal col_buf               : STD_LOGIC_VECTOR(10 downto 0);
    signal rd_done               : STD_LOGIC := '0';

    attribute ramstyle        : string;
    attribute ramstyle of fsm : architecture is "M9K";

begin
    clocked_proc : process (clk, reset)

        variable init                 : integer range 0 to 15 := 0;
        variable cnt1                 : integer range 0 to 32767 := 0;
        variable rd_cnt               : integer range 0 to 31 := 0;
        variable read, y                : integer range 0 to 7 := 0;
        variable x                 : integer range 0 to 1023 := 0;
        variable row_bf               : integer range 0 to 1023 := 7;
        variable ram_row, ram_row_tmp : integer range 0 to 2047 := 25;


    begin
        if (reset = '0') then
            current_state <= s0;
            DRAM_DQ       <= "ZZZZZZZZZZZZZZZZ";
         -- Default Reset Values
            iADDR       <= "0000000000000"; iBA <= "00"; iDQM <= "00"; iCKE <= '0'; iCS <= '1'; iRAS <= '0'; iCAS <= '0'; iWE <= '0';
            iDQ         <= "0000000000000000";
                        initialized <= '0';
            row_buf     <= "0000001001";
            col_buf     <= "00000000000";

            init    := 0;
            cnt1    := 0;
            rd_cnt  := 0;
            read    := 0;
            x       := 0;
            y       := 0;
            row_bf  := 7;
            ram_row := 25;

        elsif (clk'EVENT and clk = '1') then
            current_state <= next_state;
            DRAM_DQ       <= "ZZZZZZZZZZZZZZZZ";    -- im Moment permanent hochohming, da wir nur lesen
            case current_state is

                ---------------------------------------------------------------------------------------------------------------------------
                -- Initialisierung --------------------------------------------------------------------------------------------------------
                -- durchlauft die Initialisierungssequenz laut Datenblatt -----------------------------------------------------------------
                ---------------------------------------------------------------------------------------------------------------------------
                when s0 =>
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
                        if cnt1 < 1 then
                            cnt1 := cnt1+1;
                        else
                            init := init+1;
                            cnt1 := 0;
                        end if;

                    elsif init = 3 then         --REF1
                        iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '0'; iWE <= '1';
                        init := init+1;

                    elsif init = 4 then         --tARFC1
                        iCS <= '1';
                        if cnt1 < 5 then
                            cnt1 := cnt1+1;
                        else
                            cnt1 := 0;
                            init := init+1;
                        end if;
                    elsif init = 5 then         --REF2
                        iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '0'; iWE <= '1';
                        init := init+1;

                    elsif init = 6 then         --tARFC2
                        iCS <= '1';
                        if cnt1 < 5 then
                            cnt1 := cnt1+1;
                        else
                            cnt1 := 0;
                            init := init+1;
                        end if;

                    elsif init = 7 then         --MRS
                        iADDR <= "0000000100111"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '0'; iWE <= '1';
                        init := init+1;

                    elsif init = 8 then         --tMRD
                        iCS <= '1';
                        if cnt1 < 5 then
                            cnt1 := cnt1+1;
                        else
                            cnt1 := 0;
                            init := init+1;
                        end if;

                    elsif init = 9 then           --initialized
                        initialized <= '1';

                    else
                        init := 0;

                    end if;

                ---------------------------------------------------------------------------------------------------------------------------
                -- Idle -------------------------------------------------------------------------------------------------------------------
                -- wartet auf Befehl oder Anfrage -----------------------------------------------------------------------------------------
                ---------------------------------------------------------------------------------------------------------------------------
                when s1 =>
					  rd_done    <= '0';
                    iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '1'; iRAS <= '0'; iCAS <= '0'; iWE <= '0';

                ---------------------------------------------------------------------------------------------------------------------------
                -- Buffering --------------------------------------------------------------------------------------------------------------
                -- buffert 8 Zeilen des Bildes, per 25 full page reads --------------------------------------------------------------------
                ---------------------------------------------------------------------------------------------------------------------------
                when s2 =>


                    if rd_cnt < 25 then
                        if read = 0 then              --ACT
                            ram_row_tmp := ram_row+rd_cnt;

                            iADDR <= std_logic_vector(to_unsigned(ram_row_tmp, iADDR'length));
                            iBA   <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '1';
                            read := read+1;

                        elsif read = 1 then           --tRCD
                            iCS <= '1';
                            if cnt1 < 1 then
                                cnt1 := cnt1+1;
                            else
                                read := read+1;
                                cnt1 := 0;
                            end if;

                        elsif read = 2 then       -- read cmd
                            iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "00"; iCKE <= '1'; iCS <= '0'; iRAS <= '1'; iCAS <= '0'; iWE <= '1';
                            read := read+1;

                        elsif read = 3 then       --CAS latency = 2
                            iCS <= '1';
                            x := 0;
                            y := 0;
                            if cnt1 < 1 then
                                cnt1 := cnt1+1;
                            else
                                read := read+1;
                                cnt1 := 0;
                            end if;

                        elsif read = 4 then       --Speichern der gelesenen Werte im puffer
                            if cnt1 < 255 then
                                buffer_8rows(x,y) <= DRAM_DQ(11 downto 0);
                                if x > 799 then
                                    x := 0;
                                    y := y+1;
                                end if;
                                cnt1 := cnt1+1;
                            else
                                read := read+1;
                                cnt1 := 0;
                            end if;

                        elsif read = 5 then       --precharge
                            iADDR <= "0000000000000"; iBA <= "00"; iDQM <= "11"; iCKE <= '1'; iCS <= '0'; iRAS <= '0'; iCAS <= '1'; iWE <= '0';
                            read := read+1;

                        elsif read = 6 then       --tRP
                            iCS <= '1';
                            if cnt1 < 1 then
                                cnt1 := cnt1+1;
                            else
                                read := read+1;
                                cnt1 := 0;
                            end if;

                        elsif read = 7 then       -- ein full page read beendet
                            rd_cnt := rd_cnt+1;
                            read   := 0;
                        end if;

                    else
                        row_bf := to_integer(unsigned(row_buf(9 downto 0)));
                        row_bf := row_bf+8;
                        row_buf <= std_logic_vector(to_unsigned(row_bf, row_buf'length));
                        ram_row := ram_row+25;
                        if ram_row > 1877 then
                            ram_row := 0;
                        end if;
                        rd_done <= '1';
                        rd_cnt := 0;

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
        nCS       <= iCS;
        nCKE      <= iCKE;

    end process clocked_proc;

   -----------------------------------------------------------------
   -----------------------------------------------------------------
   -----------------------------------------------------------------
    nextstate_proc : process (current_state, initialized )

        variable row_proc, row_bf : integer range 0 to 1023 := 7;
        variable col_proc, col_bf : integer range 0 to 2047 := 0;
    begin
        case current_state is
            when s0 =>
                if initialized = '1' then
                    next_state <= s1;
                else
                    next_state <= s0;
                end if;

            when s1 =>
                row_proc := to_integer(unsigned(Vcnt(9 downto 0)));
                col_proc := to_integer(unsigned(Hcnt(10 downto 0)));
                row_bf   := to_integer(unsigned(row_buf(9 downto 0)));

                if col_proc = 0 and row_proc = row_bf then                --wenn VGA Modul anfaengt letzte Zeile zu schreiben
                    next_state <= s2;
                else
                    next_state <= s1;
                end if;

            when s2 =>
                if rd_done = '1' then
                    next_state <= s1;
                   

                else
                    next_state <= s2;
                end if;

            when others =>
                next_state <= s0;
        end case;
    end process nextstate_proc;


    ------------------------------------------------------------------
    ------------------------------------------------------------------
    ------------------------------------------------------------------
    pixel_output : process (clk, reset, current_state, ipixel, Hcnt, Vcnt, row_buf )

        variable row    : integer range 0 to 1023 := 0;
        variable column : integer range 0 to 1023 := 0;
        variable row_bf : integer range 0 to 1023 := 7;

    begin
        if (reset = '0') then
            
         -- Default Reset Values
            row:=0;
            column:=0;
            row_bf:=0;

        elsif (clk'EVENT and clk = '1') then
            case current_state is
                when s0 =>
                    ipixel <= x"FFFF";
                when s1 =>
                    column := to_integer(unsigned(Hcnt(9 downto 0)));
                    row_bf := to_integer(unsigned(row_buf(9 downto 0)));
                    row    := to_integer(unsigned(Vcnt(9 downto 0)));


                    ipixel <= "0000" & buffer_8rows(column, (row - row_bf));

                when s2 =>

                    column := to_integer(unsigned(Hcnt(9 downto 0)));
                    row_bf := to_integer(unsigned(row_buf(9 downto 0)));
                    row    := to_integer(unsigned(Vcnt(9 downto 0)));


                    ipixel <= "0000" & buffer_8rows(column, (row - row_bf));


                when others =>
                    null;
            end case;
        end if;
        
        
        pixel     <= ipixel;
        
    end process pixel_output;


end fsm;
