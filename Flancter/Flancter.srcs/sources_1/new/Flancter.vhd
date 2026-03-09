----------------------------------------------------------------------------------
-- Company     : Personal Project
-- Engineer    : MEHMET ARSLAN
--
-- Create Date : 03/05/2026 02:51:27 PM
-- Design Name : Flancter
-- Module Name : Flancter - RTL
-- Project Name: Flancter
-- Target Dev  : Xilinx FPGA
-- Tool Version: Vivado 2024+
--
-- Description : Two-domain Flancter based on Memec Design App Note.
--               Two FFs + XOR. SET_CE sets the flag, RESET_CE clears it.
--
-- Dependencies: None
--
-- Revision    :
--   Rev 0.01  - File Created
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity Flancter is
    port (
        -- Set clock domain
        sys_clk     : in  std_logic;   -- FF1 clock
        set_ce      : in  std_logic;   -- FF1 enable (sets flag)

        -- Reset clock domain
        reset_clk   : in  std_logic;   -- FF2 clock
        reset_ce    : in  std_logic;   -- FF2 enable (clears flag)

        -- Global
        reset_async : in  std_logic;   -- Async reset (active high)
        flag        : out std_logic    -- Flag output (Q1 XOR Q2)
    );
end entity Flancter;


architecture RTL of Flancter is

    signal ff1_o : std_logic := '0';
    signal ff2_o : std_logic := '0';

begin

    -- FF1: D = NOT ff2_o, clocked by sys_clk
    P_FF1 : process (sys_clk, reset_async)
    begin
        if (reset_async = '1') then
            ff1_o <= '0';
        elsif rising_edge(sys_clk) then
            if (set_ce = '1') then
                ff1_o <= not ff2_o;
            end if;
        end if;
    end process P_FF1;

    -- FF2: D = ff1_o, clocked by reset_clk
    P_FF2 : process (reset_clk, reset_async)
    begin
        if (reset_async = '1') then
            ff2_o <= '0';
        elsif rising_edge(reset_clk) then
            if (reset_ce = '1') then
                ff2_o <= ff1_o;
            end if;
        end if;
    end process P_FF2;

    -- Flag = XOR of both flops
    flag <= ff1_o xor ff2_o;

end architecture RTL;
