-- Christoph Paa


LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;





package graka_pack is

--###########################################################################
--constants
constant c_COM_LENGTH : integer range 0 to 16 := 8;

--###########################################################################
--types
type t_rx_com is (rec_pic, end_pic, check_com, filter_move_hist, filter_spread_hist, unidentified);
type t_tx_com is (board_ack, end_of_block, unidentified);
type t_command_array is ARRAY(0 to 4) of std_logic_vector(c_COM_LENGTH-1 downto 0);
type t_rec_buff_rg is ARRAY(0 to 255) of std_logic_vector(15 downto 0);
type t_rec_buff_b is ARRAY(0 to 255) of std_logic_vector(7 downto 0);

type t_cram is record
	addr	:  natural range 0 to 255;
	data_r:  std_logic_vector(7 downto 0);
	data_g:  std_logic_vector(7 downto 0);
	data_b:  std_logic_vector(7 downto 0);
	we_r		:  std_logic;
	we_g		:  std_logic;
	we_b		:  std_logic;
	q_r	:  std_logic_vector(7 downto 0);
	q_g	:  std_logic_vector(7 downto 0);
	q_B	:  std_logic_vector(7 downto 0);
end record;

type t_lut is record
	addr	:  natural range 0 to 255;
	data:  std_logic_vector(7 downto 0);
	we		:  std_logic;
	q	:  std_logic_vector(7 downto 0);
end record;

type t_filter_set is record
		move_hist  : signed(7 downto 0);
		cont_ram   : t_lut;
		cont_g_min : unsigned(7 downto 0);
		cont_g_max : unsigned(7 downto 0);
		status	  : std_logic;
end record;

component single_port_ram
		generic 
		(
			DATA_WIDTH : natural := 8;
			ADDR_WIDTH : natural := 8
		);
		port 
		(
			clk		: in std_logic;
			addr	: in natural range 0 to 2**ADDR_WIDTH - 1;
			data	: in std_logic_vector((DATA_WIDTH-1) downto 0);
			we		: in std_logic := '1';
			q		: out std_logic_vector((DATA_WIDTH -1) downto 0)
		);
end component single_port_ram;

type t_dpram is record
	raddr :  natural range 0 to 255;
	waddr	:  natural range 0 to 255;
	data_r:  std_logic_vector(7 downto 0);
	data_g:  std_logic_vector(7 downto 0);
	data_b:  std_logic_vector(7 downto 0);
	we_r		:  std_logic;
	we_g		:  std_logic;
	we_b		:  std_logic;
	q_r	:  std_logic_vector(7 downto 0);
	q_g	:  std_logic_vector(7 downto 0);
	q_B	:  std_logic_vector(7 downto 0);
end record;

component dual_port_ram is

	generic 
	(
		DATA_WIDTH : natural := 8;
		ADDR_WIDTH : natural := 8
	);

	port 
	(
		clk		: in std_logic;
		raddr	: in natural range 0 to 2**ADDR_WIDTH - 1;
		waddr	: in natural range 0 to 2**ADDR_WIDTH - 1;
		data	: in std_logic_vector((DATA_WIDTH-1) downto 0);
		we		: in std_logic := '1';
		q		: out std_logic_vector((DATA_WIDTH -1) downto 0)
	);

end component dual_port_ram;

--###########################################################################
--constants
constant c_rx_com_arr : t_command_array := (x"02", x"03",x"05", x"11", x"12");
constant c_tx_com_arr : t_command_array := (x"06", x"17",x"00", x"00", x"00");

constant c_cram_empty : t_cram := (
    addr    => 0,
    data_r  => (others => '0'),
    data_g  => (others => '0'),
    data_b  => (others => '0'),
	 we_r			=> '0',
	 we_g			=> '0',
	 we_b			=> '0',
    q_r     => (others => '0'),
    q_g     => (others => '0'),
    q_B     => (others => '0')
);

constant c_lut_empty : t_lut := (
    addr    => 0,
    data  => (others => '0'),
	 we			=> '0',
    q     => (others => '0')
);

constant c_dpram_empty : t_dpram := (
	raddr 	=> 0,
	waddr		=> 0,
	data_r	=> (others => '0'),
	data_g	=> (others => '0'),
	data_b	=> (others => '0'),
	we_r			=> '0',
	we_g			=> '0',
	we_b			=> '0',
	q_r		=> (others => '0'),
	q_g		=> (others => '0'),
	q_B		=> (others => '0')
);



constant c_filter_set_empty : t_filter_set := (
	move_hist => x"00",
	cont_ram => c_lut_empty,
	cont_g_min => x"00",
	cont_g_max => x"00",
	status => '0'
);


--###########################################################################
--functions
function get_tx_command(com_in : t_tx_com) return STD_LOGIC_VECTOR;

function get_rx_command(com_in : STD_LOGIC_VECTOR(c_COM_LENGTH-1 downto 0)) return t_rx_com;

function capped_add_8(sum1 : unsigned(7 downto 0); sum2 : signed(7 downto 0)) return unsigned;

function hist_stretch_calc(g : unsigned(7 downto 0); g_min : unsigned(7 downto 0); g_max : unsigned(7 downto 0)) return unsigned;

end package graka_pack;

package body graka_pack is

function hist_stretch_calc(g : unsigned(7 downto 0); g_min : unsigned(7 downto 0); g_max : unsigned(7 downto 0)) return unsigned is
	variable gi : signed(9 downto 0);
	variable gi_min : signed(9 downto 0);
	variable gi_max : signed(9 downto 0);
	variable erg : signed(17 downto 0);
	
	variable div1 : signed(17 downto 0);
	variable div2 : signed(17 downto 0);
	begin
		gi := signed("00" & g);
		gi_min := signed("00" & g_min);
		gi_max := signed("00" & g_max);
		
		if gi > gi_max then
			return to_unsigned(255,8);
		elsif gi > gi_min then
			div1 := signed((gi - gi_min) & "00000000");
			div2 := signed("00000000" & (gi_max - gi_min));
			erg := div1 / div2;
			return unsigned(erg(7 downto 0));
		else
			--return 0
			return to_unsigned(0, 8);
		end if;
		--return unsigned(erg(7 downto 0));
end function hist_stretch_calc;

function capped_add_8(sum1 : unsigned(7 downto 0); sum2 : signed(7 downto 0)) return unsigned is
	--adds / subtracts sum2 from unsigned sum1, returns result in 0...255 range.
	variable erg : signed(9 downto 0) := (others => '0');
	begin
		erg := signed("00" & sum1) + sum2;
		if erg > 255 then
			return to_unsigned(255,8);
		elsif erg < 0 then
			return to_unsigned(0,8);
		else
			return unsigned(erg(7 downto 0));
		end if;
end function capped_add_8;
		
function get_tx_command(com_in : t_tx_com) return STD_LOGIC_VECTOR is
	begin
		return c_tx_com_arr(t_tx_com'POS(com_in));
end function get_tx_command;

function get_rx_command(com_in : STD_LOGIC_VECTOR(c_COM_LENGTH-1 downto 0)) return t_rx_com is
	begin
		case com_in is
			when c_rx_com_arr(0) =>
				return t_rx_com'VAL(0);
			when c_rx_com_arr(1) =>
				return t_rx_com'VAL(1);
			when c_rx_com_arr(2) =>
				return t_rx_com'VAL(2);
			when c_rx_com_arr(3) =>
				return t_rx_com'VAL(3);
			when c_rx_com_arr(4) =>
				return t_rx_com'VAL(4);
			when others =>
				return t_rx_com'right;
		end case;
end function get_rx_command;
				


end package body graka_pack;