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

entity Flancter is
    PORT (
        clk_fast   : in std_logic;  -- Fast clock domain drives FF1
        clk_slow   : in std_logic;  -- Slow clock domain samples FF1 into FF2
        ff_fast_ce : in std_logic;  -- Clock enable for FF1 update on clk_fast edge
        ff_slow_ce : in std_logic;  -- Clock enable for FF2 update on clk_slow edge
        reset      : in std_logic;  -- Asynchronous active-high reset for both flops
        flag       : out std_logic  -- High while FF1 and FF2 differ
    );
end entity Flancter;

architecture RTL of Flancter is
    signal ff1_o : std_logic := '0';  -- FF1 output in fast domain
    signal ff2_o : std_logic := '0';  -- FF2 output in slow domain
begin

    P_FF1 : process (clk_fast, reset)  -- FF1 toggles based on FF2 state when enabled
    begin
        if (reset = '1') then
            ff1_o <= '0';
        elsif rising_edge(clk_fast) then
            if ff_fast_ce = '1' then
                ff1_o <= not(ff2_o);
            end if;
        end if;
    end process P_FF1;

    P_FF2 : process (clk_slow, reset)  -- FF2 captures FF1; cross-clock transfer from clk_fast to clk_slow
    begin
        if (reset = '1') then
            ff2_o <= '0';
        elsif rising_edge(clk_slow) then
            if ff_slow_ce = '1' then
                ff2_o <= ff1_o;
            end if;
        end if;
    end process P_FF2;

    flag <= ff1_o xor ff2_o;  -- XOR indicates mismatch between fast and slow domain states

end architecture RTL;
