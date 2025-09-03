module mac(In1, In2 , MacOut , CLK , rst);

    input [31:0] In1,In2;					//Inputs to MAC unit
    output [31:0] MacOut;					//Output of MAC unit
    input CLK,rst;						//Clk and rst lines for MAC unit

    reg [31:0] In1_reg     = 32'b0;				//Register to Hold In1 value
    reg [31:0] In2_reg     = 32'b0;				//Register to Hold In2 value
    reg [31:0] accumulator = 32'b0;				//Register to Hold Accumulator


    //Intermediate wires

    wire [31:0] mult_Out;
    wire [31:0] add_Out;
    wire [31:0] Out;
    
    //Top level Connections
        
    Multiplier M1(In1_reg,In2_reg,mult_Out);
    float_add F1(mult_Out,MacOut,add_Out);
    assign MacOut = accumulator;

    //Describing functionality of circuit with clock and reset

    always @(posedge CLK)
    begin
        //Clearing all registers
        if(~rst)
            begin
                In1_reg <= 0;
                In2_reg <= 0;
                accumulator<=0;
            end
        else
        //Moving data into input registers and data out to output registers
            begin
                In1_reg <= In1;
                In2_reg <= In2;
                accumulator<=add_Out;
        end
    end
endmodule


//Single Precision Multiplier Unit Implementation


