`timescale 1ns/1ps

`include "uvm_macros.svh"

import uvm_pkg::*;

interface dff_if (input logic clk);
    logic rst;
    logic din;
    logic dout;
endinterface

class transaction extends uvm_sequence_item;
  
    rand bit rst;
    rand bit din;
    bit dout;

    function new(input string path = "transaction");
        super.new(path);
    endfunction

    `uvm_object_utils_begin(transaction)
        `uvm_field_int(rst, UVM_DEFAULT);
        `uvm_field_int(din, UVM_DEFAULT);
        `uvm_field_int(dout, UVM_DEFAULT);
    `uvm_object_utils_end

endclass

class generator extends uvm_sequence #(transaction);
    `uvm_object_utils(generator)

    transaction gen_transc;

    function new(input string path = "generator");
        super.new(path);
    endfunction

    virtual task body();
      	gen_transc = transaction::type_id::create("gen_transc");

        repeat(10) begin
            start_item(gen_transc);
            gen_transc.randomize();
            `uvm_info("GEN", $sformatf("Data Generated: rst = %0d, din = %0d, \
            dout = %0d",gen_transc.rst, gen_transc.din, 
            gen_transc.dout), UVM_LOW);
            finish_item(gen_transc);
        end
    endtask
endclass

class driver extends uvm_driver #(transaction);
    `uvm_component_utils(driver);

    transaction drv_transc;

    virtual dff_if drv_dif;

    function new(input string path = "driver", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv_transc = transaction::type_id::create("drv_transc", this);

      	if (!uvm_config_db #(virtual dff_if)::get(this, "", "dif", drv_dif)) begin 
            `uvm_error("DRV", "config_db get failed: Unable to access config_bd.");
        end
        else begin 
            `uvm_info("DRV", "config_db get successful.", UVM_LOW);
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(drv_transc);
            drv_dif.din <= drv_transc.din;
            drv_dif.rst <= drv_transc.rst;
            `uvm_info("DRV", $sformatf("Data Sent: rst = %0d, din = %0d \
            dout = %0d", drv_transc.rst, drv_transc.din, 
            drv_transc.dout), UVM_LOW);
            seq_item_port.item_done();
            repeat(2) begin 
                @(posedge drv_dif.clk);
            end
        end
    endtask

endclass

class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    uvm_analysis_port #(transaction) send;

    transaction mon_transc;

    virtual dff_if mon_dif;

    function new(input string path = "monitor", uvm_component parent = null);
        super.new(path, parent);
        send = new("send", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_transc = transaction::type_id::create("mon_transc", this);

        if (!uvm_config_db #(virtual dff_if)::get(this, "", "dif", mon_dif)) begin
            `uvm_error("MON", "config_db get failed: Unable to access config_bd.");
        end
        else begin 
            `uvm_info("MON", "config_db get successful.", UVM_LOW);
        end

    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin 
            @(posedge mon_dif.clk);
            mon_transc.din = mon_dif.din;
            mon_transc.rst = mon_dif.rst;
            @(posedge mon_dif.clk);
            mon_transc.dout = mon_dif.dout;

            `uvm_info("MON", $sformatf("Data Rcvd: rst = %0d, din = %0d \
            dout = %0d", mon_transc.rst, mon_transc.din, 
            mon_transc.dout), UVM_LOW);
            
            send.write(mon_transc);
        end
    endtask
endclass

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_export #(transaction) expt;
    uvm_analysis_imp #(transaction, scoreboard) recv;

    transaction sco_transc;

    function new(input string path = "scoreboard", uvm_component parent = null);
        super.new(path, parent);
        expt = new("expt", this);
        recv = new("recv", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sco_transc = transaction::type_id::create("sco_transc",this);
    endfunction

    virtual function void write (input transaction transc);
        sco_transc = transc;
        `uvm_info("SCO", $sformatf("Data Rcvd: rst = %0d, din = %0d \
        dout = %0d", sco_transc.rst, sco_transc.din, 
        sco_transc.dout), UVM_LOW);

        if (sco_transc.rst == 1'b0 && sco_transc.din == sco_transc.dout) begin
            `uvm_info("SCO", "Test Passed.", UVM_LOW);
        end

        else if (sco_transc.rst == 1'b1 && sco_transc.dout == 'd0) begin
            `uvm_info("SCO", "Test Passed.", UVM_LOW);
        end
        else begin 
            `uvm_error("SCO", "Test Failed.");
        end
    endfunction
endclass

class agent extends uvm_agent;
    `uvm_component_utils(agent)

    monitor mon;
    driver drv;
    uvm_sequencer #(transaction) seqr;

    function new(input string path = "agent", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = driver::type_id::create("drv", this);
        mon = monitor::type_id::create("mon", this);
        seqr = uvm_sequencer #(transaction)::type_id::create("seqr", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

class environment extends uvm_env;
    `uvm_component_utils(environment)

    scoreboard sco;
    agent agt;

    function new(input string path = "environment", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sco = scoreboard::type_id::create("sco", this);
        agt = agent::type_id::create("agt", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        agt.mon.send.connect(sco.expt);
        sco.expt.connect(sco.recv);
    endfunction
endclass

class test extends uvm_test;
    `uvm_component_utils(test)

    generator gen;
    environment env;

    function new(input string path = "test", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        gen = generator::type_id::create("gen");
        env = environment::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
            gen.start(env.agt.seqr);
        phase.drop_objection(this);
    endtask
endclass

module tb_mux();
    logic g_clk = 1'b0;
    dff_if dif(g_clk);

    always begin 
        g_clk = 1'b0;
        #5;
        g_clk = 1'b1;
        #5;
    end 

    dff dut 
    (
        .clk(dif.clk),
        .rst(dif.rst),
        .din(dif.din),
        .dout(dif.dout)
    );

    initial begin 
        uvm_config_db #(virtual dff_if)::set(null,"uvm_test_top.env.agt*", "dif", dif);

        run_test("test");
    end
endmodule