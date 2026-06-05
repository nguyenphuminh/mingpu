# mingpu

Mingpu is an extremely minimal GPU architecture that I wrote for fun and also to learn basic hardware design. Though, it does not have the "G" in "GPU" (yet) - it does not do any graphics, but rather focuses on pure parallel SIMD compute.

Currently, the architecture includes:

* A control unit to dispatch instructions to compute cores.
* 16 compute cores that includes:
    * 8-bit word size.
    * 256 bytes of local mem each core.
    * A minimal 6 op ISA - NOP, ADD (signed), MUL (signed), LOAD, STORE, HALT.

## Setup

I currently uses [Icarus Verilog](https://github.com/steveicarus/iverilog) for development of this project, so have it installed and you are good to go.

## Run testbench

Run:
```sh
make sim
```

## Todos

* Rethink better arch overall, currently this is a very naive arch and implementation from me.
* Integration with real hardware, possibly with a Tang Nano 4k (which then should come with UART stuff, an assembler, and a driver too).

## Copyrights and License

Copyrights © 2026 Nguyen Phu Minh.

This project is licensed under the Apache 2.0 License.
