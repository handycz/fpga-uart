-- uart_fifo.vhd -- I/O (FIFOs) handling entity
--
-- Copyright (C) 2015 Ondrej Novak
--
-- This software may be modified and distributed under the terms
-- of the MIT license.  See the LICENSE file for details.
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_fifo is
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
end entity;

architecture behav of uart_fifo is
    component uart is
        generic(
            CLK_IN      : natural := 50*1000*1000;
            BAUDRATE    : natural := 115200
        );
        port(
            CLOCK       : in std_logic;
            ACLR        : in std_logic;

            RX          : in std_logic;
            TX          : out std_logic;

            -- interface for sending the data
            DATA_IN     : in std_logic_vector(7 downto 0);
            WR          : in std_logic;
            TX_READY    : out std_logic;

            -- interface for receiving the data
            DATA_OUT    : out std_logic_vector(7 downto 0);
            RECEIVED    : out std_logic
        );
    end component;

    component fifo_buffer
        port
        (
            clock       : in std_logic;
            data        : in std_logic_vector (7 downto 0);
            rdreq       : in std_logic;
            wrreq       : in std_logic;
            empty       : out std_logic;
            full        : out std_logic;
            q           : out std_logic_vector (7 downto 0);
            usedw       : out std_logic_vector (6 downto 0)
        );
    end component;
    signal TX_FIFO_EMPTY    : std_logic := '0';
    signal TX_DATA          : std_logic_vector(7 downto 0) := (others => '0');
    signal TX_READY         : std_logic := '0';
    signal TX_SEND          : std_logic := '0';
    signal TX_D_READ        : std_logic := '0';
    signal TX_FIFO_WR_re    : std_logic := '0';
    signal TX_FIFO_RD       : std_logic := '0';

    signal RX_RDY           : std_logic := '0';
    signal RX_DATA          : std_logic_vector(7 downto 0) := (others => '0');
    signal RX_FIFO_WR       : std_logic := '0';
    signal RX_FIFO_DATA     : std_logic_vector(7 downto 0) := (others => '0');
    signal RX_FIFO_COUNT    : std_logic_vector(COUNT'high downto COUNT'low) := (others => '0');
    signal RX_FIFO_EMPTY    : std_logic := '0';
    signal RX_FIFO_RD_re    : std_logic := '0';
    signal RX_FIFO_EMPTY_lr : std_logic := '0'; -- RX_FIFO_EMPTY value when last RX_FIFO_RD_re = '1'

begin    
    COUNT <= RX_FIFO_COUNT;
    with RX_FIFO_EMPTY_lr select DATA_OUT <= 
        RX_FIFO_DATA when '0',
        (others => '0') when others;


    uart_inst: uart port map(
        CLOCK => CLOCK,
        ACLR => ACLR,
        RX => RX,
        TX => TX,

        DATA_IN => TX_DATA,
        WR => TX_SEND,
        TX_READY => TX_READY,

        DATA_OUT => RX_DATA,
        RECEIVED => RX_RDY
        );

        -- interface -> uart
        input_fifo: fifo_buffer port map(
            clock   => CLOCK,
            data    => DATA_IN,
            rdreq   => TX_SEND,
            wrreq   => TX_FIFO_WR_re,
            empty   => TX_FIFO_EMPTY,
            q       => TX_DATA
        );

        -- uart -> interface
        output_fifo: fifo_buffer port map(
            clock   => CLOCK,
            data    => RX_DATA,
            rdreq   => RX_FIFO_RD_re,
            wrreq   => RX_FIFO_WR,
            empty   => RX_FIFO_EMPTY,
            q       => RX_FIFO_DATA,
            usedw   => RX_FIFO_COUNT
        );

        -- write data to input FIFO when receiving complete
        rx_controller: process(CLOCK) is
        begin
            if rising_edge(CLOCK) then
                if RX_FIFO_WR = '1' then 
                    RX_FIFO_WR <= '0';

                else
                    RX_FIFO_WR <= RX_RDY;

                end if;

            end if;

        end process;

        -- read data from fifo when TX line is ready
        tx_controller: process(CLOCK) is
        begin
            if rising_edge(CLOCK) then
                if TX_FIFO_EMPTY = '0' and TX_READY = '1' then
                    TX_FIFO_RD <= '1';

                else
                    TX_FIFO_RD <= '0';

                end if;

                if TX_FIFO_RD = '1' then
                    TX_SEND <= '1';

                else
                    TX_SEND <= '0';

                end if;

            end if;

        end process;

        -- generates ine clock pulses from RD and WR request
        rdwr_re_generator: process(CLOCK) is
            variable wr_old, rd_old : std_logic := '1';

        begin
            if rising_edge(CLOCK) then
                if wr_old /= WR and WR = '1' then
                    TX_FIFO_WR_re <= '1';

                else
                    TX_FIFO_WR_re <= '0';

                end if;

                if rd_old /= RD and RD = '1' then
                    RX_FIFO_RD_re <= '1';
                    RX_FIFO_EMPTY_lr <= RX_FIFO_EMPTY;

                else
                    RX_FIFO_RD_re <= '0';

                end if;

            wr_old := WR;
            rd_old := RD;

            end if;

        end process;

end architecture;