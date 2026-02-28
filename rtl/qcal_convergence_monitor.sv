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
// Module: qcal_convergence_monitor
// Description: Convergence/oscillation/drift monitor operating on window-averaged |e|; asserts CONV, OSC and DRIFT flags used by the supervisor FSM.
// ============================================================
`timescale 1ns/1ps
module qcal_convergence_monitor #(
  // Fixed-point Q4.12 (signed 16-bit) thresholds.
  // Converged when window-avg |e| <= E_TOL for STABLE_HITS consecutive windows.
  // Drift when window-avg |e| deviates from the monitor baseline by DRIFT_DELTA_THR for RESTART_HITS consecutive windows.
  parameter logic signed [15:0] E_TOL        = 16'sd512,   // ~0.125
  parameter int                 STABLE_HITS  = 4,
  // Alternative (steady-state) convergence: if |avg| stops changing
  // (|avg(k)-avg(k-1)| <= DE_TOL) for STABLE_HITS windows *and* the
  // plateau is not excessively large (avg <= PLATEAU_MAX).
  parameter logic signed [15:0] DE_TOL       = 16'sd82,    // ~0.02
  parameter logic signed [15:0] PLATEAU_MAX  = 16'sd2048,  // ~0.5
  parameter logic signed [15:0] DRIFT_DELTA_THR = 16'sd61,  // ~0.015
  parameter int                 RESTART_HITS = 4,
  parameter int                 OSC_WIN      = 8,
  parameter integer             DBG          = 1
)(
  input  logic clk, input logic rst_n,
  input  logic sample_valid,
  input  logic signed [15:0]  e,
  output logic converged,
  output logic oscillating,
  output logic drift,
  output logic signed [15:0] abs_e_avg_o
);
  localparam int FP_W = 16;
  typedef logic signed [FP_W-1:0] fp_t;

  function automatic fp_t fp_abs(input fp_t x);
    if (x[FP_W-1]) fp_abs = -x;
    else fp_abs = x;
  endfunction

  function automatic fp_t fp_sat32(input logic signed [31:0] x);
    logic signed [31:0] maxv, minv;
    begin
      maxv = (32'sh1 <<< (FP_W-1)) - 1;
      minv = -(32'sh1 <<< (FP_W-1));
      if (x > maxv) fp_sat32 = fp_t'(maxv[FP_W-1:0]);
      else if (x < minv) fp_sat32 = fp_t'(minv[FP_W-1:0]);
      else fp_sat32 = fp_t'(x[FP_W-1:0]);
    end
  endfunction
  fp_t abs_e, abs_e_acc;
  fp_t abs_e_avg;
  fp_t abs_e_avg_prev;
  logic e_sign_prev;
  logic [7:0] win_cnt;
  logic [7:0] sign_flip_cnt;
  int stable_win_cnt;
  int drift_win_cnt;
  fp_t abs_diff;
  fp_t ref_abs_e_avg;
  fp_t drift_delta;
  logic ref_valid;

  // Icarus Verilog: prefer continuous assign over always_comb
  assign abs_e = fp_abs(fp_t'(e));
  assign abs_e_avg_o = abs_e_avg;

  // Icarus Verilog: prefer always @(...) over always_ff
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      converged<=0; oscillating<=0; drift<=0;
      abs_e_acc<='0; win_cnt<=0; sign_flip_cnt<=0; e_sign_prev<=0;
      abs_e_avg<='0;
      abs_e_avg_prev<='0;
      stable_win_cnt <= 0;
      drift_win_cnt  <= 0;
      ref_abs_e_avg  <= '0;
      drift_delta    <= '0;
      ref_valid      <= 1'b0;
    end else if(sample_valid) begin
      abs_e_acc <= fp_sat32(abs_e_acc + abs_e);
      win_cnt <= win_cnt + 1;

      // Use the *current* sign directly (avoid NB assignment ordering pitfalls)
      if (win_cnt != 0 && (e[FP_W-1] != e_sign_prev)) sign_flip_cnt <= sign_flip_cnt + 1;
      e_sign_prev <= e[FP_W-1];

      if (win_cnt == (OSC_WIN-1)) begin
        abs_e_avg = fp_t'(abs_e_acc >>> $clog2(OSC_WIN));

        // Window-to-window change
        abs_diff = fp_abs(fp_t'(abs_e_avg - abs_e_avg_prev));
        abs_e_avg_prev <= abs_e_avg;

        // Convergence: either reaches absolute tolerance, or reaches a steady plateau.
        if ((abs_e_avg <= fp_t'(E_TOL)) ||
            ((abs_diff <= fp_t'(DE_TOL)) && (abs_e_avg <= fp_t'(PLATEAU_MAX))))
          stable_win_cnt <= stable_win_cnt + 1;
        else stable_win_cnt <= 0;
        converged <= (stable_win_cnt + 1 >= STABLE_HITS) ? 1'b1 : 1'b0;

        // Latch a monitor baseline the first time convergence is achieved.
        if (((stable_win_cnt + 1) >= STABLE_HITS) && !ref_valid) begin
          ref_abs_e_avg <= abs_e_avg;
          ref_valid     <= 1'b1;
        end

        // Dual-direction drift detection against the latched baseline.
        drift_delta = ref_valid ? fp_abs(fp_t'(abs_e_avg - ref_abs_e_avg)) : '0;
        if (ref_valid && (drift_delta >= fp_t'(DRIFT_DELTA_THR))) drift_win_cnt <= drift_win_cnt + 1;
        else drift_win_cnt <= 0;
        drift <= (drift_win_cnt + 1 >= RESTART_HITS) ? 1'b1 : 1'b0;

        if (DBG) begin
          $display("[CMDBG] t=%0t avg=%f prev=%f diff=%f stable_cnt=%0d conv=%0d ref_valid=%0d ref=%f dlt=%f drift_cnt=%0d drift=%0d",
            $time, $itor($signed(abs_e_avg))/4096.0, $itor($signed(abs_e_avg_prev))/4096.0,
            $itor($signed(abs_diff))/4096.0, stable_win_cnt, converged, ref_valid,
            $itor($signed(ref_abs_e_avg))/4096.0, $itor($signed(drift_delta))/4096.0, drift_win_cnt, drift);
        end

        oscillating <= (sign_flip_cnt >= (OSC_WIN/2));
        abs_e_acc <= '0; win_cnt <= 0; sign_flip_cnt <= 0;
      end
    end
  end
endmodule
