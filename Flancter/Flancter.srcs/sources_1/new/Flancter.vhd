----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/05/2026 02:51:27 PM
-- Design Name: 
-- Module Name: Flancter - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- 
-- Description:  When FF2 is clocked, Q2 becomes the same as Q1, and the output
-- will go low. In summary, clocking FF1 causes OUT to go high and clocking FF2
-- causes OUT to go low.

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

entity Flancter is
    PORT (
        sys_clk   : in std_logic;  -- Fast clock domain drives FF1
        reset_clk   : in std_logic;  -- Slow clock domain samples FF1 into FF2
        set_ce : in std_logic;  -- Clock enable for FF1 update on sys_clk edge
        reset_ce : in std_logic;  -- Clock enable for FF2 update on reset_clk edge
        reset_async      : in std_logic;  -- Asynchronous active-high reset for both flops
        flag       : out std_logic  -- High while FF1 and FF2 differ
    );
end entity Flancter;

architecture RTL of Flancter is
    signal ff1_o : std_logic := '0';  -- FF1 output in fast domain
    signal ff2_o : std_logic := '0';  -- FF2 output in slow domain
begin

    P_FF1 : process (sys_clk, reset_async)  -- FF1 toggles based on FF2 state when enabled
    begin
        if (reset_async = '1') then
            ff1_o <= '0';
        elsif rising_edge(sys_clk) then
            if set_ce = '1' then
                ff1_o <= not(ff2_o);
            end if;
        end if;
    end process P_FF1;

    P_FF2 : process (reset_clk, reset_async)  -- FF2 captures FF1; cross-clock transfer from sys_clk to reset_clk
    begin
        if (reset_async = '1') then
            ff2_o <= '0';
        elsif rising_edge(reset_clk) then
            if reset_ce = '1' then
                ff2_o <= ff1_o;
            end if;
        end if;
    end process P_FF2;

    flag <= ff1_o xor ff2_o;  -- XOR indicates mismatch between fast and slow domain states

end architecture RTL;
