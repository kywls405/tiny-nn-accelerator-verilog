// SPDX-License-Identifier: MIT
// Self-checking testbench by Yongjin Kim.

`timescale 1ns/1ns

module tb_tiny_nn_accelerator ();
    integer             i;              // 반복문에서 output address 또는 buffer index로 사용
    integer             limit;          // 현재 test case에서 비교해야 하는 output 개수, base=64 extra=128
    integer             wait_count;     // done이 올라올 때까지 기다린 cycle 수를 세는 counter
    integer             err;            // 현재 base/extra test case 안에서 발생한 error 개수
    integer             total_err;      // base와 extra 전체를 통틀어 누적된 error 개수

    reg                 clk, rst, run;  // clk: 10ns period clock, rst: DUT reset, run: 1-cycle start pulse
    reg                 batch_mode;     // batch_mode 0이면 base 8-batch, 1이면 extra 16-batch 선택
    reg                 tb_fault;       // timeout 또는 X output처럼 testbench가 치명적 오류를 발견했는지 표시

    wire                done;           // DUT가 전체 연산 완료를 알리는 신호
    wire    [4:0]       state;          // DUT 내부 FSM state를 waveform에서 확인하기 위한 신호
    wire    [31:0]      cycle_count;    // DUT 내부 latency counter

    wire                re_x;           // DUT가 X memory를 읽을 때 사용하는 read enable
    wire    [6:0]       addr_x;         // DUT가 X memory에 전달하는 read address
    wire    [7:0]       data_x_base;    // base input memory에서 읽힌 8bit X data
    wire    [7:0]       data_x_extra;   // extra input memory에서 읽힌 8bit X data
    wire    [7:0]       data_x;         // batch_mode에 따라 DUT로 전달되는 최종 X data

    wire                re_w1;          // DUT가 W1T memory를 읽을 때 사용하는 read enable
    wire    [5:0]       addr_w1;        // DUT가 W1T memory에 전달하는 read address
    wire    [7:0]       data_w1;        // W1T memory에서 읽힌 8bit weight data

    wire                re_w2;          // DUT가 W2T memory를 읽을 때 사용하는 read enable
    wire    [5:0]       addr_w2;        // DUT가 W2T memory에 전달하는 read address
    wire    [7:0]       data_w2;        // W2T memory에서 읽힌 8bit weight data

    wire                we_y;           // DUT가 Y output을 write할 때 올리는 write enable
    wire    [6:0]       addr_y;         // DUT가 write하는 Y output address
    wire    [15:0]      data_y;         // DUT가 write하는 16bit final output data

    reg     [15:0]      dut_y_mem   [0:127]; // DUT가 write한 Y output을 testbench 내부에 저장하는 capture memory
    reg                 dut_y_valid [0:127]; // 각 Y address가 실제로 write되었는지 확인하기 위한 valid bit
    reg signed [15:0]   ref_y_base_mem  [0:63];  // base 정답 y_hex.txt를 직접 읽어 저장하는 reference array
    reg signed [15:0]   ref_y_extra_mem [0:127]; // extra 정답 y_hex.txt를 직접 읽어 저장하는 reference array

    assign data_x = batch_mode ? data_x_extra : data_x_base; // batch_mode에 따라 base/extra X memory output 중 하나를 DUT에 전달

    function has_x8;                          // 8bit value 안에 X가 포함되어 있는지 확인하는 function
        input [7:0] value;                     // 검사할 8bit 값
        begin
            has_x8 = (^value === 1'bx);        // reduction XOR 결과가 X이면 value 안에 X가 있다고 판단
        end
    endfunction

    function has_x16;                         // 16bit value 안에 X가 포함되어 있는지 확인하는 function
        input [15:0] value;                    // 검사할 16bit 값
        begin
            has_x16 = (^value === 1'bx);       // reduction XOR 결과가 X이면 value 안에 X가 있다고 판단
        end
    endfunction

    file_memory #("vectors/model/w1_t_hex.txt", 8, 6, 0) // W1T hex file을 읽는 8bit x 64 behavioral memory
        U_mem_W1T    (.clk(clk), .en(re_w1), .we(1'b0), .addr(addr_w1), .din(8'd0), .dout(data_w1)); // DUT의 re_w1/addr_w1에 맞춰 data_w1 출력

    file_memory #("vectors/model/w2_t_hex.txt", 8, 6, 0) // W2T hex file을 읽는 8bit x 64 behavioral memory
        U_mem_W2T    (.clk(clk), .en(re_w2), .we(1'b0), .addr(addr_w2), .din(8'd0), .dout(data_w2)); // DUT의 re_w2/addr_w2에 맞춰 data_w2 출력

    file_memory #("vectors/inout_base/x_hex.txt", 8, 6, 0) // base X hex file을 읽는 8bit x 64 memory
        U_mem_X_BASE (.clk(clk), .en(re_x), .we(1'b0), .addr(addr_x[5:0]), .din(8'd0), .dout(data_x_base)); // base mode용 X data 출력

    file_memory #("vectors/inout_extra/x_hex.txt", 8, 7, 0) // extra X hex file을 읽는 8bit x 128 memory
        U_mem_X_EXTRA(.clk(clk), .en(re_x), .we(1'b0), .addr(addr_x), .din(8'd0), .dout(data_x_extra)); // extra mode용 X data 출력

    initial begin                              // reference Y는 functional logic 없이 정답 file만 직접 load
        $readmemh("vectors/inout_base/y_hex.txt", ref_y_base_mem);   // base 정답 64개 load
        $readmemh("vectors/inout_extra/y_hex.txt", ref_y_extra_mem); // extra 정답 128개 load
    end

    top U_top (                              // 검증 대상 DUT instance, project.v의 top module
        .clk(clk),
        .rst(rst),
        .run(run),
        .batch_mode(batch_mode),
        .done(done),
        .state(state),
        .cycle_count(cycle_count),
        .re_x(re_x),
        .addr_x(addr_x),
        .data_x(data_x),
        .re_w1(re_w1),
        .addr_w1(addr_w1),
        .data_w1(data_w1),
        .re_w2(re_w2),
        .addr_w2(addr_w2),
        .data_w2(data_w2),
        .we_y(we_y),
        .addr_y(addr_y),
        .data_y(data_y)
    );

    always #5 clk <= ~clk;                    // 10ns period clock 생성 -> 100MHz 기준 simulation

    always @(posedge clk) begin                 // DUT가 Y output을 write하는 순간 testbench 내부 memory에 capture
        if (we_y) begin                         // we_y가 1이면 현재 data_y가 유효한 최종 output이라고 판단
            dut_y_mem[addr_y] <= data_y;        // DUT가 write한 data_y를 해당 addr_y 위치에 저장
            dut_y_valid[addr_y] <= 1'b1;        // 해당 address가 실제로 write되었음을 표시 -> false pass 방지
        end
    end

    always @(posedge clk) begin                 // Y write data에 X가 섞였는지 별도로 감시하는 block
        #2;                                     // nonblocking update 이후 안정된 값을 보기 위해 clock edge 뒤 2ns 대기
        if (!tb_fault && we_y && has_x16(data_y)) begin // write 순간 data_y에 X가 있으면 즉시 error 처리
            tb_fault = 1'b1;                    // testbench fault flag set
            total_err = total_err + 1;          // 전체 error count 증가
            $display("[TB ERROR] DUT wrote X output at Y address %0d.", addr_y); // 어떤 address에서 X가 나왔는지 출력
        end
    end

    task reset_dut;                            // DUT와 testbench capture buffer를 한 번에 초기화하는 task
        begin
            rst = 1'b1;                         // DUT reset assert
            run = 1'b0;                         // reset 중에는 run을 0으로 유지
            for (i = 0; i < 128; i = i + 1) begin // base/extra 최대 output 범위 128개를 모두 초기화
                dut_y_mem[i] = 16'd0;           // waveform에서 dead 값이 보이지 않도록 capture memory는 0으로 초기화
                dut_y_valid[i] = 1'b0;          // 실제 write 여부는 valid bit로 따로 확인
            end
            repeat (5) @(posedge clk);          // reset이 충분히 반영되도록 5 clock 대기
            rst = 1'b0;                         // DUT reset deassert
            repeat (2) @(posedge clk);          // reset 해제 후 안정화 대기
        end
    endtask

    task check_output;                         // DUT가 쓴 output과 reference Y를 비교하는 self-checking task
        input mode;                              // mode 0이면 base, mode 1이면 extra
        reg [15:0] expected;                     // 현재 address에서 비교할 reference output
        begin
            err = 0;                             // 현재 test case의 error count 초기화
            limit = mode ? 128 : 64;             // extra는 128개, base는 64개 output 비교

            for (i = 0; i < limit; i = i + 1) begin // 모든 output address를 순차적으로 검사
                if (mode)
                    expected = ref_y_extra_mem[i]; // extra mode이면 extra reference array에서 정답 선택
                else
                    expected = ref_y_base_mem[i];  // base mode이면 base reference array에서 정답 선택

                if (has_x16(expected)) begin              // reference file을 잘못 읽어 정답이 X인 경우
                    err = err + 1;                       // 현재 case error 증가
                    total_err = total_err + 1;           // 전체 error 증가
                    tb_fault = 1'b1;                     // reference 자체가 잘못되었으므로 TB fault 처리
                    $display("[TB ERROR] Reference Y is X at addr %0d. Check y_hex firmware path.", i); // firmware path 확인용 message
                end
                else if (!dut_y_valid[i]) begin          // DUT가 해당 address를 한 번도 write하지 않은 경우
                    err = err + 1;                       // 현재 case error 증가
                    total_err = total_err + 1;           // 전체 error 증가
                    $display("[FAIL] mode=%0d addr=%0d was not written by DUT.", mode, i); // missing write 출력
                end
                else if (has_x16(dut_y_mem[i])) begin    // DUT가 write한 output 자체가 X인 경우
                    err = err + 1;                       // 현재 case error 증가
                    total_err = total_err + 1;           // 전체 error 증가
                    $display("[FAIL] mode=%0d addr=%0d DUT output is X, ref=%h", mode, i, expected); // DUT X output 출력
                end
                else if ($signed(dut_y_mem[i]) !== $signed(expected)) begin // DUT output과 reference를 signed 값으로 비교
                    err = err + 1;                       // mismatch이면 현재 case error 증가
                    total_err = total_err + 1;           // 전체 error 증가
                    $display("[FAIL] mode=%0d addr=%0d dut=%h ref=%h", mode, i, dut_y_mem[i], expected); // mismatch 값 출력
                end
                else begin                               // 모든 검사를 통과하면 해당 address는 correct
                    if (mode)
                        $display("[EXTRA] CORRECT addr=%0d  expected=%0d  got=%0d", i, $signed(expected), $signed(dut_y_mem[i])); // extra correct 출력
                    else
                        $display("[BASE ] CORRECT addr=%0d  expected=%0d  got=%0d", i, $signed(expected), $signed(dut_y_mem[i])); // base correct 출력
                end
            end

            if (err == 0 && !tb_fault) begin
                if (mode)
                    $display("[EXTRA] PASS : 128 / 128 outputs matched");
                else
                    $display("[BASE ] PASS : 64 / 64 outputs matched");
            end
            else begin
                if (mode)
                    $display("[EXTRA] FAIL : %0d errors", err);
                else
                    $display("[BASE ] FAIL : %0d errors", err);
            end
        end
    endtask

    task run_one_case;                         // base 또는 extra 한 case를 처음부터 끝까지 실행하는 task
        input mode;                              // mode 0이면 base, mode 1이면 extra
        begin: run_case                          // timeout 발생 시 disable할 수 있도록 named block 사용
            batch_mode = mode;                   // DUT와 X mux가 사용할 batch_mode 설정
            reset_dut();                         // 각 case 시작 전 DUT와 capture buffer 초기화

            $display("============================================================");
            if (mode)
                $display("[EXTRA] test start : 16 batches, 128 outputs");
            else
                $display("[BASE ] test start : 8 batches, 64 outputs");

            @(posedge clk);                      // clock edge에 맞춰 run pulse 시작
            run = 1'b1;                         // DUT 연산 시작을 알리는 run을 1로 올림
            @(posedge clk);                      // run은 1 clock 동안만 유지
            run = 1'b0;                         // run pulse 종료

            wait_count = 0;                     // done 대기 counter 초기화
            while ((done !== 1'b1) && (wait_count < 20000)) begin // done이 올라오거나 timeout limit에 도달할 때까지 대기
                @(posedge clk);                  // 매 clock마다 done 확인
                wait_count = wait_count + 1;     // 기다린 cycle 수 증가
            end

            if (done !== 1'b1) begin              // timeout limit까지 done이 올라오지 않은 경우
                tb_fault = 1'b1;                 // testbench fault flag set
                total_err = total_err + 1;       // 전체 error count 증가
                $display("[TB ERROR] Timeout waiting for done. mode=%0d state=%0d cycle_count=%0d", mode, state, cycle_count); // timeout 시점 상태 출력
                disable run_case;                // 현재 case를 더 진행하지 않고 종료
            end

            repeat (3) @(posedge clk);            // 마지막 write capture가 안정되도록 done 이후 몇 cycle 대기
            if (mode)
                $display("[EXTRA] done, cycle_count = %0d", cycle_count); // extra latency 출력
            else
                $display("[BASE ] done, cycle_count = %0d", cycle_count); // base latency 출력

            check_output(mode);                  // 현재 mode의 모든 output을 reference와 비교
            repeat (5) @(posedge clk);           // 다음 case 시작 전 waveform 구분을 위한 여유 cycle
        end
    endtask

    initial begin                              // 전체 test scenario를 수행하는 initial block
        clk = 1'b0;                             // clock 초기값 설정
        rst = 1'b0;                             // reset 초기값 설정
        run = 1'b0;                             // run 초기값 설정
        batch_mode = 1'b0;                      // 기본 mode는 base로 설정
        tb_fault = 1'b0;                        // testbench fault flag 초기화
        total_err = 0;                          // 전체 error count 초기화

        #100;                                   // memory initialization이 끝날 시간을 확보
        run_one_case(1'b0);                     // base 8-batch case 실행
        run_one_case(1'b1);                     // extra 16-batch case 실행

        $display("============================================================"); // 최종 결과 구분선 출력
        if (total_err == 0 && !tb_fault)        // 전체 error가 없고 TB fault도 없을 때만 pass
            $display("ALL TESTS PASSED");       // 최종 pass message 출력
        else
            $display("TEST FAILED : total errors = %0d", total_err); // 하나라도 문제가 있으면 fail message 출력

        #100;                                   // 마지막 message 확인을 위한 여유 시간
        $finish;                                // simulation 종료
    end
endmodule
