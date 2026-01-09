# 将多维的多比特对象, 拆成单比特
proc expand_bits {signal} {
    if {[regexp {\{} $signal]} {
        set signal {*}$signal
    }
    if {[regexp {(\w+)((\[.*\])+)} $signal -> base indices]} {
        if {[regexp {((\[\d+:\d+\])+)} $signal]} {
            regexp {(.*?)((\[.*\])+)} $signal -> base
            set ranges [regexp -inline -all {\[.*?\]} $indices]
            set index_ranges {}
            foreach range $ranges {
                if {[regexp {\[(\d+):(\d+)\]} $range -> hi lo]} {
                    if {$hi > $lo} {
                        lappend index_ranges [list $hi $lo]
                    } else {
                        lappend index_ranges [list $lo $hi]
                    }
                } else {
                    if {[regexp {\[(\d+)\]} $range -> hi]} {
                        lappend index_ranges [list $hi $hi]
                    }
                }
            }
            set index_ranges_num [llength $index_ranges]
            set base_list [list $base]
            foreach index_range $index_ranges {
                set result {}
                foreach base $base_list {
                    set result [concat $result [do_expand_bits $index_range $base]]
                }
                set base_list $result
            }
            return $result
        }
    }
    return $signal
}
# 处理obj(包含多比特场景)
proc handle_obj {obj} {
    set final_obj_list {}
    foreach tmp_obj ${obj} {
        set tmp_obj [string trim ${tmp_obj} "{}"]
        set obj_lst [split ${tmp_obj} "."]
        set obj_map [dict create]
        foreach tmp $obj_lst {
            set new_tmp [expand_bits $tmp]
            dict set obj_map ${tmp} ${new_tmp}
        }
        set len [llength [dict values $obj_map]]
        set value [dict values $obj_map]
        set i 1
        set tmp_value [lindex ${value} 0]
        while {$i < $len} {
            set dd {}
            foreach tmp1 [lindex $value $i] {
                foreach tmp2 ${tmp_value} {
                    set cc "$tmp2.$tmp1"
                    lappend dd $cc
                }
            }
            set tmp_value $dd
            incr i
        }
        lappend final_obj_list ${tmp_value}
    }
    return $final_obj_list
}
# 检查obj type: pin, port, net
proc check_obj_type {signal} {
    if {[get_pins ${signal}] != ""} {
        set get_cmd "get_pins"
    } elseif {[get_ports ${signal}] != ""} {
        set get_cmd "get_ports"
    } elseif {[get_nets ${signal}] != ""} {
        set get_cmd "get_nets"
    } else {
        set get_cmd ""
    }
    if {$::compare::ennoid eq "E0320"} {
        set get_cmd "get_nets"
    } elseif {$::compare::ennoid eq "E0321"} {
        if {[get_nets ${signal}] != ""} {
            set get_cmd "get_nets"
        } else {
            set get_cmd "get_pins"
        }
    }
    return $get_cmd
}
proc is_enno_obj {obj} {
    if {[get_pins ${obj}] == "" && [get_ports ${obj}] == "" && [get_nets ${obj}] == ""} {
        return 0
    } else {
        return 1
    }
}
# 判断是否被load
proc check_loaded {signal} {
    set get_cmd [check_obj_type $signal]
    if {$get_cmd != "" && [$get_cmd $signal] != ""} {
        set net [$get_cmd $signal]
        if {$::compare::ennoid eq "E0316" || $::compare::ennoid eq "E0319"} {
            set load_lst_1 [get_fanout -from ${net} -tcl_list]
            set load_lst_2 [get_fanout -from ${net} -leaf -tcl_list]
            if {${load_lst_2} ne ""} {
                return 1
            } elseif {${load_lst_1} ne ""} {
                foreach tmp_obj $load_lst_1 {
                    if {[check_if_TOP ${tmp_obj}] && [check_dir ${tmp_obj}] == "out"} {
                        return 1
                }
            }
                return 0
            } else {
                return 0
            }
        } elseif {$::compare::ennoid eq "E0314"} {
            set load_lst_1 [get_fanout -from ${net} -tcl_list]
            set load_lst_2 [get_fanout -from ${net} -leaf -tcl_list]
            if {${load_lst_2} ne ""} {
                return 1
            } elseif {${load_lst_1} ne ""} {
                foreach tmp_obj $load_lst_1 {
                    if {[check_if_TOP ${tmp_obj}] && [check_dir ${tmp_obj}] == "in"} {
                        return 1
                    }
                }
                return 0
            } else {
                return 0
            }
        } elseif {$::compare::ennoid eq "E0318"} {
            set load_lst_1 [get_fanout -from ${net} -tcl_list]
            set load_lst_2 [get_fanout -from ${net} -leaf -tcl_list]
            if {${load_lst_2} eq ""} {
                return 0
            } elseif {${load_lst_1} ne ""} {
                foreach tmp_obj $load_lst_1 {
                    set inst [get_instances ${tmp_obj}]
                    if {[get_attributes ${inst} -attribute is_leaf] == 1 && [get_attributes ${inst} -attribute view] != "VERIFIC_BUF"} {
                        return 1
                    } elseif {[check_if_TOP ${tmp_obj}] == 1} {
                        return 1
                    }
                }
                return 0
            } else {
                return 1
            }
        } elseif {$::compare::ennoid eq "E0321"} {
            set load_lst_1 [get_fanout -from ${net} -tcl_list]
            set load_lst_2_1 [get_fanout -from ${net} -tcl_list -leaf]
            set load_lst_2_2 [lsort -uniq [get_attributes [get_fanout -from ${net} -tcl_list -leaf ] -attributes view]]
            if {$load_lst_1 eq ""} {
                return 0
            } elseif {$load_lst_2_1 eq ""} {
                return 0
            } elseif {$load_lst_2_2 eq "VERIFIC_BUF"} {
                return 0
            } else {
                return 1
            }
        } elseif {$::compare::ennoid eq "E0320"} {
            set load_lst [lsort [get_instances [get_fanout -from ${net} -tcl_list]]]
            set self_inst [lindex [get_fanin -to ${net} -tcl_list -depth 1] 1]
            set attr [get_attributes ${self_inst} -attribute view]
            if {${attr} == "VERIFIC_DFFRS"} {
                set in_inst [get_instances [get_nets ${net}]]
                foreach inst ${in_inst} {
                    if {[get_attributes [get_instances ${inst}] -attribute view] == "VERIFIC_DFFRS"} {
                        continue
                    }
                    set out_lst [get_fanout -from ${inst} -tcl_list -stop ${self_inst}]
                    if {[llength ${out_lst}] == 0} {
                        return 1
                    } else {
                        set owner_list {}
                        set self_owner [get_attributes ${self_inst} -attribute owner]
                        foreach tmp [get_instances ${out_lst}] {
                            set owner [get_attributes ${tmp} -attribute owner]
                            if {${self_owner} != ${owner}} {
                                return 1
                            }
                        }
                        return 0
                    }
                }
            } else {
                set load_lst [get_fanout -from ${net} -tcl_list]
                if {$load_lst ne ""} {
                    return 1
                } else {
                    return 0
                }
            }
        } else {
            set load_lst [get_fanout -from ${net} -tcl_list]
            if {$load_lst ne ""} {
                return 1
            } else {
                return 0
            }
        }
    } else {
        # puts "$signal is not a net !!!"
        return
    }
}
proc check_14_15_16_drive {incone gate_inst} {
    # 1. 有效driver-1: 非buffer的原语门的输出output(与或非门, latch, FF, 加法器)
    set inst_cone [get_instances ${incone}]
    if {${inst_cone} != ""} {
        foreach tmp_inst ${inst_cone} {
            set view [get_attributes ${tmp_inst} -attribute view]
            if {[lsearch -exact ${gate_inst} ${view}] != -1} {
                # fanincone中只要有一个instance是gate_inst其中之一, 就是有有效driver
                return 1
            }
        }
    }
    # 2. 有效driver-2: 顶层module的input端口
    set portcone [get_ports ${incone}]
    set top_name [get_top]
    if {${portcone} != ""} {
        foreach tmp_port ${portcone} {
            set direction [get_attributes ${tmp_port} -attribute dir]
            set owner [get_attributes ${tmp_port} -attribute owner]
            if {${direction} == "in" && ${owner} == ${top_name}} {
                # 方向为in, 且owner是TOP module
                return 1
            }
        }
    }
    # 3. 有效driver-3: 黑盒或灰盒的output
    set pincone [get_pins ${incone}]
    if {${pincone} != ""} {
        foreach tmp_pin ${pincone} {
            set direction [get_attributes ${tmp_pin} -attribute dir]
            if {${direction} == "out"} {
                set if_blackbox [get_instances ${tmp_pin} -filter {@is_black_box == "1"}]
                # set if_greybox [get_instances ${tmp_pin} -filter {@is_grey_box == "1"}]
                if {${if_blackbox} != ""} {
                    return 1
                }
            }
        }
    }
    # 以上都不满足, 则表示没有有效driver
    return 0
}
# 判断是否被drive
proc check_drived {signal {option ""} tmp_debug_info} {
    upvar 1 ${tmp_debug_info} new_tmp_debug_info
    if {$::compare::ennoid eq "E0315"} {
        set get_cmd "get_nets"
    } else {
        set get_cmd [check_obj_type $signal]
    }
    if {${get_cmd} != "" && [$get_cmd ${signal}] != ""} {
        if {$::compare::ennoid eq "E0317"} {
            if {[get_fanin -to [$get_cmd ${signal}] -leaf -tcl_list] eq ""} {
                return 0
            } else {
                return 1
            }
        } elseif {$::compare::ennoid eq "E0316"} {
            if {$option ne ""} {
                set drive_lst_1 [get_fanin -to [$get_cmd $signal] -tcl_list $option ]
            } else {
                set drive_lst_1 [get_fanin -to [$get_cmd $signal] -tcl_list ]
            }
            set drive_lst_2 [lsort -uniq [get_attributes [get_fanin -to [$get_cmd $signal] -tcl_list -leaf ] -attributes view]]
            if {$drive_lst_1 eq "" || $drive_lst_2 == "VERIFIC_BUF"} {
                return 0
            } else {
                return 1
            }
        } elseif {$::compare::ennoid eq "E0314"} {
            # input-pin undriven but loaded
            set gate_inst {"VERIFIC_AND" "VERIFIC_NAND" "VERIFIC_NOR" "VERIFIC_OR" "VERIFIC_XOR" "VERIFIC_XNOR" \
                          "VERIFIC_NOT" "VERIFIC_MUX" "VERIFIC_TRANIF1" "VERIFIC_RTRANIF1" "VERIFIC_TRANIF0" "VERIFIC_RTRANIF0" \
                          "VERIFIC_DFFRS" "VERIFIC_DLATCHRS" "VERIFIC_PMOS"}
            set pin [get_pins ${signal}]
            if {$pin == ""} {
                return 0
            }
            set incone [get_fanin -to ${pin} -tcl_list]
            if {${incone} == ""} {
                # fanin为空, 直接是undriven
                return 0
            }
            set drive_res [check_14_15_16_drive ${incone} ${gate_inst}]
            if {${drive_res} eq 1} {
                lappend new_tmp_debug_info "has_driver"
            }
            return ${drive_res}
        } elseif {$::compare::ennoid eq "E0315"} {
            # TO DO
            set drive_res [check_14_15_16_drive ${incone} ${gate_inst}]
            red drive_res:: ${drive_res}
        } elseif {$::compare::ennoid eq "E0318"} {
            if {$option ne ""} {
                set drive_lst_1 [get_fanin -to [$get_cmd $signal] -tcl_list $option ]
            } else {
                set drive_lst_1 [get_fanin -to [$get_cmd $signal] -tcl_list]
            }
            set drive_lst_2 [lsort -uniq [get_attributes [get_fanin -to [$get_cmd $signal] -tcl_list -leaf ] -attributes view]]
            if {$drive_lst_1 ne "" || $drive_lst_2 != "VERIFIC_BUF"} {
                return 1
            } else {
                return 0
            }
        } elseif {$::compare::ennoid eq "E0321"} {
            set drive_lst_1 [get_fanin -to [$get_cmd $signal] -tcl_list]
            set drive_lst_2 [lsort -uniq [get_attributes [get_fanin -to [$get_cmd $signal] -tcl_list -leaf ] -attributes view]]
            if {$drive_lst_1 eq ""} {
                return 0
            } elseif {$drive_lst_2 != "VERIFIC_BUF"} {
                return 0
            } else {
                return 1
            }
        } elseif {$::compare::ennoid eq "E0331"} {
            set obj [eval [list $get_cmd $signal]]
            set fanin_cone [get_fanin -to ${obj} -pin_list]
            set drive_res {}
            foreach tmp ${fanin_cone} {
                set inst [get_instances ${tmp}]
                if {${inst} == ""} {
                    # 不是instance
                    return 0
                } else {
                    set if_leaf [get_attributes ${inst} -attribute is_leaf]
                    set inst_type [get_attributes ${inst} -attribute view]
                    # undriven 的两种场景: 
                    # 1. 如果是leaf 且不是 VERIFIC_BUF
                    if {${if_leaf} == 1 && ${inst_type} != "VERIFIC_BUF"} {
                        return 1
                    }
                    set owner [get_attributes ${inst} -attribute owner]            
                    # 2. owner 是 TOP
                    if {${owner} == [get_top]} {
                        return 1
                    }
                }
            }
            return 0
        } else {
            set obj [eval [list $get_cmd $signal]]
            if {${obj} != ""} {
                if {[get_fanin -to ${obj} -tcl_list] eq ""} {
                    return 0
                } else {
                    return 1
                }
            } else {
                return 0
            }
        }
    } else {
        return
    }
}
# 获取pin/port 的方向
proc check_dir {obj} {
    # TOP层级用get_ports, instance层级用get_pins
    if {[check_if_TOP $obj]} {
        set cmd "get_ports"
    } else {
        set cmd "get_pins"
    }
    set pin [${cmd} ${obj}]
    if {${pin} != ""} {
        if {[get_attributes [get_pins ${obj}] -attributes dir] != ""} {
            return [lsort -uniq [get_attributes [$cmd ${obj}] -attributes dir]]
        } elseif {[get_attributes [get_ports ${obj}] -attributes dir] != ""} {
            return [lsort -uniq [get_attributes [$cmd ${obj}] -attributes dir]]
        }
    }
}
# 判断 obj 是否TOP层级
proc check_if_TOP {obj} {
    foreach tmp_obj $obj {
        if {[llength [split $tmp_obj "/"]] > 2} {
            return 0
        }
    }
    return 1
}
proc check_E0310 {obj new_debug_info} {
    upvar 1 $new_debug_info tmp_debug_info
    set not_drive_lst {}
    if {[get_nets ${obj}] == ""} {
        return
    }
    set drive_lst [get_fanin -to [get_nets ${obj}] -depth 1 -leaf]
    for {set index 0} {$index < [llength ${drive_lst}]} {incr index} {
        set inst [lindex ${drive_lst} ${index}]
        set if_bbox [get_attributes ${inst} -attributes is_black_box]
        set if_three_state_gate [get_attributes ${inst} -attributes view]
        # 如果是黑盒或三态门, 获取索引
        if {${if_bbox} == 1 || ${if_three_state_gate} == "VERIFIC_TRI" || ${if_three_state_gate} == "VERIFIC_BUFIF"} {
            lappend not_drive_lst ${index}
        }
    }
    # 从drive_lst删除黑盒和三态门
    foreach idx [lsort -decreasing -integer -unique $not_drive_lst] {
        set drive_lst [lreplace $drive_lst $idx $idx]
    }
    # 判断driver长度是否大于2
    if {[llength ${drive_lst}] > 2} {
        set if_multi_drive 1
        return ${if_multi_drive}
    } else {
        set if_multi_drive 0
        return ${if_multi_drive}
    }
}
proc check_E0331 {net inst new_debug_info} {
    upvar 1 $new_debug_info tmp_debug_info
    # 1. 检查undriven
    set if_drive [check_drived ${net} "" tmp_debug_info]
    # 2. 如果是undriven, 那么检查instance是否在net的fanout中
    set net [get_nets ${net}]
    if {!${if_drive} && ${net} != ""} {
        set fanout_cone [get_fanout -from ${net} -tcl_list]
        if {[lsearch -exact ${fanout_cone} ${inst}] != -1} {
            return 1
        } else {
            return 0
        }
    } else {
        return 0
    }
}
proc check_E0336 {inst new_debug_info} {
    upvar 1 $new_debug_info tmp_debug_info
    set instance [get_instances ${inst}]
    if {${instance} != "" } {
        set pin_lst [get_pins ${instance}]
        # 1. 获取该instance所有pin, 如果为空, 则符合该E0336, 直接返回1
        if {${pin_lst} == ""} {
            return 1
        } else {
            # 2. 如果pin不为空, 对pin进行分类处理: input的pin 使用get_fanin判断是否为空, output的pin判断get_fanout是否为, 如果全部都为空, 则符合E0336；否则, 不满足E0336
            # inout 需要特殊判断: 获取该pin的net, 然后获取该net的所有pin, 判断该net除了这个pin是否还有其他的pin, 如果没有则符合E0336, 否则不符合
            set tmp_res {}
            foreach pin ${pin_lst} {
                set dir [get_attributes ${pin} -attribute dir]
                set tmp {}
                if {${dir} == "in"} {
                    set tmp [get_fanin -to ${pin} -pin_list -startpoints_only]
                } elseif {${dir} == "out"} {
                    set tmp [get_fanout -from ${pin} -pin_list -endpoints_only]
                } else {
                    # inout
                    set net [get_nets ${pin}]
                    # 去除最外层的{}
                    set tmp_pin [string trim [get_pins ${net}] "{}"]
                    if {${pin} != ${tmp_pin}} {
                        return 0
                    }
                }
                if {[llength ${tmp}] != 0 } {
                    return 0
                }
            }
            return 1
        }
    } else {
        # instance 不正确, get_instances 找不到
        return 0
    }
}
# return 1表示满足E0333, return 0表示不满足  
proc check_E0333 {obj line new_debug_info} {  
    upvar 1 $new_debug_info tmp_debug_info  
    set net [get_nets ${obj}]  
    if {${net} != ""} {  
        # 1. 获取所有instance  
        set instance_lst [get_instances ${net}]  
        # 2. 根据行号获取具体的instance  
        set inst {}  
        foreach tmp_inst ${instance_lst} {  
            set file_line [get_attributes ${tmp_inst} -attribute file_name]  
            regexp {.*\((.*)\)} $file_line -> tmp_line  
            if {${line} == ${tmp_line}} {  
                set inst ${tmp_inst}  
                break  
            }  
        }  
        if {${inst} != {}} {  
            # 3. 判断是否module instance drive  
            set if_leaf [get_instances ${inst} -filter {@is_leaf == "0"}]  
            if {${if_leaf} != ""} {  
                # 4. 是module instance drive, 遍历该instance的所有output端口, 只要存在一个output没有load, 就符合E0333；所有output都有load, 才不符合E0333  
                set pin_lst [get_pins ${inst} -filter {@dir == "out"}]  
                if {${pin_lst} != ""} {
                    foreach tmp_pin ${pin_lst} {  
                        set tmp_res [get_fanout -from ${tmp_pin} -pin_list -endpoints_only]  
                        if {${tmp_res} == "" || ${tmp_res} != ${tmp_pin}} {  
                            return 1  
                        }  
                    }  
                }  
            return 0  
        } else {  
            return 0  
        }  
    }  
    } else {  
        # net在工具中不存在  
        return 0  
    }
}
proc check_E0309_mult {obj} {
    set not_drive_lst {}
    set net [get_nets ${obj}]
    if {${net} == ""} {
        return
    }
    set drive_lst [get_fanin -to [get_nets ${obj}] -tcl_list]
    for {set index 0} {$index < [llength ${drive_lst}]} {incr index} {
        set inst [lindex ${drive_lst} ${index}]
        set if_bbox [get_attributes ${inst} -attributes is_black_box]
        set if_three_state_gate [get_attributes ${inst} -attributes view]
        # 如果是黑盒或三态门, 获取索引
        if {${if_bbox} == 1 || ${if_three_state_gate} == "VERIFIC_TRI" || ${if_three_state_gate} == "VERIFIC_BUFIF"} {
            lappend not_drive_lst ${index}
        }
    }
    # 从drive_lst删除黑盒和三态门
    foreach idx [lsort -decreasing -integer -unique $not_drive_lst] {
        set drive_lst [lreplace $drive_lst $idx $idx]
    }
    # 判断driver长度是否大于等于2
    if {[llength ${drive_lst}] >= 2} {
        set if_multi_drive 1
        return ${if_multi_drive}
    } else {
        set if_multi_drive 0
        return ${if_multi_drive}
    }
}
proc check_E0309 {net new_debug_info} {
    upvar 1 $new_debug_info tmp_debug_info
    set net [get_nets ${net}]
    # 1. 判断对象是否存在
    if {${net} != ""} {
        # 2. 判断是否 inout
        set dir [get_attributes [get_ports ${net}] -attributes dir]
        if {[llength ${dir}] > 1} {
            set dir [lsort -uniq $dir]
        }
        if {$dir == "inout"} {
            # 3. 判断是否多个driver
            set driver_lst [check_E0309_mult ${net}]
            if {${driver_lst}} {
                # 满足E0309
                return 1
            } else {
                return 0
            }
        } else {
            # 不是inout类型
            return 0
        }
    } else {
        # net不存在
        return 0
    }
}
proc chekc_E0320_load_self {net E0320_inst_list} {
    # 3.1 是FLop, 且net没有分岔, 且Q端最终回到自己的D端, 报E0320
    set self_inst_list [get_instances ${net}]
    set self_inst [lindex [get_fanin -to ${net} -tcl_list -depth 1] 1]
    set all_inst [get_instances [get_nets ${net}]]
    set all_inst [lrange ${all_inst} 1 end]
    while {[llength ${all_inst}] == 1} {
        set nextInst [lindex $all_inst 0];
        set inst_attr [get_attributes [get_instances $nextInst] -attribute view]
        if {${nextInst} == ${self_inst}} {
            return 1
        } elseif {[lsearch -exact ${E0320_inst_list} ${inst_attr}] == -1} {
            return 0
        }
        set all_inst [get_instances [get_fanout -from [get_instances $nextInst] -tcl_list -depth 1]]
        if {[llength ${all_inst}] >= 2} {
            set all_inst [lindex $all_inst 1]
        }
        # set all_inse "[get_instances ${all_inst}]"
    }
    return 0
}
# The net is Unloaded but driven
proc check_E0320 {net new_debug_info} {
    upvar 1 $new_debug_info tmp_debug_info
    set net [get_nets ${net}]
    set self_inst [lindex [get_fanin -to ${net} -tcl_list -depth 1] 1]
    set self_inst_attr [get_attributes ${self_inst} -attribute view]
    set inst_list {"VERIFIC_PWR" "VERIFIC_GND" "VERIFIC_X" "VERIFIC_Z" "VERIFIC_INV" \
                   "VERIFIC_BUF" "VERIFIC_AND" "VERIFIC_NAND" "VERIFIC_OR" "VERIFIC_NOR" "VERIFIC_XOR" \
                   "VERIFIC_MUX" "VERIFIC_PULLUP" "VERIFIC_PULLDOWN" "VERIFIC_TRI" "VERIFIC_BUFIF1" "VERIFIC_DLATCH" \
                   "VERIFIC_DLATCHRS" "VERIFIC_DFF" "VERIFIC_DFFRS" "VERIFIC_NMOS" "VERIFIC_PMOS" "VERIFIC_CMOS" \
                   "VERIFIC_TRAN" "VERIFIC_FADD" "VERIFIC_RCMOS" "VERIFIC_RNMOS" "VERIFIC_RPMOS" "VERIFIC_RTRAN"}
    set E0320_inst_list {"VERIFIC_AND" "VERIFIC_NAND" "VERIFIC_NOR" "VERIFIC_OR" "VERIFIC_XOR" "VERIFIC_XNOR" \
                         "VERIFIC_BUF" "VERIFIC_NOT" "VERIFIC_MUX" "VERIFIC_TRANIF1" "VERIFIC_RTRANIF1" "VERIFIC_TRANIF0" "VERIFIC_RTRANIF0" \
                         "VERIFIC_PMOS"}
    set seq_inst {"VERIFIC_DFFRS" "VERIFIC_DLATCHRS"}
    # 1. 只要不是gate(AND/OR/MUX), FF, LATCH 将不检查E0320, 直接return 0
    set if_comb [get_attributes ${self_inst} -attribute is_comb]
    if {$if_comb != 1 && [lsearch -exact ${inst_list} ${self_inst_attr}] == -1} {
        return 0
    }
    # 2. 只要没有任何load(fanout为空), 报E0320
    set out_cone [get_fanout -from ${net} -tcl_list]
    if {[llength ${out_cone}] == 0} {
        return 1
    }
    if {${self_inst_attr} == "VERIFIC_DFFRS"} {
        # net是单比特
        if {[llength ${net}] == 1} {
            set res [chekc_E0320_load_self $net $E0320_inst_list]
            return $res
        } else {
            # net 是多比特
            foreach tmp_net ${net} {
                set res [chekc_E0320_load_self $tmp_net $E0320_inst_list]
                if {${res} == 0} {
                    return 0
                }
            }
            return 1
        }
    }
    return 0
}
proc check_E0321 {obj new_debug_info} {
    upvar 1 $new_debug_info tmp_debug_info
    set findObj ""
    if {[get_nets ${obj}] != ""} {
        set findObj [get_nets ${obj}]
    } elseif {[get_pins ${obj}] != ""} {
        set findObj [get_pins ${obj}]
    } elseif {[get_ports ${obj}] != ""} {
        set findObj [get_ports ${obj}]
    }
    if {${findObj} == ""} {
        return 0
    }
    set in_cone [get_fanin -to ${findObj} -tcl_list]
    set out_cone [get_fanout -from ${findObj} -tcl_list]
    set top_module [get_top]
    # unload 点
    if {[llength ${in_cone}] != 0 && [llength ${out_cone}] == 0} {
        foreach tmp ${in_cone} {
            # 3.1 只要含有顶层的port, 不报E0321
            set port [get_ports ${tmp}]
            if {${port} != ""} {
                set owner [lsort -unique [get_attributes ${port} -attribute owner]]
                #
                if {${owner} == ${top_module}} {
                    return 0
                }
            }
        # 3.2 除了Buffer和module实例化的instance之外, 都是不报的
        set tmp_inst [get_instances ${tmp}]
        if {${tmp_inst} != ""} {
            set tmp_attr [lsort -unique [get_attributes ${tmp_inst} -attribute view]]
            set module_instance [get_modules ${tmp_inst}]
            if {${tmp_attr} != "VERIFIC_BUF" && ${module_instance} == ""} {
                return 0
            }
        }
    }
    return 1
    # # undriven 点
    } elseif {[llength ${in_cone}] == 0 && [llength ${out_cone}] != 0} {
        foreach tmp ${out_cone} {
            # 3.1 只要含有顶层的port, 不报E0321
            set port [get_ports ${tmp}]
            if {${port} != ""} {
                set owner [get_attributes ${port} -attribute owner]
                #
                if {${owner} == ${top_module}} {
                    return 0
                }
            }
        # 3.2 除了Buffer和module实例化的instance之外, 都是不报的
        set tmp_inst [get_instances ${tmp}]
        if {${tmp_inst} != ""} {
            set tmp_attr [get_attributes ${tmp_inst} -attribute view]
            set module_instance [get_modules ${tmp_inst}]
            if {${tmp_attr} != "VERIFIC_BUF" && ${module_instance} == ""} {
                return 0
            }
        }
    }
    return 1
    }
    return 0
}
proc check_E0317 {obj if_load if_drive new_debug_info} {
    upvar 1 $new_debug_info tmp_debug_info
    set in_pin [lindex $obj 0]
    set out_pin [lindex $obj 1]
    set in_dir [lsort -unique [get_attributes [get_pins $in_pin] -attributes dir]]
    set out_dir [lsort -unique [get_attributes [get_pins $out_pin] -attributes dir]]
    # 判断两个pin的方向
    if {$in_dir == "in" && $out_dir == "out"} {
        # 检查是否loaded/driven
        if {[check_loaded $out_pin] == $if_load && [check_drived $out_pin "" tmp_debug_info] == $if_drive} {
            return 1
        }
    }
    return 0
}
proc check_E0316 {obj if_load if_drive new_debug_info} {
    upvar 1 $new_debug_info tmp_debug_info
    set if_TOP [check_if_TOP ${obj}]
    # 1. TOP层的 output port, 判断被 drive
    if {${if_TOP} && [check_drived ${obj} "-leaf" tmp_debug_info] == $if_drive} {
        return 1
        # 2. 非TOP层的 output port, get_fanin -leaf 判断没有被 drive, get_fanout 判断被 load
    } elseif {${if_TOP} eq 0 && [check_drived ${obj} "-leaf" tmp_debug_info] == $if_drive && [check_loaded ${obj}] == $if_load} {
        return 1
    }
    return 0
}
proc check_E0314 {obj if_load if_drive new_debug_info} {
    upvar 1 $new_debug_info tmp_debug_info
    # 首先判断方向
    set direction [check_dir ${obj}]
    set pin [get_pins ${obj}]
    if {${pin} == ""} {
        lappend tmp_debug_info "is_not_pin"
    }
    if {${direction} ni {"in" "inout"}} {
        lappend tmp_debug_info "dir_not_in_or_inout: \"${direction}\""
    }
    if {${pin} != ""} {
        if {[llength [get_fanin -to $pin -pin_list]] != 1} {
            # 不是最源头的点, 不进行driveload检查
            lappend tmp_debug_info {not_source}
            return 0
        }
    }
    set if_TOP [check_if_TOP ${obj}]
    # 1. TOP层的 input, 判断被 drive
    if {${if_TOP} && [check_loaded ${obj} "-leaf"] == $if_load} {
        return 1
    # 2. 非TOP层的 input, get_fanin-leaf 判断没有被 drive, get_fanout 判断被 load
    } elseif {${if_TOP} eq 0 && [check_drived ${obj} "-leaf" tmp_debug_info] == $if_drive && [check_loaded ${obj}] == $if_load} {
        return 1
    }
    return 0
}
proc check_E0319 {obj if_load if_drive new_debug_info} {
    upvar 1 $new_debug_info tmp_debug_info
    if {[get_pins ${obj}] == ""} {
        return 0
    }
    # 首先判断方向
    if {[check_dir ${obj}] != "out"} {
        return 0
    }
    set drive_lst_1 [check_drived ${obj} "-leaf" tmp_debug_info]
    set drive_lst_2 [check_drived ${obj} "" tmp_debug_info]
    set load_lst_1 [check_loaded ${obj}]
    if {${drive_lst_1} == ${if_drive} || ${drive_lst_2} == ${if_drive} && ${load_lst_1} == ${if_load}} {
        return 1
    }
}
proc check_E0318 {obj if_load if_drive new_debug_info} {
    upvar 1 $new_debug_info tmp_debug_info
    set if_TOP [check_if_TOP ${obj}]
    # 1. TOP层的 input port, 判断是否被 load  
    if {${if_TOP} && [check_loaded ${obj}] == $if_load} {  
        return 1  
    # 2. 非TOP层的 input port, get_fanin -leaf 判断被 driven, get_fanout 判断没有被 load  
    } elseif {${if_TOP} eq 0 && [check_drived ${obj} "-leaf" tmp_debug_info] == $if_drive && [check_loaded ${obj}] == $if_load} {  
        return 1  
    }  
}
# return 1 表示符合rule, 0 表示不符合rule  
proc check_res {fail_msg if_load if_drive debug_info} {  
    upvar 1 $debug_info new_debug_info  
    set obj [lindex $fail_msg 9]  
    # 处理误报  
    if {[lindex ${fail_msg} 0] == "E"} {  
        set obj [handle_obj ${obj}]  
        if {$::compare::ennoid eq "E0317"} {  
            return [check_E0317 ${obj} ${if_load} ${if_drive} new_debug_info]  
        } elseif {$::compare::ennoid eq "E0316"} {  
            return [check_E0316 ${obj} ${if_load} ${if_drive} new_debug_info]  
        } elseif {$::compare::ennoid eq "E0314"} {  
            set res [check_E0314 ${obj} ${if_load} ${if_drive} new_debug_info]  
            return ${res}  
        } elseif {$::compare::ennoid eq "E0319"} {  
            return [check_E0319 ${obj} ${if_load} ${if_drive} new_debug_info]  
        } elseif {$::compare::ennoid eq "E0318"} {  
            return [check_E0318 ${obj} ${if_load} ${if_drive} new_debug_info]  
        } elseif {$::compare::ennoid eq "E0331"} {  
            set net [lindex ${obj} 0]  
            set inst [lindex ${obj} 1]  
            # 判断条件: 1. net 是undriven的, inst在net的fanout里面  
            if {[check_E0331 ${net} ${inst} new_debug_info]} {  
                return 1  
            }
            return 0
        } elseif {$::compare::ennoid eq "E0310"} {
            if {[check_E0310 ${obj} new_debug_info]} {
                return 1
            }
        } elseif {$::compare::ennoid eq "E0336"} {
            if {[check_E0336 ${obj} new_debug_info]} {
                return 1
            }
        } elseif {$::compare::ennoid eq "E0333"} {
            set line [lindex ${fail_msg} 4]
            if {[check_E0333 ${obj} ${line} new_debug_info]} {
                return 1
            }
        } elseif {$::compare::ennoid eq "E0309"} {
            if {[check_E0309 ${obj} new_debug_info]} {
                return 1
            } else {
                return 0
            }
        } elseif {$::compare::ennoid eq "E0320"} {
            #
            return [check_E0320 $obj new_debug_info]
        } elseif {$::compare::ennoid eq "E0321"} {
            return [check_E0321 $obj new_debug_info]
        } else {
            # 除E0317,E0316,E0318之外的rule
            if {[check_loaded $obj] == $if_load && [check_drived $obj ""] == $if_drive} {
                return 1
            }
        }
    } else {
    # 处理漏报
        set obj [__s_to_e_obj ${obj}]
        # 如果转换格式后sg的obj在elint中不是真实的object, 视为sg错误, 该msg pass
        if {[is_enno_obj ${obj}] == 0} {
            return 1
        }
    if {$::compare::ennoid eq "E0316"} {
        set if_TOP [check_if_TOP ${obj}]
        # 1. TOP层的 output port, 判断被 drive
        if {${if_TOP} && [check_drived ${obj} "" tmp_debug_info] != $if_drive} {
            return 1
        # 2. 非TOP层的 output port, get_fanin -leaf 判断没有被 drive, get_fanout 判断被 load
        } elseif {${if_TOP} eq 0 && [check_drived ${obj} "-leaf" tmp_debug_info] != $if_drive || [check_loaded ${obj}] != $if_load} {
            return 1
        }
    } elseif {$::compare::ennoid eq "E0318"} {
        set if_TOP [check_if_TOP ${obj}]
        # 1. TOP层的 input port, 判断是否被 load
        if {${if_TOP} && [check_loaded ${obj}] != $if_load} {
            return 1
        # 2. 非TOP层的 input port, get_fanin -leaf 判断被 driven, get_fanout 判断没有被 load
        } elseif {${if_TOP} eq 0 && [check_drived ${obj} "-leaf" tmp_debug_info] != $if_drive || [check_loaded ${obj}] != $if_load} {
            return 1
        }
    } elseif {$::compare::ennoid eq "E0317"} {
        set in_pin [lindex $obj 0]
        set out_pin [lindex $obj 1]
        set in_dir [get_attributes [get_pins $in_pin] -attributes dir]
        set out_dir [get_attributes [get_pins $out_pin] -attributes dir]
        # 如果sg的obj方向不正确, 视为sg是误报, enno正确
        if {$in_dir != "in" || $out_dir == "out"} {
            return 1
        } else {
            # pin方向正确, 但是load-drive不符合
            if {[check_loaded $out_pin] != $if_load && [check_drived $out_pin "" tmp_debug_info] != $if_drive} {
                return 1
            }
        }
    } elseif {$::compare::ennoid eq "E0310"} {
        set res [check_E0310 ${obj} new_debug_info]
        # 场景1: 如果get不到sg报的obj 则视为sg报的是错的, 添加到match中
        # 场景2: 如果sg的obj不满足E310的规则, 添加到match中
        if {${res} == {} || ${res} == 0} {
            return 1
        }
    } elseif {$::compare::ennoid eq "E0309"} {
        set new_obj {}
        set obj [__s_to_e_obj ${obj}]
        foreach tmp_obj ${obj} {
            set tmp_obj "[get_top]/${tmp_obj}"
            lappend new_obj ${tmp_obj}
        }
        if {[check_E0309 ${new_obj} new_debug_info]} {
            return 1
        }
    } elseif {$::compare::ennoid eq "E0321"} {
        set net [__s_to_e_obj ${obj}]
        set res [check_E0321 $net new_debug_info]
        if {${res} eq 1} {
            return 0
        } else {
            return 1
        }
    } elseif {$::compare::ennoid eq "E0319"} {
        set obj [__s_to_e_obj [lindex ${obj} 0]]
        # 黑盒的漏报暂时不处理: 待RD的结论: 是否所有黑盒标签都视为有效driver
        if {[get_attributes [get_instances [get_pins ${obj}]] -attribute is_black_box] == 1} {
            return 0
        }
        set res [check_E0319 ${obj} ${if_load} ${if_drive} new_debug_info]
        if {${res} eq 1} {
            return 0
        } else {
            return 1
        }
    } elseif {$::compare::ennoid eq "E0320"} {
        set res [check_E0320 $obj new_debug_info]
        if {${res} eq 1} {
            return 0
        } else {
            return 1
        }
    } elseif {$::compare::ennoid eq "E0336" || $::compare::ennoid eq "E0333" || $::compare::ennoid eq "E0331" || $::compare::ennoid eq "E0309"} {
        # sg只报了信号名, 没有Hier, 脚本无法处理这种漏报, 继续放在miss中
        return 0
    } elseif {$::compare::ennoid eq "E0314"} {
        set res [check_E0314 ${obj} ${if_load} ${if_drive} new_debug_info]
        if {${res} eq 1} {
            return 0
        } else {
            return 1
        }
    }
    }
}
# 将objunmatch拆分为false和miss
proc split_objunmatch {objunmatch_list false_list miss_list} {
    set all_msg {}
    for {set idx 0} {$idx < [llength ${objunmatch_list}]} {incr idx} {
        set tmp_msg [lindex ${objunmatch_list} ${idx}]
        lappend tmp_msg "OBJ__TAG"
        set e_or_s [lindex ${tmp_msg} 0]
        if {${e_or_s} == "E"} {
            lappend false_list "${tmp_msg} ${idx}"
        } else {
            lappend miss_list "${tmp_msg} ${idx}"
        }
    }
    lappend all_msg ${false_list}
    lappend all_msg ${miss_list}
    return ${all_msg}
}
proc delete_pass_msg {lst match_list} {
    if {[llength ${match_list}] != 0} {
        foreach idx [lsort -decreasing -integer -unique $match_list] {
            set lst [lreplace $lst $idx $idx]
        }
        return ${lst}
    } else {
        return ${lst}
    }
}
proc check_s_if_obj {msg} {
    # 转换s_obj为e_obj的格式
    set s_obj [lindex ${msg} 9]
    set s_obj [__s_to_e_obj ${s_obj}]
    # 判断是否enno电路中的obj
    if {[is_enno_obj ${s_obj}] != 1} {
        return 0
    } else {
        return 1
    }
}
proc add_debug_info {msg info} {
    set diff_content [lindex ${msg} 11]
    if {${diff_content} == ""} {
        set msg [lreplace ${msg} 11 11 ${info}]
    } else {
        lappend diff_content ${info}
        set msg [lreplace ${msg} 11 11 ${diff_content}]
    }
    return ${msg}
}
proc check_msg {false_fail obj_fail miss_fail origin_dict} {
    # 获取原始pass的msg
    set origin_pass [dict get ${origin_dict} pass]
    # 获取该rule预期结果: 是否被Drive, 和是否被Load
    if {$::compare::ennoid ni {"E0310" "E0333"}} {
        set load_drive_res [dict get $::compare::driverLoad $::compare::ennoid "ennoid_res"]
        set if_load [lindex $load_drive_res 0]
        set if_drive [lindex $load_drive_res 1]
    } else {
        set load_drive_res {}
        set if_load {}
        set if_drive {}
    }
# 一. 拆分objunmatch并lappend到false和miss
set all_msg [split_objunmatch ${obj_fail} ${false_fail} ${miss_fail}]
set all_false_msg [lindex ${all_msg} 0]
set all_miss_msg [lindex ${all_msg} 1]
set false_len [llength ${all_false_msg}]
set miss_len [llength ${all_miss_msg}]
set e_pass_idx {}
set s_pass_idx {}
# 二. 遍历all_false_msg, 处理误报的msg
set final_false_msg {}
for {set ee_idx 0} {$ee_idx < ${false_len}} {incr ee_idx} {
    set debug_info {}
    set e_msg [lindex ${all_false_msg} ${ee_idx}]
    set res [check_res ${e_msg} ${if_load} ${if_drive} debug_info]
    set e_msg [add_debug_info ${e_msg} ${debug_info}]
    if {${res} eq 1} {
        lappend e_pass_idx ${ee_idx}
        lappend origin_pass ${e_msg}
    } else {
        lappend final_false_msg ${e_msg}
    }
}
# 三. 遍历all_miss_msg, 处理漏报的msg
set final_miss_msg {}
for {set ss_idx 0} {$ss_idx < ${miss_len}} {incr ss_idx} {
    set debug_info {}
    set s_msg [lindex ${all_miss_msg} ${ss_idx}]
    # 转换s_obj为elint格式, 然后判断是否是elint的真实obj, 如果不是, 直接放在miss里
    if {[Check_s_if_obj ${s_msg}] != 1} {
        lappend debug_info "not_obj"
        set s_msg [add_debug_info ${s_msg} ${debug_info}]
        lappend final_miss_msg ${s_msg}
        continue
    }
    set res [check_res ${s_msg} ${if_load} ${if_drive} debug_info]
    set s_msg [add_debug_info ${s_msg} ${debug_info}]
    if {${res} eq 1} {
        lappend s_pass_idx ${ss_idx}
        lappend origin_pass ${s_msg}
    } else {
        lappend final_miss_msg ${s_msg}
    }
}
# 四. 处理数据, objunmatch 置空, 只有false和miss
dict set origin_dict pass ${origin_pass}
dict set origin_dict falseReport ${final_false_msg}
dict set origin_dict missReport ${final_miss_msg}
dict set origin_dict objectUnmatch {}
return ${origin_dict}
}
proc compare_canonical_net {origin_dict false_fail obj_fail miss_fail} {
    upvar 1 $origin_dict new_origin_dict
    # 只有以下rule的obj是net, 才支持get_nets -canonical
    if {$::compare::ennoid ni {"E0309" "E0310" "E0315" "E0320" "E0321" "E0331" "E0333"}} {
        set cmd {get_nets}
        return
    }
    set origin_pass_msg [dict get ${new_origin_dict} pass]
    # 1. 通过get_nets -canonical 匹配
    set all_msg [split_objunmatch ${obj_fail} ${false_fail} ${miss_fail}]
    set all_false_msg [lindex ${all_msg} 0]
    set all_miss_msg [lindex ${all_msg} 1]
    set e_dict [dict create]
    set s_dict [dict create]
    for {set ee 0} {$ee < [llength ${all_false_msg}]} {incr ee} {
        set e_msg [lindex ${all_false_msg} ${ee}]
        set e_net [lindex ${e_msg} 9]
        set e_net [get_nets ${e_net} -canonical]
        dict set e_dict ${e_net} ${ee}
    }
    for {set ss 0} {$ss < [llength ${all_miss_msg}]} {incr ss} {
        set s_msg [lindex ${all_miss_msg} ${ss}]
        set s_net [__s_to_e_obj [lindex ${s_msg} 9]]
        set s_net [get_nets ${s_net} -canonical]
        if {${s_net} == ""} {
            continue
        }
        dict set s_dict ${s_net} ${ss}
    }
    # 判断elint的net, sg有没有报
    set e_pass_idx {}
    set s_pass_idx {}
    dict for {net e_idx} ${e_dict} {
        if {[dict exists ${s_dict} ${net}]} {
            set s_idx [dict get ${s_dict} ${net}]
            # 匹配的msg分别追加"canonical_net"标记
            set e_msg [lindex ${all_false_msg} ${e_idx}]
            set e_msg [add_debug_info ${e_msg} "canonical_net"]
            set s_msg [lindex ${all_miss_msg} ${s_idx}]
            set s_msg [add_debug_info ${s_msg} "canonical_net"]
            lappend origin_pass_msg ${e_msg}
            lappend origin_pass_msg ${s_msg}
            lappend e_pass_idx ${e_idx}
            lappend s_pass_idx ${s_idx}
        }
    }
    # 删除已经pass的msg
    set final_false_msg [delete_pass_msg ${all_false_msg} ${e_pass_idx}]
    set final_miss_msg [delete_pass_msg ${all_miss_msg} ${s_pass_idx}]
    # 整理数据: 返回新的false, miss, pass
    dict set new_origin_dict pass ${origin_pass_msg}
    dict set new_origin_dict falseReport ${final_false_msg}
    dict set new_origin_dict missReport ${final_miss_msg}
}
proc get_signal_name {signal} {
    set signal [lindex [split ${signal} "/"] end]
    if {[string first "." ${signal}] != -1} {
        set signal [lindex [split ${signal} "\."] end]
    }
    return ${signal}
}
# 输入一个信号, 获取索引的列表；如: A[5, 2:0] 输出: {5 2 1 0}
proc get_num {str} {
    set left_index [string last "\[" ${str}]
    set right_index [string last "\]" ${str}]
    if {${right_index} == -1 || ${left_index} == -1 || ${right_index} <= ${left_index}} {
        return {}
    }
    set content [string range $str [expr ${left_index} + 1] [expr ${right_index} -1]]
    set result {}
    foreach part [split ${content} ","] {
        set part [string trim $part]
        if {[regexp {^(\d+)\s*:\s*(\d+)$} $part -> start end]} {
            for {set index $start} {$index >= $end} {incr index -1} {
                lappend result $index
            }
        } else {
            lappend result $part
        }
    }
    return $result
}
proc handle_diff_instance {new_fail_dict} {
    # 从pass的e_msg中以[list signal_name, owner] 为key, msg在原始miss_msg中的索引为value, 来创建dict
    upvar 1 $new_fail_dict tmp_fail_dict
    set debug_info {}
    set e_pass_dict [dict create]
    set miss_dict [dict create]
    set miss_msg [dict get ${tmp_fail_dict} missReport]
    set pass_msg [dict get ${tmp_fail_dict} pass]
    for {set idx 0} {$idx < [llength ${pass_msg}]} {incr idx} {
        set msg [lindex ${pass_msg} ${idx}]
        if {[lindex ${msg} 0] != "E"} {
            continue
        }
        set e_obj [lindex ${msg} 9]
        if {[llength ${e_obj}] == 1} {
            set e_obj [lindex ${e_obj} 0]
        }
        # 获取所在module
        set e_owner [lsort -unique [get_attributes [get_nets ${e_obj}] -attribute owner]]
        if {$e_owner == "String"} {
            continue
        }
        # 获取owner的original_name, 如果包含了parameter, 需要去除括号
        set e_owner [get_attributes [get_attributes [get_nets ${e_obj}] -attribute owner] -attribute original_name]
        if {[string first "\(" ${e_owner}] != -1} {
            set e_owner [lindex [split ${e_owner} "\("] 0]
        }
        set e_signal_name [lindex [split [lindex ${e_obj} 0] "/"] end]
        set e_key_name [list ${e_signal_name} ${e_owner}]
        set e_value ${idx}
        dict set e_pass_dict ${e_key_name} ${e_value}
    }
    set s_match_idx {}
    for {set s_idx 0} {$s_idx < [llength ${miss_msg}]} {incr s_idx} {
        set s_msg [lindex ${miss_msg} ${s_idx}]
        set s_obj [lindex [lindex ${s_msg} 9] 0]
        set s_obj [__s_to_e_obj ${s_obj}]
        # 转换后仍不是elint的电路中的object, 视为综合差异, s_msg PASS
        if {[is_enno_obj ${s_obj}] == 0} {
            # lappend pass_msg ${s_msg}
            # lappend s_match_idx ${s_idx}
            continue
        }
        set s_owner [lsort -unique [get_attributes [get_nets ${s_obj}] -attribute owner]]
        if {$s_owner == "String"} {
            continue
        }
        set s_owner [lsort -unique [get_attributes [get_attributes [get_nets ${s_obj}] -attribute owner] -attribute original_name]]
        if {[string first "\(" ${s_owner}] != -1} {
            set s_owner [lindex [split ${s_owner} "\("] 0]
        }
        set s_signal_name [lindex [split [lindex ${s_obj} 0] "/"] end]    
        set s_key_name [list ${s_signal_name} ${s_owner}]
        # 1. enno和sg只要报了相同module(instance可以不同)的相同信号, 两者就匹配
        if {[dict exists ${e_pass_dict} ${s_key_name}]} {
            # red s_key_name:: ${s_key_name}
            set s_msg [add_debug_info ${s_msg} "same_module_diff_instance"]
            lappend pass_msg ${s_msg}
            lappend s_match_idx ${s_idx}
            continue
        }
        # 2. 特殊情况处理: 相同module, 但是sg只报了部分bit, elint报的更多一些
        # s: REG_A[0] module_A ; e: REG_A[1:0] module_A
        # 判断e和s的no bus的信号名是否一致, 然后判断e的索引是否包含s的索引, 包含则PASS
        if {[string first "\[" ${s_signal_name} ] != -1} {
            set s_no_bus_name [lindex [split ${s_signal_name} "\["] 0]
            foreach tmp_e_key [dict keys ${e_pass_dict}] {
                set e_signal_name [lindex ${tmp_e_key} 0]
                set e_no_bus_name [lindex [split ${e_signal_name} "\["] 0]
                if {${e_no_bus_name} == ${s_no_bus_name}} {
                    set tmp_e_owner [lindex ${tmp_e_key} 1]
                    if {${tmp_e_owner} == ${s_owner}} {
                        # owner相同, 判断索引是否是包含关系
                        set e_num [get_num [lindex ${tmp_e_key} 0]]
                        set s_num [get_num ${s_signal_name}]
                        set if_contain {}
                        foreach ss ${s_num} {
                            if {[lsearch -exact ${e_num} ${ss}] != -1} {
                                lappend if_contain 1
                            }
                        }
                        if {[llength ${if_contain}] == [llength ${s_num}]} {
                            lappend pass_msg ${s_msg}
                            lappend s_match_idx ${s_idx}
                        }
                    }
                }
            }
        }
    }
    if {[llength ${s_match_idx}] != 0} {
        set new_miss_msg [delete_pass_msg ${miss_msg} ${s_match_idx}]
        dict set tmp_fail_dict missReport ${new_miss_msg}
        dict set tmp_fail_dict pass ${pass_msg}
    }
}
# sg可能会少报bit, 只要sg报的bit我们报了, sg那条msg就pass
proc handle_diff_bit {new_fail_dict} {
    upvar 1 $new_fail_dict tmp_fail_dict
    set pass_msg [dict get ${tmp_fail_dict} pass]
    set miss_msg [dict get ${tmp_fail_dict} missReport]
    # 以信号名为key, 所有bit为value
    set e_dict {}
    set s_dict {}
    for {set idx 0} {$idx < [llength $pass_msg]} {incr idx} {
        set msg [lindex ${pass_msg} ${idx}]
        if {[lindex ${msg} 0] != "E"} {
            continue
        }
        set e_obj [lindex [lindex ${msg} 9] 0]
        # e_net是单维的多比特才进行收集
        set all_net [get_nets ${e_obj}]
        if {[llength ${all_net}] == 1} {
            continue
        }
        if {[string match "*\]" ${e_obj}] && [string first "\]\[" ${e_obj}] == -1 } {
            set e_obj_name {*}[get_nets ${e_obj} -bus]
            set e_all_idx {}
            foreach tmp_net $all_net {
                set tmp_idx [dict values [regexp -all -inline {\[([0-9]+)\]} $tmp_net]]
                if {[llength ${tmp_idx}] > 1} {
                    set tmp_idx [lindex ${tmp_idx} end]
                }
                lappend e_all_idx ${tmp_idx}
            }
            set e_all_idx [lsort -decreasing -integer ${e_all_idx}]
            dict set e_dict ${e_obj_name} [list ${e_all_idx} ${idx}]
        }
    }
    set miss_len [llength ${miss_msg}]
    for {set s_idx 0} {$s_idx < ${miss_len}} {incr s_idx} {
        set s_msg [lindex ${miss_msg} ${s_idx}]
        set s_obj [lindex [lindex ${s_msg} 9] 0]
        set s_obj [__s_to_e_obj ${s_obj}]
        if {[is_enno_obj ${s_obj}] != 1} {
            continue
        }
        set s_all_net [get_nets ${s_obj}]
        if {[llength ${s_all_net}] == 1} {
            continue
        }
        if {[string match "*\]" ${s_obj}] && [string first "\]\[" ${s_obj}] == -1 } {
            set s_obj_name {*}[get_nets ${s_obj} -bus]
            set s_all_idx {}
            foreach tmp_net $s_all_net {
                set tmp_idx [dict values [regexp -all -inline {\[([0-9]+)\]} $tmp_net]]
                if {[llength ${tmp_idx}] > 1} {
                    set tmp_idx [lindex ${tmp_idx} end]
                }
                lappend s_all_idx ${tmp_idx}
            }
            set s_all_idx [lsort -decreasing -integer ${s_all_idx}]
            dict set s_dict ${s_obj_name} [list ${s_all_idx} ${s_idx}]
        }
    }
    # 判断sg_obj的每一个索引是否都在e_obj中存在
    set s_pass_index {}
    dict for {obj_name value} ${e_dict} {
        set e_index [lindex ${value} 0]
        if {[dict exists ${s_dict} ${obj_name}]} {
            set s_value [dict get ${s_dict} ${obj_name}]
            set s_index [lindex ${s_value} 0]
            set res {}
            foreach s_tmp_idx ${s_index} {
                if {[lsearch -exact ${e_index} ${s_tmp_idx}] != -1} {
                    lappend res 1
                }
            }
            # 所有index都有, 才pass
            if {[llength ${s_index}] == [llength ${res}]} {
                set s_pass_idx [lindex ${s_value} 1]
                set s_msg [lindex ${miss_msg} ${s_pass_idx}]
                lappend pass_msg ${s_msg}
                lappend s_pass_index ${s_pass_idx}
            }
        }
    }
    if {[llength ${s_pass_index}] != 0} {
        dict set tmp_fail_dict pass ${pass_msg}
        set new_miss [delete_pass_msg ${miss_msg} ${s_pass_index}]
        dict set tmp_fail_dict missReport ${new_miss}
    }
}
proc check_s_obj_exists {new_fail_dict} {
    upvar 1 $new_fail_dict tmp_fail_dict
    if {$::compare::ennoid in {"E0314" "E0317" "E0319"}} {
        set cmd {get_pins}
    } elseif {$::compare::ennoid in {"E0309" "E0310" "E0315" "E0320" "E0321" "E0333"}} {
        set cmd {get_nets}
    } elseif {$::compare::ennoid in {"E0316" "E0318"}} {
        set cmd {get_ports}
    }
    set pass_msg [dict get ${tmp_fail_dict} pass]
    set miss_msg [dict get ${tmp_fail_dict} missReport]
    set e_all_obj [dict create]
    # 获取所有的e-pass-obj, 并建key, 每一个bit都是一个key
    foreach msg $pass_msg {
        if {[lindex ${msg} 0] != "E"} {
            continue
        }
        set e_obj [lindex ${msg} 9]
        set e_obj [${cmd} ${e_obj}]
        if {[llength ${e_obj}] == 1} {
            set e_obj [lindex ${e_obj} 0]
            dict set e_all_obj ${e_obj} "XXX"
        } else {
            foreach tmp_obj ${e_obj} {
                dict set e_all_obj ${tmp_obj} "XXX"
            }
        }
    }
    set miss_len [llength ${miss_msg}]
    set s_pass_idx {}
    set new_miss {}
    # 遍历所有的miss_obj, 判断msg中的obj我们有没有报
    for {set s_idx 0} {$s_idx < ${miss_len}} {incr s_idx} {
        set s_msg [lindex ${miss_msg} ${s_idx}]
        set s_obj [lindex ${s_msg} 9]
        set s_obj [__s_to_e_obj ${s_obj}]
        if {[is_enno_obj ${s_obj}] == 0} {
            continue
        }
        set s_obj [${cmd} ${s_obj}]
        if {${s_obj} == ""} {
            continue
        }
        set s_obj_len [llength ${s_obj}]        
        if {${s_obj_len} == 1} {
            # 该条msg, sg报的单比特
            if {[dict exists ${e_all_obj} ${s_obj}]} {
                yellow 11-s_obj:: ${s_obj}
                set s_msg [add_debug_info ${s_msg} "contain_s_obj"]
                lappend pass_msg ${s_msg}
                lappend s_pass_idx ${s_idx}
                continue
            }
        } else {
            # 该条msg, sg报的多比特
            set tmp_res {}
            foreach tmp_s_obj ${s_obj} {
                if {[dict exists ${e_all_obj} ${tmp_s_obj}]} {
                    lappend tmp_res 1
                }
            }
            # 如果该obj的所有bit, elint都报了, 该条s_msg PASS
            if {[llength ${tmp_res}] == ${s_obj_len}} {
                set s_msg [add_debug_info ${s_msg} "contain_s_obj"]
                lappend pass_msg ${s_msg}
                lappend s_pass_idx ${s_idx}
                continue
            }
        }
        # 如果单比特和多比特都不符合, 则继续放在miss
        lappend new_miss ${s_msg}
    }
    if {[llength ${s_pass_idx}] != 0} {
        dict set tmp_fail_dict pass ${pass_msg}
        dict set tmp_fail_dict missReport ${new_miss}
    }
}
proc handle_special_scenarios {fail_dict} {
    upvar 1 $fail_dict new_fail_dict
    if {$::compare::ennoid != "E0331" && $::compare::ennoid != "E0321" && $::compare::ennoid != "E0336"} {
        # 1. 检查miss_obj我们有没有报, 只要报了就PASS, 否则就是miss
        check_s_obj_exists new_fail_dict
        # 2. 对于module实例化多次的场景, elint和sg报的层次可能不一样, 只要信号名相同, 且owner相同, 视为sg的漏报pass
        handle_diff_instance new_fail_dict
    }
}
# ============================================================== 脚本入口 ==============================================================
proc check_driver_load {ennoid origin_dict} {
    INFO "Start driver load judgment \[ennoid: $ennoid\]"
    # 判断失败rule是否需要检查drive-load, 如果不是, 则原样返回
    if {${ennoid} ni {"E0309" "E0310" "E0314" "E0315" "E0316" "E0317" "E0318" "E0319" "E0320" "E0321" "E0331" "E0333" "E0336"}} {
        return ${origin_dict}
    }
    # 获取失败的msg
    set line_fail [dict get $origin_dict "lineNumUnmatch"]
    set obj_fail [dict get $origin_dict "objectUnmatch"]
    set false_fail [dict get $origin_dict "falseReport"]
    set miss_fail [dict get $origin_dict "missReport"]
    set fail_dict [list]
    # 开始检查drive/Load
    # 一. 处理canonical net
    compare_canonical_net origin_dict $false_fail $obj_fail $miss_fail
    # 二. 进行rule规则检查
    set fail_dict [check_msg $false_fail $obj_fail $miss_fail $origin_dict]
    # 三. 进行特殊处理
    handle_special_scenarios fail_dict
    return ${fail_dict}
}
