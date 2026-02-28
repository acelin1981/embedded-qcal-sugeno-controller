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
// Module: qcal_error_estimator
// Description: Computes p_meas, error e=p_target-p_meas, and delta-error de=e(k)-e(k-1) in fixed-point from window statistics.
// ============================================================
`timescale 1ns/1ps
module qcal_error_estimator #(
  parameter integer DBG = 1
) (
  input  logic clk, input logic rst_n,
  input  logic stats_valid,
  input  logic [15:0] count1,
  input  logic [15:0] N_total,
  input  logic signed [15:0] p_target,
  output logic out_valid,
  output logic signed [15:0] p_meas,
  output logic signed [15:0] e,
  output logic signed [15:0] de
);
  localparam int FP_W = 16;
  localparam int FP_F = 12;
  typedef logic signed [FP_W-1:0] fp_t;

  fp_t e_prev;
  fp_t p_raw;

  always_comb begin
    if (N_total==0) p_raw='0;
    else p_raw = fp_t'(((count1 <<< FP_F) / N_total));
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin out_valid<=0; p_meas<='0; e<='0; de<='0; e_prev<='0; end
    else begin
      out_valid <= stats_valid;
      if (stats_valid) begin
        p_meas <= p_raw;
        e <= p_target - p_raw;
        de <= (p_target - p_raw) - e_prev;
        e_prev <= (p_target - p_raw);
        if (DBG) $display("[ESTDBG] t=%0t count1=%0d N=%0d p_raw=%f e=%f de=%f", $time, count1, N_total, $itor($signed(p_raw))/4096.0, $itor($signed(p_target-p_raw))/4096.0, $itor($signed((p_target-p_raw)-e_prev))/4096.0);
      end
    end
  end
endmodule
