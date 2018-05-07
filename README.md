# OpenMIPS Processor


This is an implementation of the **MIPS32 Release 1** architecture.

This processor is ISA-compliant and fully synthesizeable. It has a 32-bit
virtual address space and supports up to 36 bits of physical memory (64 GiB).
It has a 16-entry TLB with configurable page sizes up to 256 MiB, an 8 KiB
instruction cache, and a 2-KiB data cache.

Over one hundred tests validate individual hardware components, each
implemented instruction, and complex programs that execute millions of
simulated cycles and instructions. The processor runs at about 66 MHz
on a Spartan 6 FPGA.

This project was authored by Grant Ayers. Please feel free to send questions
or feedback to ayers AT cs.stanford.edu.

## Processor Details

- Single-issue in-order 8-stage pipeline with full hardware interlocking and
  forwarding.
- Harvard architecture with separate instruction and data ports which can be
  combined if desired.
- All required MIPS32 instructions are implemented, including hardware
  multiplication and division, fused multiply/adds, atomic load linked / store
  conditional, and unaligned loads and stores.
- "Branch likely" instructions are supported.
- Complete Coprocessor 0 allows ISA-compliant interrupts, exceptions, and
  user/kernel modes.
- Full virtual memory support with page sizes ranging from 4 KiB to 256 MiB.
- 16-entry dual-ported TLB
- Instruction (8 KiB) and data (2 KiB) caches are 2-way set-associative,
  pipelined, and virtually-indexed, physically-tagged.
- Software toolchain support for floating point (no FPU).
- Division, multiplication, and fused multiply instructions are multi-cycle
  and partially asynchronous from the pipeline allowing some masking of
  latency.
- Hardware is big- or little-endian at synthesis time and supports
  reverse-endian accesses in User mode.
- Parameterized addresses for exception/interrupt vectors and boundary address
  between user/kernel regions.
- Extensive documentation in-source and elsewhere.
- A clean, modular design written completely from scratch.


## Software Details

The simulation infrastructure is one of the key strengths of this project. Here
are some examples of things you can do with it:

- Automatically build a complete MIPS cross-compiler and toolchain.
  Currently this is based on GCC 6.4, Binutils 2.27, and Newlib 2.5. Supported
  languages are C and MIPS assembly.
- Compile and simulate over one hundred software tests written in MIPS assembly
  and C. Easily add additional tests.
- View the text-based object dump disassembly for each test.
- Record an instruction trace for each retired processor instruction during a test.
- Record a full register trace (all MIPS architectural registers) for all instructions.
  of a test and compare two register traces (e.g., for A/B testing).
- Use 'printf'-type functions (with stdout via Newlib).
- Dump an output buffer of memory to a text file.
- Simulate in either big- or little-endian mode.
- Use floating point operations transparently via software floating point libraries.

## Getting Started: Processor Synthesis Only

### Dependencies

1. Synthesis software (Cadence, Synopsis, Xilinx, Altera, etc.).

The hardware Verilog files are located in `hardware/src`, with the primary processor
and cache files being in `hardware/src/MIPS32`. Add these to your project according
to the software you are using. All of the design files are written
in vendor-independent code with the exception of the fused multiply/add and
multiply/subtract ALU logic. Currently this is implemented only for a Xilinx Spartan 6
device (xc6slx45t) in `hardware/src/Xilinx/xc6slx45t-3-fgg484/MAddSub/`. If you can
contribute this logic for other devices (or especially a vendor-independent version)
please contact me. This processor has been tested on Xilinx and Altera (Intel) FPGAs.

## Getting Started: Building and Testing the Processor

### Dependencies

1. Linux or a Unix-like environment (bash, GNU make, python, sed, awk, etc.). Tested on Ubuntu 16.04 LTS.
2. Xilinx ISE 14.7. Other versions may work but are untested. Other toolchains (e.g., Altera) could be
   made to work with additional effort.

### Steps

Note: All paths are relative to the main project directory. You can speed everything up by
substituting `-j4` with the number of hardware threads your machine supports (e.g.,
`-j16` for a 16-core machine).


1. Download and build the MIPS GCC cross-compiler and `make-hex` utility:
```bash
cd software/gcc-mips
make -j4
cd software/util/make_hex
make
```
2. Make sure the Xilinx tools are in your path. For example, if Xilinx ISE 14.7 (64-bit)
   is installed to `/opt/Xilinx/14.7`, then the appropriate command for bash would be:
```bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh
```
3. Run the hardware unit ("micro") tests:
```bash
cd hardware/test/micro
make -j4
```
4. Run the hardware instruction-level ("macro") tests:
```bash
cd hardware/test/macro
make -j4
```
5. Synthesize and implement the design (for a Spartan 6 device with MIPS32.v
   as the top-level module):
```bash
cd hardware
make -j4
```
See the FAQ below for more information.



## Directory Organization

    README.md      : This README file
    LICENSE        : Software license (applies to all contents)
    hardware/      : Contains all hardware source code
      config/      : Settings for hardware synthesis/implementation
      src/         : Hardware HDL source files
      test/macro   : Instruction-level test infrastructure
      test/micro   : Hardware unit tests
    software/      : Toolchain and code generation utilities

