import gpu_pkg::*;

module gpu_top (
    input  logic clk, rst_n, start,
    output logic done,

    // Readback (use after done)
    input  logic [$clog2(NUM_CORES)-1:0] rd_core,
    input  logic [ADDR_W-1:0]            rd_addr,
    output logic [DATA_W-1:0]            rd_data,

    // Init (write before start)
    input  logic [$clog2(NUM_CORES)-1:0] init_core,
    input  logic [ADDR_W-1:0]            init_addr,
    input  logic [DATA_W-1:0]            init_data,
    input  logic                         init_we,
    input  logic                         init_imem_we,
    input  logic [PC_W-1:0]              init_imem_addr,
    input  logic [INST_W-1:0]            init_imem_data
);
    instr_t               dispatch_instr;
    logic                 instr_valid;
    logic [NUM_CORES-1:0] core_halted;
    logic [NUM_CORES-1:0] core_busy;
    logic [DATA_W-1:0]    core_rd_data [NUM_CORES];

    assign done    = &core_halted;
    assign rd_data = core_rd_data[rd_core];

    control_unit cu (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .core_halted    (core_halted),
        .any_core_busy  (|core_busy),
        .dispatch_instr (dispatch_instr),
        .instr_valid    (instr_valid),
        .init_imem_we   (init_imem_we),
        .init_imem_addr (init_imem_addr),
        .init_imem_data (init_imem_data)
    );

    generate
        for (genvar i = 0; i < NUM_CORES; i++) begin : g_cores
            compute_core #(.THREAD_ID(i)) core_i (
                .clk         (clk),
                .rst_n       (rst_n),
                .start       (start),
                .instr       (dispatch_instr),
                .instr_valid (instr_valid),
                .halted      (core_halted[i]),
                .busy        (core_busy[i]),
                .rd_addr     (rd_addr),
                .rd_data     (core_rd_data[i]),
                .init_we     (init_we && (init_core == i[$clog2(NUM_CORES)-1:0])),
                .init_addr   (init_addr),
                .init_data   (init_data)
            );
        end
    endgenerate
endmodule
