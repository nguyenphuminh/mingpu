package gpu_pkg;
    parameter int NUM_CORES = 80;  // Number of cores
    parameter int DATA_W    = 16;  // Data width in bits
    parameter int OPCODE_W  = 8;   // Opcode width in bits
    parameter int OPERAND_W = 8;   // Operand width in bits
    parameter int INST_W    = OPCODE_W + OPERAND_W; // Full instruction (opcode + operand) width in bits
    parameter int ADDR_W    = 8;   // Mem address width in bits
    parameter int MEM_DEPTH = 256; // Local mem size in words/slots
    parameter int PC_W      = 8;   // Program counter width in bits

    typedef enum logic [OPCODE_W-1:0] {
        NOP   = 0,
        ADD   = 1,
        MUL   = 2,
        STORE = 3,
        LOAD  = 4,
        HALT  = 5
    } opcode_t;

    typedef struct packed {
        opcode_t opcode;
        logic [OPERAND_W-1:0] operand;
    } instr_t;
endpackage
