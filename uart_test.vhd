-- uart_test.vhd -- Example use of the UART library
--
-- Copyright (C) 2015 Ondrej Novak
--
-- This software may be modified and distributed under the terms
-- of the MIT license.  See the LICENSE file for details.
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_test is
    port(
        CLOCK_50    : in std_logic;

        UART_RXD    : in std_logic;
        UART_TXD    : out std_logic;

        KEY         : in std_logic_vector(3 downto 0);
        SW          : in std_logic_vector(9 downto 0);
        LEDR        : out std_logic_vector(9 downto 0);
        LEDG        : out std_logic_vector(7 downto 0)
        );
end entity;

architecture behav of uart_test is
    component uart_fifo is
    generic(
        CLK_IN      : natural := 50*1000*1000;
        BAUDRATE    : natural := 115200
        );
    port(
        CLOCK   : in std_logic;
        ACLR    : in std_logic;
        RX      : in std_logic;
        TX      : out std_logic;

        -- data input
        DATA_IN : in std_logic_vector(7 downto 0);
        WR      : in std_logic;

        -- data output
        DATA_OUT: out std_logic_vector(7 downto 0);
        COUNT   : out std_logic_vector(6 downto 0);
        RD      : in std_logic
    );
    end component;

    signal rd, wr : std_logic := '0';

begin
    wr <= not KEY(0);
    rd <= not KEY(1);
    
    uart_inst: uart_fifo port map(
        CLOCK => CLOCK_50,
        ACLR => '0',

        RX => UART_RXD,
        TX => UART_TXD,

        DATA_IN => SW(7 downto 0),
        WR => wr,

        DATA_OUT => LEDG,
        COUNT => LEDR(6 downto 0),

        RD => rd
        );

end architecture;