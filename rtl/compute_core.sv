import gpu_pkg::*;

module compute_core #(
    parameter int THREAD_ID = 0
)(
    input  logic   clk,
    input  logic   rst_n,       // Active-low reset (0 = in reset)
    input  logic   start,       // Clears halted and acc to allow restart without full reset
    input  instr_t instr,       // Broadcast from control unit
    input  logic   instr_valid, // 1 = execute this cycle
    output logic   halted,      // Stays high after HALT executes
    output logic   busy,        // High while completing a multi-cycle op

    // For mem read
    input  logic [ADDR_W-1:0] rd_addr,
    output logic [DATA_W-1:0] rd_data,

    // For mem init (write before start, mutually exclusive with STORE)
    input  logic              init_we,
    input  logic [ADDR_W-1:0] init_addr,
    input  logic [DATA_W-1:0] init_data
);
    // Local mem
    (* ram_style = "block" *) logic [DATA_W-1:0] lmem [MEM_DEPTH];

    // Accumulator/register
    logic signed [DATA_W-1:0] acc;

    // Decode operand
    logic signed [OPERAND_W-1:0] operand; // Signed operand for arithmetic ops
    logic        [ADDR_W-1:0]    addr;    // Mem address for mem access ops

    assign operand = signed'(instr.operand);
    assign addr    = instr.operand;

    (* use_dsp = "yes" *) logic signed [DATA_W-1:0] mul_result;
    assign mul_result = acc * operand;

    // Executing flag - CU wants to execute and core is not halted yet
    logic executing;
    assign executing = instr_valid && !halted;

    // Single read port: LOAD takes priority over readback
    logic [ADDR_W-1:0] mem_raddr;
    logic [DATA_W-1:0] mem_rdata;
    logic              load_req, load_in_flight, load_done;

    assign load_req  = executing && instr.opcode == LOAD && !load_in_flight; // only first cycle
    assign mem_raddr = load_req ? addr : rd_addr;
    assign rd_data   = mem_rdata;
    assign busy      = load_req | load_in_flight;  // | mul_req | mul_in_flight | etc.

    // op_done pattern - add more done signals here for future multi-cycle ops
    logic              op_done;
    logic [DATA_W-1:0] op_result;

    assign op_done   = load_done;  // | alu_done | mul_done | etc.
    assign op_result = mem_rdata;

    // Memory block
    logic [ADDR_W-1:0] wr_addr;
    logic [DATA_W-1:0] wr_data;
    logic              wr_en;

    assign wr_en   = init_we || (executing && instr.opcode == STORE && !op_done);
    assign wr_addr = init_we ? init_addr : addr;
    assign wr_data = init_we ? init_data : DATA_W'(acc);

    always_ff @(posedge clk) begin
        if (wr_en)
            lmem[wr_addr] <= wr_data;
        mem_rdata <= lmem[mem_raddr];
    end

    // Load control - separate block so it gets a proper reset
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || start) begin
            load_in_flight <= 1'b0;
            load_done      <= 1'b0;
        end else begin
            load_done <= load_req;
            if (load_req)       load_in_flight <= 1'b1;
            else if (load_done) load_in_flight <= 1'b0;
        end
    end

    // Execute (one instruction per clock cycle)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || start) begin
            acc    <= '0;
            halted <= 1'b0;
        end else begin
            if (op_done) begin
                acc <= signed'(op_result);   // Capture multi-cycle result
            end else if (executing) begin
                case (instr.opcode)
                    NOP: ;   // Do nothing
                    ADD: acc <= DATA_W'(acc + operand);
                    MUL: acc <= mul_result;
                    LOAD: ;  // Handled by op_done above
                    STORE: ; // Handled in memory block above
                    HALT: halted <= 1'b1;
                    default: ;
                endcase
            end
        end
    end
endmodule
