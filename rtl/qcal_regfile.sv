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
// Module: qcal_regfile
// Description: Minimal register file holding the calibrated parameter amp (write on update, read for plant/control).
// ============================================================
`timescale 1ns/1ps
module qcal_regfile (
  input logic clk, input logic rst_n,
  input logic wr_en,
  input  logic signed [15:0] wr_data,
  output logic signed [15:0] reg_amp
);
  localparam int FP_W = 16;
  typedef logic signed [FP_W-1:0] fp_t;

  fp_t amp_r;
  assign reg_amp = amp_r;
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) amp_r <= '0;
    else if (wr_en) amp_r <= wr_data;
  end
endmodule