module Multiplier(A,B,C);

    input [31:0] A,B;					//inputs to Multiplier A,B
    output [31:0] C;					//output of Multiplier C

    //Intermediate Values

    wire [47:0] X;					
    wire [7:0] X_s;
    wire [7:0] exponent_out;
    wire [1:0] dummy_carry;
    wire zeroCheck;

    // Sign Bit Calculation

    assign C[31] = A[31]^B[31];
	
    // Mantissa Bits Calculations

    TreeMultiplier U1(A[22:0],B[22:0],X) ;
    assign comp_out = (X[47]==1'b1) ? 1'b1 : 1'b0 ;
    Mux um1(X[45:23],X[46:24],X[47],C[22:0]);

    // Exponent Bits Calculations

    ripple_carry_adder_8bit ua1(A[30:23],B[30:23],1'b0,X_s,dummy_carry[0]);
    ripple_carry_adder_8bit ua2(X_s,8'b10000001,X[47],exponent_out,dummy_carry[1]);
    Mux8bit um2(8'b0,exponent_out,zeroCheck,C[30:23]);
    zeroDetect Uz1 (A[30:23],B[30:23],zeroCheck);   

endmodule


// Implementing single precision Float adder 

module float_add (
    input  [31:0] a,      
    input  [31:0] b,       
    output [31:0] result 
);

   
    wire sign_a = a[31];
    wire [7:0] exp_a = a[30:23];
    wire [23:0] mant_a = {1'b1, a[22:0]}; // Add implicit leading 1

    wire sign_b = b[31];
    wire [7:0] exp_b = b[30:23];
    wire [23:0] mant_b = {1'b1, b[22:0]}; // Add implicit leading 1

    // Compare exponents and align mantissas
    wire [7:0] exp_diff;
    wire [23:0] mant_a_shifted, mant_b_shifted;
    wire [7:0] exp_large;
    wire sign_large;

    assign exp_diff = (exp_a > exp_b) ? (exp_a - exp_b) : (exp_b - exp_a);
    assign exp_large = (exp_a > exp_b) ? exp_a : exp_b;
    assign sign_large = (exp_a > exp_b) ? sign_a : sign_b;

    // Shift the smaller mantissa to align with the larger exponent
    assign mant_a_shifted = (exp_a > exp_b) ? mant_a : (mant_a >> exp_diff);
    assign mant_b_shifted = (exp_b > exp_a) ? mant_b : (mant_b >> exp_diff);

    // Add or subtract mantissas based on the signs
    wire [24:0] mantissa_sum;
    wire [24:0] mantissa_diff;
    wire [24:0] mantissa_result;

    assign mantissa_sum = (sign_a == sign_b) ? (mant_a_shifted + mant_b_shifted) : 25'b0;
    assign mantissa_diff = (sign_a != sign_b) ? 
        ((mant_a_shifted > mant_b_shifted) ? (mant_a_shifted - mant_b_shifted) : (mant_b_shifted - mant_a_shifted)) : 25'b0;

    assign mantissa_result = (sign_a == sign_b) ? mantissa_sum : mantissa_diff;

    // Normalize result
    wire [24:0] normalized_mantissa;
    wire [7:0] normalized_exponent;
    wire normalized_sign;

    assign normalized_mantissa = (mantissa_result[24]) ? mantissa_result >> 1 : mantissa_result;
    assign normalized_exponent = (mantissa_result[24]) ? exp_large + 1 : exp_large;

  
    wire [24:0] final_mantissa;
    wire [7:0] final_exponent;
    assign final_mantissa = (normalized_mantissa[23]) ? normalized_mantissa : normalized_mantissa << 1;
    assign final_exponent = (normalized_mantissa[23]) ? normalized_exponent : normalized_exponent - 1;

    // sign
    assign normalized_sign = (sign_a == sign_b) ? sign_a : (mant_a_shifted > mant_b_shifted ? sign_a : sign_b);

    //final result
    assign result = {normalized_sign, final_exponent, final_mantissa[22:0]};

endmodule



// Zero Detect Unit Implementation

module zeroDetect(A1,B1,status);

    input [7:0] A1,B1;				//Input bits to module
    output status;				//Status bit indicating output

    wire [13:0] temp;

    assign temp[0] = A1[0] | B1[0];
    assign temp[1] = A1[1] | B1[1];
    assign temp[2] = A1[2] | B1[2];
    assign temp[3] = A1[3] | B1[3];
    assign temp[4] = A1[4] | B1[4];
    assign temp[5] = A1[5] | B1[5];
    assign temp[6] = A1[6] | B1[6];
    assign temp[7] = A1[7] | B1[7];
    assign temp[8] = temp[0] | temp[1];
    assign temp[9] = temp[2] | temp[3];
    assign temp[10] = temp[4] | temp[5];
    assign temp[11] = temp[6] | temp[7];
    assign temp[12] = temp[8] | temp[9];
    assign temp[13] = temp[10] | temp[11];

    assign status = temp[12] | temp[13];

endmodule


// 8-bit Ripple Carry Adder Module


module ripple_carry_adder_8bit (
    input [7:0] A,   // First 8-bit input
    input [7:0] B,   // Second 8-bit input
    input Cin,       // Carry input
    output [7:0] Sum, // 8-bit Sum output
    output Cout      // Final Carry output
);
    wire [7:0] carry; // Internal carry wires

    // Instantiate 8 Full Adders
    full_adder fa0 (A[0], B[0], Cin,   Sum[0], carry[0]);
    full_adder fa1 (A[1], B[1], carry[0], Sum[1], carry[1]);
    full_adder fa2 (A[2], B[2], carry[1], Sum[2], carry[2]);
    full_adder fa3 (A[3], B[3], carry[2], Sum[3], carry[3]);
    full_adder fa4 (A[4], B[4], carry[3], Sum[4], carry[4]);
    full_adder fa5 (A[5], B[5], carry[4], Sum[5], carry[5]);
    full_adder fa6 (A[6], B[6], carry[5], Sum[6], carry[6]);
    full_adder fa7 (A[7], B[7], carry[6], Sum[7], Cout);
endmodule


// 1 Bit Full adder Implementation

module full_adder (
    input a,         // First input bit
    input b,         // Second input bit
    input cin,       // Carry input
    output sum,      // Sum output
    output cout      // Carry output
);
    assign sum = a ^ b ^ cin;       // XOR for sum
    assign cout = (a & b) | (b & cin) | (a & cin); // Carry-out
endmodule



// Tree Multiplier implementation

module TreeMultiplier(A,B,D);


    	input [22:0] A, B;				//Inputs to module 
    	output [47:0] D;				//Output to module

    	//Intermediate Wires

    	wire [23:0] A_m ; 
    	wire [23:0] B_m;
    	wire [47:0] S_m  [11:0];
    	wire [47:0] Q_m  [5:0];
    	wire [47:0] Qn_m [2:0];
    	wire [47:0] U ;
    	wire [47:0] D ;
    	wire [47:0] AB_m [23:0];

    	//Appending the hidden bit
    	assign A_m = {1'b1,A};
    	assign B_m = {1'b1,B};

	//Generating Partial Products

        assign AB_m[0]= (B_m[0]==1'b1) ? ({24'b0,A_m}) : {48'b0} ;
        assign AB_m[1]= (B_m[1]==1'b1) ? ({23'b0,A_m,1'b0}) : {48'b0} ;
        assign AB_m[2]= (B_m[2]==1'b1) ? ({22'b0,A_m,2'b0}) : {48'b0} ;
        assign AB_m[3]= (B_m[3]==1'b1) ? ({21'b0,A_m,3'b0}) : {48'b0} ;
        assign AB_m[4]= (B_m[4]==1'b1) ? ({20'b0,A_m,4'b0}) : {48'b0} ;
        assign AB_m[5]= (B_m[5]==1'b1) ? ({19'b0,A_m,5'b0}) : {48'b0} ;
        assign AB_m[6]= (B_m[6]==1'b1) ? ({18'b0,A_m,6'b0}) : {48'b0} ;
        assign AB_m[7]= (B_m[7]==1'b1) ? ({17'b0,A_m,7'b0}) : {48'b0} ;
        assign AB_m[8]= (B_m[8]==1'b1) ? ({16'b0,A_m,8'b0}) : {48'b0} ;
        assign AB_m[9]= (B_m[9]==1'b1) ? ({15'b0,A_m,9'b0}) : {48'b0} ;
        assign AB_m[10]= (B_m[10]==1'b1) ? ({14'b0,A_m,10'b0}) : {48'b0} ;
        assign AB_m[11]= (B_m[11]==1'b1) ? ({13'b0,A_m,11'b0}) : {48'b0} ;
        assign AB_m[12]= (B_m[12]==1'b1) ? ({12'b0,A_m,12'b0}) : {48'b0} ;
        assign AB_m[13]= (B_m[13]==1'b1) ? ({11'b0,A_m,13'b0}) : {48'b0} ;
        assign AB_m[14]= (B_m[14]==1'b1) ? ({10'b0,A_m,14'b0}) : {48'b0} ;
        assign AB_m[15]= (B_m[15]==1'b1) ? ({9'b0,A_m,15'b0})  : {48'b0} ;
        assign AB_m[16]= (B_m[16]==1'b1) ? ({8'b0,A_m,16'b0})  : {48'b0} ;
        assign AB_m[17]= (B_m[17]==1'b1) ? ({7'b0,A_m,17'b0})  : {48'b0} ;
        assign AB_m[18]= (B_m[18]==1'b1) ? ({6'b0,A_m,18'b0})  : {48'b0} ;
        assign AB_m[19]= (B_m[19]==1'b1) ? ({5'b0,A_m,19'b0})  : {48'b0} ;
        assign AB_m[20]= (B_m[20]==1'b1) ? ({4'b0,A_m,20'b0})  : {48'b0} ;
        assign AB_m[21]= (B_m[21]==1'b1) ? ({3'b0,A_m,21'b0})  : {48'b0} ;
        assign AB_m[22]= (B_m[22]==1'b1) ? ({2'b0,A_m,22'b0})  : {48'b0} ;
        assign AB_m[23]= (B_m[23]==1'b1) ? ({1'b0,A_m,23'b0})  : {48'b0} ;

	// Tree based Adder Implementation

	//Stage 1       
 
        customAdder U1(AB_m[0],AB_m[1],S_m[0]);
        customAdder U2(AB_m[2],AB_m[3],S_m[1]);
        customAdder U3(AB_m[4],AB_m[5],S_m[2]);
        customAdder U4(AB_m[6],AB_m[7],S_m[3]);
        customAdder U5(AB_m[8],AB_m[9],S_m[4]);
        customAdder U6(AB_m[10],AB_m[11],S_m[5]);
        customAdder U7(AB_m[12],AB_m[13],S_m[6]);
        customAdder U8(AB_m[14],AB_m[15],S_m[7]);
        customAdder U9(AB_m[16],AB_m[17],S_m[8]);
        customAdder U10(AB_m[18],AB_m[19],S_m[9]);
        customAdder U11(AB_m[20],AB_m[21],S_m[10]);
        customAdder U12(AB_m[22],AB_m[23],S_m[11]);
	
	//Stage 2

        customAdder U13(S_m[0],S_m[1],Q_m[0]);
        customAdder U14(S_m[2],S_m[3],Q_m[1]);
        customAdder U15(S_m[4],S_m[5],Q_m[2]);
        customAdder U16(S_m[6],S_m[7],Q_m[3]);
        customAdder U17(S_m[8],S_m[9],Q_m[4]);
        customAdder U18(S_m[10],S_m[11],Q_m[5]);

	//Stage 3

        customAdder U19(Q_m[0],Q_m[1],Qn_m[0]);
        customAdder U20(Q_m[2],Q_m[3],Qn_m[1]);
        customAdder U21(Q_m[4],Q_m[5],Qn_m[2]);

	//Stage 4

        customAdder U22(Qn_m[0],Qn_m[1],U);
        customAdder U23(U,Qn_m[2],D);
        
endmodule


//Custom Adder Implementation

module customAdder(A_ca,B_ca,Sum_ca);

    input [47:0] A_ca;					//input  to Module
    input [47:0] B_ca;					//input  to Module
    output [47:0] Sum_ca;				//Output to Module

    wire [2:0] carry_temp;				

   //Custom adder built using 3 BK adders

    BkAdder16 u1(A_ca[15:0],B_ca[15:0],1'b0,Sum_ca[15:0],carry_temp[0]);
    BkAdder16 u2(A_ca[31:16],B_ca[31:16],carry_temp[0],Sum_ca[31:16],carry_temp[1]);
    BkAdder16 u3(A_ca[47:32],B_ca[47:32],carry_temp[1],Sum_ca[47:32],carry_temp[2]);


endmodule




//16 Bit BK adder Implementation


module BkAdder16(A_in,B_in,Carry_in,Sum_out,Carry_out);

    //Module port definitions
    input wire [15:0] A_in,B_in;
    input wire Carry_in;

    output wire [15:0]Sum_out;
    output wire Carry_out;

    //Intermediate wire connections
    wire [15:0] Prop,Gen;                   //Holds the Propogate and Generate signals from each stage
    wire[15:0] Carry_inter;                 //Holds the Carry_outs from each stage ie, Carry_inter[0]==> Carry_out of zeroth stage
    wire [14:0] Prop_inter;                 
    wire [14:0] Gen_inter;


    //Generation of P and G signals
    PgGenerationBlock instance1(A_in,B_in,Prop,Gen);   

    //Generation of Group Generate and Propogate signals
    //First level 
    GroupGPBlock instance1_0(Gen[1],Prop[1],Gen[0],Prop[0],Prop_inter[0],Gen_inter[0]); 
    GroupGPBlock instance3_2(Gen[3],Prop[3],Gen[2],Prop[2],Prop_inter[1],Gen_inter[1]);

    GroupGPBlock instance5_4(Gen[5],Prop[5],Gen[4],Prop[4],Prop_inter[2],Gen_inter[2]);
    GroupGPBlock instance7_6(Gen[7],Prop[7],Gen[6],Prop[6],Prop_inter[3],Gen_inter[3]);

    GroupGPBlock instance9_8(Gen[9],Prop[9],Gen[8],Prop[8],Prop_inter[4],Gen_inter[4]);
    GroupGPBlock instance11_10(Gen[11],Prop[11],Gen[10],Prop[10],Prop_inter[5],Gen_inter[5]);

    GroupGPBlock instance13_12(Gen[13],Prop[13],Gen[12],Prop[12],Prop_inter[6],Gen_inter[6]);
    GroupGPBlock instance15_14(Gen[15],Prop[15],Gen[14],Prop[14],Prop_inter[7],Gen_inter[7]);
    
    //Second level
    GroupGPBlock instance3_0(Gen_inter[1],Prop_inter[1],Gen_inter[0],Prop_inter[0],Prop_inter[8],Gen_inter[8]);
    GroupGPBlock instance7_4(Gen_inter[3],Prop_inter[3],Gen_inter[2],Prop_inter[2],Prop_inter[9],Gen_inter[9]);
    GroupGPBlock instance11_8(Gen_inter[5],Prop_inter[5],Gen_inter[4],Prop_inter[4],Prop_inter[10],Gen_inter[10]);
    GroupGPBlock instance15_12(Gen_inter[7],Prop_inter[7],Gen_inter[6],Prop_inter[6],Prop_inter[11],Gen_inter[11]);
    
    //Third level
    GroupGPBlock instance7_0(Gen_inter[9],Prop_inter[9],Gen_inter[8],Prop_inter[8],Prop_inter[12],Gen_inter[12]);
    GroupGPBlock instance15_8(Gen_inter[11],Prop_inter[11],Gen_inter[10],Prop_inter[10],Prop_inter[13],Gen_inter[13]);

    //Final level
    GroupGPBlock instance15_0(Gen_inter[13],Prop_inter[13],Gen_inter[12],Prop_inter[12],Prop_inter[14],Gen_inter[14]);

    //Carry generation from group propogate and generate terms
    assign Carry_inter[0]=Gen[0]|(Prop[0]&Carry_in);
    assign Carry_inter[1]=Gen_inter[0]|(Prop_inter[0]&Carry_in);
    assign Carry_inter[2]=Gen[2]|(Prop[2]&Carry_inter[1]);
    assign Carry_inter[3]=Gen_inter[8]|(Prop_inter[8]&Carry_in);
    assign Carry_inter[4]=Gen[4]|(Prop[4]&Carry_inter[3]);
    assign Carry_inter[5]=Gen[5]|(Prop[5]&Carry_inter[4]);
    assign Carry_inter[6]=Gen[6]|(Prop[6]&Carry_inter[5]);
    assign Carry_inter[7]=Gen_inter[12]|(Prop_inter[12]&Carry_in);
    assign Carry_inter[8]=Gen[8]|(Prop[8]&Carry_inter[7]);
    assign Carry_inter[9]=Gen[9]|(Prop[9]&Carry_inter[8]);
    assign Carry_inter[10]=Gen[10]|(Prop[10]&Carry_inter[9]);
    assign Carry_inter[11]=Gen[11]|(Prop[11]&Carry_inter[10]);
    assign Carry_inter[12]=Gen[12]|(Prop[12]&Carry_inter[11]);
    assign Carry_inter[13]=Gen[13]|(Prop[13]&Carry_inter[12]);
    assign Carry_inter[14]=Gen[14]|(Prop[14]&Carry_inter[13]);
    assign Carry_inter[15]=Gen_inter[14]|(Prop_inter[14]&Carry_in);

    //Carry Vector which holds the input carry to all stage 0 to 15
    wire [15:0] Carry_Vector={Carry_inter[14:0],Carry_in};

    //Final Carry Out 
    assign Carry_out = Carry_inter[15];

    //Generating Sum at each stage by xor ing the propogate with Carryin of each stage
    assign Sum_out = Prop ^ Carry_Vector;

endmodule

//Group generate and propogate creation block
module GroupGPBlock(Gen_H,Prop_H,Gen_L,Prop_L,G_Prop,G_Gen);

    input wire Gen_H,Gen_L,Prop_H,Prop_L;
    output wire G_Gen,G_Prop;
    assign G_Gen = Gen_H |(Prop_H&Gen_L);
    assign G_Prop = Prop_H&Prop_L;

endmodule


//Propogate and Generate creation block
module PgGenerationBlock(A,B,P,G);

    input wire [15:0] A,B;
    output [15:0] P,G;

    assign P = A^B;
    assign G = A&B;


endmodule

//23 bit data MUX

module Mux(a,b,sel,y);

    input [22:0] a;
    input [22:0] b;
    input sel;
    output [22:0] y;
    assign y = (sel==1'b0)?a:b;

endmodule

//8 bit data MUX

module Mux8bit(a,b,sel,y);

    input [7:0] a;
    input [7:0] b;
    input sel;
    output [7:0] y;
    assign y = (sel==1'b0)?a:b;

endmodule






