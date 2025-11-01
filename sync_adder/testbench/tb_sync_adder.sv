`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

localparam DATA_WIDTH = 32;

class transaction extends uvm_sequence_item;
    rand bit rst;
    rand bit [DATA_WIDTH-1:0] a;
    rand bit [DATA_WIDTH-1:0] b;
    bit [DATA_WIDTH:0] y;

    function new (input string path = "transaction");
      super.new(path);
    endfunction

    `uvm_object_utils_begin(transaction)
        `uvm_field_int(rst, UVM_DEFAULT);
        `uvm_field_int(a, UVM_DEFAULT);
        `uvm_field_int(b, UVM_DEFAULT);
        `uvm_field_int(y, UVM_DEFAULT);
    `uvm_object_utils_end
endclass

class generator extends uvm_sequence #(transaction);
    `uvm_object_utils(generator)

    transaction t;

    function new (input string path = "generator");
        super.new(path);
    endfunction

    virtual task body();
        t = transaction::type_id::create("t");
        repeat(10) begin 
            start_item(t);
            t.randomize();
          	`uvm_info("GEN", $sformatf("Data Send: rst = %0d, a = %0d, b = %0d",t.rst, t.a, t.b),UVM_LOW);
            finish_item(t);
        end
    endtask
endclass

class driver extends uvm_driver #(transaction);
    `uvm_component_utils(driver)

    transaction tc;

    virtual sync_adder_if #(.DATA_WIDTH(DATA_WIDTH)) saif;

    function new(input string path = "driver", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual sync_adder_if #(.DATA_WIDTH(DATA_WIDTH)))::get(this, "", "saif", saif)) begin 
            `uvm_error("DRV", "uvm_config_db: Unable to set the configuration.");
        end
        else begin
          `uvm_info("DRV", "uvm_config_db: configuration done.", UVM_LOW);
        end
    endfunction
  
  	virtual task pre_run_phase(uvm_phase phase);
      saif.rst = 1'b0;
      saif.a = 'd0;
      saif.b = 'd0;
      repeat (5) begin
      	@(posedge saif.clk);
      end
      saif.rst = 1'b1;
    endtask

    virtual task run_phase(uvm_phase phase);
		forever begin
            seq_item_port.get_next_item(tc); // seq_item_port is build in uvm_driver
          	saif.rst <= tc.rst;
            saif.a <= tc.a;
            saif.b <= tc.b;
          	`uvm_info("DRV", $sformatf("Data Sent: rst = %0d, a = %0d, b = %0d",tc.rst, tc.a, tc.b), UVM_LOW);
          	seq_item_port.item_done();
          	repeat (2) begin
              @(posedge saif.clk);
            end
        end
    endtask
endclass

class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    uvm_analysis_port #(transaction) send;

    transaction t;

    virtual sync_adder_if #(.DATA_WIDTH(DATA_WIDTH)) saif;

    function new (input string path = "monitor", uvm_component parent = null);
        super.new(path, parent);
        send = new("send", this);
    endfunction

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        t = transaction::type_id::create("t");
        if (!uvm_config_db #(virtual sync_adder_if #(.DATA_WIDTH(DATA_WIDTH)))::get(this,"","saif",saif)) begin 
            `uvm_error("MON", "config_db Failed: Unable to access the config_db");
        end
        else begin
            `uvm_info("MON", "config_db Successful.",UVM_LOW);
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            repeat(2) begin
                @(posedge saif.clk);
            end
            t.rst = saif.rst;
            t.a = saif.a;
            t.b = saif.b;
            t.y = saif.y;

            `uvm_info("MON", $sformatf("Data Sent to SCO: rst = %0d, a = %0d, b = %0d, y = %0d",t.rst, t.a, t.b, t.y), UVM_LOW);

            send.write(t);
        end
    endtask
endclass

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard);

    uvm_analysis_imp #(transaction,scoreboard) recv;

    transaction tr;

    function new (input string path = "scoreboard", uvm_component parent = null);
        super.new(path, parent);
        recv = new("recv", this);
    endfunction 

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");
    endfunction

    virtual function void write(input transaction t);
        tr = t;
        `uvm_info("SCO", $sformatf("Data rcvd from monitor: rst = %0d, a = %0d, b = %0d",tr.rst, tr.a, tr.b), UVM_LOW);
      	if ((tr.rst == 1'b0) && tr.y == (tr.a + tr.b)) begin 
              `uvm_info("SCO", "Test Passed", UVM_LOW);
        end
      	else if (tr.rst == 1'b1 && tr.y == 'd0) begin
            `uvm_info("SCO", "Test Passed", UVM_LOW);
        end
        else begin 
            `uvm_error("SCO", "Test Failed");
        end
    endfunction
endclass

class agent extends uvm_agent;
    `uvm_component_utils(agent)

    driver drv;
    monitor mon;
    uvm_sequencer #(transaction) seqr;

    function new (input string path = "agent", uvm_component parent = null);
        super.new(path,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = driver::type_id::create("drv",this);
        mon = monitor::type_id::create("mon", this);
        seqr = uvm_sequencer #(transaction)::type_id::create("seqr",this);
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
      	agt.mon.send.connect(sco.recv);
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
        gen = generator::type_id::create("gen", this);
        env = environment::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
            gen.start(env.agt.seqr);
        phase.drop_objection(this);
    endtask
endclass

module sync_adder_tb();
    sync_adder_if #(.DATA_WIDTH(DATA_WIDTH)) saif();

	initial begin 
        saif.clk = 1'b0;
    end

    always begin 
        saif.clk = 1'b0;
        #5;
        saif.clk = 1'b1;
        #5;
    end  
  
    sync_adder 
    #(
        .DATA_WIDTH(DATA_WIDTH)
    ) 
    dut 
    (
        .clk(saif.clk),
        .rst(saif.rst),
        .a(saif.a),
        .b(saif.b), 
        .y(saif.y)
    );

    initial begin
        uvm_config_db #(virtual sync_adder_if #(.DATA_WIDTH(DATA_WIDTH)))::set(null, "uvm_test_top.env.agt*", "saif", saif);

        run_test("test");
    end

endmodule