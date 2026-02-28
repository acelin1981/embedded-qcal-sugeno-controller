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
// Module: tb_qcal_apb_top
// Description: Self-checking testbench/harness: programs rule table via APB, drives plant model + drift/noise, and logs POLL traces.
// ============================================================
`timescale 1ns/1ps
module tb_qcal_apb_top;
  // Fixed-point config (Q4.12 signed 16-bit)
  localparam int FP_W = 16;
  localparam int FP_F = 12;
  typedef logic signed [FP_W-1:0] fp_t;

  // Icarus Verilog compatibility:
  // Avoid declarations inside procedural blocks.
  fp_t noise, p_true;
  integer thr;
  fp_t D[0:8];

  function automatic fp_t fp_from_int(input int x);
    fp_from_int = fp_t'(x <<< FP_F);
  endfunction

  function automatic fp_t fp_from_real(input real x);
    fp_from_real = fp_t'($rtoi(x * (1<<FP_F)));
  endfunction

  // Sign-extend 16-bit fixed-point to 32-bit APB data
  function automatic [31:0] sx16_to32(input fp_t x);
    sx16_to32 = {{16{x[FP_W-1]}}, x};
  endfunction
  logic clk, rst_n;
  logic PSEL, PENABLE, PWRITE;
  logic [11:0] PADDR;
  logic [31:0] PWDATA;
  logic [31:0] PRDATA;
  logic PREADY, PSLVERR;
  logic plant_bit_valid, plant_bit;

  qcal_apb_top dut(
    .clk(clk),.rst_n(rst_n),
    .PSEL(PSEL),.PENABLE(PENABLE),.PWRITE(PWRITE),.PADDR(PADDR),.PWDATA(PWDATA),
    .PRDATA(PRDATA),.PREADY(PREADY),.PSLVERR(PSLVERR),
    .plant_bit_valid(plant_bit_valid),.plant_bit(plant_bit)
  );

  initial clk=0; always #5 clk=~clk;

  fp_t amp_star, k_gain;
  int seed;
  fp_t amp_q;
  int drift_k, drift_len;
  integer drift_step_m;
  real drift_step_r;
  logic drift_on;
  logic tb_conv_en;
  logic ever_nonzero_e;

  // TB-side convergence detection (do NOT rely on RTL CONV bit)
  int k;
  int stable_cnt;
  int KMAX;
  int M_STABLE;
  real E_TOL;
  real e_real;
  real abs_e;
  logic [31:0] st, amp, le, ld, uc;

  function automatic fp_t clamp01(input fp_t x);
    if (x < 0) return 0;
    if (x > fp_from_int(1)) return fp_from_int(1);
    return x;
  endfunction

  task automatic apb_write(input [11:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      PSEL<=1; PWRITE<=1; PADDR<=addr; PWDATA<=data; PENABLE<=0;
      @(posedge clk);
      PENABLE<=1;
      @(posedge clk);
      PSEL<=0; PWRITE<=0; PENABLE<=0; PADDR<=0; PWDATA<=0;
    end
  endtask

  task automatic apb_read(input [11:0] addr, output [31:0] data);
    begin
      @(posedge clk);
      PSEL<=1; PWRITE<=0; PADDR<=addr; PENABLE<=0;
      @(posedge clk);
      PENABLE<=1;
      @(posedge clk);
      data = PRDATA;
      PSEL<=0; PENABLE<=0; PADDR<=0;
    end
  endtask

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin plant_bit_valid<=0; plant_bit<=0; end
    else begin
      noise = fp_t'((($urandom(seed) % 165) - 82));
      p_true = clamp01((fp_from_int(1)>>>1) + (((amp_q - amp_star)*k_gain) >>> FP_F) + noise + (drift_on ? fp_from_real(drift_step_r) : 0));
      thr = $urandom(seed) % 4096;
      plant_bit <= (thr < p_true);
      plant_bit_valid <= 1'b1;
    end
  end

  initial begin
    seed=123;
    amp_q = 0;
    drift_on = 0;
    amp_star = fp_from_real(1.0);
    k_gain   = fp_from_real(0.20);

    PSEL=0; PENABLE=0; PWRITE=0; PADDR=0; PWDATA=0;
    rst_n=0;
    repeat(10) @(posedge clk);
    rst_n=1;

    // MANUAL mode enable
    apb_write(12'h000, 32'h1);

    D[0]=fp_from_real( 0.10); D[1]=fp_from_real( 0.08); D[2]=fp_from_real( 0.06);
    D[3]=fp_from_real( 0.04); D[4]=fp_from_real( 0.00); D[5]=fp_from_real(-0.04);
    D[6]=fp_from_real(-0.06); D[7]=fp_from_real(-0.08); D[8]=fp_from_real(-0.10);

    for (int i=0;i<9;i++) begin
      apb_write(12'h010, i);
      apb_write(12'h014, sx16_to32(D[i]));
      apb_write(12'h018, 32'h1);
    end

    // Read back rule table via APB
    for (int i=0;i<9;i++) begin
      logic [31:0] rdd;
      apb_write(12'h034, i);
      apb_read(12'h038, rdd);
      $display("[RULE_RD] i=%0d delta=%f", i, $signed(rdd)/4096.0);
    end

    // AUTO + START
    apb_write(12'h000, 32'h0);
    apb_write(12'h000, 32'h2);

    // -------- TB convergence settings --------
    // NOTE: Your current runs show E around ~0.45-0.50. If you want to *see* convergence,
    // start with a looser E_TOL (e.g. 0.5) to validate the mechanism, then tighten it.
    E_TOL    = 0.02;   // error tolerance (real)
    M_STABLE = 8;      // must stay within E_TOL for this many polls
    KMAX     = 2000;   // max polls before timeout
    stable_cnt = 0;
    tb_conv_en = 0;
    ever_nonzero_e = 0;
    drift_k = 800;
    drift_len = 400;
    drift_step_m = 0;
    drift_step_r = 0.0;
    if ($value$plusargs("DRIFT_K=%d", drift_k)) ;
    if ($value$plusargs("DRIFT_LEN=%d", drift_len)) ;
    if ($value$plusargs("DRIFT_STEP_M=%d", drift_step_m)) ;
    drift_step_r = drift_step_m / 1000.0;

    for (k=0; k<KMAX; k++) begin
      apb_read(12'h020, st);
      apb_read(12'h024, amp);
      apb_read(12'h028, le);
      apb_read(12'h02C, ld);
      apb_read(12'h030, uc);

      drift_on = (k >= drift_k) && (k < (drift_k + drift_len));
      if (k==drift_k || k==(drift_k+drift_len)) begin
        $display("[TBDBG] t=%0t k=%0d drift_on=%0d drift_step=%f", $time, k, drift_on, drift_step_r);
      end

      amp_q  = fp_t'(amp[15:0]);
      e_real = $itor($signed(le)) / 4096.0;
      abs_e  = (e_real < 0.0) ? (-e_real) : e_real;
      if (abs_e > 1.0e-9) ever_nonzero_e = 1;
      tb_conv_en = (uc >= 5) && ever_nonzero_e;

      if (tb_conv_en) begin
        if (abs_e <= E_TOL) stable_cnt++;
        else                stable_cnt = 0;
      end else begin
        stable_cnt = 0;
      end

      $display("[POLL] k=%0d BUSY=%0d CONV=%0d OSC=%0d DRIFT=%0d UPD=%0d AMP=%f E=%f D=%f tben=%0d stable=%0d/%0d tol=%f",
        k, st[0], st[1], st[2], drift_on, uc,
        amp_q/4096.0, e_real, $itor($signed(ld))/4096.0, tb_conv_en,
        stable_cnt, M_STABLE, E_TOL
      );

      if (tb_conv_en && stable_cnt >= M_STABLE) begin
        $display("[CONVERGED_TB] k=%0d |E|=%f <= %f for %0d consecutive polls", k, abs_e, E_TOL, M_STABLE);
        $finish;
      end

      repeat(600) @(posedge clk);
    end

    $display("[TIMEOUT_TB] Not converged within KMAX=%0d polls. Last |E|=%f (tol=%f)", KMAX, abs_e, E_TOL);
    $finish;
  end
endmodule