## Frequently-Asked Questions (FAQ):
1. [Processor questions](#processor-questions)
    1. [Which instructions are supported?](#which-instructions-are-supported?)
    2. [Are interrupts and exceptions supported?](#are-interrupts-and-exceptions-supported?)
    3. [Can this processor run Linux?](#can-this-processor-run-linux?)
2. [Verification questions](#verification-questions)
    1. [How do I run a single test?](#how-do-i-run-a-single-test?)
    2. [How do I create an instruction trace for a test?](#how-do-i-create-an-instruction-trace-for-a-test?)
    3. [How do I create a register trace for a test?](#how-do-i-create-a-register-trace-for-a-test?)
    4. [How do I view the waveform for a test?](#how-do-i-view-the-waveform-for-a-test?)
3. [Usage questions](#usage-questions)
    1. [How much of the design is vendor-independent?](#how-much-of-the-design-is-vendor-independent?)
    2. [Which device parts are supported for vendor-dependent modules?](#which-device-parts-are-supported-for-vendor-independent-modules?)
    3. [How do I import the MIPS design into my own project?](#how-do-i-import-the-mips-design-into-my-own-project?)
    4. [What is the 'PABITS' parameter in the top-level MIPS module?](#what-is-the-pabits-parameter-in-the-top-level-mips-module?)
    5. [Why is there a synthesis warning for an unconnected block?](#why-is-there-a-synthesis-warning-for-an-unconnected-block?)

### Processor questions

#### Which instructions are supported?
All instructions that are required by the [MIPS32 Release 1 ISA](https://archive.org/details/MIPS_Technologies_MD00086)
are implemented, including TLB, cache, fused multiply/add, multiply/sub, and the
deprecated "branch likely" instructions. Instructions for some optional unimplemented
components (e.g., JTAG and hardware floating point) are not implemented. Note that
software floating point support is available via the GCC toolchain.

#### Are interrupts and exceptions supported?
Yes. Interrupts and exceptions are fully supported and ISA-compliant. Specifically,
there are five hardware interrupts which are inputs to the processor. The fifth
interrupt is shared with the count and compare registers (used to implement a timer
interrupt). There are also two software interrupts. All interrupts and exceptions
use the ISA-defined exception vectors.

#### Can this processor run Linux?
This processor has all of the technical requirements to run an operating system
such as Linux (namely virtual memory support). However this has not been tested.

### Verification questions

#### How do I run a single test?
Just use `make test_<test_name>` where `<test_name>` is the name of the specific test.
For example, to test the XOR instruction you would do the following:
```bash
cd hardware/tests/macro
make test_xor
```
The list of valid test targets is simply the name of the subfolders in `hardware/test/macro/tests/`.

#### How do I create an instruction trace for a test?
Use the target `make itrace_<test_name>` where `<test_name>` is the name of the
specific test.

#### How do I create a register trace for a test?
Use the target `make rtrace_<test_name>` where `<test_name>` is the name of the
specific test.

#### How do I view the waveform for a test?
Use the target `make wave_<test_name>` where `<test_name>` is the name of the
specific test.

### Usage questions

#### How much of the design is vendor-independent?
This project aims to be as vendor-independent as possible while still being easily
implemented on several real-world devices. Currently what this means is that all
but three modules are vendor-independent:
1. Simple dual-port BRAM (used in caches)
2. True dual-port BRAM with different port aspect ratios (used in caches)
3. Fused multiply/add unit (multicycle long ALU operations)

#### Which device parts are supported for vendor-dependent modules?
- Xilinx Spartan-6 LX45T and close variants
- Xilinx Virtex-5 LX110T and close variants (partial support; no multicycle
  ALU modules)
To target another device family you will need to create custom BRAM and ALU modules.
You can also extend the Makefiles to support custom devices. Note that changing
the Makefiles to anything other than xc6slx45t is not tested or supported at
this time.

#### How do I import the MIPS design into my own project?
Check the module list in `hardware/config/<part>/sources_syn.lst` to see which
files you should copy to your project. Generally the files are in three locations:
1. Processor and Cache: `hardware/src/MIPS32`
2. General-purpose modules: `hardware/src/Common`
3. Part-specific modules: `hardware/src/<part>`
Note that you will need to manually generate Coregen BRAM cores in the
part-specific directories based on their `.cgp`/`.xcp` files.

#### What is the PABITS parameter in the top-level MIPS module?
MIPS32 has 32-bit virtual addresses and up to 36 bits of physically-addressable
memory (64 GiB). This parameter specifies how much physical memory is actually
attached to the processor, where 12 < `PABITS` <= 36. The recommended value is 32.

#### Why is there a synthesis warning for an unconnected block?
The dual-ported TLB exports a dirty bit which is only useful for the data cache.
Because the instruction cache does not use this signal on its port, you may see
a warning about signal `S_D_B_D` in the TLB block. For some tools there is no
trivial way to avoid this warning but it is harmless.
