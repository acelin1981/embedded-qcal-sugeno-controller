// SPDX-License-Identifier: MIT
//
// MIT License
//
// Copyright (c) 2026 Che-Ping Lin (Ace Lin)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

// ============================================================
// Module: qcal_param_update
// Description: Bounded parameter update: amp_next = clip(amp + Δ) with step limit and saturation bounds (fixed-point).
// ============================================================
`timescale 1ns/1ps
module qcal_param_update #(
  parameter logic signed [15:0] STEP_LIMIT = 16'sd512,
  parameter logic signed [15:0] SAT_MIN    = -16'sd16384,
  parameter logic signed [15:0] SAT_MAX    =  16'sd16384
)(
  input  logic clk, input logic rst_n,
  input  logic in_valid,
  input  logic signed [15:0]  cur_param,
  input  logic signed [15:0]  delta,
  output logic out_valid,
  output logic signed [15:0]  next_param
);
  localparam int FP_W = 16;
  typedef logic signed [FP_W-1:0] fp_t;

  fp_t d_lim, sum;
  logic signed [31:0] tmp;
  // Icarus Verilog: prefer plain always @* over always_comb
  always @* begin
    if(delta>STEP_LIMIT) d_lim=STEP_LIMIT;
    else if(delta<-STEP_LIMIT) d_lim=-STEP_LIMIT;
    else d_lim=delta;
    tmp = cur_param + d_lim;
    if(tmp>SAT_MAX) sum=SAT_MAX;
    else if(tmp<SAT_MIN) sum=SAT_MIN;
    else sum=fp_t'(tmp[15:0]);
  end

  // Icarus Verilog: prefer always @(...) over always_ff
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin out_valid<=0; next_param<='0; end
    else begin out_valid<=in_valid; if(in_valid) next_param<=sum; end
  end
endmodule
