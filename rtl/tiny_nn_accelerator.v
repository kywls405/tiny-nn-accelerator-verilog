// SPDX-License-Identifier: MIT
// Tiny neural-network accelerator RTL by Yongjin Kim.

`timescale 1ns/1ns

// -------------------------------------------------------
// 4-bit Carry Lookahead Adder
// -------------------------------------------------------
module cla4(
    input  [3:0] A,       // 입력 A 4bit
    input  [3:0] B,       // 입력 B 4bit
    input        Cin,     // 입력 Carryin 1bit
    output [3:0] S,       // 출력 A, B에 대한 덧셈결과 S 4bit 
    output       Cout,    // 출력 A, B에 대한 Carryout 1ibt
    output       G_group, // 출력 A, B에 대한 Generation 1bit
    output       P_group  // 출력 A, B에 대한 Propagation 1bit
);

    wire [3:0] P, G; // 각 bit에 대한 Propagation, Generation을 위한 wire 총 4bit 선언
    
    assign P = A ^ B; // Propagation은 XOR 연산을 통해 파악 -> Carry가 전파되는지 판단
    assign G = A & B; // Generation은 AND 연산을 통해 파악 -> Carry가 생기는지 판단
    
    // S[0] = P[0] XOR Cin
    assign S[0] = P[0] ^ Cin; // 0번째 bit 덧셈 연산
    // S[1] = P[1] XOR (P[0]Cin OR G[0])
    assign S[1] = P[1] ^ ( (P[0]&Cin) | G[0] ); // 1번째 bit 덧셈 연산
    // S[2] = P[2] XOR (P[1]P[0]Cin OR P[1]G[0] OR G[1]) 
    assign S[2] = P[2] ^ ( (P[1]&P[0]&Cin) | (P[1]&G[0]) | G[1] ); // 2번째 bit 덧셈 연산
    // S[3] = P[3] XOR (P[2]P[1]P[0]Cin OR P[2]P[1]G[0] OR P[2]G[1] OR G[2])
    assign S[3] = P[3] ^ ( (P[2]&P[1]&P[0]&Cin) | (P[2]&P[1]&G[0]) | (P[2]&G[1]) | G[2] ); // 3번째 bit 덧셈 연산 

    // G_group -> P[3]P[2]P[1]G[0] OR P[3]P[2]G[1] OR P[3]G[2] OR G[3]
    // 입력된 4bit에 대해서 Generation이 존재하는지 input(4bit) 만으로 판단 -> 기존 각 bit에 대한 carry 판단을 해야했던 ripple 방식과의 차이점
    assign G_group = ( (P[3]&P[2]&P[1]&G[0]) | (P[3]&P[2]&G[1]) | (P[3]&G[2]) | G[3] );
    // P_group -> P[3]P[2]P[1]P[0]
    // 입력된 4bit에 대해서 Propagation이 존재하는지 input(4bit) 만으로 판단 -> 기존 각 bit에 대한 carry 판단을 해야했던 ripple 방식과의 차이점
    assign P_group = ( P[3] & P[2] & P[1] & P[0] );
    // Carry out = P[3]P[2]P[1]P[0]Cin OR p[3]P[2]G[0] OR P[3]G[2] OR G[3];
    assign Cout = G_group | (P_group & Cin); // 별도의 carry 계산 없이 input 만으로 Carry 발생 여부 판단 
               
endmodule

// -------------------------------------------------------
// 8-bit Carry Lookahead Adder 
// -------------------------------------------------------
module cla8(
    input  [7:0] A,       // 입력 A 8bit
    input  [7:0] B,       // 입력 B 8bit
    input        Cin,     // 입력 Carryin 1bit
    output [7:0] S,       // 출력 A, B에 대한 덧셈결과 S 8bit
    output       Cout,    // 출력 A, B에 대한 Carryout 1bit
    output       G_group, // 출력 A, B에 대한 Generation 1bit
    output       P_group  // 출력 A, B에 대한 Propagation 1bit
);
    // C4 : 4LSBs에서 발생하는 carry -> input(4LSBs, Cin) 만으로 판단
    // G0, G1 : cla4 모듈의 output 중 G_group을 받음
    // P0, P1 : cla4 모듈의 output 중 P_group을 받음 
    wire C4, G0, G1, P0, P1;
     
    assign C4 = G0 | (P0 & Cin); // input 만으로 MSBs에 전해질 Carry를 계산
    assign G_group = G1 | (P1 & G0); // input(8bit) 만으로 계산된 Generation
    assign P_group = P1 & P0; // input(8bit) 만으로 계산된 Propagation
    
    // 각 instance에게 input을 전달하고 ouuput을 받음
    cla4 LSBs (.A(A[3:0]), .B(B[3:0]), .Cin(Cin), .S(S[3:0]), .Cout(), .G_group(G0), .P_group(P0)); // 8bit 중 4LSBs와 Cin 전달
    cla4 MSBs (.A(A[7:4]), .B(B[7:4]), .Cin(C4), .S(S[7:4]), .Cout(Cout), .G_group(G1), .P_group(P1)); // 8bit 중 4MSBs와 4LSBs로부터 발생된 C4 전달
    
endmodule

// -------------------------------------------------------
// 16-bit Carry Lookahead Adder 
// -------------------------------------------------------
module cla16(
    input  [15:0] A,       // 입력 A 8bit
    input  [15:0] B,       // 입력 B 8bit
    input         Cin,      // 입력 Carryin 1bit
    output [15:0] S,       // 출력 A, B에 대한 덧셈결과 S 16bit
    output        Cout,     // 출력 A, B에 대한 Carryout 1bit
    output        G_group,  // 출력 A, B에 대한 Generation 1bit
    output        P_group   // 출력 A, B에 대한 Propagation 1bit
);
    // C8 : 8LSBs에서 발생하는 carry -> input(8LSBs, Cin) 만으로 판단
    // G0, G1 : cla8 모듈의 output 중 G_group을 받음
    // P0, P1 : cla8 모듈의 output 중 P_group을 받음 
    wire C8, G0, G1, P0, P1;
     
    assign C8 = G0 | (P0 & Cin); // input 만으로 MSBs에 전해질 Carry를 계산
    assign G_group = G1 | (P1 & G0); // input(8bit) 만으로 계산된 Generation
    assign P_group = P1 & P0; // input(8bit) 만으로 계산된 Propagation
    
    // 각 instance에게 input을 전달하고 ouuput을 받음
    cla8 LSBs (.A(A[7:0]), .B(B[7:0]), .Cin(Cin), .S(S[7:0]), .Cout(), .G_group(G0), .P_group(P0)); // 16bit 중 8LSBs와 Cin 전달
    cla8 MSBs (.A(A[15:8]), .B(B[15:8]), .Cin(C8), .S(S[15:8]), .Cout(Cout), .G_group(G1), .P_group(P1)); // 16bit 중 8MSBs와 8LSBs로부터 발생된 C8 전달
    
endmodule

// -------------------------------------------------------
// 4-bit Multiplier (signed-signed)
// -------------------------------------------------------
module mult4ss(
    input  [3:0] A, // 입력 A 4bit
    input  [3:0] B, // 입력 B 4bit
    output [7:0] P  // 출력 A, B에 대한 곱셈결과 P 8bit
);

    wire signed [7:0] A_ext = { {4{A[3]}} , {A} }; // input으로 받은 4bit를 부호를 고려해 8bit로 확장 -> MSB를 [7:4]에 동일하게 배치
    
    // PP(Partial Product) -> 부분곱 => 각 자릿수에 대해서 곱한 뒤 Shift하여 더하는 방식
    wire signed [7:0] PP0 = B[0] ? A_ext << 0 : 8'b0; // B[0] = 1이면 A, 아니면 0
    wire signed [7:0] PP1 = B[1] ? A_ext << 1: 8'b0; // B[1] = 1이면 A, 아니면 0
    wire signed [7:0] PP2 = B[2] ? A_ext << 2: 8'b0; // B[2] = 1이면 A, 아니면 0
    // 만약 B[3]이 1이라면 음수이므로 연산에 주의해야 한다 -> 위처럼 똑같이 계산 후 마지막에 음수를 더해준다
    wire signed [7:0] PP3 = B[3] ? ((~(A_ext << 3)) + 8'b1) : 8'b0; // A_ext를 3bit만큼 shift한 뒤 [~(not)을 붙이고 1을 더하여] 2의 보수 방식으로 음수를 만들어준다
    
    wire [7:0] SUM0, SUM1; // 부분곱을 취한 PP를 더하기 위한 wire
    
    cla8 ADD0 (.A(PP0), .B(PP1), .Cin(1'b0), .S(SUM0), .Cout(), .G_group(), .P_group()); // 8bit Adder를 이용해 0번째, 1번째 PP에 대한 덧셈
    cla8 ADD1 (.A(PP2), .B(PP3), .Cin(1'b0), .S(SUM1), .Cout(), .G_group(), .P_group()); // 8bit Adder를 이용해 2번째, 3번째 PP에 대한 덧셈
    cla8 ADD2 (.A(SUM0), .B(SUM1), .Cin(1'b0), .S(P), .Cout(), .G_group(), .P_group()); // 마지막 두 SUM을 더하면 최종적으로 곱한 값
    
endmodule

// -------------------------------------------------------
// 4-bit Multiplier (signed-unsigned)
// -------------------------------------------------------
module mult4su(
    input  [3:0] A, // 입력 A 4bit
    input  [3:0] B, // 입력 B 4bit
    output [7:0] P  // 출력 A, B에 대한 곱셈결과 P 8bit
);
    // signed A와 unsigned B를 곱하기 위해 A만 sign extension 후 partial product를 계산
    wire [7:0] A_ext = { {4{A[3]}} , {A} }; // input으로 받은 4bit를 부호를 고려해 8bit로 확장 -> MSB를 [7:4]에 동일하게 배치
    
    // PP(Partial Product) -> 부분곱 => 각 자릿수에 대해서 곱한 뒤 Shift하여 더하는 방식
    wire [7:0] PP0 = B[0] ? A_ext << 0 : 8'b0; // B[0] = 1이면 A, 아니면 0
    wire [7:0] PP1 = B[1] ? A_ext << 1 : 8'b0; // B[1] = 1이면 A, 아니면 0
    wire [7:0] PP2 = B[2] ? A_ext << 2 : 8'b0; // B[2] = 1이면 A, 아니면 0
    wire [7:0] PP3 = B[3] ? A_ext << 3 : 8'b0; // B[3] = 1이면 A, 아니면 0 -> Unsigned 반영
    
    wire [7:0] SUM0, SUM1; // 부분곱을 취한 PP를 더하기 위한 wire
    
    cla8 ADD0 (.A(PP0), .B(PP1), .Cin(1'b0), .S(SUM0), .Cout(), .G_group(), .P_group()); // 8bit Adder를 이용해 0번째, 1번째 PP에 대한 덧셈
    cla8 ADD1 (.A(PP2), .B(PP3), .Cin(1'b0), .S(SUM1), .Cout(), .G_group(), .P_group()); // 8bit Adder를 이용해 2번째, 3번째 PP에 대한 덧셈
    cla8 ADD2 (.A(SUM0), .B(SUM1), .Cin(1'b0), .S(P), .Cout(), .G_group(), .P_group()); // 마지막 두 SUM을 더하면 최종적으로 곱한 값
    
endmodule

// -------------------------------------------------------
// 4-bit Multiplier (unsigned-unsigned)
// -------------------------------------------------------
module mult4uu(
    input  [3:0] A, // 입력 A 4bit
    input  [3:0] B, // 입력 B 4bit
    output [7:0] P  // 출력 A, B에 대한 곱셈결과 P 8bit
);
    // unsigned A와 unsigned B를 곱하기 위해 A를 zero extension 후 partial product를 계산
    wire [7:0] A_ext = { 4'b0 , {A} }; // input으로 받은 4bit를 unsigned 8bit로 확장
    
    // PP(Partial Product) -> 부분곱 => 각 자릿수에 대해서 곱한 뒤 Shift하여 더하는 방식
    wire [7:0] PP0 = B[0] ? A_ext << 0 : 8'b0; // B[0] = 1이면 A, 아니면 0
    wire [7:0] PP1 = B[1] ? A_ext << 1 : 8'b0; // B[1] = 1이면 A, 아니면 0
    wire [7:0] PP2 = B[2] ? A_ext << 2 : 8'b0; // B[2] = 1이면 A, 아니면 0
    wire [7:0] PP3 = B[3] ? A_ext << 3 : 8'b0; // B[3] = 1이면 A, 아니면 0 -> Unsigned 반영
    
    wire [7:0] SUM0, SUM1; // 부분곱을 취한 PP를 더하기 위한 wire
    
    cla8 ADD0 (.A(PP0), .B(PP1), .Cin(1'b0), .S(SUM0), .Cout(), .G_group(), .P_group()); // 8bit Adder를 이용해 0번째, 1번째 PP에 대한 덧셈
    cla8 ADD1 (.A(PP2), .B(PP3), .Cin(1'b0), .S(SUM1), .Cout(), .G_group(), .P_group()); // 8bit Adder를 이용해 2번째, 3번째 PP에 대한 덧셈
    cla8 ADD2 (.A(SUM0), .B(SUM1), .Cin(1'b0), .S(P), .Cout(), .G_group(), .P_group()); // 마지막 두 SUM을 더하면 최종적으로 곱한 값
    
endmodule

// 8-bit Multiply-and-Add (MAD) Unit
module mad8(
    input               clk,  // 입력 clk (clock)
    input               rst,  // 입력 rst (reset)
    input				en,   // 입력 en (enable to input Data)
    input   [7:0] 		A,    // 입력 A 8bit
    input   [7:0] 		B,    // 입력 B 8bit
    input   [15:0]      C,    // 입력 C 16bit (상수)
    output reg			busy, // 출력 busy 1bit (Cycle 실행 중인지 판단)
    output reg [15:0] 	P,     // 출력 P 16bit (A, B, C의 MAD 연산 결과)
    output     [15:0]   P_next
);
    
    parameter C0 = 3'b000; // Cycle0 인지 판별하기 위한 Param (초기 대기 상태)
    parameter C1 = 3'b001; // Cycle1 인지 판별하기 위한 Param (1번째 partial multiplication을 수행하는 Cycle1)
    parameter C2 = 3'b010; // Cycle2 인지 판별하기 위한 Param (2번째 partial multiplication을 수행하는 Cycle2)
    parameter C3 = 3'b011; // Cycle3 인지 판별하기 위한 Param (3번째 partial multiplication을 수행하는 Cycle3)
    parameter C4 = 3'b100; // Cycle4 인지 판별하기 위한 Param (4번째 partial multiplication을 수행하는 Cycle4)
    
    // 각 muliplier의 결과를 받기 위한 wire
    // PUU : unsigned x unsigned
    // PSU : signed x unsigned
    // PSS : signed x signed
    wire [7:0]  PUU, PSU, PSS;
    
    // SUM : cla16이 temp + Mult를 계산한 결과
    // Mult : 현재 cycle에서 temp에 더해질 partial product
    wire [15:0] SUM, Mult;
    
    reg  [2:0]  cycle; // 현재 FSM 상태
    
    // 입력 A, B를 상/하위 4bit로 나누어 저장
    // Ah, Bh는 상위 4bit -> signed로 해석되는 nibble
    // Al, Bl는 하위 4bit -> unsigned로 해석되는 nibble
    // mul_A, mul_B는 현재 cycle에서 multiplier에 실제로 넣을 4bit 입력
    reg  [3:0]  Ah, Al, Bh, Bl, mul_A, mul_B;
  
    reg  [15:0] temp; // temp : 이전 cycle까지의 누적 합을 저장하는 reg -> 매 cycle마다 SUM이 다시 temp로 저장됨
    
    // 각 cycle에서 부호조합에 맞는 muliplier
    // mu1_A, mul_B는 Sequentail Logic에서 할당됨
    mult4uu UU(.A(mul_A), .B(mul_B), .P(PUU)); // unsigned x unsigned multiplication -> PUU wire는 Mult wire에 전달
    mult4su SU(.A(mul_A), .B(mul_B), .P(PSU)); // signed x unsigned multiplication   -> PSU wire는 Mult wire에 전달
    mult4ss SS(.A(mul_A), .B(mul_B), .P(PSS)); // signed x signed multiplication     -> PSS wire는 Mult wire에 전달
    
    // 현재 누적값 temp와 cycle의 partial product를 더하기 위한 cla16 module
    cla16 ADD (.A(temp), .B(Mult), .Cin(1'b0), .S(SUM), .Cout(), .G_group(), .P_group());  // SUM = temp + Mult
    
    assign P_next = SUM;
    
    // Cycle에 따라 어떤 partial product를 더할지 선택
    assign Mult = (cycle == C1) ? {8'b0, PUU} :                     // C1 : Al x Bl -> 최하위 자리이므로 0bit shift
                  (cycle == C2) ? {{8{PSU[7]}}, PSU} << 4 :         // C2 : Bh x Al -> 중간 자리이므로 4bit left shift
                  (cycle == C3) ? {{8{PSU[7]}}, PSU} << 4 :         // C3 : Ah x Bl -> 중간 자리이므로 4bit left shift    
                  (cycle == C4) ? {{8{PSS[7]}}, PSS} << 8 : 16'b0;  // C2 : Ah x Bh -> 최상위 자리이므로 8bit left shift
    
    // Sequential Logic                         
    always @(posedge clk or posedge rst) begin // clk의 positive edge or rst의 positive edge 마다 내부 register update
        if (rst)  begin // rst가 1일 때 실행
            busy  <= 1'b0; // busy를 0으로 초기화
            cycle <= C0;   // cycle을 0으로 초기화
            {Ah, Al, Bh, Bl, mul_A, mul_B} <= {4'b0, 4'b0, 4'b0, 4'b0, 4'b0, 4'b0}; // multiplication을 위한 4bit 0으로 초기화
            temp <= 16'b0; // 누적값 초기화
            P <= 16'b0;
        end else begin // rst가 0일 때 실행
            if ((en) && (cycle == C0)) begin // en이 1이면서 cycle이 C0(대기 상태)일 때만 연산 시작
                cycle <= C1;  // cycle에 C1을 넣으며 연산 과정 시작
                busy <= 1'b1; // 연산 시작이므로 busy를 1로 상승
                
                Ah <= A[7:4]; Al <= A[3:0]; // input 8bit A를 상위, 하위 4bit로 나누어 nibble reg에 저장
                Bh <= B[7:4]; Bl <= B[3:0]; // input 8bit B를 상위, 하위 4bit로 나누어 nibble reg에 저장
                
                mul_A <= A[3:0]; mul_B <= B[3:0]; // C1에서는 Al x Bl 이므로 mul_A, mul_B에 각각 설정
                
                temp <= C; // 누적값의 시작은 16bit 상수 C로 설정
            end
            
            // busy 상태일 동안 각 cycle마다 계산된 SUM을 출력 P에 계속 반영
            // 따라서 P는 각 cycle의 SUM으로 갱신되고, 최종적으로 C4의 SUM이 최종 MAD 결과가 됨
            if (busy) P <= SUM;
            
            case (cycle) // cycle의 값에 따라 실행될 연산
                C1 : begin // cycle의 값이 C1인 경우
                    // 다음 cycle(C2)에서 연산해야 될 값 설정
                    mul_A <= Bh; // mul_A에 signed 4bit인 Bh 설정
                    mul_B <= Al; // mul_B에 unsigned 4bit인 Al 설정
                    
                    //C1의 결과 누적
                    temp <= SUM; // Combinational Logic을 통해 계산된 temp + Mult의 결과를 temp에 누적 
           
                    cycle <= C2; // 다음 cycle로 갱신
                end
                C2 : begin
                    // 다음 cycle(C3)에서 연산해야 될 값 설정
                    mul_A <= Ah; // mul_A에 signed 4bit인 Ah 설정
                    mul_B <= Bl; // mul_B에 unsigned 4bit인 Bl 설정
                    
                    //C2의 결과 누적
                    temp <= SUM; // Combinational Logic을 통해 계산된 temp + Mult의 결과를 temp에 누적
                    
                    cycle <= C3; // 다음 cycle로 갱신
                end
                C3 : begin
                    // 다음 cycle(C4)에서 연산해야 될 값 설정
                    mul_A <= Ah; // mul_A에 signed 4bit인 Ah 설정
                    mul_B <= Bh; // mul_B에 signed 4bit인 Bh 설정
                    
                    //C3의 결과 누적
                    temp <= SUM; // Combinational Logic을 통해 계산된 temp + Mult의 결과를 temp에 누적
                    
                    cycle <= C4; // 다음 cycle로 갱신
                end
                C4 : begin
                    // en이 0인 경우 -> 새로운 입력 존재(X)
                    // 새로운 입력이 없다면 연산을 진행하지 않는다는 의미로
                    if (~en) begin busy <= 1'b0; cycle <= C0; end // busy를 0으로 하강, cycle을 C0(대기 상태)로 변경
                    else     begin // 새로운 입력이 있다면
                        cycle <= C1;  // cycle에 C1을 넣으며 새로운 연산 과정 시작
                        busy <= 1'b1; // 새로운 연산 시작이므로 busy를 1로 유지
                        
                        Ah <= A[7:4]; Al <= A[3:0]; // input 8bit A를 상위, 하위 4bit로 나누어 nibble reg에 저장
                        Bh <= B[7:4]; Bl <= B[3:0]; // input 8bit B를 상위, 하위 4bit로 나누어 nibble reg에 저장
                        
                        mul_A <= A[3:0]; mul_B <= B[3:0]; // C1에서는 Al x Bl 이므로 mul_A, mul_B에 각각 설정
                
                        temp <= C; // 누적값의 시작은 16bit 상수 C로 설정
                    end
                end
                default : begin
                    // 기본적으로는 C0(대기 상태) 유지
                    // en이 0인 경우 -> 새로운 입력 존재(X)
                    if (~en) begin
                        cycle <= C0; // cycle을 C0(대기 상태)로 유지
                        busy  <= 1'b0; // busy를 0으로 유지
                    end
                end
            endcase
        end
    end
    
endmodule

// -------------------------------------------------------
// Weight Stationary Systolic Element
// -------------------------------------------------------
module se8 (
    input               clk,                  // 입력 clk (clock)
    input               rst,                  // 입력 rst (reset)
    input               en,                   // 입력 en (현재 SE에서 MAD 연산을 시작할지 판단)
    input               pre_fill,             // 입력 pre_fill (B weight를 SE에 저장하는 구간인지 판단)
    input       [7:0]   data_from_left,       // 입력 data_from_left 8bit (왼쪽 SE 또는 외부 A 입력으로부터 들어오는 A 값)
    input       [15:0]  data_from_top,        // 입력 data_from_top 16bit (위쪽 SE로부터 들어오는 partial sum 또는 prefill weight)
    output  reg [7:0]   data_to_right,        // 출력 data_to_right 8bit (현재 SE가 오른쪽 SE로 전달하는 A 값)
    output  reg [15:0]  data_to_bottom,       // 출력 data_to_bottom 16bit (현재 SE가 아래쪽 SE로 전달하는 partial sum)
    output  reg         busy,                 // 출력 busy 1bit (현재 SE가 유효한 MAD 연산 과정 중인지 판단)

    /* YOU CAN DECLARE ADDITIONAL PORTS HERE IF YOU NEED */
    output      [15:0]  psum_to_bottom_now    // 출력 psum_to_bottom_now 16bit (아래 SE가 같은 cycle에 바로 사용할 수 있는 partial sum)
);

    reg  [7:0] Weight;                        // Weight : pre_fill 동안 저장되는 B 값 -> weight stationary 방식으로 계산 중 고정됨
    reg  [3:0] psum_valid_delay;              // psum_valid_delay : MAD 시작 후 partial sum이 유효해지는 cycle을 맞추기 위한 shift register

    wire        real_en;                      // real_en : pre_fill 구간을 제외하고 실제 MAD에 전달할 enable
    wire        psum_active;                  // psum_active : 현재 SE에서 MAD partial sum이 출력되는 구간인지 판단
    wire        busy_next;                    // busy_next : 현재 posedge 이후에도 SE에 남은 연산이 있는지 판단
    wire [15:0] mad_p_next;                   // mad_p_next : mad8 내부에서 현재 cycle에 계산된 combinational MAD 결과

    assign real_en     = en & ~pre_fill;      // pre_fill이 0이고 en이 1일 때만 실제 MAD 연산을 시작
    assign psum_active = |psum_valid_delay;   // psum_valid_delay 중 하나라도 1이면 MAD 결과 stream이 진행 중이라고 판단
    assign busy_next   = real_en | (|psum_valid_delay[2:0]); // 마지막 결과만 남은 cycle에서는 busy가 내려가도록 판단

    assign psum_to_bottom_now = psum_active ? mad_p_next : data_to_bottom; // MAD 진행 중에는 최신 psum을, 아니면 registered bottom 값을 전달

    mad8 u_mad (                              // mad8 instance 생성 -> 현재 SE의 A, Weight, partial sum에 대해 MAD 수행
        .clk(clk),                            // mad8에 clock 전달
        .rst(rst),                            // mad8에 reset 전달
        .en(real_en),                         // pre_fill을 제외한 실제 enable 전달
        .A(data_from_left),                   // MAD 입력 A로 왼쪽에서 들어온 data 사용
        .B(Weight),                           // MAD 입력 B로 현재 SE에 저장된 Weight 사용
        .C(data_from_top),                    // MAD 입력 C로 위에서 내려온 partial sum 사용
        .busy(),                              // mad8의 busy는 se8에서 따로 사용하지 않으므로 연결하지 않음
        .P(),                                 // mad8의 registered P는 한 cycle 늦게 나오므로 사용하지 않음
        .P_next(mad_p_next)                   // 현재 cycle의 계산 결과를 바로 사용하기 위해 P_next를 연결
    );

    always @(*) begin                         // SE busy를 현재 valid 흐름 기준으로 combinational하게 판단
        if (rst || pre_fill) begin            // reset 또는 pre_fill 중에는 계산 busy가 아님
            busy = 1'b0;                      // busy를 0으로 설정
        end
        else begin                            // 일반 계산 구간인 경우
            busy = busy_next;                 // 현재 SE에 남은 연산 여부를 busy로 전달
        end
    end

    always @(posedge clk or posedge rst) begin // clk의 positive edge 또는 rst의 positive edge마다 내부 register update
        if (rst) begin                        // rst가 1일 때 실행
            Weight           <= 8'd0;         // 저장된 Weight를 0으로 초기화
            data_to_right    <= 8'd0;         // 오른쪽으로 전달할 A 값을 0으로 초기화
            data_to_bottom   <= 16'd0;        // 아래로 전달할 partial sum을 0으로 초기화
            psum_valid_delay <= 4'd0;         // partial sum valid delay register를 0으로 초기화
        end
        else if (pre_fill) begin              // pre_fill이 1일 때 실행 -> B weight를 SE에 저장하는 구간
            Weight           <= data_from_top[7:0]; // data_from_top의 하위 8bit를 현재 SE의 Weight로 저장
            data_to_bottom   <= data_from_top;      // 위에서 받은 prefill 값을 아래 SE로 그대로 전달
            psum_valid_delay <= 4'd0;         // pre_fill 중에는 MAD 결과 valid delay를 초기화
        end
        else begin                            // rst와 pre_fill이 모두 0인 일반 계산 구간
            if (real_en) begin                // 현재 SE에 유효한 A 입력이 들어온 경우
                data_to_right <= data_from_left; // 입력받은 A 값을 오른쪽 SE로 전달
            end

            psum_valid_delay <= {psum_valid_delay[2:0], real_en}; // real_en을 shift하여 MAD 결과가 나오는 timing을 추적

            if (psum_active) begin            // MAD가 진행 중인 cycle이면
                data_to_bottom <= mad_p_next; // 현재 MAD의 partial sum 또는 final sum을 아래 방향 output에 갱신
            end
        end
    end

endmodule

// -------------------------------------------------------
// 4x4 Weight Stationary Systolic Array
// -------------------------------------------------------
module sa8_4x4 (
    input                   clk,              // 입력 clk (clock)
    input                   rst,              // 입력 rst (reset)
    input                   en,               // 입력 en (외부에서 A 입력이 유효한 cycle인지 판단)
    input                   pre_fill,         // 입력 pre_fill (B weight를 array에 미리 채우는 구간인지 판단)
    input       [8*4-1:0]   A,                // 입력 A 32bit (4개의 8bit A 값이 row 방향으로 들어옴)
    input       [8*4-1:0]   B,                // 입력 B 32bit (4개의 8bit B weight 값이 column 방향으로 들어옴)
    output  reg [16*4-1:0]  C,                // 출력 C 64bit (bottom row에서 나오는 4개의 16bit 결과)
    output  reg             busy              // 출력 busy 1bit (systolic array 전체가 연산 중인지 판단)
);

    reg        pf_active;                     // pf_active : pre_fill pulse 이후 weight가 아래 row까지 전달되는 동안 pre_fill 상태를 유지하기 위한 register
    reg [2:0]  pf_cnt;                        // pf_cnt : pre_fill 유지 cycle을 세기 위한 counter
    reg [31:0] en_delay;                      // en_delay : 각 SE 위치에 맞는 local enable을 만들기 위한 shift register

    wire       pf_valid;                      // pf_valid : 실제 array 내부에서 사용하는 pre_fill valid 신호
    wire       a_valid;                       // a_valid : pre_fill이 끝난 뒤 실제 A 입력을 받아도 되는 enable 신호

    wire [7:0]  right    [0:15];              // right : 각 SE의 data_to_right를 다음 SE의 data_from_left로 연결하기 위한 wire
    wire [15:0] down     [0:15];              // down : 각 SE의 data_to_bottom을 아래 SE로 전달하기 위한 wire
    wire [15:0] psum_now [0:15];              // psum_now : 같은 cycle에 최신 partial sum을 아래 SE나 C output으로 전달하기 위한 bypass wire
    wire [15:0] se_busy;                      // se_busy : 16개 SE 각각의 live busy 신호를 모으기 위한 wire

    assign pf_valid = pre_fill | pf_active;   // 외부 pre_fill 또는 내부 pf_active가 1이면 prefill 구간으로 판단
    assign a_valid  = en & ~pf_valid;         // prefill 구간이 아닐 때만 A 입력 enable을 유효하게 사용

    genvar i, j;                              // generate문에서 row index i, column index j로 사용
    generate
        for (i = 0; i < 4; i = i + 1) begin : ROW // 4개의 row를 생성
            for (j = 0; j < 4; j = j + 1) begin : COL // 각 row마다 4개의 column을 생성

                localparam integer SE_IDX = 4*i + j; // 현재 SE의 2차원 좌표 [i][j]를 1차원 index로 변환
                localparam integer A_IDX  = 8*(3-i); // A bus에서 현재 row에 해당하는 8bit 위치 계산
                localparam integer B_IDX  = 8*(3-j); // B bus에서 현재 column에 해당하는 8bit 위치 계산
                localparam integer DELAY  = 4*(i+j); // 현재 SE가 입력을 받아야 하는 timing delay 계산

                wire        local_en;        // local_en : 현재 SE에만 들어가는 enable 신호
                wire [7:0]  left_data;       // left_data : 현재 SE의 data_from_left에 연결될 A 값
                wire [15:0] top_data;        // top_data : 현재 SE의 data_from_top에 연결될 partial sum 또는 weight 값

                if (DELAY == 0) begin : EN_NOW // SE[0][0]은 delay 없이 바로 enable 사용
                    assign local_en = a_valid; // 첫 SE는 현재 a_valid를 local_en으로 사용
                end
                else begin : EN_DELAYED      // 나머지 SE는 위치에 맞게 enable을 delay하여 사용
                    assign local_en = en_delay[DELAY-1]; // en_delay에서 현재 SE의 timing에 맞는 bit를 선택
                end

                assign left_data = (j == 0) ? A[A_IDX +: 8] : right[SE_IDX-1]; // 첫 column은 외부 A를 받고, 나머지는 왼쪽 SE의 출력을 받음

                assign top_data = (i == 0) ? (pf_valid ? {8'b0, B[B_IDX +: 8]} : 16'd0)
                                           : (pf_valid ? down[SE_IDX-4] : psum_now[SE_IDX-4]); // 첫 row는 B 또는 0을 받고, 나머지 row는 prefill 중 down, 계산 중 최신 psum을 받음

                se8 u_se (                   // 현재 위치 [i][j]에 se8 instance 생성
                    .clk(clk),               // clock 연결
                    .rst(rst),               // reset 연결
                    .en(local_en),           // 현재 SE timing에 맞게 delay된 enable 연결
                    .pre_fill(pf_valid),     // 내부 prefill valid 신호 연결
                    .data_from_left(left_data), // 왼쪽 또는 외부에서 들어오는 A 값 연결
                    .data_from_top(top_data),   // 위쪽에서 들어오는 weight 또는 partial sum 연결
                    .data_to_right(right[SE_IDX]), // 오른쪽 SE로 전달되는 A 값 연결
                    .data_to_bottom(down[SE_IDX]), // 아래쪽 SE로 전달되는 registered partial sum 또는 weight 연결
                    .busy(se_busy[SE_IDX]),  // 현재 SE의 live busy를 se_busy array에 연결
                    .psum_to_bottom_now(psum_now[SE_IDX]) // 현재 cycle의 최신 partial sum bypass 연결
                );

            end
        end
    endgenerate

    always @(posedge clk or posedge rst) begin // clk의 positive edge 또는 rst의 positive edge마다 top-level register update
        if (rst) begin                         // rst가 1일 때 실행
            C         <= 64'd0;                // C 출력을 0으로 초기화
            busy      <= 1'b0;                 // top-level busy를 0으로 초기화
            pf_active <= 1'b0;                 // prefill 유지 flag 초기화
            pf_cnt    <= 3'd0;                 // prefill counter 초기화
            en_delay  <= 32'd0;                // enable delay register 초기화
        end
        else begin                             // rst가 0일 때 실행
            if (pre_fill) begin                // 외부 pre_fill이 들어온 경우
                pf_active <= 1'b1;             // weight가 아래 row까지 전달될 수 있도록 내부 prefill 유지 시작
                pf_cnt    <= 3'd0;             // prefill counter를 0으로 초기화
            end
            else if (pf_active) begin          // 내부 prefill 유지 상태인 경우
                if (pf_cnt == 3'd2) begin      // 추가로 필요한 prefill 전달 cycle이 끝났는지 판단
                    pf_active <= 1'b0;         // prefill 유지 종료
                    pf_cnt    <= 3'd0;         // prefill counter 초기화
                end
                else begin                     // 아직 prefill 전달 cycle이 남은 경우
                    pf_cnt <= pf_cnt + 3'd1;   // counter를 1 증가
                end
            end

            en_delay <= pf_valid ? 32'd0 : {en_delay[30:0], a_valid}; // prefill 중에는 enable delay를 초기화하고, 계산 중에는 a_valid를 shift

            C[15:0]   <= psum_now[15];        // bottom row의 column 3 최신 결과를 C의 하위 16bit에 저장
            C[31:16]  <= psum_now[14];        // bottom row의 column 2 최신 결과를 C[31:16]에 저장
            C[47:32]  <= psum_now[13];        // bottom row의 column 1 최신 결과를 C[47:32]에 저장
            C[63:48]  <= psum_now[12];        // bottom row의 column 0 최신 결과를 C의 상위 16bit에 저장

            busy <= a_valid | (|se_busy);     // A 입력이 새로 들어왔거나 하나 이상의 SE에 남은 연산이 있으면 busy를 1로 유지
        end
    end

endmodule

// -------------------------------------------------------
// Final Project Controller
// -------------------------------------------------------
// Assignment 4의 ctrl 구조를 기반으로 FC1 - Norm/ReLU - FC2 전체 동작을 제어
// 하나의 4x4 Systolic Array와 CLA Accumulator를 재사용하여 base/extra case를 모두 처리
module ctrl (
    input               clk,           // 입력 clk 1bit (전체 controller 동작 clock)
    input               rst,           // 입력 rst 1bit (state, counter, buffer 초기화)
    input               run,           // 입력 run 1bit (testbench에서 1 cycle 동안 들어오는 start signal)
    input               batch_mode,    // 입력 batch_mode 1bit (0: base 8-batch, 1: extra 16-batch)

    output  reg         done,          // 출력 done 1bit (전체 FC1-Norm-ReLU-FC2 연산이 끝났는지 표시)
    output  reg [4:0]   state,         // 출력 state 5bit (파형에서 FSM 상태를 확인하기 위한 debug output)
    output  reg [31:0]  cycle_count,   // 출력 cycle_count 32bit (IDLE/DONE을 제외한 실제 동작 cycle 수 측정)

    output  reg         re_x,          // 출력 re_x 1bit (X input memory read enable)
    output  reg [6:0]   addr_x,        // 출력 addr_x 7bit (base 64개, extra 128개 X memory address)
    input       [7:0]   data_x,        // 입력 data_x 8bit (X memory에서 읽혀 ctrl로 들어오는 activation data)

    output  reg         re_w1,         // 출력 re_w1 1bit (W1T weight memory read enable)
    output  reg [5:0]   addr_w1,       // 출력 addr_w1 6bit (W1T 8x8 weight address)
    input       [7:0]   data_w1,       // 입력 data_w1 8bit (W1T memory에서 읽혀 ctrl로 들어오는 weight data)

    output  reg         re_w2,         // 출력 re_w2 1bit (W2T weight memory read enable)
    output  reg [5:0]   addr_w2,       // 출력 addr_w2 6bit (W2T 8x8 weight address)
    input       [7:0]   data_w2,       // 입력 data_w2 8bit (W2T memory에서 읽혀 ctrl로 들어오는 weight data)

    output  reg         we_y,          // 출력 we_y 1bit (FC2 최종 결과를 Y memory에 write하기 위한 enable)
    output  reg [6:0]   addr_y,        // 출력 addr_y 7bit (base 64개 또는 extra 128개 Y output address)
    output  reg [15:0]  data_y,        // 출력 data_y 16bit (Y memory에 저장할 최종 FC2 결과)

    output  reg         sa_en,         // 출력 sa_en 1bit (systolic array에 A tile data를 넣는 enable)
    output  reg         sa_prefill,    // 출력 sa_prefill 1bit (systolic array 내부 weight register를 채우는 enable)
    input               sa_busy,       // 입력 sa_busy 1bit (systolic array가 아직 연산 중인지 알려주는 status)
    output  reg [31:0]  sa_data_A,     // 출력 sa_data_A 32bit (4개의 8bit activation을 systolic array로 전달)
    output  reg [31:0]  sa_data_B,     // 출력 sa_data_B 32bit (4개의 8bit weight를 systolic array prefill용으로 전달)
    input       [63:0]  sa_data_C,     // 입력 sa_data_C 64bit (systolic array bottom row에서 나온 4개의 16bit 결과)

    output  reg [15:0]  acc_data_P,    // 출력 acc_data_P 16bit (현재 tile_k partial product를 CLA accumulator로 전달)
    output  reg [15:0]  acc_data_C,    // 출력 acc_data_C 16bit (기존 누적값을 CLA accumulator로 전달)
    input       [15:0]  acc_out_C      // 입력 acc_out_C 16bit (CLA accumulator가 계산한 acc_data_C + acc_data_P 결과)
);
    localparam [4:0] IDLE       = 5'd0; // IDLE : run 입력을 기다리는 초기 대기 상태
    localparam [4:0] LOAD_X     = 5'd1; // LOAD_X : X memory에서 input activation을 x_buf로 읽어오는 상태
    localparam [4:0] LOAD_W1    = 5'd2; // LOAD_W1 : W1T memory에서 FC1 weight를 w1_buf로 읽어오는 상태
    localparam [4:0] LOAD_W2    = 5'd3; // LOAD_W2 : W2T memory에서 FC2 weight를 w2_buf로 읽어오는 상태
    localparam [4:0] CLEAR_TILE = 5'd4; // CLEAR_TILE : 현재 4x4 tile buffer를 구성하고 partial buffer를 초기화하는 상태
    localparam [4:0] WHT_LOAD   = 5'd5; // WHT_LOAD : systolic array에 B weight tile을 pre_fill하는 상태
    localparam [4:0] COMP       = 5'd6; // COMP : systolic array에 A를 diagonal timing으로 공급하고 결과를 capture하는 상태
    localparam [4:0] ACCUM      = 5'd7; // ACCUM : tile_k=0/1에서 나온 partial result를 CLA로 누적하는 상태
    localparam [4:0] STORE_TILE = 5'd8; // STORE_TILE : FC1이면 Norm/ReLU 후 x3_buf 저장, FC2이면 Y memory write 상태
    localparam [4:0] DONE_ST    = 5'd9; // DONE_ST : 모든 batch와 layer 계산이 끝난 완료 상태

    localparam [1:0] COMP_SEND  = 2'd0; // COMP_SEND : 현재 comp_step에 해당하는 A diagonal data를 SA에 전송
    localparam [1:0] COMP_WAIT  = 2'd1; // COMP_WAIT : SA 내부 mad8 timing에 맞추어 output capture를 기다리는 phase
    localparam [1:0] COMP_GAP   = 2'd2; // COMP_GAP : 다음 COMP phase로 넘어가기 전 timing 간격을 맞추는 phase
    localparam [1:0] COMP_IDLE  = 2'd3; // COMP_IDLE : comp_step 증가 여부를 판단하는 phase

    localparam integer TILE_SIZE = 4;   // TILE_SIZE : 4x4 systolic array tile 크기

    integer r, c, i;                                      // for loop에서 row, column, index로 사용되는 integer 변수
    integer lane, lane_row;                              // COMP state에서 diagonal A input lane을 계산하기 위한 변수
    integer diag_d, diag_start, diag_end, diag_row, diag_col; // SA output을 4x4 tile 좌표로 다시 저장하기 위한 diagonal index 변수

    reg             batch_latched;                       // run 시점의 batch_mode를 저장 -> base/extra 동작 범위 고정
    reg             layer;                               // 현재 layer 표시, 0이면 FC1, 1이면 FC2
    reg [2:0]       tile_row;                            // 현재 처리 중인 4-row output tile index
    reg             tile_col;                            // 현재 처리 중인 4-column output tile index, 0 또는 1
    reg             tile_k;                              // K dimension을 4개씩 나누는 tile index, 0 또는 1
    reg [7:0]       load_cnt;                            // X/W1/W2 memory load address와 저장 순서를 세는 counter
    reg [1:0]       prefill_cnt;                         // WHT_LOAD에서 4개 weight row를 SA에 넣기 위한 counter
    reg [3:0]       comp_step;                           // COMP에서 A diagonal input step과 SA output diagonal step을 세는 counter
    reg [1:0]       comp_phase;                          // COMP_SEND/WAIT/GAP/IDLE의 sub-phase를 나타내는 counter
    reg [4:0]       accum_cnt;                           // 4x4 tile의 16개 element를 CLA로 누적하기 위한 counter
    reg [4:0]       store_cnt;                           // STORE_TILE에서 16개 element를 x3_buf 또는 Y memory에 저장하기 위한 counter

    reg [7:0]       x_buf  [0:127];                      // X input buffer, extra 16-batch까지 저장하기 위해 128개 확보
    reg [7:0]       x3_buf [0:127];                      // FC1 이후 Norm/ReLU 결과 X3 저장 buffer -> FC2 input으로 사용
    reg [7:0]       w1_buf [0:63];                       // W1T 8x8 weight를 저장하는 buffer
    reg [7:0]       w2_buf [0:63];                       // W2T 8x8 weight를 저장하는 buffer

    reg [7:0]       buf_A  [0:3][0:3];                   // 현재 4x4 matrix multiplication에 들어갈 A tile buffer
    reg [7:0]       buf_B  [0:3][0:3];                   // 현재 4x4 matrix multiplication에 들어갈 B weight tile buffer
    reg [15:0]      buf_P0 [0:3][0:3];                   // tile_k=0에서 나온 4x4 partial result 저장 buffer
    reg [15:0]      buf_P1 [0:3][0:3];                   // tile_k=1에서 나온 4x4 partial result 저장 buffer
    reg [15:0]      acc    [0:3][0:3];                   // P0와 P1을 누적한 최종 4x4 output tile buffer

    wire [7:0] elem_count;                               // 현재 mode에서 읽어야 하는 X element 개수, base=64 extra=128
    wire [2:0] last_tile_row;                            // 현재 mode에서 마지막 tile_row index, base=1 extra=3

    assign elem_count    = batch_latched ? 8'd128 : 8'd64; // extra mode이면 X 128개, base mode이면 X 64개를 load
    assign last_tile_row = batch_latched ? 3'd3   : 3'd1;  // extra mode이면 4개 row tile, base mode이면 2개 row tile 처리

    function [6:0] flat_addr;                         // 현재 tile 내부 index를 전체 Y/X3 flat address로 바꾸는 function
        input [3:0] idx;                                // idx : 4x4 tile 안에서 0~15까지의 element index
        integer out_r, out_c;                           // out_r/out_c : 전체 matrix 기준 row/column index
        begin
            out_r = (tile_row << 2) + (idx >> 2);        // tile_row*4 + tile 내부 row를 계산
            out_c = (tile_col << 2) + (idx & 3);         // tile_col*4 + tile 내부 column을 계산
            flat_addr = (out_r << 3) + out_c;            // 전체 matrix는 column 8개이므로 row*8 + column으로 flatten
        end
    endfunction

    function [7:0] tile_a;                              // 현재 layer/tile 위치에서 A tile의 한 element를 읽는 function
        input [1:0] local_r;                            // local_r : 4x4 tile 내부 row
        input [1:0] local_c;                            // local_c : 4x4 tile 내부 K column
        integer row, col, idx;                          // 전체 matrix 기준 row/column과 flat index
        begin
            row = (tile_row << 2) + local_r;             // 전체 batch row index 계산
            col = (tile_k << 2) + local_c;               // 전체 K dimension column index 계산
            idx = (row << 3) + col;                      // 전체 input matrix는 8-column이므로 row*8+col로 접근
            tile_a = (layer == 1'b0) ? x_buf[idx] : x3_buf[idx]; // FC1이면 X, FC2이면 Norm/ReLU 결과 X3를 사용
        end
    endfunction

    function [7:0] tile_b;                              // 현재 layer/tile 위치에서 B weight tile의 한 element를 읽는 function
        input [1:0] local_r;                            // local_r : 4x4 tile 내부 K row
        input [1:0] local_c;                            // local_c : 4x4 tile 내부 output column
        integer row, col, idx;                          // 전체 weight matrix 기준 row/column과 flat index
        begin
            row = (tile_k << 2) + local_r;               // 전체 K dimension row index 계산
            col = (tile_col << 2) + local_c;             // 전체 output feature column index 계산
            idx = (row << 3) + col;                      // W1T/W2T도 8-column이므로 row*8+col로 접근
            tile_b = (layer == 1'b0) ? w1_buf[idx] : w2_buf[idx]; // FC1이면 W1T, FC2이면 W2T를 사용
        end
    endfunction

    function [15:0] partial_value;                      // 현재 tile_k에 해당하는 partial result buffer에서 element를 읽는 function
        input [4:0] idx;                                // idx : 4x4 tile 내부 element index
        begin
            partial_value = (tile_k == 1'b0) ? buf_P0[idx[3:2]][idx[1:0]]
                                             : buf_P1[idx[3:2]][idx[1:0]]; // tile_k에 따라 P0 또는 P1 선택
        end
    endfunction

    function [15:0] acc_value;                          // 누적 완료된 4x4 output tile에서 element를 읽는 function
        input [4:0] idx;                                // idx : 4x4 tile 내부 element index
        begin
            acc_value = acc[idx[3:2]][idx[1:0]];         // idx[3:2]는 row, idx[1:0]은 column으로 해석
        end
    endfunction

    function [7:0] norm_relu;                           // FC1 16bit 결과에 Norm과 ReLU를 적용하여 8bit X3를 만드는 function
        input [15:0] value;                             // value : FC1에서 나온 16bit signed output
        reg signed [15:0] shifted16;                    // shifted16 : arithmetic right shift 이후의 signed 16bit 값
        reg [7:0] shifted8;                             // shifted8 : README 조건에 따라 truncate한 8bit 값
        begin
            shifted16 = $signed(value) >>> 5;            // Norm : signed value를 32로 나누기 위해 arithmetic right shift 5 수행
            shifted8  = shifted16[7:0];                  // 16bit Norm 결과에서 하위 8bit만 사용
            norm_relu = shifted8[7] ? 8'd0 : shifted8;   // ReLU : sign bit가 1이면 0, 아니면 그대로 통과
        end
    endfunction

    always @(*) begin                                // 현재 state와 counter 값에 따라 외부 port와 datapath control을 조합논리로 생성
        re_x = 1'b0;      addr_x = 7'd0;              // 기본값 : X memory read 비활성화 및 address 0
        re_w1 = 1'b0;     addr_w1 = 6'd0;             // 기본값 : W1T memory read 비활성화 및 address 0
        re_w2 = 1'b0;     addr_w2 = 6'd0;             // 기본값 : W2T memory read 비활성화 및 address 0
        we_y = 1'b0;      addr_y = 7'd0;      data_y = 16'd0; // 기본값 : Y memory write 비활성화
        sa_en = 1'b0;     sa_prefill = 1'b0;  sa_data_A = 32'd0; sa_data_B = 32'd0; // 기본값 : SA 입력 비활성화
        acc_data_P = 16'd0; acc_data_C = 16'd0;       // 기본값 : CLA accumulator 입력 0

        case (state)
            LOAD_X: begin                              // X memory에서 input activation을 순차적으로 읽는 상태
                if (load_cnt < elem_count) begin             // base/extra mode에 맞는 element 개수까지만 read enable 발생
                    re_x = 1'b1;                             // X memory read enable을 1로 올림
                    addr_x = load_cnt[6:0];                  // 현재 load_cnt 값을 X memory address로 사용
                end
            end

            LOAD_W1: begin                             // W1T memory에서 FC1 weight를 순차적으로 읽는 상태
                if (load_cnt < 8'd64) begin            // W1T는 8x8이므로 64개 element만 read
                    re_w1 = 1'b1;                      // W1T memory read enable을 1로 올림
                    addr_w1 = load_cnt[5:0];           // 현재 load_cnt 값을 W1T memory address로 사용
                end
            end

            LOAD_W2: begin                             // W2T memory에서 FC2 weight를 순차적으로 읽는 상태
                if (load_cnt < 8'd64) begin            // W2T도 8x8이므로 64개 element만 read
                    re_w2 = 1'b1;                      // W2T memory read enable을 1로 올림
                    addr_w2 = load_cnt[5:0];           // 현재 load_cnt 값을 W2T memory address로 사용
                end
            end

            WHT_LOAD: begin                            // SA 내부 weight register를 채우기 위해 B tile row를 순차적으로 전달
                sa_prefill = (prefill_cnt == 2'd0);       // prefill 시작 pulse는 첫 cycle에만 1로 발생시킴
                case (prefill_cnt)                        // SA의 top row부터 weight가 아래로 내려가므로 B row를 역순으로 넣어 timing을 맞춤
                    2'd0:    sa_data_B = {buf_B[3][0], buf_B[3][1], buf_B[3][2], buf_B[3][3]}; // B tile 3번째 row 전달
                    2'd1:    sa_data_B = {buf_B[2][0], buf_B[2][1], buf_B[2][2], buf_B[2][3]}; // B tile 2번째 row 전달
                    2'd2:    sa_data_B = {buf_B[1][0], buf_B[1][1], buf_B[1][2], buf_B[1][3]}; // B tile 1번째 row 전달
                    default: sa_data_B = {buf_B[0][0], buf_B[0][1], buf_B[0][2], buf_B[0][3]}; // B tile 0번째 row 전달
                endcase
            end

            COMP: begin                                // A tile을 diagonal 형태로 SA에 공급하는 상태
                sa_en = (comp_phase == COMP_SEND) && (comp_step < 4'd4); // COMP_SEND phase의 앞 4 step에서만 새 A 입력 유효
                for (lane = 0; lane < TILE_SIZE; lane = lane + 1) begin  // 4개의 A input lane을 각각 계산
                    lane_row = comp_step - lane;        // 현재 lane에 들어갈 A tile row 계산
                    if ((comp_step >= lane) && (lane_row < TILE_SIZE))
                        sa_data_A[8*(TILE_SIZE-1-lane) +: 8] = buf_A[lane_row][lane]; // diagonal 위치에 맞는 A 값을 전달
                    else
                        sa_data_A[8*(TILE_SIZE-1-lane) +: 8] = 8'd0; // 아직 유효한 A가 없는 lane은 0으로 채움
                end
            end

            ACCUM: begin                               // P0/P1 partial result를 CLA accumulator에 넣는 상태
                if (accum_cnt < 5'd16) begin           // 4x4 tile의 16개 element까지만 accumulator 입력 생성
                    acc_data_C = acc[accum_cnt[3:2]][accum_cnt[1:0]]; // 기존 누적값을 CLA 입력 A로 전달
                    acc_data_P = partial_value(accum_cnt);            // 현재 tile_k partial result를 CLA 입력 B로 전달
                end
            end

            STORE_TILE: begin                          // 완성된 4x4 output tile을 저장하는 상태
                if ((layer == 1'b1) && (store_cnt < 5'd16)) begin // FC2 layer일 때만 외부 Y memory에 write
                    we_y = 1'b1;                       // Y memory write enable
                    addr_y = flat_addr(store_cnt[3:0]); // 현재 tile 내부 index를 전체 Y address로 변환
                    data_y = acc_value(store_cnt);      // 누적 완료된 16bit Y 결과를 data_y로 전달
                end
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin          // clk positive edge 또는 rst positive edge마다 ctrl 내부 register update
        if (rst) begin                                      // rst가 1이면 모든 state, counter, buffer를 초기화
            done <= 1'b0;
            state <= IDLE;
            cycle_count <= 32'd0;
            batch_latched <= 1'b0;
            layer <= 1'b0;
            tile_row <= 3'd0;
            tile_col <= 1'b0;
            tile_k <= 1'b0;
            load_cnt <= 8'd0;
            prefill_cnt <= 2'd0;
            comp_step <= 4'd0;
            comp_phase <= COMP_SEND;
            accum_cnt <= 5'd0;
            store_cnt <= 5'd0;

            for (i = 0; i < 128; i = i + 1) begin
                x_buf[i] <= 8'd0;
                x3_buf[i] <= 8'd0;
            end
            for (i = 0; i < 64; i = i + 1) begin
                w1_buf[i] <= 8'd0;
                w2_buf[i] <= 8'd0;
            end
            for (r = 0; r < 4; r = r + 1) begin
                for (c = 0; c < 4; c = c + 1) begin
                    buf_A[r][c] <= 8'd0;
                    buf_B[r][c] <= 8'd0;
                    buf_P0[r][c] <= 16'd0;
                    buf_P1[r][c] <= 16'd0;
                    acc[r][c] <= 16'd0;
                end
            end
        end
        else begin                                          // rst가 0이면 현재 state에 따라 sequential 동작 수행
            if (state != IDLE && state != DONE_ST)             // 실제 accelerator가 동작 중인 state에서만 latency counter 증가
                cycle_count <= cycle_count + 32'd1;

            case (state)                                      // 현재 FSM state에 따라 다음 state와 내부 buffer를 갱신
                IDLE: begin                                // run 입력을 기다리는 대기 상태
                    done <= 1'b0;                            // 새 연산 시작 전 done을 0으로 내림
                    cycle_count <= 32'd0;                    // latency 측정을 위해 cycle_count 초기화
                    load_cnt <= 8'd0;                        // memory load counter 초기화
                    layer <= 1'b0;                           // 첫 layer는 FC1이므로 0으로 초기화
                    tile_row <= 3'd0;                        // 첫 row tile부터 시작
                    tile_col <= 1'b0;                        // 첫 column tile부터 시작
                    tile_k <= 1'b0;                          // 첫 K tile부터 시작
                    if (run) begin                           // testbench에서 run pulse가 들어오면 연산 시작
                        batch_latched <= batch_mode;         // run 시점의 batch_mode를 저장하여 base/extra 범위 고정
                        state <= LOAD_X;                     // X input memory load state로 이동
                    end
                end

                LOAD_X: begin                              // X memory output을 x_buf에 저장하는 상태
                    if (load_cnt != 8'd0)                    // mem_behavior는 read 후 data가 나오므로 0번째 cycle은 저장하지 않음
                        x_buf[load_cnt - 8'd1] <= data_x;    // 이전 address에서 나온 data_x를 x_buf에 저장

                    if (load_cnt == elem_count) begin        // base/extra mode에 필요한 X 개수를 모두 읽은 경우
                        load_cnt <= 8'd0;                    // 다음 memory load를 위해 counter 초기화
                        state <= LOAD_W1;                    // W1T load state로 이동
                    end
                    else begin
                        load_cnt <= load_cnt + 8'd1;         // 아직 남은 X가 있으면 다음 address로 이동
                    end
                end

                LOAD_W1: begin                              // W1T memory output을 w1_buf에 저장하는 상태
                    if (load_cnt != 8'd0)                    // memory read latency를 고려해 load_cnt-1 위치에 저장
                        w1_buf[load_cnt - 8'd1] <= data_w1;  // 이전 address에서 나온 data_w1을 w1_buf에 저장

                    if (load_cnt == 8'd64) begin             // W1T 64개 element를 모두 읽은 경우
                        load_cnt <= 8'd0;                    // counter 초기화
                        state <= LOAD_W2;                    // W2T load state로 이동
                    end
                    else begin
                        load_cnt <= load_cnt + 8'd1;         // 다음 W1T address로 이동
                    end
                end

                LOAD_W2: begin                              // W2T memory output을 w2_buf에 저장하는 상태
                    if (load_cnt != 8'd0)                    // memory read latency를 고려해 load_cnt-1 위치에 저장
                        w2_buf[load_cnt - 8'd1] <= data_w2;  // 이전 address에서 나온 data_w2를 w2_buf에 저장

                    if (load_cnt == 8'd64) begin             // W2T 64개 element를 모두 읽은 경우
                        load_cnt <= 8'd0;                    // counter 초기화
                        layer <= 1'b0;                       // FC1부터 계산 시작
                        tile_row <= 3'd0;                    // 첫 row tile부터 시작
                        tile_col <= 1'b0;                    // 첫 column tile부터 시작
                        tile_k <= 1'b0;                      // 첫 K tile부터 시작
                        state <= CLEAR_TILE;                 // 현재 tile buffer 구성 state로 이동
                    end
                    else begin
                        load_cnt <= load_cnt + 8'd1;         // 다음 W2T address로 이동
                    end
                end

                CLEAR_TILE: begin                          // 현재 tile_row/tile_col/tile_k에 해당하는 4x4 A/B tile을 준비
                    for (r = 0; r < 4; r = r + 1) begin       // tile 내부 row 반복
                        for (c = 0; c < 4; c = c + 1) begin   // tile 내부 column 반복
                            buf_A[r][c] <= tile_a(r[1:0], c[1:0]); // 현재 layer와 tile index에 맞는 A element 저장
                            buf_B[r][c] <= tile_b(r[1:0], c[1:0]); // 현재 layer와 tile index에 맞는 B weight element 저장
                            buf_P0[r][c] <= 16'd0;            // tile_k=0 partial buffer 초기화
                            buf_P1[r][c] <= 16'd0;            // tile_k=1 partial buffer 초기화
                            if (tile_k == 1'b0)
                                acc[r][c] <= 16'd0;           // 새로운 output tile의 첫 K tile이면 최종 acc buffer도 초기화
                        end
                    end
                    prefill_cnt <= 2'd0;                      // weight prefill counter 초기화
                    comp_step <= 4'd0;                        // COMP diagonal step 초기화
                    comp_phase <= COMP_SEND;                  // COMP phase를 SEND부터 시작하도록 설정
                    accum_cnt <= 5'd0;                        // accumulation counter 초기화
                    state <= WHT_LOAD;                        // weight prefill state로 이동
                end

                WHT_LOAD: begin                               // buf_B에 저장된 4x4 weight tile을 SA 내부 Weight register에 prefill
                    if (prefill_cnt == 2'd3) begin            // 4개 row를 모두 전달한 경우
                        prefill_cnt <= 2'd0;                  // prefill counter 초기화
                        comp_step <= 4'd0;                    // compute step 초기화
                        comp_phase <= COMP_SEND;              // compute phase 초기화
                        state <= COMP;                        // 실제 SA compute state로 이동
                    end
                    else begin
                        prefill_cnt <= prefill_cnt + 2'd1;    // 다음 weight row를 전달하기 위해 counter 증가
                    end
                end

                COMP: begin                                  // SA에 A를 넣고, timing에 맞춰 4x4 result를 diagonal 단위로 capture
                    if (comp_phase == COMP_WAIT) begin          // WAIT phase에서 SA output이 유효한지 확인
                        if (comp_step >= 4'd4) begin            // 앞 4 step은 SA filling 구간이므로 step 4부터 output capture 시작
                            diag_d = comp_step - 4'd4;          // 현재 capture해야 하는 output diagonal index 계산
                            diag_start = (diag_d < TILE_SIZE) ? diag_d : TILE_SIZE - 1; // diagonal의 시작 row 계산
                            diag_end = (diag_d < TILE_SIZE) ? 0 : diag_d - (TILE_SIZE - 1); // diagonal의 끝 row 계산

                            for (diag_row = diag_start; diag_row >= diag_end; diag_row = diag_row - 1) begin // 현재 diagonal의 element들을 저장
                                diag_col = diag_d - diag_row;   // diagonal index와 row로 column 계산
                                if (tile_k == 1'b0)
                                    buf_P0[diag_row][diag_col] <= sa_data_C[16*(TILE_SIZE-1-diag_col) +: 16]; // 첫 K tile 결과는 P0에 저장
                                else
                                    buf_P1[diag_row][diag_col] <= sa_data_C[16*(TILE_SIZE-1-diag_col) +: 16]; // 두 번째 K tile 결과는 P1에 저장
                            end
                        end
                    end

                    if (comp_phase == COMP_IDLE) begin          // 한 comp_step의 SEND/WAIT/GAP/IDLE phase가 끝난 시점
                        if (comp_step == 4'd10) begin           // 모든 diagonal input/output step이 끝난 경우
                            comp_step <= 4'd0;                  // 다음 tile을 위해 comp_step 초기화
                            comp_phase <= COMP_SEND;            // phase 초기화
                            accum_cnt <= 5'd0;                  // accumulation 시작 준비
                            state <= ACCUM;                     // partial result accumulation state로 이동
                        end
                        else begin
                            comp_step <= comp_step + 4'd1;      // 다음 diagonal step으로 이동
                            comp_phase <= COMP_SEND;            // 다음 step도 SEND phase부터 시작
                        end
                    end
                    else begin
                        comp_phase <= comp_phase + 2'd1;        // SEND -> WAIT -> GAP -> IDLE 순서로 phase 증가
                    end
                end

                ACCUM: begin                                 // P0/P1 partial result를 acc buffer로 누적하는 상태
                    if (accum_cnt < 5'd16) begin             // 4x4 tile의 16개 element를 순차적으로 처리
                        if (tile_k == 1'b0)
                            acc[accum_cnt[3:2]][accum_cnt[1:0]] <= partial_value(accum_cnt); // 첫 K tile이면 partial result를 그대로 acc에 저장
                        else
                            acc[accum_cnt[3:2]][accum_cnt[1:0]] <= acc_out_C; // 두 번째 K tile이면 기존 acc와 partial result를 더한 CLA 결과 저장
                        accum_cnt <= accum_cnt + 5'd1;        // 다음 element로 이동
                    end
                    else begin
                        accum_cnt <= 5'd0;                    // accumulation counter 초기화
                        if (tile_k == 1'b0) begin             // 첫 K tile만 끝난 경우
                            tile_k <= 1'b1;                   // 두 번째 K tile로 이동
                            state <= CLEAR_TILE;              // 같은 output tile의 다음 K tile을 준비
                        end
                        else begin                            // 두 K tile이 모두 끝난 경우
                            tile_k <= 1'b0;                   // 다음 output tile을 위해 tile_k 초기화
                            store_cnt <= 5'd0;                // STORE_TILE counter 초기화
                            state <= STORE_TILE;              // 완성된 4x4 output tile 저장 state로 이동
                        end
                    end
                end

                STORE_TILE: begin                             // 완성된 4x4 tile을 layer에 따라 x3_buf 또는 Y memory로 저장
                    if (store_cnt < 5'd16) begin              // tile 내부 16개 element를 순차 저장
                        if (layer == 1'b0)
                            x3_buf[flat_addr(store_cnt[3:0])] <= norm_relu(acc_value(store_cnt)); // FC1이면 Norm/ReLU 후 X3 buffer에 저장
                        store_cnt <= store_cnt + 5'd1;        // 다음 element로 이동
                    end
                    else begin
                        store_cnt <= 5'd0;                    // tile 저장 완료 후 counter 초기화
                        if (tile_col == 1'b0) begin           // 첫 column tile이 끝난 경우
                            tile_col <= 1'b1;                 // 두 번째 column tile로 이동
                            state <= CLEAR_TILE;              // 다음 output column tile 준비
                        end
                        else begin                            // 두 column tile이 모두 끝난 경우
                            tile_col <= 1'b0;                 // 다음 row tile을 위해 tile_col 초기화
                            if (tile_row != last_tile_row) begin // 아직 처리할 row tile이 남은 경우
                                tile_row <= tile_row + 3'd1;  // 다음 row tile로 이동
                                state <= CLEAR_TILE;          // 다음 output row tile 준비
                            end
                            else begin                        // 현재 layer의 모든 row/column tile이 끝난 경우
                                tile_row <= 3'd0;             // 다음 layer 또는 done을 위해 tile_row 초기화
                                if (layer == 1'b0) begin      // FC1이 끝난 경우
                                    layer <= 1'b1;            // FC2 layer로 전환
                                    tile_k <= 1'b0;           // FC2의 첫 K tile부터 시작
                                    state <= CLEAR_TILE;      // X3와 W2T를 이용한 FC2 tile 준비
                                end
                                else begin                    // FC2까지 모두 끝난 경우
                                    done <= 1'b1;             // 전체 연산 완료 표시
                                    state <= DONE_ST;         // DONE_ST로 이동
                                end
                            end
                        end
                    end
                end

                DONE_ST: begin                              // 전체 연산 완료 후 유지되는 상태
                    done <= 1'b1;                            // testbench가 완료를 확인할 수 있도록 done을 1로 유지
                    state <= DONE_ST;                         // 외부 reset 전까지 DONE_ST 유지
                end

                default: begin                               // 정의되지 않은 state가 들어오면 안전하게 IDLE로 복귀
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

// -------------------------------------------------------
// Top module with Controller, Systolic Array and Accumulator
// -------------------------------------------------------
// README에서 지정한 top I/O는 유지하고, 내부에서 ctrl / sa8_4x4 / cla16을 연결
module top(
    input               clk,          // 입력 clk (testbench에서 생성되는 10ns period clock)
    input               rst,          // 입력 rst (전체 accelerator register 초기화)
    input               run,          // 입력 run (연산 시작을 알리는 1-cycle pulse)
    input               batch_mode,   // 입력 batch_mode (0: base 8-batch, 1: extra 16-batch)

    output              done,         // 출력 done (전체 연산 완료 여부)
    output  reg [4:0]   state,        // 출력 state (ctrl FSM state를 파형에서 확인하기 위한 debug signal)
    output  reg [31:0]  cycle_count,  // 출력 cycle_count (latency 측정을 위한 cycle counter)

    output  reg         re_x,         // 출력 re_x (X memory read enable)
    output  reg [6:0]   addr_x,       // 출력 addr_x (X memory read address)
    input       [7:0]   data_x,       // 입력 data_x (X memory에서 읽힌 8bit activation)

    output  reg         re_w1,        // 출력 re_w1 (W1T memory read enable)
    output  reg [5:0]   addr_w1,      // 출력 addr_w1 (W1T memory read address)
    input       [7:0]   data_w1,      // 입력 data_w1 (W1T memory에서 읽힌 8bit weight)

    output  reg         re_w2,        // 출력 re_w2 (W2T memory read enable)
    output  reg [5:0]   addr_w2,      // 출력 addr_w2 (W2T memory read address)
    input       [7:0]   data_w2,      // 입력 data_w2 (W2T memory에서 읽힌 8bit weight)

    output  reg         we_y,         // 출력 we_y (Y memory write enable)
    output  reg [6:0]   addr_y,       // 출력 addr_y (Y memory write address)
    output  reg [15:0]  data_y        // 출력 data_y (Y memory에 write할 16bit final output)
);
    wire            done_;                         // ctrl에서 생성된 done 신호를 top output으로 전달하기 위한 내부 wire
    wire [4:0]      state_;                        // ctrl에서 생성된 FSM state 내부 wire
    wire [31:0]     cycle_count_;                  // ctrl에서 생성된 cycle_count 내부 wire

    wire            re_x_, re_w1_, re_w2_, we_y_;  // ctrl에서 생성된 memory enable 내부 wire
    wire [6:0]      addr_x_, addr_y_;              // ctrl에서 생성된 X/Y address 내부 wire
    wire [5:0]      addr_w1_, addr_w2_;            // ctrl에서 생성된 W1T/W2T address 내부 wire
    wire [15:0]     data_y_;                       // ctrl에서 생성된 Y write data 내부 wire

    wire            sa_en, sa_prefill, sa_busy;    // ctrl과 systolic array 사이의 enable/status wire
    wire [31:0]     sa_data_A, sa_data_B;          // ctrl에서 SA로 전달되는 4-lane A/B data
    wire [63:0]     sa_data_C;                     // SA에서 ctrl로 돌아오는 4-lane 16bit result

    wire [15:0]     acc_data_P;                    // ctrl에서 CLA accumulator로 전달되는 partial result
    wire [15:0]     acc_data_C;                    // ctrl에서 CLA accumulator로 전달되는 기존 acc 값
    wire [15:0]     acc_out_C;                     // CLA accumulator가 계산한 누적 결과

    assign done = done_;                           // done은 wire output이므로 ctrl의 done_을 직접 연결

    always @(*) begin                              // ctrl 내부 wire를 top의 reg output port로 그대로 전달
        state = state_;
        cycle_count = cycle_count_;
        re_x = re_x_;
        addr_x = addr_x_;
        re_w1 = re_w1_;
        addr_w1 = addr_w1_;
        re_w2 = re_w2_;
        addr_w2 = addr_w2_;
        we_y = we_y_;
        addr_y = addr_y_;
        data_y = data_y_;
    end

    ctrl U_ctrl (                                  // Final Project 전체 scheduling과 memory/datapath 제어를 담당하는 controller
        .clk(clk),
        .rst(rst),
        .run(run),
        .batch_mode(batch_mode),
        .done(done_),
        .state(state_),
        .cycle_count(cycle_count_),
        .re_x(re_x_),
        .addr_x(addr_x_),
        .data_x(data_x),
        .re_w1(re_w1_),
        .addr_w1(addr_w1_),
        .data_w1(data_w1),
        .re_w2(re_w2_),
        .addr_w2(addr_w2_),
        .data_w2(data_w2),
        .we_y(we_y_),
        .addr_y(addr_y_),
        .data_y(data_y_),
        .sa_en(sa_en),
        .sa_prefill(sa_prefill),
        .sa_busy(sa_busy),
        .sa_data_A(sa_data_A),
        .sa_data_B(sa_data_B),
        .sa_data_C(sa_data_C),
        .acc_data_P(acc_data_P),
        .acc_data_C(acc_data_C),
        .acc_out_C(acc_out_C)
    );

    sa8_4x4 U_sa (                                // FC1과 FC2에서 공통으로 재사용되는 4x4 weight-stationary systolic array
        .clk(clk),
        .rst(rst),
        .en(sa_en),
        .pre_fill(sa_prefill),
        .A(sa_data_A),
        .B(sa_data_B),
        .C(sa_data_C),
        .busy(sa_busy)
    );

    cla16 U_accumulator (                         // tile_k=0/1 partial result를 더하기 위한 16bit CLA accumulator
        .A(acc_data_C),
        .B(acc_data_P),
        .Cin(1'b0),
        .S(acc_out_C),
        .Cout(),
        .G_group(),
        .P_group()
    );
endmodule
