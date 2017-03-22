`timescale 1ps/1ps


//
// This is an inefficient implementation.
//   make it run correctly in less cycles, fastest implementation wins
//

//
// States:
//

// Fetch
`define F0 0
`define F2 2

// decode
`define D0 3

// load
`define L0 4
`define L2 6

// write-back
`define WB 7

// execute
`define EXEC 10

// halt
`define HALT 15

module main();

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(1,main);
        $dumpvars(1,i0);
    end

    // clock
    wire clk;
    clock c0(clk);

    counter ctr(finalHalt,clk,(state == `D0),cycle);

    reg [3:0]state = `F0;
    reg [3:0]state_2 = `F0;
  
    // regs
    reg [15:0]regs[0:15];

    // PC
    reg [15:0]pc = 16'h0000;

    // fetch 
    wire [15:0]fetchOut;
    wire fetchReady;
        wire [15:0]fetchOut2;
    wire fetchReady2;
        wire [15:0]fetchOut3;
    wire fetchReady3;
        wire [15:0]fetchOut4;
    wire fetchReady4;
        wire [15:0]fetchOut5;
    wire fetchReady5;
        wire [15:0]fetchOut6;
    wire fetchReady6;
        wire [15:0]fetchOut7;
    wire fetchReady7;

    // load 
    wire [15:0]loadOut;
    wire loadReady;

    wire [15:0]sourcea = sources[ra];
    wire [15:0]sourceb = sources[rb];

    wire [15:0]sourcexxxxxxx = sources[queue[queue_pointer][11:8]];
    wire [15:0]sourceyyyyyyyy = sources[queue[queue_pointer][7:4]];

    mem i0(clk,
       /* fetch port */
       (state == `F0),
       pc,
       fetchReady,
       fetchOut,

       /* load port */
       (state == `L0),
       memory_res,
       loadReady,
       loadOut,

       (booting),
       pc + 2,
       fetchReady2,
       fetchOut2,
            
        (booting),
       pc + 3,
       fetchReady3,
       fetchOut3,
        (booting),
       pc + 4,
       fetchReady4,
       fetchOut4,
       (booting),
       pc + 5,
       fetchReady5,
       fetchOut5,
       (booting),
       pc + 6,
       fetchReady6,
       fetchOut6
);
    reg actualHalt = 0;
    reg finalHalt = 0;
    reg [15:0] inst_list [0:1024];
    reg [15:0] memory_list [0:1024];
    reg [15:0] inst_list_index = 0;
    reg [15:0] memory_index = 0;
    reg [15:0] list_size = 0;
    //reg [3:0] sources [0:29];

    reg booting = 1;

    reg [10:0] sources [0:15];
    //reg [15:0] source_values [0:29];

    reg [15:0] queue [0:1024];
    reg [15:0] pc_queue [0:1024];
    reg [15:0] queue_index = 0;
    reg [15:0] queue_pointer = 0;
    reg [15:0] queue_size = 0;


    reg [15:0]inst;

    wire [15:0]r_3 = regs[3];

    wire[15:0]dis_instr = queue[queue_pointer];

    // decode
    wire [3:0]opcode = inst[15:12];
    wire [3:0]ra = inst[11:8];
    wire [3:0]rb = inst[7:4];
    wire [3:0]rt = inst[3:0];
    wire [15:0]jjj = inst[11:0]; // zero-extended
    wire [15:0]ii = inst[11:4]; // zero-extended

    reg [15:0]va;
    reg [15:0]vb;

    reg [15:0]res; // what to write in the register file
    reg [15:0]memory_res;

    wire writes = opcode == 4'h0 | opcode == 4'h1 | opcode == 4'h4 | opcode == 4'h5;

    wire usesRegs = opcode == 4'h1 | opcode == 4'h6 |  
    opcode == 4'h7;

    reg isRekt = 0;

    reg load_lock = 0;
    wire [15:0] gdi = sources[3];

    reg useGhostie = 0;
    reg[15:0]ghost_pc = 0;

    reg jeqForce = 0;

    always @(posedge clk) begin
        case(state)
        `F0: begin
            state <= `F2;
        end
        `F2: begin

            if (fetchReady) begin
                state <= `D0;
                if(queue_size > 0 & sources[queue[queue_pointer][11:8]] == 0 & 
                sources[queue[queue_pointer][7:4]] == 0) begin
                    inst <= queue[queue_pointer];
                    pc <= pc_queue[queue_pointer];
                    queue_pointer <= queue_pointer + 1;
                    ghost_pc <= pc;
                    jeqForce <= 0;
                end else if(jeqForce) begin
                    state <= `F0;
                end
                else begin
                    inst <= fetchOut;
                end

            end
        end
        `D0: begin
            if ((((writes & sources[rt] > 0) | (usesRegs & (sources[ra] > 0 | sources[rb] > 0))) & !(opcode == 4'h7))
                |  ((opcode == 4'h4 | opcode == 4'h5) & load_lock)) begin
               queue[queue_index] = inst;
               queue_index <= queue_index + 1;
               queue_size <= queue_size + 1;

               pc_queue[queue_index] <= pc;
               if(usesRegs) begin
                   //sources[ra] <= sources[ra] + 1; 
                   //sources[rb] <= sources[rb] + 1;                        
               end
               if(opcode == 4'h6) begin
                   jeqForce <= 1;
               end
               state <= `F0;
               pc <= pc + 1;
            end
            else begin
                va <= regs[ra];
                vb <= regs[rb];
                case(opcode)
                4'h0 : begin // mov
                    res <= ii;
                    state <= `WB;
                end
                4'h1 : begin // add
                    state <= `EXEC;
                end
                4'h2 : begin // jmp
                    pc <= jjj;
                    state <= `F0;
                end
                4'h3 : begin // halt
                    actualHalt <= 1;
                end
                4'h4 : begin // ld
                    memory_res <= ii;
                    state <= `L0;
                end
                4'h5 : begin // ldr
                    state <= `EXEC;
                end
                4'h6 : begin // jeq
                    if(sources[ra] > 0 | sources[rb] > 0) begin
                        state <= `D0;
                    end else begin
                        state <= `EXEC;
                    end
                end
                default: begin
                    $display("unknown inst %x @ %x",inst,pc);
                    pc <= pc + 1;
                    state <= `F0;
                end
                endcase
            end        
        end
        `WB: begin
            //$display("#reg[%d] <= 0x%x",rt,res);
            regs[rt] <= res;
            pc <= pc + 1;
            state <= `F0;
        end
        `L0: begin
            state <= `L2;
            inst_list[inst_list_index] = inst;
            inst_list_index <= inst_list_index + 1;
            memory_index = inst_list_index;
            list_size <= list_size + 1;
            sources[rt] <= sources[rt] + 1;
            pc <= pc + 1;
            state <= `F0;
            load_lock <= 1;
        end
        `L2: begin

            
        end
        `EXEC : begin
            case (opcode)
                4'h1 : begin // add
                    res <= va + vb;
                    state <= `WB;
                end
                4'h5 : begin // ldr
                    memory_res <= va + vb;
                    state <= `L0;
                end
                4'h6 : begin // jeq

                    pc <= pc + ((va == vb) ? inst[3:0] : 1);
                    state <= `F0;
                end
               
                default: begin
                    $display("invalid opcode in exec %d",opcode);
                    $finish;
                end
            endcase
        end
        `HALT: begin
        end
        default: begin
            $display("unknown state %d",state);
            $finish;
        end
        endcase
        if (loadReady) begin
            memory_list[memory_index] = loadOut;
            state_2 <= `WB;
            load_lock <= 0;
        end
        if(state_2 == `WB) begin
            regs[inst_list[memory_index][3:0]] <= memory_list[memory_index];
            list_size <= list_size - 1;
            sources[inst_list[memory_index][3:0]] <= sources[inst_list[memory_index][3:0]] - 1;
            state_2 <= 0;
            memory_index <= memory_index + 1;
        end
        if((state == `HALT | actualHalt) & list_size == 0 & !finalHalt) begin
            $display("#0:%x",regs[0]);
            $display("#1:%x",regs[1]);
            $display("#2:%x",regs[2]);
            $display("#3:%x",regs[3]);
            $display("#4:%x",regs[4]);
            $display("#5:%x",regs[5]);
            $display("#6:%x",regs[6]);
            $display("#7:%x",regs[7]);
            $display("#8:%x",regs[8]);
            $display("#9:%x",regs[9]);
            $display("#10:%x",regs[10]);
            $display("#11:%x",regs[11]);
            $display("#12:%x",regs[12]);
            $display("#13:%x",regs[13]);
            $display("#14:%x",regs[14]);
            $display("#15:%x",regs[15]);
            finalHalt <= 1;
        end

        if(booting) begin
            booting <= 0;
            sources[0] = 0;
            sources[1] = 0;
            sources[2] = 0;
            sources[3] = 0;
            sources[4] = 0;
            sources[5] = 0;
            sources[6] = 0;
            sources[7] = 0;
            sources[8] = 0;
            sources[9] = 0;
            sources[10] = 0;
            sources[11] = 0;
            sources[12] = 0;
            sources[13] = 0;
            sources[14] = 0;
            sources[15] = 0;
        end
    end

endmodule
