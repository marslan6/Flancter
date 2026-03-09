----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/09/2026 05:30:17 PM
-- Design Name: 
-- Module Name: Flancter_uP_FPGA - RTL
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Flancter_uP_FPGA is
    GENERIC (
        ADDRESS_W : integer range 1 to 256 := 32;
        -- Define the specific memory address the uP must read to clear the flag
        TARGET_ADDRESS : std_logic_vector(ADDRESS_W-1 downto 0)
    );
    PORT (
        GEN_INTERRUPT_TO_uC : in std_logic;

        -- FPGA DOMAIN
        SYS_CLK : in std_logic;
        RESET : in std_logic;
        INT : out std_logic := '0';

        -- uC DOMAIN
        RD_L : in std_logic;
        ADDRESS : in std_logic_vector(ADDRESS_W-1 downto 0)
    );
end entity Flancter_uP_FPGA;

architecture RTL of Flancter_uP_FPGA is
    signal SET_CE : std_logic := '0';
    signal RESET_CE : std_logic := '0';
    signal FLAG : std_logic := '0';
    signal sync_ff_1 : std_logic := '0';


    signal ff3_o : std_logic := '0';
    signal ff4_o : std_logic := '0';

begin

    INT <= FLAG;

    flancter : entity work.Flancter
        port map (
            sys_clk => SYS_CLK,
            reset_clk => RD_L,
            set_ce => SET_CE,
            reset_ce => RESET_CE,
            reset_async => RESET,
            flag => FLAG
        );
    
        P_SEQUENTIAL : process(SYS_CLK, RESET) 
        begin
            if (RESET = '1') then
                ff3_o <= '0';
                ff4_o <= '0';
            elsif rising_edge(SYS_CLK) then
                ff3_o <= FLAG;
                ff4_o <= ff3_o;
            end if;
        end process;

        P_ADDR_DECODE : process (ADDRESS)
        begin 
            if (ADDRESS = TARGET_ADDRESS) then
                RESET_CE <= '1';
            else 
                RESET_CE <= '0';
            end if;
        end process P_ADDR_DECODE;

        P_SET_CE : process (SYS_CLK, RESET)
        begin
            if (RESET = '1') then
                SET_CE <= '0';
            elsif rising_edge(SYS_CLK) then
                if (FLAG = ff4_o and GEN_INTERRUPT_TO_uC = '1') then
                    SET_CE <= '1';
                else
                    SET_CE <= '0';
                end if; 
            end if;
        end process;


end architecture RTL;
