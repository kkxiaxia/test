# test
test
yuh

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%: SelfDetermine--DTS2022051809258.v
//*******************************************************************************************
// Create Time   : 
//                 RULE=SelfDetermine,MODULE=TOP,WARNING-"There is self-determined expression (Expr:"rc_ctu_x_i < reg_ROI_x + reg_ROI_width") present in the design",line:31
//                 RULE=SelfDetermine,MODULE=TOP,WARNING-"There is self-determined expression (Expr:"rc_ctu_y_i + 1 > reg_ROI_y") present in the design",line:31
//                 RULE=SelfDetermine,MODULE=TOP,WARNING-"There is self-determined expression (Expr:"rc_ctu_y_i < reg_ROI_y + reg_ROI_height") present in the design",line:31
//               : RULE=SelfDetermine,MODULE=TOP,WARNING-"There is self-determined expression (Expr:"rc_ctu_x_i < reg_ROI_x + reg_ROI_width") present in the design" line:31
//               : RULE=SelfDetermine,MODULE=TOP,WARNING-"There is self-determined expression (Expr:"rc_ctu_y_i + 1 > reg_ROI_y") present in the design" line:31
//               : RULE=SelfDetermine,MODULE=TOP,WARNING-"There is self-determined expression (Expr:"rc_ctu_y_i < reg_ROI_y + reg_ROI_height") present in the design" line:31
//*******************************************************************************************

module TOP(
reg [3:0] cnt,
input [6:0] reg_ROI_y ,
input [5:0] reg_ROI_height ,
input [6 -1 :0] rc_ctu_x_i ,
input [6:0] reg_ROI_x ,
input [6:0] reg_ROI_width ,
input [6 -1 :0] rc_ctu_y_i ,
input in1,
output reg out1
);
always@(*)
begin
if((cnt =='d7) && (rc_ctu_x_i + 1 > reg_ROI_x) && (rc_ctu_x_i < reg_ROI_x + reg_ROI_width) && (rc_ctu_y_i + 1 > reg_ROI_y) && (rc_ctu_y_i < reg_ROI_y + reg_ROI_height))
out1 =in1;
end
endmodule
