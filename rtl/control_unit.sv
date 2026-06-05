import gpu_pkg::*;
    
module control_unit (
    input  logic                  clk, rst_n,
    input  logic                  start,          // Pulse high to begin
    input  logic [NUM_CORES-1:0]  core_halted,    // One bit per core
    input  logic                  any_core_busy,  // Stall when any core is completing a multi-cycle op
    output instr_t                dispatch_instr,
    output logic                  instr_valid,

    // To init program
    input  logic                  init_imem_we,
    input  logic [PC_W-1:0]       init_imem_addr,
    input  logic [INST_W-1:0]     init_imem_data
);
    logic [INST_W-1:0] imem [2**PC_W];  // Write program here before start
    logic [INST_W-1:0] dispatch_reg;    // Registered instruction - stays stable while instr_valid=1
    logic [PC_W-1:0]   pc;
    logic              running;

    // Registered dispatch: guaranteed to match instr_valid timing
    assign dispatch_instr = instr_t'(dispatch_reg);

    always_ff @(posedge clk) begin
        if (init_imem_we)
            imem[init_imem_addr] <= init_imem_data;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc           <= '0;
            running      <= 1'b0;
            instr_valid  <= 1'b0;
            dispatch_reg <= '0;
        end else begin
            if (start && !running) begin
                running <= 1'b1;
                pc      <= '0;
            end

            if (running) begin
                if (&core_halted) begin
                    running     <= 1'b0;    // Every core has halted - done
                    instr_valid <= 1'b0;
                end else if (!any_core_busy) begin
                    instr_valid  <= 1'b1;
                    dispatch_reg <= imem[pc]; // Capture current instruction before advancing
                    pc           <= pc + 1;
                end else begin
                    instr_valid <= 1'b0;  // Lower during stall - core sees executing=0, no re-trigger
                end
            end
        end
    end
endmodule
