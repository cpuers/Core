`include "defines.v"

module InstrBuffer (
    input                                             clk,
    input                                             rst,
    input                                             flush,
    input  [                3:0][`IB_DATA_BUS_WD-1:0] if1_to_ib,
    input  [                2:0]                      push_num,
    input  [                1:0]                      pop_op,
    output [ `IB_WIDTH_LOG2:0]                      if_bf_sz,
    output empty,
    output [`IB_DATA_BUS_WD-1:0]                      pop_instr0,
    output [`IB_DATA_BUS_WD-1:0]                      pop_instr1

);
  reg [`IB_DATA_BUS_WD-1:0] buffer[`IB_WIDTH-1:0];
  reg [`IB_WIDTH_LOG2-1:0] head_ptr;
  reg [`IB_WIDTH_LOG2-1:0] tail_ptr;
  reg [`IB_WIDTH_LOG2:0] buffer_size;
  wire [`IB_WIDTH_LOG2-1:0] pop_num;
  always @(posedge clk) begin
    if (rst | flush) begin
      buffer_size <= `IB_WIDTH_LOG2'h0;
    end else begin
      buffer_size <= buffer_size + {2'b0, push_num} - {3'b0, (&pop_op ? 2'd2:pop_op)}; // FIX ME
    end
  end
  assign if_bf_sz = buffer_size;
  always @(posedge clk) begin
    if (rst | flush) begin
      head_ptr <= `IB_WIDTH_LOG2'h0;
      tail_ptr <= `IB_WIDTH_LOG2'h0;
    end else begin
      //push
      case (push_num)
        3'd0: begin
          tail_ptr <= tail_ptr;
        end
        3'd1: begin
          buffer[tail_ptr] <= if1_to_ib[0];
          tail_ptr <= tail_ptr + 1;
        end
        3'd2: begin

          buffer[tail_ptr] <= if1_to_ib[0];
          buffer[tail_ptr+1] <= if1_to_ib[1];
          tail_ptr <= tail_ptr + 2;
        end
        3'd3: begin
          buffer[tail_ptr] <= if1_to_ib[0];
          buffer[tail_ptr+1] <= if1_to_ib[1];
          buffer[tail_ptr+2] <= if1_to_ib[2];
          tail_ptr <= tail_ptr + 3;
        end
        3'd4: begin
          buffer[tail_ptr] <= if1_to_ib[0];
          buffer[tail_ptr+1] <= if1_to_ib[1];
          buffer[tail_ptr+2] <= if1_to_ib[2];
          buffer[tail_ptr+3] <= if1_to_ib[3];
          tail_ptr <= tail_ptr + 4;
        end
        default: begin
          tail_ptr <= tail_ptr;
        end
      endcase
      //pop

      case (pop_op)
        2'b00: begin
          head_ptr <= head_ptr;
        end
        2'b01: begin
          head_ptr <= head_ptr + 1;
        end
        2'b11: begin
          head_ptr <= head_ptr + 2;
        end
        default: begin
          head_ptr <= head_ptr;
        end
      endcase
    end
  end


  assign pop_instr0 = buffer[head_ptr];
  assign pop_instr1 = buffer[head_ptr+1];
  assign empty = | buffer_size;
  

endmodule
