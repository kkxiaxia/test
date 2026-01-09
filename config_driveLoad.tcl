###############################################
##
## 脚本名字:    Driver_load.tcl
## 用处: 使用 driver load 脚本的 rule
## 脚本负责人:  夏康凯
## list中索引0是if_load，索引1是if_drive，1表示yes，0表示no
###############################################

dict set ::compare::driverLoad E0315 [dict create \
            rule_map_1 [lindex [dict get $::userCommon::rulemap E0315] 1] \
            ennoid_res [list 1 0]]

dict set ::compare::driverLoad E0320 [dict create \
            rule_map_1 [lindex [dict get $::userCommon::rulemap E0320] 1] \
            ennoid_res [list 0 1]]

dict set ::compare::driverLoad E0316 [dict create \
            rule_map_1 [lindex [dict get $::userCommon::rulemap E0316] 1] \
            ennoid_res [list 1 0]]

dict set ::compare::driverLoad E0318 [dict create \
            rule_map_1 [lindex [dict get $::userCommon::rulemap E0318] 1] \
            ennoid_res [list 0 1]]

dict set ::compare::driverLoad E0317 [dict create \
            rule_map_1 [lindex [dict get $::userCommon::rulemap E0317] 1] \
            ennoid_res [list 1 0]]

dict set ::compare::driverLoad E0321 [dict create \
            rule_map_1 [lindex [dict get $::userCommon::rulemap E0321] 1] \
            ennoid_res [list 0 0]]

dict set ::compare::driverLoad E0314 [dict create \
            rule_map_1 [lindex [dict get $::userCommon::rulemap E0314] 1] \
            ennoid_res [list 1 0]]

dict set ::compare::driverLoad E0319 [dict create \
            rule_map_1 [lindex [dict get $::userCommon::rulemap E0319] 1] \
            ennoid_res [list 0 1]]

# E0310只检测是否多驱，不检查load
# dict set ::compare::driverLoad E0310 [dict create \
#    rule_map_1 [lindex [dict get $::userCommon::rulemap E0310] 1] \
#    ennoid_res [list XXXX 1]]

# 检查net是否undriven
dict set ::compare::driverLoad E0331 [dict create \
            rule_map_1 [lindex [dict get $::userCommon::rulemap E0331] 1] \
            ennoid_res [list XXXX 0]]

# obj是instance，不是直接进行drive/load检查
dict set ::compare::driverLoad E0336 [dict create \
            rule_map_1 [lindex [dict get $::userCommon::rulemap E0336] 1] \
            ennoid_res [list XXXX XXXX]]

dict set ::compare::driverLoad E0309 [dict create \
            rule_map_1 [lindex [dict get $::userCommon::rulemap E0309] 1] \
            ennoid_res [list XXXX 1]]            
