LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.graka_pack.all;



package ram_pack is







procedure ram_read
	(signal : in lol;
	 signal : out llol);






end package ram_pack;
--###########################################################################
--end package head, begin package body
--###########################################################################
package body ram_pack is


procedure ram_read
	(signal : in lol;
	 signal : out llol;	
	)is
	
BEGIN

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
                            if cnt2 < 3 then
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
								
								

                        rd_cnt := 0;
                        rd_done <= '1';                                             --wieder in den Zustand s_ram_idle versetzen
								
                    end if;










end package body ram_pack;