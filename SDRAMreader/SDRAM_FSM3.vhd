--SDRAM controller als FSM realisiert
--gibt grundlegende Struktur vor, aendert 1x pro sekunde den angezeigten Farbwert
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SDRAM_FSM3 is

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

end entity SDRAM_FSM3;

architecture beh of SDRAM_FSM3 is

    -- interne States
    type states is (s_init, s_idle, s_read);
    signal current_state, next_state : states;

     --interne Signale fuer Ausgangspins
    signal   iDQ                   : STD_LOGIC_VECTOR(15 downto 0) := "ZZZZZZZZZZZZZZZZ";
    signal   iADDR                 : STD_LOGIC_VECTOR(12 downto 0) := "0000000000000";
    signal   iBA, iDQM             : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal   iWE, iCAS, iRAS, iCKE : STD_LOGIC := '0';
    signal   iCS                   : STD_LOGIC := '1';
    signal   ipixel                : STD_LOGIC_VECTOR(15 downto 0) := x"0000";

    -- Buffer fuer 8 Zeilen des anzuzeigenden Bildes
    type pic_array is array (0 to 7) of std_logic_vector(11 downto 0);
    signal pic_buf : pic_array := (others => x"FFF");

    --iterne Signale fuer Kommunikation zwischen den Prozessen
    signal  initialized, rd_done, rd_req : STD_LOGIC := '0';
    signal buf_y                         : STD_LOGIC_VECTOR(9 downto 0) := "0000000111"; --speichert global die Nummer der letzten gepufferten Bildzeile

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
    next_state_logic : process (current_state, rd_req, rd_done, initialized)
    begin
        case current_state is
            when s_init =>
                if initialized = '1' then
                    next_state <= s_idle;
                else
                    next_state <= s_init;
                end if;

            when s_idle =>
                if  rd_req = '1' then
                    next_state <= s_read;
                else
                    next_state <= s_idle;
                end if;

            when s_read =>
                if rd_done = '1' then
                    next_state <= s_idle;
                else
                    next_state <= s_read;
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
        variable bf_y      : integer range 0 to 1023 := 7; --speichert letzten Zeile des picture arrays zum Vergleich mit VGA-Modul
        variable pic_cnt, cyc_cnt : integer range 0 to 127 := 0;
        variable read_cnt         : integer range 0 to 31 := 0;
        variable color            : integer range 0 to 4095 := 3456;

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

            initialized <= '0';
            rd_req      <= '0';
            rd_done     <= '0';

            cnt1     := 0;
            cnt2     := 0;
            init     := 0;
            bf_y     := 7;
            pic_cnt  := 0;
            cyc_cnt  := 0;
            read_cnt := 0;
            color    := 0;

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
                -- Idle -------------------------------------------------------------------------------------------------------------------------------------------
                -- Wartet darauf, dass das VGA-Modul anfaengt die letzte gepufferte Zeile zu lesen und wechselt dann in den Zustand s_read ------------------------
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
                -- read 8 y-lines ---------------------------------------------------------------------------------------------------------------------------------
                -- fuehrt 25 full page reads durch, um 8 Zeilen des displays zu puffern ---------------------------------------------------------------------------
                --------------------------------------------------------------------------------------------------------------------------------------------------- 
                when s_read =>
                    rd_req <= '0';
                    bf_y := to_integer(unsigned(buf_y(9 downto 0)));

                    --pseudoread fuer testzwecke, aendert jede sekunde die Bildschirmfarbe
                    if pic_cnt < 72 then                    --72 Bilder = 1 Sekunde
                        if cyc_cnt < 75 then                --75x25x256 pixel = 1 bild
                            if read_cnt < 25 then           --fuehrt 25 full page reads durch
                                pic_buf(0) <= std_logic_vector(to_unsigned(color, 12)); --platzhalter fuer wirklichen lese algorithmus
                                read_cnt := read_cnt+1;
                            else
                                bf_y := bf_y+8;            --nach 25 reads ist die naechste Startzeile 8 Zeilen weiter
                                if bf_y > 599 then         --falls außerhalb des darstellbaren Bereichs, fangen wir wieder bi 7 an
                                    bf_y := 7;
                                end if;
                                buf_y <= std_logic_vector(to_unsigned(bf_y, buf_y'length)); --wird weiter an globalen Speicher gegeben
                                read_cnt := 0;
                                cyc_cnt  := cyc_cnt+1;
                                rd_done <= '1';                                             --wieder in den Zustand s_idle versetzen
                            end if;
                        else
                            pic_cnt := pic_cnt+1;
                            cyc_cnt := 0;
                        end if;

                    else
                        color   := color+1;
                        pic_cnt := 0;
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

        variable cnt1 : integer range 0 to 150000000 := 0;

    begin
        if (reset = '0') then

            ipixel <= x"0000";

            cnt1 := 0;

        elsif (clk'EVENT and clk = '1') then
            case current_state is
                when s_init =>
                    ipixel <= x"FFFF";

                when s_idle =>
                    ipixel <= "0000" & pic_buf(0);

                when s_read =>
                    ipixel <= "0000" & pic_buf(0);

                when others =>
                    null;
            end case;
        end if;

        pixel <= ipixel;

    end process VGA_out;


end beh;
