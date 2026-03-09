----------------------------------------------------------------------------------
-- Company     : Personal Project
-- Engineer    : MEHMET ARSLAN
--
-- Create Date : 03/09/2026 05:30:17 PM
-- Design Name : Flancter uP-FPGA Interface
-- Module Name : Flancter_uP_FPGA - RTL
-- Project Name: Flancter
-- Target Dev  : Xilinx FPGA
-- Tool Version: Vivado 2024+
--
-- Description : Top-level wrapper that connects the basic two-domain Flancter
--               to a microcontroller (uC) bus interface.
--
--               FPGA side (SYS_CLK domain):
--                 * An event pulse on GEN_INTERRUPT_TO_uC sets the Flancter
--                   flag, which is forwarded to the uC as INT.
--                 * FF3 and FF4 form a 2-stage resynchroniser that feeds a
--                   stable copy of FLAG back into the SYS_CLK domain for the
--                   interlock guard (FLAG must have returned to idle before a
--                   new set is permitted).
--
--               uC side (RD_L domain):
--                 * When the uC reads the address matching TARGET_ADDRESS,
--                   RESET_CE is asserted and FF2 inside the Flancter clocks,
--                   clearing the flag.
--
-- Dependencies: work.Flancter
--
-- Revision    :
--   Rev 0.01  - File Created
--
-- Additional Comments:
--   The INT output drives the uC interrupt pin directly.  No FPGA-side
--   resync is needed because the uC's interrupt controller provides its
--   own input synchronisation.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Flancter_uP_FPGA is
    generic (
        -- Address bus width (bits)
        ADDRESS_W      : integer range 1 to 256 := 32
    );
    port (
        -- Trigger from FPGA logic to request an interrupt
        GEN_INTERRUPT_TO_uC : in  std_logic;

        -- FPGA clock domain
        SYS_CLK             : in  std_logic;   -- System clock
        RESET               : in  std_logic;   -- Async active-high reset
        INT                 : out std_logic;   -- Interrupt output to uC
        TARGET_ADDRESS      : out std_logic_vector(ADDRESS_W - 1 downto 0); -- Memory-mapped address the uC must read to clear the interrupt flag

        -- uC bus domain
        RD_L                : in  std_logic;    -- Active-low read strobe (clocks FF2)
        ADDRESS             : in  std_logic_vector(ADDRESS_W - 1 downto 0)  -- Address bus
    );
end entity Flancter_uP_FPGA;


architecture RTL of Flancter_uP_FPGA is

    ---------------------------------------------------------------------------
    -- Function: resize_addr
    --   Dynamically resizes a 32-bit base address to match the target width.
    --
    --   Parameters:
    --     base  : 32-bit source address
    --     width : target width in bits
    --
    --   Behavior:
    --     width > 32  → Zero-extends (MSBs padded with '0', base in LSBs)
    --     width <= 32 → Truncates (keeps only the lower 'width' bits)
    --
    --   Example:
    --     resize_addr(x"ABCD00A5", 64) → x"00000000_ABCD00A5"
    --     resize_addr(x"ABCD00A5", 16) → x"00A5"
    ---------------------------------------------------------------------------
    function resize_addr (base : std_logic_vector(31 downto 0); width : integer) return std_logic_vector is
        variable result : std_logic_vector(width-1 downto 0) := (others => '0');
    begin
        if (width > 32) then
            result(31 downto 0) := base;
        else 
            result := base(width - 1 downto 0);
        end if;

        return result;
    end function resize_addr;

    -- Base address (32-bit canonical value)
    constant BASE_ADDR_C : std_logic_vector(31 downto 0) := x"ABCD00A5";

    -- Internal control signals
    signal SET_CE   : std_logic := '0';   -- Clock-enable to set the Flancter
    signal RESET_CE : std_logic := '0';   -- Clock-enable to clear the Flancter
    signal FLAG     : std_logic := '0';   -- Raw Flancter flag output

    -- Memory-mapped address constant (dynamically sized to ADDRESS_W)
    constant MEM_ADDR_C : std_logic_vector(ADDRESS_W - 1 downto 0) := resize_addr(BASE_ADDR_C, ADDRESS_W);

    -- 2-stage resynchroniser (FLAG → SYS_CLK domain)
    signal ff3_o    : std_logic := '0';   -- First sync stage
    signal ff4_o    : std_logic := '0';   -- Second sync stage (stable copy)

begin

    TARGET_ADDRESS <= MEM_ADDR_C;

    ---------------------------------------------------------------------------
    -- Drive the interrupt pin directly from FLAG.
    -- The uC's interrupt controller provides its own input synchronisation.
    ---------------------------------------------------------------------------
    INT <= FLAG;

    ---------------------------------------------------------------------------
    -- Flancter instantiation
    --   SET side  → SYS_CLK domain (FPGA)
    --   RESET side → RD_L domain   (uC bus read strobe)
    ---------------------------------------------------------------------------
    flancter_inst : entity work.Flancter
        port map (
            sys_clk     => SYS_CLK,
            reset_clk   => RD_L,
            set_ce      => SET_CE,
            reset_ce    => RESET_CE,
            reset_async => RESET,
            flag        => FLAG
        );

    ---------------------------------------------------------------------------
    -- 2-FF Resynchroniser — FLAG into SYS_CLK domain
    --   ff3_o captures the raw asynchronous FLAG.
    --   ff4_o is the metastability-safe, stable copy used by P_SET_CE.
    ---------------------------------------------------------------------------
    P_RESYNC : process (SYS_CLK, RESET)
    begin
        if (RESET = '1') then
            ff3_o <= '0';
            ff4_o <= '0';
        elsif rising_edge(SYS_CLK) then
            ff3_o <= FLAG;
            ff4_o <= ff3_o;
        end if;
    end process P_RESYNC;

    ---------------------------------------------------------------------------
    -- Address decoder (combinational)
    --   Asserts RESET_CE when the uC places ADDRESS on the bus.
    --   RD_L acts as the clock for FF2 inside the Flancter, so the actual
    --   clear happens on the rising edge of RD_L while RESET_CE is high.
    ---------------------------------------------------------------------------
    P_ADDR_DECODE : process (ADDRESS)
    begin
        if (ADDRESS = MEM_ADDR_C) then
            RESET_CE <= '1';
        else
            RESET_CE <= '0';
        end if;
    end process P_ADDR_DECODE;

    ---------------------------------------------------------------------------
    -- SET_CE generator — interlock guard
    --   Only permits a new set when FLAG has returned to idle (FLAG = ff4_o,
    --   meaning the resynchronised copy matches the current flag state) and
    --   GEN_INTERRUPT_TO_uC is asserted.  This enforces the interlocked
    --   protocol required by the Flancter design.
    ---------------------------------------------------------------------------
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
    end process P_SET_CE;

end architecture RTL;
