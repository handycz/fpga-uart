-- uart.vhd -- Communication handling entity
--
-- Copyright (C) 2015 Ondrej Novak
--
-- This software may be modified and distributed under the terms
-- of the MIT license.  See the LICENSE file for details.
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
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
end entity;

architecture behav of uart is
    type rx_state_t is (rx_idle, rx_wait, rx_stop, rx_store);
    type tx_state_t is (tx_idle, tx_sendbit);

    signal SAMPLE : std_logic := '0';
    signal RX_STATE : rx_state_t := rx_idle;
    signal RX_STATE_NEXT : rx_state_t := rx_idle;
    signal RX_DATA : unsigned(7 downto 0) := (others => '0');
    signal RX_COMPLETE : std_logic := '0';
    signal RX_GET_ACLR : std_logic := '0';
    signal RX_COUNT : integer range 0 to 15 := 0;

    signal TX_SIGNAL : std_logic := '0';
    signal TX_DATA : unsigned(9 downto 0) := (others => '1');
    signal TX_STATE : tx_state_t := tx_idle;
    signal TX_STATE_NEXT : tx_state_t := tx_idle;
    signal TX_GEN_ACLR : std_logic := '0';
    signal TX_SENT : std_logic := '0';
    signal TX_COUNT : integer range 0 to 15 := 0;

begin

    ---------------------
    -- Output signals
    ---------------------

    DATA_OUT <= std_logic_vector(RX_DATA);
    TX <= TX_DATA(0);
    RECEIVED <= RX_COMPLETE;

    ---------------------
    -- Generate sampling impulses
    ---------------------
    samplegen: process(CLOCK) is
        constant boundary : integer := CLK_IN / BAUDRATE;
        variable counter : integer range 0 to boundary := 0;

    begin
        if RX_GET_ACLR = '1' then
            counter := 0;

        elsif rising_edge(CLOCK) then
            counter := counter + 1;

            if counter = boundary - 1 then
                counter := 0;

            end if;

            if counter = boundary/2 then
                SAMPLE <= '1';

            else
                SAMPLE <= '0';

            end if; -- counter = boundary


        end if; -- rising_edge(CLOCK)

    end process;

    ---------------------
    -- Generate TX impulses
    ---------------------
    txgen: process(CLOCK) is
        constant boundary : integer := CLK_IN / BAUDRATE;
        variable counter : integer range 0 to boundary := 0;

    begin
        if TX_GEN_ACLR = '1' then
            counter := 0;

        elsif rising_edge(CLOCK) then
            counter := counter + 1;

            if counter = boundary - 1 then
                counter := 0;
                TX_SIGNAL <= '1';

            else
                TX_SIGNAL <= '0';

            end if; -- counter = boundary


        end if; -- rising_edge(CLOCK)

    end process;

    ---------------------
    -- Switch RX state to next state
    ---------------------
    rx_state_sw: process(CLOCK, ACLR) is
    begin
        if ACLR = '1' then
            RX_STATE <= rx_idle;

        elsif rising_edge(CLOCK) then
            RX_STATE <= RX_STATE_NEXT;

        end if;

    end process;

    ---------------------
    -- RX FSM logic
    ---------------------
    rx_fsm: process(CLOCK) is
        variable rx_rcv : unsigned(7 downto 0) := (others => '0');

    begin

        if rising_edge(CLOCK) then
            case RX_STATE is 
            when rx_idle =>
                RX_COMPLETE <= '0';
                RX_GET_ACLR <= '1';

                if RX = '0' then
                    RX_GET_ACLR <= '0';
                    RX_COUNT <= 0;
                    rx_rcv := (others => '0');
                    RX_STATE_NEXT <= rx_wait;

                end if;

            when rx_wait =>
                if SAMPLE = '1' then
                    RX_COUNT <= RX_COUNT + 1;

                    if RX_COUNT = 8 then
                        RX_STATE_NEXT <= rx_stop;

                    else
                        rx_rcv(rx_rcv'high) := RX;
                        rx_rcv := rx_rcv srl 1;
                        RX_STATE_NEXT <= rx_wait;

                    end if;

                end if;

            when rx_stop =>
                if RX = '1' then
                    RX_STATE_NEXT <= rx_store;
                    RX_DATA <= rx_rcv;

                end if;

            when rx_store => 
                RX_COMPLETE <= '1';
                RX_STATE_NEXT <= rx_idle;

            end case;

        end if;

    end process;

    ---------------------
    -- Switch TX state to next state
    ---------------------
    tx_state_sw: process(CLOCK, ACLR) is
    begin
        if ACLR = '1' then
            TX_STATE <= tx_idle;

        elsif rising_edge(CLOCK) then
            TX_STATE <= TX_STATE_NEXT;

        end if;

    end process;

    ---------------------
    -- TX FSM logic
    ---------------------
    tx_fsm: process(CLOCK) is
    begin
        if rising_edge(CLOCK) then
            case TX_STATE is
            when tx_idle =>
                if WR = '1' then
                    TX_DATA <= '1' & unsigned(DATA_IN) & '0';
                    TX_COUNT <= 0;
                    TX_STATE_NEXT <= tx_sendbit;
                    TX_GEN_ACLR <= '1';
                    TX_READY <= '0';

                else
                    TX_READY <= '1';
                    
                end if;

            when tx_sendbit =>
                if TX_SIGNAL = '1' then
                    if TX_COUNT < 9 then
                        TX_COUNT <= TX_COUNT + 1;
                        TX_DATA <= TX_DATA srl 1;
                        TX_STATE_NEXT <= tx_sendbit;

                    else
                        TX_COUNT <= 0;
                        TX_STATE_NEXT <= tx_idle;
                        TX_DATA <= (others => '1');

                    end if;

                else
                    TX_GEN_ACLR <= '0';

                end if;

            end case;

        end if;
    end process;


end architecture;