# 从msg中获取obj  
proc get_obj_from_msg {msg} {  
    set tmp_list [split $msg "`"]  
    set obj [lindex $tmp_list 5]  
    set obj {*}[lrange $obj 0 end-1]  
    set obj [expand_bits $obj]  
    set obj [add_top_to_obj $obj]  
    return $obj  
}  
# 输入: 一个列表 和 索引列表, 删除列表中这些索引所在元素  
proc delete_diff_msg {lst match_list} {  
    foreach idx [lsort -decreasing -integer -unique $match_list] {  
        set lst [lreplace $lst $idx $idx]  
    }  
    return ${lst}  
}  
# 获取符合差异的msg的索引列表  
proc get_idx {match_list} {  
    set idx_lst {}  
    foreach tmp ${match_list} {  
        lappend idx_lst [lindex ${tmp} 0]  
    }  
    return ${idx_lst}  
}  
# 给符合差异的msg添加差异编号的标记  
proc add_diff_num_to_msg {idx_list fail_list origin_pass} {  
    upvar 1 $origin_pass new_pass  
    foreach tmp $idx_list {  
        set idx [lindex $tmp 0]  
        set diff_num [lindex $tmp 1]  
        set msg [lindex ${fail_list} $idx]  
        lappend msg ${diff_num}  
        lappend new_pass ${msg}
    }
}
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
proc process_false_msg {ennoid origin_pass all_false_msg e_obj_pass_idx e_pass_idx} {  
    upvar 1 $origin_pass new_origin_pass  
    upvar 1 $e_obj_pass_idx new_e_obj_pass_idx  
    upvar 1 $e_pass_idx new_e_pass_idx  
    set false_len [llength ${all_false_msg}]  
    # 开始处理false  
    for {set e_idx 0} {$e_idx < ${false_len}} {incr e_idx} {  
        set e_msg [lindex ${all_false_msg} ${e_idx}]  
        set tmp_res [check_false_diff ${ennoid} ${e_msg}]  
        set diff_res [lindex ${tmp_res} 1]  
        if {${diff_res} eq 1} {  
            # 已满足差异  
            set diff_num [lindex ${tmp_res} 0]  
            # 判断是objunmatch还是falseReport中的e_msg pass了  
            if {[string first "OBJ__TAG" ${e_msg}] != -1} {  
                lappend new_e_obj_pass_idx [lindex ${e_msg} end]  
            }  
            lappend new_e_pass_idx ${e_idx}  
            set e_msg [add_diff_num ${e_msg} ${diff_num}]  
            # 将该msg添加到pass  
            lappend new_origin_pass ${e_msg}
        }
    }
}
proc add_diff_num {msg diff_num} {  
    set origin_diff [lindex ${msg} 11]  
    lappend origin_diff ${diff_num}  
    set msg [lreplace ${msg} 11 11 ${origin_diff}]  
    return ${msg}  
}  
proc process_miss_msg {ennoid origin_pass all_miss_msg s_obj_pass_idx s_pass_idx} {  
    upvar 1 $origin_pass new_origin_pass  
    upvar 1 $s_obj_pass_idx new_s_obj_pass_idx  
    upvar 1 $s_pass_idx new_s_pass_idx  
    set miss_len [llength ${all_miss_msg}]  
    # 开始处理miss  
    for {set s_idx 0} {$s_idx < ${miss_len}} {incr s_idx} {  
        set s_msg [lindex ${all_miss_msg} ${s_idx}]  
        set tmp_res [check_miss_diff ${ennoid} ${s_msg}]  
        set diff_res [lindex ${tmp_res} 1]  
        if {${diff_res} eq 1} {  
            # 已满足差异  
            set diff_num [lindex ${tmp_res} 0]  
            # 判断是objunmatch还是missReport中的s_msg pass了  
            if {[string first "OBJ__TAG" ${s_msg}] != -1} {  
                lappend new_s_obj_pass_idx [lindex ${s_msg} end]  
            }  
            lappend new_s_pass_idx ${s_idx}  
            set s_msg [add_diff_num ${s_msg} ${diff_num}]  
            # 将该msg添加到pass  
            lappend new_origin_pass ${s_msg}  
        }  
    }  
}  
# 多比特的instance通过net获取instance不包含索引的名字  
proc get_multiple_inst_name {inst} {  
    set origin_inst ${inst}  
    set inst [get_instances ${origin_inst}]  
    if {[llength ${inst}] == 1} {  
        return ${origin_inst}  
    }  
    # get_nets [get_pins "[lindex [get_instances FE_TSS/U_NEST_0/G_NEST_FE_TSS.U_NEST_FE/U_NEST_SUB/U_NEST_WRAP/U_NEST_CA/tscd_nest_api_data_dly1[127:0]] 0]/q"] -bus
    set inst [lindex ${inst} 0]  
    set inst_q_pin [get_pins "${inst}/q"]
    set net [get_nets [get_pins ${inst_q_pin}] -bus]
    if {${net} != ""} {
        return ${net}
    } else {
        return ${inst}
    }
}
proc get_idx {inst_index} {
    set idx_list {}
    set parts [split ${inst_index} ":"]
    set start [lindex ${parts} 0]
    set end [lindex ${parts} 1]
    if {${start} > ${end}} {
        set high_idx ${start}
        set low_idx ${end}
    } else {
        set high_idx ${end}
        set low_idx ${start}
    }
    for {set index ${low_idx}} {$index <= ${high_idx}} {incr index} {
        lappend idx_list ${index}
    }
    return ${idx_list}
}
# 获取inst所有的索引列表, [1:2] 则返回{1 2}; [1]返回{1}, 否则返回{}
proc get_inst_index {inst} {
    # 1. 如果不是] 结尾, 表示非bus, 直接返回{}
    if { ![string match "*]" $inst] } {
        return {}
    }
    # 2. 是多比特, 返回索引列表
    set inst_index [lindex [regexp -inline {.*\[([^]]*)\]} $inst] 1]
    set idx_list {}
    # 3. 判断单比特还是多比特: 是否有":"  
    if {[string first ":" ${inst_index}] != -1} {
    # [XX:YY]
        # 不包含逗号的场景: [6:2]
        if {[string first "," ${inst_index}] == -1} {
            set idx_list [get_idx ${inst_index}]
    } else {
            # 包含逗号的场景:[6:2, 0]
            set idx_list {}
            set parts [split ${inst_index} ","]
            foreach tmp_idx ${parts} {
                if {[string first ":" ${tmp_idx}] != -1} {
                    lappend idx_list {*}[get_idx ${tmp_idx}]
                } else {
                    regsub -all {\s} $tmp_idx "" new_str
                    lappend idx_list ${new_str}
                    # set idx_list [concat ${idx_list} ${tmp_idx}]
                }
            }
            set idx_list [lsort ${idx_list}]
        }
    } else {
# [XX]
        lappend idx_list ${inst_index}
    }
    return ${idx_list}
}
proc remove_useless_str {str} {
    # 删除空格
    regsub -all { } ${str} "" no_space_str
    # 删除
    regsub -all {\\} ${no_space_str} "" no_backslash_str
    # /替换为.
    regsub -all {/} ${no_backslash_str} "." result
    return ${result}
}
# 此处根据rule自定义差异proc的执行顺序和输入
# 可选输入有:
#       all_false_msg, all_miss_msg: 所有的e_msg和s_msg(包含objunmatch中的e和s)
#       origin_pass(包含字符串比对, 和process_false_msg ,process_miss_msg 已经pass的msg), 
#       e_obj_pass_idx, s_obj_pass_idx: msg在objunmatch中的索引(为了通过差异后, 在原始objunmatch中删除该msg)
# 输出:
#       e_obj_pass_idx s_obj_pass_idx: 符合差异的e/s_msg, 将[lindex $e/s_msg end]添加到e/s_obj_pass_idx
# 其它:
#       e_pass_idx, s_pass_idx: 该msg在all_false_msg和all_miss_msg中的索引(为了通过差异后, 为了通过差异后, 在all_false_msg和all_miss_msg中删除该msg)
proc process_special_msg {ennoid all_miss_msg all_false_msg all_objunmatch_msg origin_pass e_obj_pass_idx s_obj_pass_idx} {
    upvar 1 $all_miss_msg new_all_miss_msg    
    upvar 1 $all_false_msg new_all_false_msg  
    upvar 1 $origin_pass new_origin_pass  
    upvar 1 $e_obj_pass_idx new_e_obj_pass_idx
    upvar 1 $s_obj_pass_idx new_s_obj_pass_idx  
    upvar 1 $all_objunmatch_msg new_all_objunmatch_msg  
    set false_len [llength ${new_all_false_msg}]  
    set miss_len [llength ${new_all_miss_msg}]  
    # 如果special_diff为空, 直接return  
    if {[llength [dict get $::compare::diffPorc ${ennoid} "special_diff"]]==0} {  
        return 
    }  
    # 1. 按rule进行特殊差异处理, 一个rule的差异串行处理  
    # dict for {k v} [dict get $::compare::diffPorc ${ennoid}] {  
    set special_diff_list [dict get $::compare::diffPorc ${ennoid} "special_diff"]  
    foreach diff_num ${special_diff_list} {  
        eval $diff_num new_origin_pass new_e_obj_pass_idx new_s_obj_pass_idx new_all_false_msg new_all_miss_msg new_all_objunmatch_msg
    }  
    # }  
    # diff_num 举例:   
    # Diff_XXX_0001 的内部处理完差异后, 必须处理all_false,all_miss,origin_pass,e_obj_pass_idx,s_obj_pass_idx(1. 删除符合差异的msg; 2. 并追加到pass中; 3. 获取在objunmatch中的索引), 给下一个差异提供新的输入, 例如:   
    # proc Diff_XXX_0001 {args...........} {  
    #     upvar 1 $new_all_false_msg tmp_all_false_msg  
    #     upvar 1 $new_all_miss_msg tmp_all_miss_msg  
    #     set e_pass_idx {}  
    #     set s_pass_idx {}  
    #     ......  
    #     处理数据: 在all_false_msg和all_miss_msg中删除已经pass的msg  
    #     if {${e_pass_idx} != {}} {  
    #         set tmp_all_false_msg [delete_diff_msg ${tmp_all_false_msg} ${e_pass_idx}]  
    #      }  
    #      if {${s_pass_idx} != {}} {  
    #         set tmp_all_miss_msg [delete_diff_msg ${tmp_all_miss_msg} ${s_pass_idx}]  
    #      }  
    #      }  
}  
proc uniqe_s_E0233 {miss_list input_dict} {  
    upvar 1 $input_dict tmp_dict  
    # 使用字典记录每个消息第一次出现的索引  
    set message_first_occurrence [dict create]  
    set sg_same_idx [list]  
    # 找出所有重复的索引(除了每个消息第一次出现)  
    for {set index 0} {$index < [llength $miss_list]} {incr index} {  
        set miss_msg [lindex $miss_list $index]  
        if {[dict exists $message_first_occurrence $miss_msg]} {  
            # 重复消息, 记录索引  
            lappend sg_same_idx $index  
        } else {
            # 第一次出现此消息, 记录索引
            dict set message_first_occurrence $miss_msg $index
        }
    }
    set sg_same_idx [lsort -unique -integer $sg_same_idx]
    if {[llength $sg_same_idx] == 0} {
        # 没有重复msg, 直接return
        return
    }
    # 构建新的miss和pass
    set origin_pass [dict get $tmp_dict pass]
    set new_miss_list [list]
    for {set index 0} {$index < [llength $miss_list]} {incr index} {
        if {$index in $sg_same_idx} {
            # 重复消息: 添加到pass, 并添加标记
            set s_msg [lindex $miss_list $index]
            lappend s_msg "Diff_ca_sg_bug_001"
            lappend origin_pass $s_msg
        } else {
            # 唯一或第一次出现的msg, 保留在miss中
            lappend new_miss_list [lindex $miss_list $index]
    }
    }
    # 更新dict
    dict set tmp_dict pass $origin_pass
    dict set tmp_dict missReport $new_miss_list
}
proc get_false_miss_from_obj {final_objunmatch falseReport missReport} {
    upvar 1 $final_objunmatch new_objunmatch
    upvar 1 $falseReport new_falseReport
    upvar 1 $missReport new_missReport
    set len [llength ${new_objunmatch}]
    set e_lines [dict create]
    set s_lines [dict create]
    # 分别以行号和文件名为key建dict
    for {set index 0} {$index < ${len}} {incr index} {
        set tmp_msg [lindex ${new_objunmatch} ${index}]
        set msg_type [lindex ${tmp_msg} 0]
        set line [lindex ${tmp_msg} 4]
        set file [lindex ${tmp_msg} 7]
        if {${msg_type} == "E"} {
            dict lappend e_lines "$line ${file}" $index
        } else {
            dict lappend s_lines "$line ${file}" $index
        }
    }
    set false_index {}
    foreach line_file [dict keys ${e_lines}] {  
        if {![dict exists ${s_lines} ${line_file}]} {  
            set e_idx [dict get ${e_lines} ${line_file}]  
            set false_index [concat ${e_idx} ${false_index}]  
        }  
    }
    set miss_index {}  
    foreach line_file [dict keys ${s_lines}] {  
        if {![dict exists ${e_lines} ${line_file}]} {  
            set s_idx [dict get ${s_lines} ${line_file}]  
            set miss_index [concat ${s_idx} ${miss_index}]  
        }  
    }  
# 将行号和文件唯一的msg添加到false和miss中, 并在diff_proc 中追加标记: from_objunmatch  
    if {[llength false_index] != 0} {  
        foreach ee ${false_index} {  
            set e_msg [lindex ${new_objunmatch} ${ee}]  
            set origin_diff [lindex ${e_msg} 11]  
            lappend origin_diff "from_objunmatch"  
            lset e_msg 11 ${origin_diff}  
            lappend new_falseReport ${e_msg}  
        }
    }  
    if {[llength ${miss_index}] != 0} {  
        foreach ss ${miss_index} {  
            set s_msg [lindex ${new_objunmatch} ${ss}]  
            set origin_diff [lindex ${s_msg} 11]  
            lappend origin_diff "from_objunmatch"  
            lset s_msg 11 ${origin_diff}  
            lappend new_missReport ${s_msg}  
        }
    }    
    # 在objunmatch中删除 false和miss的msg  
    set all_unique_index [concat ${false_index} ${miss_index}]  
    set new_objunmatch [delete_diff_msg ${new_objunmatch} ${all_unique_index}]  
}  
proc handle_miss_bit {new_fail_dict} {  
    # 从pass的e_msg中以[list signal_name, owner] 为key, msg在原始miss_msg中的索引为value, 来创建dict  
    upvar 1 $new_fail_dict tmp_fail_dict  
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
        set e_signal_name [lindex [split [lindex ${e_obj} 0] "/"] end]
        set e_key_name [list ${e_signal_name}]
        set e_value ${idx}
        dict set e_pass_dict ${e_key_name} ${e_value}
    }
    set s_match_idx {}
    for {set s_idx 0} {$s_idx < [llength ${miss_msg}]} { incr s_idx} {
        set s_msg [lindex ${miss_msg} ${s_idx}]
        set s_obj [lindex [lindex ${s_msg} 9] 0]
        set s_signal_name [lindex [split [lindex ${s_obj} 0] "/"] end]
        set s_key_name [list ${s_signal_name}]
        # 判断e和s的no bus的信号名是否一致, 然后判断e的索引是否包含s的索引, 包含则PASS
        if {[string first "\[" ${s_signal_name}] != -1} {
            set s_no_bus_name [lindex [split ${s_signal_name} "\["] 0]
            foreach tmp_e_key [dict keys ${e_pass_dict}] {
                set e_signal_name [lindex ${tmp_e_key} 0]
                set e_no_bus_name [lindex [split ${e_signal_name} "\["] 0]
                if {${e_no_bus_name} == ${s_no_bus_name}} {
                    set tmp_e_owner [lindex ${tmp_e_key} 1]
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
    if {[llength ${s_match_idx}] != 0} {
        set new_miss_msg [delete_pass_msg ${miss_msg} ${s_match_idx}]
        dict set tmp_fail_dict missReport ${new_miss_msg}
        dict set tmp_fail_dict pass ${pass_msg}
    }
}
# 主检查流程
proc check_diff {ennoid input_dict} {
    # lappend __msg "[format {%s: %-6s}ennoid $ennoid]"
    # dict for {k v}$input_dict {
    #	lappend __msg [format {%s:%-6s} $k [llength $v]]
    # }
    #puts [join $__msg " | "]
    # red 原始输入:: ${input_dict}
    # red	Start-check_diff
    INFO "Start difference processing \[ennoid: $ennoid\]"
    # 处理E0233: sg重复报三条的问题, 两条标记差异, 剩下一条继续其他的差异处理
    set miss_list [dict get $input_dict missReport]
    # 一. E0233: sg会重复报3条, 此处对sg去重, missReport中只保留一条, 其余的放到pass并标记Diff_ca_sg_001
    if {${ennoid} == "E0233"} {
        uniqe_s_E0233 ${miss_list} input_dict
    }
    set false_list [dict get $input_dictfalseReport]
    set obj_unmatch_list [dict get$input_dict objectUnmatch]
    set miss_list [dict get $input_dictmissReport]
    set top_name [get_top]
    set filepath $::compare::filepath
    #二. 拆分objunmatch并lappend到false和miss, 获取所有的e_msg和s_msg
    set all_e_msg {}
    set all_s_msg {}
    if {[llength ${obj_unmatch_list}] != 0} {
        set all_msg [split_objunmatch ${obj_unmatch_list} ${false_list} ${miss_list}]
        set all_e_msg [lindex ${all_msg} 0]
        set all_s_msg [lindex ${all_msg} 1]
    }
    if {${all_e_msg} !={}} {
        set all_false_msg ${all_e_msg}
    } else {
        set all_false_msg ${false_list}
    }
    if {${all_s_msg} != {}} {
        set all_miss_msg ${all_s_msg}
    } else {
        set all_miss_msg ${miss_list}
    }
    # 拆分后的false在原始objunmatch中的索引
    set e_obj_pass_idx {}
    # e_msg在all_false_msg中的索引
    set e_pass_idx {}
    set false_len [llength ${all_false_msg}]
    set origin_pass [dict get ${input_dict} pass]
    # 拆分后的false在原始objunmatch中的索引
    set e_obj_pass_idx {}
    # all_false_msg中的passmsg的索引
    set e_pass_idx {}
    # 三. 如果该rule的差异的msg存在固定特征, 可在此处提前处理, 避免双层for循环次数太多
    process_special_msg ${ennoid} all_miss_msg all_false_msg obj_unmatch_list origin_pass e_obj_pass_idx s_obj_pass_idx
    # 四. 遍历all_false_msg, 处理误报差异, pass的msg放到pass-key, 并在all_false_msg和objunmatch中删除
    process_false_msg ${ennoid} origin_pass ${all_false_msg} e_obj_pass_idx e_pass_idx
    # 在all_false_msg中删除pass的msg
    if {[llength ${e_pass_idx}] != 0} {
        set all_false_msg [delete_diff_msg ${all_false_msg} ${e_pass_idx}]
    }
    # 五. 遍历all_miss_msg, 处理误报差异, pass的msg放到pass-key, 并在all_miss_msg和objunmatch中删除
    set s_obj_pass_idx {}
    set s_pass_idx {}
    process_miss_msg ${ennoid} origin_pass ${all_miss_msg} s_obj_pass_idx s_pass_idx
    # 在all_miss_msg中删除pass的msg
    if {[llength ${s_pass_idx}] != 0} {
        set all_miss_msg [delete_diff_msg ${all_miss_msg} ${s_pass_idx}]
    }
    # 差异处理完之后, all_e_msg和all_s_msg中非的OBJ__TAG的msg, 就是剩下的真正的false/miss
    set final_false_msg {}
    set final_miss_msg {}
    foreach e_msg ${all_false_msg} {
        if {[string first "OBJ__TAG" ${e_msg}] == -1} {
            lappend final_false_msg ${e_msg}
        }
    }
    foreach s_msg ${all_miss_msg} {
        if {[string first "OBJ__TAG" ${s_msg}] == -1} {
            lappend final_miss_msg ${s_msg}
        }
    }
    # objunmatch中删除已经pass的msg
    set all_pass_index [concat $e_obj_pass_idx $s_obj_pass_idx]
    set final_objunmatch [delete_diff_msg ${obj_unmatch_list} ${all_pass_index}]
    ## 将objunmatch中只出现一次的行号的msg, 放到false或者miss中
    get_false_miss_from_obj final_objunmatch final_false_msg final_miss_msg
    dict set input_dict falseReport ${final_false_msg}
    dict set input_dict missReport ${final_miss_msg}
    dict set input_dict pass ${origin_pass}
    dict set input_dict objectUnmatch ${final_objunmatch}
    ## 如果elint报的对象的bit完全包含sg的bit, 则sg那条msg 也pass
    if {${ennoid} == "E0251"} {
        handle_miss_bit input_dict
    }
    return ${input_dict}
    INFO "Compeleted check diff proc \[ennoid: $ennoid\]"
}
# 差异检查函数
proc check_false_diff {ennoid msg} {
    set diff_dict [dict get $::compare::diffPorc $ennoid]
    if {[dict exists $diff_dict false_diff_map ] == ""} {
    return [list ${ennoid} 0]
    }
    foreach diff_num [dict get $diff_dict false_diff_map ] {
        if {[${diff_num} ${msg}]} {
            return "${diff_num} 1"
        } else {
        continue
    }
    }
    return "0 0"
}
proc check_miss_diff {ennoid msg} {
    set unmatch_list [list]
    set passList [list]
    set diff_dict [dict get $::compare::diffPorc $ennoid]
    if {[dict exists $diff_dict miss_diff_map ] == ""} {
        return [list ${ennoid} 0]
    }
    foreach diff_num [dict get $diff_dict miss_diff_map ] {
        if {[${diff_num} ${msg}]} {
            return "${diff_num} 1"
        } else {
        continue
    }
    }
    return "0 0"
}
# ========================================= 具体的差异实现 =========================================
# ######################################################################################### 
# time: 20250328
# owner: kkxia
# description: E0251 - STARC05-3.3.1.4b, tool A: 综合出Latch, verific综合出ff, enno误报
# solution: 判断误报的obj是不是VERIFIC_DLATCHR, 所有obj都不是, 则视为满足Diff_019
# case: B1_11887
# ######################################################################################### 
proc Diff_019 {msg} {
    set false_obj [get_obj_from_msg $msg]
    foreach obj $false_obj {
        if {[get_attributes [get_instances $obj] -attribute view] ne "VERIFIC_DFFRS"} {
            return 0
        }
    }
    return 1
}
# ######################################################################################### 
# time: 20250328
# owner: kkxia
# description: E0248 - W128: 同一违规sg 报了完全一样的两条
# ## solution: 判断missing msg是否已经在pass的msg中, 如果在, 视为满足Diff_003
# ## case: B1_10348, B1_10354
# ######################################################################################### 
set ::compare::passMessage ""
proc Diff_003 {miss_list} {
    set ret 0
    foreach tmp_list $::compare:: passMessage {
        if {${miss_list} == ${tmp_list} } {
            set ret 1
             break
        }
    }
    return $ret
}
# ######################################################################################### 
# ## time: 20250401
# ## owner: kkxia
# ## description: E0308 - W498: GenerateFor 同一违规Elint: 报一条, SG: 报多条
# ## solution: 遍历已经pass的msg, 如果rule-ennoid, generate_block的name, 文件三者都相同, 视为满足该差异
# ## case: B2_279
# ######################################################################################### 
proc Diff_006 {miss_msg} {
    set pass_msg_list $::compare:: passMessage
    set not_match_list ""
    foreach tmp_1 ${pass_msg_list} {
        set tmp_list_1 [split ${tmp_1} " "]
        set rule_id_1 [lrange ${tmp_list_1} 0 3]
        set pass_objs [lindex ${tmp_1} end]
        set pass_net [lindex ${pass_objs} 0]
        set gen_blk [string trim [lindex ${pass_objs} 2]]
        set gen_blk_name [regsub {(\[)[^][]*]$} $gen_blk ""]
        set pass_file [lindex ${tmp_1} end-2]
        set tmp_list_2 [split ${miss_msg} " "]
        set rule_id_2 [lrange ${tmp_list_2} 0 3]
        set a_objs [lindex ${miss_msg} end]
        set a_net [lindex ${a_objs} 0]	
        set a_gen_blk [string trim [lindex ${a_objs} end]]
        # 获取漏报msg的generate block的name(不包括索引)
        set a_gen_blk_name [regsub {(\[)[^][]*]$} $a_gen_blk ""]
        set file_2 [lindex ${miss_msg} end-2]
        if {${rule_id_1} != ${rule_id_2} || ${a_gen_blk_name} != ${gen_blk_name} || ${pass_file}!= ${file_2}} {
            lappend not_match_list ${miss_msg}
        }
    }
    if {[llength ${not_match_list}] == 0} {
        return 1
    } else {
        return 0
    }
}
# #########################################################################################
# ## time: 20250401
# ## owner: kkxia
# ## description: E0200 - W426 SG在同一个地方以相同内容报告两次, 不合理
# ## solution: 判断已经比对通过的msg中是否包含完全一样的msg, 如果有, 则视为满足Diff_029
# ## case: B2_285
# #########################################################################################
proc Diff_029 {miss_list} {
    foreach pass_msg $::compare::passMessage {
        if {${miss_list} == ${pass_msg}} {
            return 1
        }
    }
    return 0
}
proc Diff_040 {A_list enno_list} {
    set e_obj_list [lindex ${enno_list} 9]
    set e_clk [get_nets [lindex ${e_obj_list} 0] -canonical]
    set e_ff [lindex ${e_obj_list} 1]
    set s_obj_list [lindex ${A_list} 9]
    set s_clk [lindex ${s_obj_list} 0]
    set s_clk [reformat_s_names_setup ${s_clk}]
    set s_ff [lindex ${s_obj_list} 1]
    set s_ff [reformat_s_names_setup ${s_ff}]
    if {${ff1} == ${s_ff}} {
        if {${e_clk} != "" && ${e_clk} == [get_nets ${s_clk} -canonical]} {
            return 1
        } else {
        return 0
        }
    }
return 0
}
# #########################################################################################
# ## time: 20250409
# ## owner: kkxia
# ## description: E0077 - W123, 1bit 变量A工具没报位宽 , elint报了
# ## solution: 对A工具报的变量进行get_nets, 如果和enno的相同且变量位宽为1, 则满足Diff_009
# ## case: B3_NEW_171
# #########################################################################################
proc Diff_009 {A_list enno_list} {
    set e_obj [lindex $enno_list 9]
    set e_top [lindex $e_obj 2]
    set s_obj [lindex $A_list 9]
    set s_top [lindex [split [lindex $s_obj 2] ":"] 1]
    set e_obj [lindex $e_obj 0]
    set e_obj_name [lindex [split $e_obj "\["] 0]
    set s_obj [lindex $s_obj 0]
    # 判断信号名是否一致
    if {$e_obj_name == $s_obj} {
        set e_obj "$e_top/${e_obj}"
        # 判断 enno-obj 的位宽是否为1
        set e_obj_wth [get_attributes [get_nets $e_obj] -attributes bit_width]
        if {$e_obj_wth == 1} {
            return 1
        } else {
            return 0
        }
    } else {
        return 0
    }
}
# #########################################################################################
# ## time: 20250417
# ## owner: kkxia
# ## description:
# ## solution: 以B2_088为例: 获取TOP.syn_clk连接的FF, 然后判断它们的clk是否有连接到input的信号上, 如果有, 则满足该差异
# ## case: B3_NEW_036, B2_088
# #########################################################################################
proc Diff_041_1 {false_list} {
    set if_diff ""
    set s_net [lindex ${false_list} 5 0]
    set ff_list [get_instances [get_nets ${s_net}] -filter {@view == "VERIFIC_DFFRS"}]
    foreach ff ${ff_list} {
        set pin [get_pins ${ff}/clk]
        if {${pin} != ""} {
            set if_in [get_attributes [get_ports [get_fanin -to ${pin} -buf_inv_only -tcl_list ] -bus ] -filter {@dir == "in"}]
            if {[lsearch -exact ${if_in} 1] != -1} {
                return 1
            }
        } else {
            return 0
        }
    }
    return 0
}
# Diff_041的另一种场景: enno误报一条, 如果该net没有driver, 视为enno正确, 满足Diff_041
proc Diff_041_2 {msg} {
    set false_obj [get_obj_from_msg $msg]
    set false_obj "TOP.U_TOP1/WWW[2].U_TOP2/icg_clk"
    # 2025-04-17: 需要获取enno原始的obj, 待鑫冰适配
    set if_ff [get_attributes [get_nets ${false_obj} ] -attributes driver]
    if {[llength ${if_ff}] == 0} {
        return 1
    }
    return 0
}
# #########################################################################################
## time: 20250418
## owner: kkxia
## description: E0259(TwoLevelLatchUsed) - STARC05-2.4.1.5, 综合差异, sg综合成了MUX
## solution: 遍历obj, 判断是否全部都是 VERIFIC_DLATCHRS, 如果是就满足该issue
## case: B1_16414, B1_16277
## #########################################################################################
proc Diff_052 {false_list} {
    set false_list [lindex ${false_list} 0]
    set objs [lindex ${false_list} 9]
    foreach e_obj ${objs} {
        set inst_num [llength [get_instances ${e_obj}]]
        set latch_num [llength [get_instances ${e_obj} -filter {@view == "VERIFIC_DLATCHRS"}]]
        if {${latch_num} != ${inst_num}} {
            return 0
        }
    }
    return 1
}
# 2025-04-21: 可能依赖谢天的修改, 待结论
proc Diff_045 {A_list enno_list} {
    set e_objs [lindex ${enno_list} end]
    set e_obj_1 [lrange ${e_objs} 0 2]
    set e_net [lindex ${e_objs} end]
    set s_objs [lindex ${A_list} end]
    set s_obj_1 [lrange ${s_objs} 0 2]
    set s_net [lindex ${s_objs} end]
    if {${e_obj_1} == ${s_obj_1}} {
        set top_name [get_top]
        set e_net_1 [lindex [split ${e_net} ${top_name}] end]
        set s_net_1 [lindex [split ${s_net} ${top_name}] end]
        if {${e_net_1} == ".VSS" && ${s_net_1} == ".VCC"} {
            return 1
        } else {
            set e_ff [lindex ${e_objs} 1]
            set tmp_net [get_nets ${e_ff}]
            if {${tmp_net} == ""} {
                return 0
            }
            set pinlist [get_pins [get_fanin -to ${tmp_net} -tcl_list ]]
            set pinlist [string map {"/" "."} ${pinlist}]
            if {[lsearch -exact ${pinlist} ${e_net}] != -1} {
                return 1
            } else {
                return 0
            }
        }
    }
    return 0
}
# #########################################################################################
# ## time: 20250422
# ## owner: kkxia
# ## description: E0233 STARC05-1.4.3.1b
# ## solution: ff的clk能get_fanin出MUX, 且drivers在clk的get_fanin之中
# ## case: B3_NEW_052, B3_NEW_077, B3_NEW_127, B3_NEW_135
# #########################################################################################
proc Diff_049 {false_list} {
    set e_obj [lindex ${false_list} 5]
    set clk "[get_instances [lindex ${e_obj} 1]]"
    set clk_list {}
    foreach tmp ${clk} {
        lappend clk_list "${tmp}/clk"
    }
    set driver [lindex ${e_obj} 0]
    set net [get_nets ${driver}]
    if {${net} != ""} {
        set mux [get_instances [get_fanin -to ${net} -tcl_list ] -filter {@view == "VERIFIC_MUX"}]
        if {[llength ${mux}] != 0} {
            foreach tmp_clk $clk_list {
                set tmp_net [get_nets [get_pins ${tmp_clk}]]
                if {${tmp_net} == ""} {
                    return
                }
                set net_list [get_fanin -to ${tmp_net} -tcl_list]
                if {[lsearch -exact $net_list ${driver}] == -1} {
                    return 0
                }
            }
        } else {
            return 0
        }
        return 1
    } else {
        return 0
    }
}
# #########################################################################################
# ## time: 20250427
### owner: kkxia
## description: E0145(AssignSameSignalInAlways) - STARC05-2.2.3.3: 对于多处原因都会导致report的错误, 只需要任选一出报出行号
# ## solution: 只要ff相同就满足该差异
# ## case: B3_NEW_052, B3_NEW_077,B3_NEW_127, B3_NEW_135
# #########################################################################################
proc Diff_076 {A_list enno_list} {
    set e_obj [lindex ${enno_list} end 0]
    set s_obj [lindex ${A_list} end 0]
    if {${e_obj} == ${s_obj}} {
        return 1
    } else {
        return 0
    }
}
# 2025.04.28: 将A工具name, X.Y.Z最后一个点转换为斜杠
proc reformat_A_names {str} {
    set top_name [get_top]
    if {![string match "${top_name}.*" ${str}]} {
        set str "${top_name}.${str}"
    }
    set parts [split $str "."]
    if {[llength $parts] > 1 &&[llength [split ${str} .]] > 2} {
        set last_part [lindex $parts end]
        set remaining_parts [lrange $parts0 end-1]
        set str "[join $remaining_parts .]/$last_part"
    } else {
        ERROR "Do not found in the str $str\[ennoid: $::compare::ennoid\]"
    }
    return $str
}
# #########################################################################################
# ## time: 20250428
# ## owner: kkxia
# ## description: A工具综合成latch, elint综合成FF
# # solution: A工具报的obj在elint全部都是FF, 则满足该差异
### case: B3_NEW_027
# #########################################################################################
proc Diff_102 {miss_list} {
    set objs [lindex ${miss_list} 9]
    foreach tmp_obj ${objs} {
        set tmp_obj [reformat_A_names ${tmp_obj}]
        if {[get_attributes [get_instances${tmp_obj}] -attributes view] != "VERIFIC_DFFRS"} {
            return 0
        }
    }
    return 1
}
# #########################################################################################
# ## time: 20250428
# ## owner: kkxia
# ## description: SG将pkt_idx优化了, 所以不认为pkt_idx会综合成FF
# ## solution: enno工具报的obj在elint是FF, 则满足该差异
# ## case: B2_044
# #########################################################################################
proc Diff_327 {false_list} {
    set false_list [lindex ${false_list} 0]
    set objs [lindex ${false_list} 9 0]
    set net [string trim [lindex [split ${objs} "="] 0]]
    # net是单比特
    set net "[get_top].${net}"
    set inst [get_instances "${net}"]
    if {${inst} != ""} {
        return 1
    }
    # net是多比特, 需要加上[*]
    set inst [get_instances "${net}[*]"]
    if {${inst} != ""} {
        return 1
    }
    return 0
}
# #########################################################################################
# ## time: 20250428
# ## owner: kkxia
# ## description: 综合差异, elint的ff既有set又有reset,sg不是
# ## solution: enno工具报的obj在elint是FF, 则满足该差异
# ## case: B2_044
# #########################################################################################
proc Diff_319 {false_list} {
    set false_list [lindex ${false_list} 0]
    set objs [lindex ${false_list} 9]
    set ff "[lindex ${objs} end].[lindex ${objs} 1]"
    set reset_net [lindex ${objs} 0]
    # 判断port连的instance是不是FF
    if {[get_instances ${ff} -filter {@view == "VERIFIC_DFFRS"}] != ""} {
        set net [get_nets [get_pins ${ff}/s]]
        if {${net} == ""} {
            return
    }
    set net_list [get_fanin -to ${net} -tcl_list]
    # 判断reset signal在不在FF/s的fanin cone, 且FF的reset是否为空
    if {[lsearch -exact ${net_list} ${reset_net}] && [get_pins ${ff}/r] != ""} {
        return 1
    }
    }
    return 0
}
# #########################################################################################
# ## time: 20250428
# ## owner: kkxia
# ## description: 认为一个FF的set和reset只用报一个,不用全都报
# ## solution: elint只要报了该FF的reset或者set的fanin cone中的net, 就满足该差异
# ## case: B1_20525
# #########################################################################################
proc Diff_318 {miss_list} {  
    set objs [lindex ${miss_list} 9]  
    set ff "[lindex ${objs} end].[lindex ${objs} 1]"  
    set net [lindex ${objs} 0]  
    # 第一个obj只要是该ff的reset 或是 set 的fanin cone就满足差异  
    # 判断port连的instance是不是FF  
    if {[get_instances ${ff} -filter {@view == "VERIFIC_DFFRS"}] != ""} {  
        # 场景1: elint报reset  
        set pin1 [get_nets [get_pins ${ff}/r]]  
        if {${pin1} != ""} {  
            set net_list [get_fanin -to ${pin1} -tcl_list]  
            if {[lsearch -exact ${net_list} ${net}]} {  
                return 1
            }  
        }
        # 场景2: elint报set  
        set pin2 [get_nets [get_pins ${ff}/s]]  
        if {${pin2} != ""} {  
            set net_list [get_fanin -to ${pin2} -tcl_list]  
            if {[lsearch -exact ${net_list} ${net}]} {  
                return 1  
            }  
        }  
    }  
    return 0    
}  
# ######################################################################################### 
# ## time: 20250428  
# ## owner: kkxia  
# ## description: elint和A工具报的ff都是违规的, elint和A工具报任意一个ff都是符合rule的  
# ## solution: elint的output的那个FF只要在它报的另一个FF的fanin cone, 就满足该差异  
# ## case: B2_435  
# ## #########################################################################################  
proc Diff_316 {A_list enno_list} {  
    set e_objs [lindex ${enno_list} end]  
    set e_f1 [lindex ${e_objs} 0]  
    set e_f2 [lindex ${e_objs} 1]  
    set s_objs [lindex ${A_list} end]  
    set s_f1 [lindex ${s_objs} 0]  
    set s_f2 [lindex ${s_objs} 1]  
    if {${e_f1} == ${s_f1} && [get_instances ${e_f1} -filter {@view == "VERIFIC_DFFRS"}] != ""} {  
        # 判断elint的f1的Q是否接在了f2的clk
        set f2_clk "${e_f2}/clk"  
        set pin [get_pins ${f2_clk}]  
        if {${pin} == ""} {  
            return 0  
        }  
        set inst_list [get_instances [get_fanin -to ${pin} -tcl_list]]  
        if {[lsearch -exact ${inst_list} ${e_f1}]} {  
            return 1  
        }  
    }  
    return 0  
}  
# #########################################################################################  
# ## time: 20250429
# ## owner: kkxia  
# ## description: 综合差异, 由于三态门的input和control都是0, 因此elint将三态门优化调了, 而sg保留了三态门  
# ## solution: 是FF且没有接三态门, 就满足该差异  
# ## case: B1_07853  
# #########################################################################################  
proc Diff_309 {miss_list} { 
    set net [lindex ${miss_list} 9 0]  
    set net [reformat_A_names ${net}]  
    set tmp_net [get_nets ${net}]  
    if {${tmp_net} == ""} {  
        return 0  
    }  
    # 判断是否FF  
    set if_ff [get_instances ${tmp_net} -filter {@view == "VERIFIC_DFFRS"}]  
    # 判断是否接了三态门(VERIFIC_TRI)
    set if_tri [get_instances [lindex [get_fanin to ${tmp_net} -depth 1 -tcl_list ] 4] -filter {@view == "VERIFIC_TRI"}]  
    if {${if_ff} != "" && ${if_tri} == ""} {  
        return 1  
    }  
    return 0  
}  
# #########################################################################################  
# ## time: 20250429  
# ## owner: kkxia  
# ## description: 综合差异, elint没有综合出TOP.w1  
# ## solution: A工具报的两个latch, 只要任意一个在elint中不存在, 就满足该diff  
# ## case: E0259_027  
# #########################################################################################  
proc Diff_100 {miss_list} {  
    set objs [lindex ${miss_list} 9]  
    foreach inst ${objs} {  
        set inst [reformat_A_names ${inst}]  
        if {[get_instances ${inst} -filter {@view == "VERIFIC_DLATCHRS"}] == ""} {  
            return 0  
        }  
    }  
    return 1  
}  
# #########################################################################################  
# ## time: 20250507  
# ## owner: kkxia  
# ## description: E0260 - LatchFeedback: 综合差异, Verific没有全部bit都综合成Latch,   
# ## solution: 获取A工具比elint多的bit, 如果在elint没有综合出来, 或者是没有综合成Latch, 这两种情况都视为满足该差异  
# ## case: B2_118  
# #########################################################################################  
proc Diff_366-1 {false_list miss_list} {  
    set e_obj [lindex ${false_list} end-1 0]  
    set s_obj [lindex [reformat_s_names_setup [lindex ${miss_list} end-1 0]] 0]  
    set e_obj_name [get_nets $e_obj -bus]  
    set s_obj_name [get_nets $s_obj -bus]  
    # 1. 判断e和s的信号名是否一致  
    if {${e_obj_name} == ${s_obj_name}} {  
        # 2. 获取A工具比elint多的bit  
        set extra_bits [get_extra_bits ${e_obj} ${s_obj}]  
        # 3. 判断多出的bit在elint的综合情况  
        if {[get_instances ${extra_bits}] == ""} {
            return 1
        } else {
            if {[get_instances ${extra_bits} -filter @view=="VERIFIC_DLATCHRS"] == ""} {
                return 1
            }
        }
    }
    return 0
}
# ## 和Diff_366-1属于同一类差异
# ## B1_16537: 漏报一条elint内悬空的net, 如果判断A工具报的net在elint内是悬空的, 就满足Diff_366这条差异
proc Diff_366-2 {miss_list} {
    set obj [lindex ${miss_list} 9 0]
    set obj [reformat_A_names ${obj}]
    if {[get_nets ${obj}] != ""} {
        if {[get_instances [get_nets ${obj}]] == ""} {
            return 1
        } else {
            return 0
        }
    } else {
        return 1
    }
    return 0
}
# ##########################################################################################
# ## time: 20250507
# ## owner: kkxia
# ## description: 综合差异, Verific Latch的输出端no load
# ## solution: 判断漏报的obj, 右侧是否为空(是否是no load)
# ## case: B2_066
# ##########################################################################################
proc Diff_365 {miss_list} {
    set obj [lindex ${miss_list} 9 0]
    set net [get_nets ${obj}]
    if {${net} == ""} {
        return 0
    }
    foreach tmp_obj ${net} {
        if {[get_fanout -from ${tmp_obj} -tcl_list] != ""} {
            return 0
        }
    }
    return 1
}
# ##########################################################################################
# ## time: 20250508
# ## owner: kkxia
# ## description:
# ## solution: 首先判断obj是不是一个Latch, 如果是, 且它的d到q端是一个环, 那么视为符合“将一个信号赋给自己”, 也就满足该差异
# ## case: E0260_048 E0260_049 E0260_051 E0260_053 E0260_055 E0260_057 E0260_059 E0260_060
# ## E0260_061 E0260_062 E0260_063 E0260_073 E0260_074 E0260_076 E0260_078 E0260_080
# ## E0260_082 E0260_084 E0260_085 E0260_086 E0260_087 E0260_088
# ##########################################################################################
proc Diff_095 {false_list} {
    set false_list [lindex ${false_list} 0]
    set obj [lindex ${false_list} 9 0]
    foreach tmp_obj [get_instances ${obj}] {
        if {[get_instances ${tmp_obj} -filter @view=="VERIFIC_DLATCHRS"] != ""} {
            set pin [get_pins ${tmp_obj}/d]
            if {${pin} != ""} {
                set fanin_cone [get_fanin -to ${pin} -tcl_list]
                set latch_q "${tmp_obj}/q"
                if {![lsearch -exact ${fanin_cone} ${latch_q}]} {
                    return 0
                }
            }
        } else {
            return 0
        }
    }
    return 1
}
# ##########################################################################################
# ## time: 20250508
# ## owner: kkxia
# ## description: loop对象报告的起点不一致
# ## solution: A工具和elint的对象分别进行排序后, 如果一致, 则满足该差异
# ## case: E0344_052 E0344_062 E0344_074 E0344_077 E0344_093 E0344_095 E0344_096 E0344_097
# ##########################################################################################
proc Diff_109 {A_list enno_list} {
    set A_num [lindex ${A_list} 4]
    set enno_num [lindex ${enno_list} 4]
    set e_obj [lsort [split [lindex ${enno_list} end] "-"]]
    set s_obj [lsort [split [lindex ${A_list} end] "-"]]
    if {${e_obj} == ${s_obj} && ${A_num} == ${enno_num}} {
        return 1
    } else {
        return 0
    }
    return 0
}
# 待get_fanin/fanout适配 combloop标签
proc Diff_370 {false_list} {
    # pink false_list:${false_list}
    set false_list [lindex ${false_list} 0]
    set obj [lindex ${false_list} 5]
    foreach tmp_obj $obj {
        if {[get_ports ${tmp_obj}] != "" || [get_nets ${tmp_obj}] != "" || [get_pins ${tmp_obj}] != "" } {
            set obj
        }
    }
    return 0
}
# ##########################################################################################
# ## time: 20250508
# ## owner: kkxia
# ## description: A工具报比特位, enno只报信号名
# ## solution: 只比较两者的信息名是否一致
# case: E0035_016, E0035_027, E0035_028, E0035_030, E0035_031, E0035_033, E0035_047, E0035_025,
#       E0035_040, E0035_056, E0035_064, E0035_015, E0035_019, E0035_035, E0035_057,
#       E0035_004, E0035_002, E0035_006, E0035_007, E0035_009, E0035_010, E0035_012, E0035_013,
# E0035_022, E0035_037, E0035_050, E0035_062, E0035_065
# #########################################################################################
proc Diff_439 {A_list enno_list} {
    set e_obj [lindex ${enno_list} 5]
    set A_obj [lindex ${A_list} 5]
    set e_module [lindex ${e_obj} end]
    set A_module [string map  {":" ""} [lindex ${A_obj} end]]
    # 判断hierarchy是否相同
    if {${e_module} == ${A_module}} {
        set A_net [lindex [split ${A_obj} "\["] 0]
        set e_net [lindex ${e_obj} 0]
        if {${e_net} == ${A_net}} {
            return 1
        }
    }
    return 0
}
# #########################################################################################
# ## time: 20250529
# ## owner: kkxia
# ## description: 变量片选用做循环变量, A工具报整个信号, elint报片选信号
# ## solution: 首先判断两个工具报的信号名是否一致, 如果一致, 通过elint的行号, 判断那一行的循环变量和elint报的是否一致
# ## case: E0183_061
# #########################################################################################
proc Diff_163 {A_list enno_list} {
    set e_num [lindex ${enno_list} 4]
    set e_file [lindex ${enno_list} 7]
    set s_obj [lindex ${A_list} 5]
    set e_obj [lindex ${enno_list} 5]
    set e_obj_name [lindex [split ${e_obj} "\["] 0]
    if {${e_obj_name} == ${s_obj}} {
        # 根据行号获取该行的循环变量
        set for_line [string trim [exec bash -c "sed -n ' '${e_num}'p' ${e_file}"] " "]
        set tmp [lindex [split ${for_line} ";"] 0]
        regexp {for\s\((.*)=} $tmp -> loop_var
        set loop_var [string trim ${loop_var} ""]
        if {${loop_var} == ${e_obj}} {
            return 1
        }
    }
    return 0
}
# #########################################################################################
## time: 20250529
## owner: kkxia
## description: 一个for循环有多个循环变量, elint分多条报(a和b), A工具合并报一条(a,b)
## solution: 首先判断两个工具报的信号名是否一致, 如果一致, 通过elint的行号, 判断那一行的循环变量和elint报的是否一致
## case: E0183_061
# #########################################################################################
proc Diff_162 {false_list obj_unmatch_list} {
    set e_tmp_msg ${false_list}
    set s_tmp_msg [list]
    foreach tmp_msg $Obj_unmatch_list {
        if { [lindex ${tmp_msg} 0] == "E"} {
            lappend e_tmp_msg ${tmp_msg}
        } else {
            lappend s_tmp_msg ${tmp_msg}
        }
    }
    if { [llength ${e_tmp_msg}] > 1} {
        foreach tmp_e ${e_tmp_msg} {  
            set e_num [lindex ${tmp_e} 4]  
            set e_file [lindex ${tmp_e} 7]  
            set e_obj [lindex ${tmp_e} 5]  
            foreach tmp_s ${S_tmp_msg} {  
                set s_num [lindex ${tmp_s} 4]  
                set s_file [lindex ${tmp_s} 7]  
                set s_obj_list [split [lindex ${tmp_s} 5] ","]  
                if {${e_num} != ${s_num} || ${e_file} != ${s_file} || [lsearch -exact ${s_obj_list} ${e_obj}] < 0} {  
                    return 0  
                }  
            }
        }
    } else {
        return 0
    }
    return 1
}  
######################################################################################### 
## time: 20250529  
## owner: kkxia  
## description: 一个for循环有多个循环变量, obj不匹配, A工具报了(a, b)和a, elint报了a和b  
## solution: 判断(a,b) 中不是obj不匹配的那个obj是不是在passlist中已经存在, 如果是, 再判断enno的obj是否在A工具的objList中  
## case: E0183_056,E0183_057  
######################################################################################### 
proc Diff_161 {A_list enno_list} {  
    set pass_msg_list $::compare::passMessage  
    set e_obj [lindex ${enno_list} 5]
    set s_obj [split [lindex ${A_list} 5] ","]  
    set other_obj [list]  
    foreach tmp_obj ${s_obj} {  
        if {${tmp_obj} != ${e_obj}} {  
            lappend other_obj ${tmp_obj}  
        }  
    }  
    set if_pass_obj 0  
    foreach pass_msg ${pass_msg_list} {  
        set ennoid [lindex ${pass_msg} 3]  
        if {${ennoid} == "ForLoopidxNotInteger"} {  
            set obj [lindex ${pass_msg} 5]  
            if {${obj} in ${other_obj}} {  
                set if_pass_obj 1  
                break  
            }  
        }  
    }  
    if {${if_pass_obj} == 1 && [llength ${s_obj}] > 1 && $e_obj in $s_obj} {  
        return 1  
    } else {  
        return 0  
    }
} 
######################################################################################### 
## time: 20250328  
## owner: kkxia  
## description: E0257 - W18, tool A 综合出latch, verific综合出ff, enno误报  
## solution: 判断误报的obj是不是VERIFIC_DLATCHRS, 所有obj都不是, 则视为满足Diff_032  
## case: B3_NEW_037  
## ######################################################################################### 
proc Diff_032 {miss_msg} {
    set miss_obj [get_obj_from_msg $miss_msg]
    set res_list [list]
    set tmp_list ""
    set ret 0
    foreach tmp_obj ${miss_obj} {
        set cell_type [get_attributes [get_instances ${tmp_obj}] -attribute view]
        if {${cell_type} != "VERIFIC_DFFRS"} {
            lappend tmp_list "${tmp_obj}"
        }
    }
    if {[llength ${tmp_list}] == 0} {
        set ret 1
    }
    return $ret
}
# #########################################################################################
## time: 20250328
## owner: kkxia
## description: E0257 - W18, tool A: sg 综合出mux , verific综合出latch, enno误报
## solution: 判断误报的obj是不是VERIFIC_DLATCHRS, 如果不是, 视为满足Diff_030
## case: B1_16051, B1_16052, B1_16064
# #########################################################################################
proc Diff_030 {false_msg} {
    set false_obj [get_obj_from_msg $false_msg]
    foreach obj $false_obj {
        if {[get_attributes [get_instances $obj] -attribute view] ne "VERIFIC_DLATCHRS"} {
            return 0
        }
    }
    return 1
}
# #########################################################################################
# ## time: 20250402
# ## owner: kkxia
# ## description: E0257 - W18, sg全部是latch, verific在bus上只有一部分生成了latch
# ## solution: 如果行号相同, 且双方obj_name相同, 通过sg的obj get出来的latch和lenno报的数量一致
# ## case: B2_118
# #########################################################################################
proc Diff_031 {false_list miss_list} {
    set not_match ""
    # set false_list [lindex ${false_list} 0]
    # set miss_list [lindex ${miss_list} 0]
    set e_num [lindex ${false_list} 4]
    set s_num [lindex ${miss_list} 4]
    if {${e_num} == ${s_num}} {     # 2025-04-27: 行号现在有问题, issue: 36742
        set false_obj [lindex ${false_list} end 0]
        set miss_obj [lindex ${miss_list} end 0]
        set false_obj_name [lindex [split ${false_obj} "\["] 0]
        set miss_obj_name [lindex [split ${miss_obj} "\["] 0]
        if {${false_obj_name} == ${miss_obj_name}} {
            set miss_obj [lindex [add_top_to_obj ${miss_obj}] 0]
            set false_obj [lindex [add_top_to_obj ${false_obj}] 0]
            set inst_num [llength [get_nets ${miss_obj}]]
            set latch_num [llength [get_instances ${miss_obj} -filter {@view == "VERIFIC_DLATCHRS"}]]
            if {[llength [get_nets ${false_obj}]] == ${latch_num} && ${latch_num} < ${inst_num}} {
                return 1
            } else {
                return 0
            }
        } else {
            return 0
        }
    } else {
        return 0
    }
}
# #########################################################################################
# ## time: 20250421
# ## owner: kkxia
# ## description: E0289 W446
# ## solution: 如果obj_name 相同, 视为满足Diff_047
# ## case: B1_04866
# #########################################################################################
proc Diff_047 {A_list enno_list} {
    set s_rule [lindex ${A_list} 1]
    if {${s_rule} == "W446"} {
        set s_objs [lindex ${A_list} end]
        set e_objs [lindex ${enno_list} end]
        set e_obj "[lindex ${e_obj} 1].[lindex ${e_objs} 0]"
        set s_obj "[lindex ${s_obj} 1].[lindex ${s_objs} 0]"
        set e_obj_name [lindex [split ${e_obj} "\["] 0]
        set s_obj_name [lindex [split ${s_obj} "\["] 0]
        set s_obj_name [string map {":" ""} ${s_obj_name}]
        if {${e_obj_name} == ${s_obj_name}} {
            return 1
        }
    }
    return 0
}
# #########################################################################################
# ## time: 20251009
# ## owner: kkxia
# ## description: E0253 STARCO5-1.3.1.7: enno和sg对于struct类型的obj打印形式不一致; 
# ## enno: stl.out1[0][0], sg: stl[out1][0][0]
# ## solution: 将sg的obj转换为enno格式, 转换后一致, 则满足Diff_532
# ## case: B1_12352 B1_12353
# #########################################################################################
proc Diff_537 {A_list enno_list} {
    set s_obj [lindex ${A_list} 5 0]
    # 将sg的obj转换为enno格式
    set s_obj [reformat_s_names_setup ${s_obj}]
    # 去除最外层的{}
    set s_obj [string trim ${s_obj} "{}"]
    set e_obj [lindex ${enno_list} 5 0]
    if {${e_obj} == ${s_obj}} {
        return 1
    } else {
        return 0
    }
    return 0
}
# #########################################################################################
# ## time: 20251010
# ## owner: kkxia
# ## description: E0297 - STARC-2.10.3.2b: sg只报了function名字: fun1, enno报了function名字以及参数: fun1(a)
# ## solution: enno的只保留function_name, 再去和sg对比
# ## case: B1_05128 B2_457 B2_464 B1_05455 B3_NEW_015
# #########################################################################################
proc Diff_627 {A_list enno_list} {
    set s_obj [lindex ${A_list} 5]
    set e_obj [lindex ${enno_list} 5]
    set e_func [lindex ${e_obj} 2]
    # 将enno的function_name(args), 改为只有function_name
    set e_func [lindex [split ${e_func} "\("] 0]
    lset e_obj 2 ${e_func}
    if {${e_obj} == ${s_obj}} {
        return 1
    } else {
        return 0
    }
}
# #########################################################################################
# ## time: 20251009
# ## owner: kkxia
# ## description: obj不一致, sg在有些报错hier带genrate for, 有些不带, enno统一都带
# ## solution: 将enno的hier中的generate去掉, 再跟sg对比: TOP:gen1 --> TOP
# ## case: B2_380 B3_NEW_119 B3_NEW_178
# #########################################################################################
proc Diff_594 {A_list enno_list} {
    set s_obj [lindex ${A_list} 5]
    set e_obj [lindex ${enno_list} 5]
    set e_hier [lindex ${e_obj} end]
    set e_hier [lindex [split ${e_hier} ":"] 0]
    lset e_obj end ${e_hier}
    if {${s_obj} == ${e_obj}} {
        return 1
    } else {
        return 0
    }
}
# #########################################################################################
# ## time: 20251010
# ## owner: kkxia
# ## description: E0177 - DisallowCaseX-ML, obj不一致, sg的generate没有索引: TOP:gen1, 而enno有: TOP:gen1[1]
# ## solution: 将enno的hier中的generate的索引去掉再跟sg比: TOP:gen1[1] --> TOP:gen1
# ## case: E0177_260 E0177_261 E0177_262 E0177_263 E0177_264 E0177_265 E0177_266 E0177_267
# #########################################################################################
proc Diff_502 {A_list enno_list} {
    set s_obj [lindex ${A_list} 5]
    set e_obj [lindex ${enno_list} 5]
    # 去除enno_obj中generate后面的方括号: TOP:gen1[1] --> TOP:gen1
    set e_obj [regsub {\[.*?\]} $e_obj ""]
    if {${s_obj} == ${e_obj}} {
        return 1
    } else {
        return 0
    }
}
# #########################################################################################
# ## time: 20251010
# ## owner: kkxia
# ## description: E0154 - W552: sg的obj中含有“SpyInst_@”关键字
# ## solution: 删除sg_obj中的“SpyInst_@”后再和enno的对比
# ## case: E0154_036 E0154_028
# #########################################################################################
proc Diff_387 {A_list enno_list} {
    set s_obj [lindex ${A_list} 5]
    if {[string first ":_SpyInst_0@" ${s_obj}] == -1} {
        return 0
    }
    set e_obj [lindex ${enno_list} 5]
    set s_obj [regsub {:_SpyInst_0@} $s_obj ":"]
    if {${e_obj} == ${s_obj}} {
        return 1
    } else {
        return 0
    }
}
# #########################################################################################
# ## time: 20251011
# ## owner: kkxia
# ## description: E0125 STARC05-1.2.1.1a: 18版本的sg没有报hier, 因此将enno的hier去掉再进行对比
# ## 22版本的sg有hier, 理论上前面compare阶段就可以match, 走不到这个diff
# ## solution: 将enno的hier去掉再跟sg比: U_TEST1.U_TEST.clk --> clk
# ## case: B2_384
# #########################################################################################
proc Diff_482 {A_list enno_list} {  
    set s_obj [lindex ${A_list} 5]  
    set e_obj [lindex ${enno_list} 5]  
    # enno: 获取没有hier的obj  
    set e_obj [lindex [split ${e_obj} "."] end]  
    if {${e_obj} == ${s_obj}} {  
        return 1  
    } else {  
        return 0  
    }  
}  
# ######################################################################################### 
# ## time: 20251011  
# ## owner: kkxia  
# ## description: E0239 - STARC05-1.3.1.3: flop信号 SG 报在FF q 连出去的net上(SG有的报在FF上), elint统一报在FF上  
# ## solution: 通过get_nets -canonical 验证enno和sg的net是否在一条线上  
# ## case: B1_20742 B1_20739  
# ######################################################################################### 
proc Diff_264 {A_list enno_list} {  
    set s_obj [lindex ${A_list} 9]  
    set e_obj [lindex ${enno_list} 9]  
    set s_obj_1 [lindex ${A_list} 5]  
    set e_obj_1 [lindex ${enno_list} 5]  
    set e_other "[lindex ${e_obj_1} 0] [lindex ${e_obj_1} 2] [lindex ${e_obj_1} 3]"  
    set s_other "[lindex ${s_obj_1} 0] [lindex ${s_obj_1} 2] [lindex ${s_obj_1} 3]"  
    # 如果除了flop之外的其他obj全部都一致  
    if {${e_other} == ${s_other}} {  
        set e_flop [lindex ${e_obj} 1]  
        set s_flop [lindex ${s_obj} 1]  
        set s_flop [reformat_s_names_setup ${s_flop}]  
        set e_net [get_nets ${e_flop} -canonical]  
        set s_net [get_nets ${s_flop} -canonical]  
        if {${e_net} != "" && ${s_net} != "" && ${e_net} == ${s_net}} {  
            return 1  
        } else {  
            return 0  
        }  
    } else {  
        return 0  
    }  
}  
# ######################################################################################### 
# ## time: 20251013  
# ## owner: kkxia  
# ## description: E0089 - TristateName: enno: 若合并之后的bit与声明的位宽相同, 则只报错变量名, 不报index; 而sg只报信号名  
# ## solution: 对enno的obj进行fold bus bits(合并多比特的打印), 然后和sg进行对比;   
# ## enno: [fold_bus_bits [get_nets TOP/XXXXX]] --> TOP/u_i_mode_buf_0/u_ram_lp/data_o[7:0], 然后用变量名: data_o[7:0] 和sg比
## case: B3_NEW_058     B2_125
# #########################################################################################
proc Diff_652 {A_list enno_list} {
    set s_obj [string trim [lindex ${A_list} 9] "{}"]
    set e_obj [lindex ${enno_list} 9]
    set e_obj [fold_bus_bits [get_nets ${e_obj}]]
    set e_obj_name [lindex [split ${e_obj} "/"] end]
    if {${s_obj} == ${e_obj_name}} {
        return 1
    } else {
        return 0
    }
}
# #########################################################################################
# ## time: 20251013
# ## owner: kkxia
# ## description: E0313 - sim_race02: 两种场景: 1. enno报了索引, sg没报; 2. enno是大端, sg是小端
# ## solution: 1. 去掉索引; 2. 转换sg为enno格式
# ## case: B2_396 B2_395
# #########################################################################################
proc Diff_289 {A_list enno_list} {
    set s_obj [lindex ${A_list} 5]
    set e_obj [lindex ${enno_list} 5]
    # 先判断两个行号是否一致
    set e_line "[lrange ${e_obj} 0 1]"
    set s_line "[lrange ${s_obj} 0 1]"
    if {${e_line} == ${s_line}} {
        # 场景1: enno报了索引, 而sg没有报
        set s_net [lindex ${s_obj} end]
        set e_net [lindex ${e_obj} end]
        if {[string first "\[" ${s_net}] == -1} {
            set e_net_name [lindex [split ${e_net} "\["] 0]
            if {${s_net} == ${e_net_name}} {
                return 1
            }
        }
        # 场景2: enno报大端: XXX[1 : 0], sg报小端: XXX[0 : 1]
        if {[string first "\[" ${s_net}] != -1 && [string first "\[" ${e_net}] != -1} {
            set s_net [reverse_bit_range ${s_net}]
            if {$s_net == $e_net} {
                return 1
            }
        }
        return 0
    }
    return 0
}
# #########################################################################################
# ## time: 20251024
# ## owner: kkxia
# ## description: E0239 - STARC05-1.3.1.3: objunmatch, 对于reset signal, enn和sg都报了内建信号, 因此不对比该项
# ## solution: 只对比其他项
# ## case: B3_NEW_121, B4_399
# #########################################################################################
proc Diff_270 {A_list enno_list} {  
    set s_obj [lindex ${A_list} 5]  
    set e_obj [lindex ${enno_list} 5]  
    # 如果除了reset signal之外, 其他obj一致, 视为满足该差异  
    set e_obj_1 [concat [lrange ${e_obj} 1 1] [lindex ${e_obj} end]]
    set s_obj_1 [concat [lrange ${s_obj} 1 1] [lindex ${s_obj} end]]  
    if {${e_obj_1} == ${s_obj_1}} {  
        return 1  
    } else {  
        return 0  
    }
}  
# #########################################################################################  
## time: 20251024  
## owner: kkxia  
## description: E0230 - STARCGS-1.3.1.3: enno漏报, 对于out1, enno和sg的综合不一致, enno是ff, sg是组合逻辑  
## solution: instance 在enno综合是ff, 视为满足该差异  
## case: B4_399  
#########################################################################################  
proc Diff_723 {miss_msg} {  
    set s_obj [lindex ${miss_msg} 5]  
    set reset_net [lindex ${s_obj} 2]  
    set reset_net [reformat_s_names_setup ${reset_net}]  
    if {[get_attributes [get_instances ${reset_net}] -attributes view] == "VERIFIC_DFFRS"} {  
        return 1  
    } else {  
        return 0  
    }
}  
# #########################################################################################  
## time: 20251027  
## owner: kkxia  
## description: E0220 - W111: obj不匹配, sg (w13[7:6,4:2,0]) elint(w13[7:6,4:2,...)  
## solution: 以逗号分隔, 看前两项是否完全一致  
## case: B2_169 B2_400 B3_125 B3_143 B3_140 B3_187 B3_NEW_108 B3_NEW_093 B4_067  
#########################################################################################  
proc Diff_475 {A_list enno_list} {
    set s_obj [lindex ${A_list} 5]  
    set e_obj [lindex ${enno_list} 5]  
    set e_top_name [lindex ${e_obj} 1]  
    set s_top_name [lindex ${s_obj} 1]  
    if {${e_top_name} != "" && ${e_top_name} == ${s_top_name}} {  
        set e_net [lindex ${e_obj} 1]  
        set s_net [lindex ${s_obj} 1]  
        # sg: w13[7:6,4:2,0]; e: w13[7:6,4:2,...], 以逗号分隔, 看前两项是否完全一致  
        if {[lrange [split ${e_net} ","] 0 1] == [lrange [split ${s_net} ","] 0 1] } {  
            return 1  
        } else {  
            return 0  
        }  
    } else {  
    # 报的hierarchy不一致  
        return 0  
    }  
    return 0  
}
#########################################################################################  
## time: 20251029
## owner: chenhaiyang
## description: E0364 - W111: 误报, sg把and门到ff rst的逻辑综合成了latch
## solution: 判断and门和ff组合的情况
## case: B4_045 B4_127 B4_128 B4_179 B4_198 B4_201 B4_314 B4_399 B4_448
#########################################################################################  
# proc Diff_ca_001 {enno_list} {
#     set obj_lst [lindex $enno_list 9]
#     set rst_type [lindex $obj_lst 0]
#     set net [lindex $obj_lst 1]
#     set ff [lindex $obj_lst 2]
#     set rst_pin [join [concat {*}$ff r] /]
#     if {$rst_type == "set"} {
#         set rst_pin [join [concat {*}$ff s] /]
#     }
#     set tmp_gates [get_fanin -to [get_nets [get_pins $rst_pin]] -buf_inv_only -leaf -tcl_list]
#     set ahead_gate ""
#     set ahead_gate_type ""
#     foreach gate $tmp_gates {
#         set gate_type [get_attributes $gate -attributes view]
#         if {$gate_type in "VERIFIC_AND"} {
#             set ahead_gate $gate
#             set ahead_gate_type $gate_type
#             break
#         }
#     }
#     if {$ahead_gate_type != "VERIFIC_AND"} {return 0}
#     set ahead_gate_pins [get_pins $ahead_gate -filter {@dir == "in"}]
#     set from_src ""
#     foreach pin $ahead_gate_pins {
#         set tmp_trace [get_fanin -to [get_nets $pin] -buf_inv_only -tcl_list]
#         set start_point [lindex $tmp_trace end]
#         if {$start_point == [get_top]} {
#             set start_point [lindex $tmp_trace end-1]
#         }
#         lappend from_src $start_point
#     }
#     set from_src [concat {*}$from_src]
#     if {[lsort -unique $from_src] > 1} {
#         return 1
#     }
#     return 0
# }
# #########################################################################################  
# ## time: 20251113
# ## owner: wanghan
# ## description: E0364 - W111: 误报, 三方综合成了latch
# ## solution: 判断门和ff组合的情况
# ## case:
#########################################################################################  
proc Diff_ca_001 {enno_list} {
    if {[regexp {OBJ__TAG} $enno_list]} {
        return 0
    }
    set re 0
    set obj_lst [lindex $enno_list 9]
    set var [lindex $obj_lst 1]
    if {[get_nets $var] != ""} {
        if {[llength [get_pins [get_fanout -from [get_nets $var] -pin_list] -filter {@name=="r"||@name=="s"}]] > 0} {
            set inst_list [get_instances [get_fanin -to [get_nets $var] -pin_list]]
            set gate_list {VERIFIC_INV VERIFIC_BUF VERIFIC_AND VERIFIC_OR VERIFIC_XOR VERIFIC_XNOR VERIFIC_MUX}
            foreach inst $inst_list {
                set inst_type [get_attributes $inst -attributes view]
                if {[lsearch -exact $gate_list $inst_type] != -1} {
                    set re 1
                    break
                }
            }
        }
    }
    return $re
}
# #########################################################################################  
# ## time: 20251030
# ## owner: wanghan
# ## description: E0034 - STARC05-1.1.4.6b: 误报, input端口接常值, 电路一样, 且三方接了电源和地的
# ## solution: 判断是否是design中的常值
# ## case:
#########################################################################################  
proc Diff_ca_003 {enno_list} {
    set re 0
    set obj_list [lindex $enno_list 9]
    set tmp_pin_list [get_pins [lindex $obj_list 0]]
    if {$tmp_pin_list != ""} {
        set constant_type [lindex $obj_list 2]
        foreach pin $tmp_pin_list {
            set tmp_instance [lreverse [get_instances [get_fanin -to [get_nets [get_pins $pin]] -pin_list]]]
            foreach var $tmp_instance {
                set type [get_attributes $var -attributes view]
                if {$type == "VERIFIC_BUF"} {
                    continue
                } elseif {$type == "VERIFIC_GND"} {
                    set tool_value 0
                } elseif {$type == "VERIFIC_PWR"} {
                    set tool_value 1
                } elseif {$type == "VERIFIC_INV"} {
                    set tool_value [expr !($tool_value)]
                } else {
                    return 0
                }
            }
            if {$constant_type == "tied-high" && $tool_value == "1"} {
                set re 1
            } elseif {$constant_type == "tied-low" && $tool_value == "0"} {
                set re 1
            } else {
                set re 0
                break
            }
        }
    }
    return $re
}
# #########################################################################################  
# ## time: 20251104
# ## owner: chenhaiyang
# ## description: E0338 - 部分port虽然有连接net,但是net后面悬空
# ## solution: 判断net后面是否有leaf
# ## case: Gen01-m011
#########################################################################################  
proc Diff_ca_007 {enno_list} {
    set obj_lst [lindex $enno_list 9]
    set hier [lindex $obj_lst 2]
    set hier [lmap i [split $hier :] {lindex [split $i @] 0}]
    lappend hier [lindex $obj_lst 1] [lindex $obj_lst 0]
    set hier [concat {*}$hier]
    set pin [join $hier /]
    set pin [get_pins $pin]
    if {$pin == ""} {
        return 0
    }
    foreach i $pin {
        set ahead_leaf [get_fanin -to $i -depth 1 -tcl -leaf]
        if {$ahead_leaf == ""} {
            return 1
        }
        set behind_leaf [get_fanout -from $i -depth 1 -tcl -leaf]
        if {$behind_leaf == ""} {
            return 1
        }
    }
    return 0
}
# #########################################################################################  
# ## time: 20251104  
# ## owner: chenhaiyang  
# ## description: E0251 - 当ff的r/s pin为0时, sg综合的ff没有r/s pin, enno有  
# ## solution: 判断r/s pin是否都为0  
# ## case: Gen01-m011  
# #########################################################################################  
proc Diff_ca_009 {enno_list} {  
    set obj_lst [lindex $enno_list 9]  
    set inst [get_instances [join [concat {*}[lindex $obj_lst 1] [lindex $obj_lst 0]] /]]  
    set r_pin [get_pins $inst -filter {@name == "r"}]  
    set r_net [get_nets $r_pin]  
    if {$r_net == ""} {  
        return 0  
    }  
    set const_gate [get_fanin -to $r_net -leaf -depth 1 -tcl_list]  
    set const_type [get_attributes $const_gate -attributes view]  
    if {$const_type != "VERIFIC_GND"} {  
        return 0  
    }  
    set s_pin [get_pins $inst -filter {@name == "s"}]  
    set s_net [get_nets $s_pin]  
    if {$s_net == ""} {  
        return 0  
    }  
    set const_gate [get_fanin -to $s_net -leaf -depth 1 -tcl_list]  
    set const_type [get_attributes $const_gate -attributes view]  
    if {$const_type != "VERIFIC_GND"} {  
        return 0  
    }  
    return 1  
}  
# #########################################################################################  
# ## time: 20251104  
# ## owner: wanghan  
# ## description: E0236 - 不是input端口, 三方未报告  
# ## solution: 判断报告的对象是否连接端口, 未连接或者端口方向为out  
# ## case: Gen01-m011
# #########################################################################################  
set report_dict_E0236 [dict create]
set recorded_E0236 [dict create]
proc Diff_ca_008 {enno_list} {
    global report_dict_E0236 recorded_E0236
    set tmp_report_dict_E0236 $report_dict_E0236
    set re 0
    set obj_list [lindex $enno_list 9]
    set tmp_var [get_nets [lindex $obj_list 0]]
    set tmp_fanin [get_fanin -to $tmp_var -depth 1 -pin_list]
    set tmp_inst [get_instances $tmp_fanin]
    set tmp_module [get_modules $tmp_inst]
    if {$tmp_module != ""} {
        set tmp_list ""
        foreach var $tmp_fanin {
            if {[get_modules [get_instances $var]] != ""} {
                set tmp_list [concat $tmp_list $var]
            }
        }
        set tmp_port [get_ports [get_pins $tmp_list]]
        set port_dir [get_attributes $tmp_port -attributes dir]
        foreach var $port_dir {
            if {$var == "out"} {
                set re 1
            } else {
                set re 0
                break
            }
        }
    } else {
        set re 1
    }
    if {$re == "1" && [get_nets $tmp_var] != ""} {
        if {![dict exists $recorded_E0236 $tmp_var]} {
            set ts [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
            set tmp_pin_list [get_fanin_only_qequivalent_buffer [get_nets $tmp_var]]
            foreach tmp_pin $tmp_pin_list {
                dict set tmp_report_dict_E0236 [join [get_nets [get_pins $tmp_pin]] -] 1
            }
            dict set recorded_E0236 $tmp_var 1
        }
    }
    set report_dict_E0236 $tmp_report_dict_E0236
    return $re
}
proc quickly_get_line {file num} {
    set fp [open $file r]
    while {[gets $fp line] != -1} {
        if {[incr c] == $num} {
            return $line
        }
    }
    close $fp
}
# #########################################################################################  
# ## time: 20251111
# ## owner: chenhaiyang
# ## description: E0239 - obj1为net, obj2为inst, obj3为pin
# ## solution: 这个方案性能太慢, 暂时不做, 改用其他方案
# ## case: Gen01-m011
# #########################################################################################  
proc Diff_ca_010 {A_list enno_list} {
    return 0
    red "----------------------------------"
    red [incr ::wwww]
    # if {[incr ::wwww] > 50} {
    #     set ::wwww 0
    #     throw USER_STOP "user stop!"
    # }
    set s_obj [lindex $A_list 9]
    set e_obj [lindex $enno_list 9]
    # red $s_obj
    # green $e_obj
    set s_net [concat {*}[get_nets -canonical [__s_to_e_obj [lindex $s_obj 0]]]]
    set e_net [concat {*}[get_nets -canonical [lindex $e_obj 0]]]
    # green "pass-1"
    # return 1    
    red "s_net: $s_net"
    green "e_net: $e_net"
    if {$s_net == $e_net} {
        green "[incr ::xxxxx]"
        return 1
    }
    return 0
    set s_inst [concat {*}[__s_to_e_obj [lindex $s_obj 1]]]
    set e_inst [concat {*}[lindex $e_obj 1]]
    # red "s_inst: $s_inst"
    # green "e_inst: $e_inst"
    set s_inst_net [get_nets -canonical [get_pins $s_inst/r]]
    set e_inst_net [get_nets -canonical [get_pins $e_inst/r]]
    # if {$s_inst_net != $e_inst_net} {
    #     red "fail-2"
    #     return 0
    # }    
    red "s_inst_net: $s_inst_net"
    green "e_inst_net: $e_inst_net"
    set s_clk [concat {*}[__s_to_e_obj [lindex $s_obj 2]]]
    set e_clk [concat {*}[lindex $e_obj 2]]
    # red "s_clk: $s_clk"
    # green "e_clk: $e_clk"
    set s_clk_net [get_nets -canonical [get_pins $s_clk]]
    set e_clk_net [get_nets -canonical [get_pins $e_clk]]
    # if {$s_clk_net != $e_clk_net} {
    #     red "fail-3"
    #     return 0
    # }
    red "s_clk_net: $s_clk_net"
    green "e_clk_net: $e_clk_net"
    # if {$s_net == $e_net && $s_inst_net == $e_inst_net && $s_clk_net == $e_inst_net} {
    #     return 1
    #     green "pass-1"
    # }
    return 0
}
# #########################################################################################  
# ## time: 20251112
# ## owner: chenhaiyang
# ## description: E0246 - 延迟使用了小数, 对于0.00 sg报,elint不报
# ## solution: 判断是否是可整数化的数字, 比如0.00
# ## case: Gen01-m011
# #########################################################################################  
proc Diff_ca_021 {s_list} {
    # red $s_list
    set nums [lindex $s_list 9 0]
    # red "$nums -- [expr {$nums == 0}]"
    return [expr {$nums == 0}]
}
# #########################################################################################  
# ## time: 20251106
# ## owner: chenhaiyang
# ## description: E0089 - bufif定义的三态信号名必须以_z结尾, 三方未报
# ## solution: foreach verilog file
# ## case: Gen01-m011
# #########################################################################################  
proc Diff_ca_011 {enno_list} {
    # test proc ,need hier
    set file [lindex $enno_list 7]
    set num [lindex $enno_list 4]
    set line ""
    set fp [open $file r]
    while {[gets $fp line] != -1} {
        if {[incr c] == $num} {
            break
        }
    }
    close $fp
    if {[string match {bufif[01]} [lindex $line 0]]} {
        return 1
    }
    return 0
}
# #########################################################################################  
# ## time: 20251105
# ## owner: wanghan
# ## description: E0228 - clock不是input端口, 三方未报告
# ## solution: 判断报告的对象是否连接端口, 未连接或者端口方向为out
# ## case: Gen01-m011
# #########################################################################################  
set report_dict_E0228 [dict create]
proc Diff_ca_012 {enno_list} {
    global report_dict_E0228
    set tmp_report_dict_E0228 $report_dict_E0228
    set re 0
    set obj_list [lindex $enno_list 9]
    set tmp_var [get_nets [lindex $obj_list 0]]
    set tmp_fanin [get_fanin -to $tmp_var -depth 1 -pin_list]
    set tmp_inst [get_instances $tmp_fanin]
    set tmp_module [get_modules $tmp_inst]
    if {$tmp_module != ""} {
        set tmp_list ""
        foreach var $tmp_fanin {
            if {[get_modules [get_instances $var]] != ""} {
                set tmp_list [concat $tmp_list $var]
            }
        }
        set tmp_port [get_ports [get_pins $tmp_list]]
        set port_dir [get_attributes $tmp_port -attributes dir]
        foreach var $port_dir {
            if {$var == "out"} {
                set re 1
            } else {
                set re 0
                break
            }
        }
    } else {
        set re 1
    }
    if {$re == "1" && [get_nets $tmp_var] != ""} {
        set tmp_pin_list [get_fanin_only_qequivalent_buffer [get_nets $tmp_var]]
        foreach tmp_pin $tmp_pin_list {
            dict set tmp_report_dict_E0228 [join [get_nets [get_pins $tmp_pin]] -] 1
        }
    }
    set report_dict_E0228 $tmp_report_dict_E0228
    return $re
}
# #########################################################################################  
# ## time: 20251107
# ## owner: chenhaiyang
# ## description: E0255 - r/s为常值时我们推成了ff, sg为latch
# ## solution: 判断r/s为常值, 判断inst=ff
# ## case: Gen01-m011
# #########################################################################################  
proc Diff_ca_013 {enno_list} {
    # need const ?
    # return 0
    set obj_list [lindex $enno_list 9]
    set inst [lindex $obj_list 2]
    set tmp_var [get_attributes [get_nets [lindex $obj_list 6]] -attributes inferred_constant]
    set inst_type [lsort -unique [get_attributes [get_instances $inst] -attributes view]]
    if {$inst_type == "VERIFIC_DFFRS" && $tmp_var != ""} {
        return 1
    }
    return 0
}
# #########################################################################################  
# ## time: 20251108
# ## owner: kkxia
# ## description: E0233, 综合差异, sg综合成了ff, 而我们没有,存在黑盒
# ## solution: 判断我们的电路中是否连接到了一个黑盒
# ## case: Gen01-m011
# #########################################################################################  
proc Diff_ca_014 {miss_msg} {
    set s_obj [lindex ${miss_msg} 9]
    set s_ff [lindex ${s_obj} 1]
    set s_ff [reformat_s_names_setup ${s_ff}]
    set if_black_box [get_attributes [get_instances [get_attributes [get_pins [get_nets ${s_ff}] -filter {@dir == "out"}] -attribute owner]] -attribute is_black_box]
    set if_black_box [lsort -unique ${if_black_box}]
    if {${if_black_box} == 1} {
        return 1
    } else {
        return 0
    }
    return 0
}
# #########################################################################################  
# ## time: 20251110
# ## owner: wanghan
# ## description: E0243 - 误报, ff的输出作为了另一个ff的复位或置位, 三方未报告
# ## solution: 判断报告的前一个ff的输出连接到了后一个ff的复位和置位上则为差异
# ## case: Gen03-m101
# ######################################################################################### 
proc Diff_ca_017 {enno_list} {
    global report_dict_E0243
    set re 0
    set obj_list [lindex $enno_list 9]
    set instance_1 [get_instances [lindex $obj_list 0]]
    set instance_2 [get_instances [lindex $obj_list 2]]
    set rst_type [lindex $obj_list 1]
    if {$rst_type == "synchronous"} {
    if {$instance_1 != "" && $instance_2 != "" && [is_sync_ff $instance_2]} {
        set ff_d_net [get_nets [get_pins [get_instances $instance_2] -filter {@name == "d"}]]
        if {$ff_d_net != ""} {
            set like_mux [lindex [get_fanin -to $ff_d_net -leaf -buf_inv_only -tcl_list] end]
            set type [get_attributes $like_mux -attribute view]
            set mux_sel_net [get_nets [get_pins $like_mux -filter {@name == "c"}]]
            if {$type == "VERIFIC_MUX" && $mux_sel_net != ""} {
                set inst_list [get_instances [get_pins [get_fanin -to $mux_sel_net -pin_list] -filter {@name=="q"}]]
                if {[lsearch -exact $inst_list {*}$instance_1] != -1} {
                    set re 1
                }
            }
        }
    }
    } else {
        if {$instance_1 != "" && $instance_2 != ""} {
            ## 获取第二个的ff复位和置位端前连接的器件
            set inst_list [get_instances [get_pins [get_fanin -to [get_nets [get_pins $instance_2 -filter {@name=="s"||@name=="r"}]] -pin_list] -filter {@name=="q"}]]
            if {[lsearch -exact $inst_list {*}$instance_1] != -1} {
                ## 存放enno报告的对方, 供处理三方报告了相同message的漏报
                dict set report_dict_E0243 [join $instance_1 -] 1
                set re 1
            }
        }
    }
    return $re
}
# proc Diff_ca_111 {miss_list} {
#     set re 0
#     set obj_list [lindex $miss_list 9]
#     set instance_1 [lindex $obj_list 0]
#     set instance_2 [lindex $obj_list 2]
#     set rst_type [lindex $obj_list 1]
#     if {$rst_type == "asynchronous"} {
#         blue [reformat_s_names_setup $instance_1]
#         green [reformat_s_names_setup $instance_2]
#     }
#     return $re
# }
# #########################################################################################  
# ## time: 20251112
# ## owner: wanghan
# ## description: E0027 - 漏报,
# ## solution: 获取三方报告的对象的fanin,若有则属于差异
# ## case: Gen03-m101
# ######################################################################################### 
proc Diff_ca_019 {miss_list} {
    set re 0
    set obj_list [lindex $miss_list 9]
    set var [lindex $obj_list 0]
    set hier_list [lrange [split [lindex $obj_list 1] ":"] 1 end]
    set i 0
    set final_hier ""
    foreach hier $hier_list {
        set tmp_hier [split $hier "@"]
        if {[llength $tmp_hier] > 1} {
            set tmp_hier [lindex $tmp_hier 0]
        }
        if {$i == "0"} {
            set final_hier $tmp_hier
        } else {
            set final_hier ${final_hier}/${tmp_hier}
        }
        incr i
    }
    set final_hier_var ${final_hier}/${var}
    if {[get_nets [get_pins $final_hier_var]] != ""} {
        if {[get_fanin -to [get_nets [get_pins $final_hier_var]]] != ""} {
            set re 1
        }
    }
    return $re
}
# #########################################################################################  
# ## time: 20251112
# ## owner: wanghan
# ## description: E0026 - 只报告顶层的
# ## solution: 获取三方报告的层级, 不是顶层的则属于差异
# ## case: Gen03-m101
# ######################################################################################### 
proc Diff_ca_020 {miss_list} {
    set re 0
    set obj_list [lindex $miss_list 9]
    set var [lindex $obj_list 0]
    set hier_list [lrange [split [lindex $obj_list 1] ":"] 1 end]
    set i 0
    set final_hier ""
    foreach hier $hier_list {
        set tmp_hier [split $hier "@"]
        if {[llength $tmp_hier] > 1} {
            set tmp_hier [lindex $tmp_hier 0]
        }
        if {$i == "0"} {
            set final_hier $tmp_hier
        } else {
            set final_hier ${final_hier}/${tmp_hier}
        }
        incr i
    }
    # set final_hier_var ${final_hier}/${var}
    # if {[get_nets [get_pins $final_hier_var]] != ""} {
    #     if {[get_fanout -from [get_nets [get_pins $final_hier_var]]] != ""} {
    #         set re 1
    #     }
    # }
    if {$final_hier != [get_top]} {
        set re 1
    }
    return $re
}
# #########################################################################################  
# ## time: 20251108
# ## owner: wanghan
# ## description: E0261 - 误报, latch的gate端有门结构, 未报告
# ## solution: 获取latch的gate端的1层fanin, 若为门结构则属于差异
# ## case: Gen01-m011
# ######################################################################################### 
proc Diff_ca_022 {enno_list} {
    set re 0
    set obj [lindex $enno_list 9]
    set instance_list [get_instances [get_fanin -to [get_nets $obj] -pin_list] -filter {@view=="VERIFIC_DLATCHRS"}]
    set gate_list {VERIFIC_INV VERIFIC_BUF VERIFIC_AND VERIFIC_OR VERIFIC_XOR VERIFIC_XNOR VERIFIC_MUX}
    foreach inst $instance_list {
        set gate_pin_net [get_nets [get_pins [get_instances $inst] -filter {@name=="gate"}]]
        set type [get_attributes [get_instances [get_fanin -to $gate_pin_net -pin_list -depth 1 ] ] -attributes view]
        if {[lsearch -exact $gate_list $type] != -1} {
            set re 1
            break
        }
    }
    return $re
}
# #########################################################################################  
# ## time: 20251115
# ## owner: wanghan
# ## description: E0332 - 误报, output未连接, 三方未报告
# ## solution: 根据报告的文件和行号, 拿到对应的行, 判断是否未连接, 未连接则属于差异
# ## case: Gen02-m006
# ######################################################################################### 
proc Diff_ca_018 {enno_list} {
    set re 0
    set obj [lindex $enno_list 9]
    set line_num [lindex $enno_list 4]
    set file [lindex $enno_list 7]
    set fp [open $file r]
    set tmp_line_num 0
    set line_content ""
    while {[gets $fp line] != -1} {
        incr tmp_line_num
        if {$line_num == $tmp_line_num} {
            set line_content $line
            break
        }
    }
    close $fp
    if {[regexp {\.(\S+)\s*\(\s*\)\s*} $line_content matched tmp_obj]} {
        if {$tmp_obj == $obj} {
            set re 1
        }
    }
    return $re
}
# #########################################################################################  
# ## time: 20251117
# ## owner: yhyin
# ## description: E0089 false report,sg not report because of current instance is bbox
# ## solution: determine whether the current instance has cells that can't be synthesized with A tool
# ## case: Gen02-m006
# ######################################################################################### 
proc Diff_ca_024 {enno_list} {
    set ret 0
    set signal_name [lindex $enno_list 9]
    set hier [get_instances [get_attributes [get_nets $signal_name] -attributes owner]]
    if {[get_instances "${hier}/*" -filter {@view == "VERIFIC_PMOS"}] ne ""} {
        set ret 1
    }
    return $ret
}
# ######################################################################################### 
# ## time: 20251117
# ## owner: yhyin
# ## description: E0092 same as E0089 false report,sg not report because of current instance is bbox
# ## solution: determine whether the current instance has cells that can't be synthesized with A tool
# ## case: Gen02-m006
# ######################################################################################### 
proc Diff_ca_025 {enno_list} {
    set ret 0
    set signal_name [lindex $enno_list 9]
    set hier [get_instances [get_attributes [get_nets $signal_name] -attributes owner]]
    if {[get_instances "${hier}/*" -filter {@view == "VERIFIC_PMOS"}] ne ""} {
        set ret 1
    }
    return $ret
}
# ######################################################################################### 
# ## time: 20251120
# ## owner: yhyin
# ## description: E0233, sg拆分报, elint合并报
# ## solution: 通过文件名,行号,clock,flop_name为key建dict, 然后进行遍历处理
# ## case: Gen02-m006
# ######################################################################################### 
proc Diff_ca_027 {new_origin_pass new_e_obj_pass_idx new_s_obj_pass_idx new_all_false_msg new_all_miss_msg} {
    upvar 1 $new_origin_pass tmp_origin_pass
    upvar 1 $new_e_obj_pass_idx tmp_e_obj_pass_idx
    upvar 1 $new_s_obj_pass_idx tmp_s_obj_pass_idx
    upvar 1 $new_all_false_msg tmp_new_all_false_msg
    upvar 1 $new_all_miss_msg tmp_new_all_miss_msg
    set e_key_dict [dict create]
    # 以文件名,行号,clock,flop_name为key, value是所有的ff索引
    for {set ee 0} {$ee < [llength ${tmp_new_all_false_msg}]} {incr ee} {
        set value {}
        set e_msg [lindex ${tmp_new_all_false_msg} ${ee}]
        set e_file [lindex ${e_msg} 7]
        set e_line [lindex ${e_msg} 4]
        set e_obj [lindex ${e_msg} 9]
        set e_clk [remove_useless_str [get_nets [lindex ${e_obj} 0] -canonical]]
        set e_ff [lindex ${e_obj} 1]
        set e_ff_name [get_multiple_inst_name ${e_ff}]
        set e_ff_name [remove_useless_str ${e_ff_name}]
        # 获取ff所有索引
        set e_ff_idx_list [get_inst_index ${e_ff}]
        set key_name [list ${e_file} ${e_line} ${e_clk} ${e_ff_name}]
        # value的索引1是msg在all_false/miss中索引
        # lappend value ${e_ff_idx_list}
        # lappend value ${ee}
        # lappend value ${e_msg}
        set value [list ${e_ff_idx_list} ${ee} ${e_msg}]
        if {[dict exists ${e_key_dict} ${key_name}]} {
            dict lappend e_key_dict ${key_name} ${value}
        } else {
            dict set e_key_dict ${key_name} ${value}
        }
    }
    set s_key_dict [dict create]
    for {set ss 0} {$ss < [llength ${tmp_new_all_miss_msg}]} {incr ss} {
        set value {}
        set s_msg [lindex ${tmp_new_all_miss_msg} ${ss}]
        set s_file [lindex ${s_msg} 7]
        set s_line [lindex ${s_msg} 4]
        set s_obj [lindex ${s_msg} 9]
        set s_clk [remove_useless_str [lindex ${s_obj} 0]]
        set s_ff [lindex ${s_obj} 1]
        # 去除所有的空格,斜杠, 反斜杠
        set s_ff_name [remove_useless_str ${s_ff}]
        regsub {\[[0-9]+(\:[0-9]+)?\]$} $s_ff_name "" no_idx_ff_name
        # 获取ff所有索引
        set s_ff_idx_list [get_inst_index ${s_ff}]
        set key_name [list ${s_file} ${s_line} ${s_clk} ${no_idx_ff_name}]
        set value [list ${s_ff_idx_list} ${ss} ${s_msg}]      
        # lappend value ${s_ff_idx_list}
        # lappend value ${ss}
        # lappend value ${s_msg}
        # dict set s_key_dict ${key_name} ${value}
        if {[dict exists ${s_key_dict} ${key_name}]} {
            dict lappend s_key_dict ${key_name} ${value}
        } else {
            dict set s_key_dict ${key_name} [list ${value}]
        }
    }
    set e_pass_idx {}
    set s_pass_idx {}
    dict for {kk vv} ${e_key_dict} {
        if {[dict exists ${s_key_dict} ${kk}]} {
            set s_value [dict get ${s_key_dict} ${kk}]
            set s_all_idx {}
            set e_all_idx [lindex ${vv} 0]
            foreach aa [dict get ${s_key_dict} ${kk}] {
                set s_tmp_idx [lindex ${aa} 0]
                set s_all_idx [concat ${s_all_idx} ${s_tmp_idx}]
            }
            set s_all_idx [lsort ${s_all_idx}]
            if {[lsort ${e_all_idx}] == ${s_all_idx}} {
                # 满足差异, 获取在all_false/all_miss中索引, 在哦objunmatch中的索引
                lappend e_pass_idx [lindex ${vv} 1]
                set e_msg [lindex ${vv} 2]
                if {[string first "OBJ__TAG" ${e_msg}] != -1} {
                    lappend tmp_e_obj_pass_idx [lindex ${e_msg} end]
                }
                foreach tmp_s ${s_value} {
                    set s_msg [lindex ${tmp_s} 2]
                    lappend s_pass_idx [lindex ${tmp_s} 1]
                    if {[string first "OBJ__TAG" ${s_msg}] != -1} {
                        lappend tmp_s_obj_pass_idx [lindex ${s_msg} end]
                    }
                }
            }
        }
    }
    # 获取差异处理后新的all_false/miss
    if {${e_pass_idx} != {}} {
        set tmp_new_all_false_msg [delete_diff_msg ${tmp_new_all_false_msg} ${e_pass_idx}]
    }
    if {${s_pass_idx} != {}} {
        set tmp_new_all_miss_msg [delete_diff_msg ${tmp_new_all_miss_msg} ${s_pass_idx}]
    }
}
# ######################################################################################### 
# ## time: 20251108
# ## owner: kkxia
# ## description: E0233, objunmatch, clock信号, elint报在内层, sg报在外层
# ## solution: 通过sg的clock去get_fanin找我们的clock
# ## case: Gen01-m011
# ######################################################################################### 
proc Diff_ca_015 {new_origin_pass new_e_obj_pass_idx new_s_obj_pass_idx new_all_false_msg new_all_miss_msg} {
    upvar 1 $new_origin_pass tmp_origin_pass
    upvar 1 $new_e_obj_pass_idx tmp_e_obj_pass_idx
    upvar 1 $new_s_obj_pass_idx tmp_s_obj_pass_idx
    upvar 1 $new_all_false_msg tmp_new_all_false_msg
    upvar 1 $new_all_miss_msg tmp_new_all_miss_msg
    set e_pass_idx {}
    set s_pass_idx {}
    for {set ee 0} {$ee < [llength ${tmp_new_all_false_msg}]} {incr ee} {
        set e_msg [lindex ${tmp_new_all_false_msg} $ee]
        set e_obj [lindex ${e_msg} 9]
        set e_clk [lindex ${e_obj} 0]
        set e_ff [lindex ${e_obj} 1]
        for {set ss 0} {$ss < [llength ${tmp_new_all_miss_msg}]} {incr ss} {
            set s_msg [lindex ${tmp_new_all_miss_msg} $ss]
            set s_obj [lindex ${s_msg} 9]
            set s_clk [lindex ${s_obj} 0]
            set s_clk [reformat_s_names_setup ${s_clk}]
            set s_ff [lindex ${s_obj} 1]
            set s_ff [reformat_s_names_setup ${s_ff}]
            set s_ff [string trim ${s_ff} "{}"]
            if {${e_ff} == ${s_ff}} {
                set s_fanin [get_fanin -to [get_nets ${s_clk}] -tcl_list -buf_inv_only]
                if {[lsearch -exact ${s_fanin} ${e_clk}] != -1} {
                    # 符合差异
                    lappend e_pass_idx ${ee}
                    lappend s_pass_idx ${ss}
                    if {[string first "OBJ__TAG" ${e_msg}] != -1} {
                        lappend tmp_e_obj_pass_idx [lindex ${e_msg} end]
                    }
                    if {[string first "OBJ__TAG" ${s_msg}] != -1} {
                        lappend tmp_s_obj_pass_idx [lindex ${s_msg} end]
                    }
                    set origin_diff [lindex ${e_msg} 11]
                    lappend origin_diff "Diff_ca_015"
                    set e_msg [lreplace ]
                }
            }
        }
    }
}
proc Diff_ca_000 {new_origin_pass new_e_obj_pass_idx new_s_obj_pass_idx new_all_false_msg new_all_miss_msg new_all_objunmatch_msg} {
    upvar 1 $new_origin_pass tmp_origin_pass
    upvar 1 $new_e_obj_pass_idx tmp_e_obj_pass_idx
    upvar 1 $new_s_obj_pass_idx tmp_s_obj_pass_idx
    upvar 1 $new_all_false_msg tmp_new_all_false_msg
    upvar 1 $new_all_miss_msg tmp_new_all_miss_msg
    upvar 1 $new_all_objunmatch_msg tmp_new_all_objunmatch_msg
    set e_key_map [dict create]
    set s_key_map [dict create]
    set e_pass_idx_list [list]
    set s_pass_idx_list [list]
    set tmp_new_all_objunmatch_msg [list]
    for {set index 0} {$index < [llength $tmp_new_all_false_msg]} {incr index} {
        set e_msg [lindex $tmp_new_all_false_msg $index]
        set file_line_key "[lindex $e_msg 7] [lindex $e_msg 4]"
        dict lappend e_key_map $file_line_key $index
    }
    for {set index 0} {$index < [llength $tmp_new_all_miss_msg]} {incr index} {
        set e_msg [lindex $tmp_new_all_miss_msg $index]
        set file_line_key "[lindex $e_msg 7] [lindex $e_msg 4]"
        dict lappend s_key_map $file_line_key $index
    }
    dict for {k v} $e_key_map {
        if {[dict exists $s_key_map $k]} {
            foreach idx $v {
                lappend tmp_new_all_objunmatch_msg [lindex $tmp_new_all_false_msg $idx]
            }
            foreach idx [dict get $s_key_map $k] {
                lappend tmp_new_all_objunmatch_msg [lindex $tmp_new_all_miss_msg $idx]
            }
            lappend e_pass_idx_list {*}$v
            lappend s_pass_idx_list {*}[dict get $s_key_map $k]
        }
    }
    set tmp_new_all_false_msg [delete_diff_msg ${tmp_new_all_false_msg} ${e_pass_idx_list}]
    set tmp_new_all_miss_msg [delete_diff_msg ${tmp_new_all_miss_msg} ${s_pass_idx_list}]
}
# ######################################################################################### 
# ## time: 20251117
# ## owner: chenhaiyang
# ## description: E0239 - same as Diff_ca_010
# ## solution:
# ## case: Gen02-m009
# ######################################################################################### 
proc Diff_ca_023 {s_obj_list} {
    set obj_list [lindex $s_obj_list 9]
    set key [lrange $obj_list 0 1]
    if {$key in $::compare::DIFF_E0239} {
        return 1
    }
    return 0
}
# ######################################################################################### 
# ## time: 20251118
# ## owner: chenhaiyang
# ## description: E0250 - 不连接r/s的情况下(const=0)elint综合的ff带r/s端, 三方不带
# ## solution:
# ## case: Gen01-m011
# ######################################################################################### 
proc Diff_ca_026 {obj_list} {
    set inst [get_instances [lindex $obj_list 9 0]]
    set r_pin [get_pins $inst -filter {@name == "r"}]
    set r_net [get_nets $r_pin]
    if {$r_net == ""} {
        return 0
    }
    set const_gate [get_fanin -to $r_net -leaf -depth 1 -tcl_list]
    set const_type [get_attributes $const_gate -attributes view]
    if {$const_type != "VERIFIC_GND"} {
        return 0
    }
    set s_pin [get_pins $inst -filter {@name == "s"}]
    set s_net [get_nets $s_pin]
    if {$s_net == ""} {
        return 0
    }
    set const_gate [get_fanin -to $s_net -leaf -depth 1 -tcl_list]
    set const_type [get_attributes $const_gate -attributes view]
    if {$const_type != "VERIFIC_GND"} {
        return 0
    }
    return 1
}
# ######################################################################################### 
# ## time: 20251124
# ## owner: yhyin
# ## description: re do objunmatch check,this proc better origin objunmatch process
# ## solution:
# ## case:
# ######################################################################################### 
proc redo_objunmatch {new_origin_pass new_e_obj_pass_idx new_s_obj_pass_idx new_all_false_msg new_all_miss_msg new_all_objunmatch_msg} {
    upvar 1 $new_origin_pass tmp_origin_pass
    upvar 1 $new_e_obj_pass_idx tmp_e_obj_pass_idx
    upvar 1 $new_s_obj_pass_idx tmp_s_obj_pass_idx
    upvar 1 $new_all_false_msg tmp_new_all_false_msg
    upvar 1 $new_all_miss_msg tmp_new_all_miss_msg
    upvar 1 $new_all_objunmatch_msg tmp_new_all_objunmatch_msg
    set e_key_map [dict create]
    set s_key_map [dict create]
    set e_pass_idx_list [list]
    set s_pass_idx_list [list]
    set tmp_new_all_objunmatch_msg [list]
    for {set index 0} {$index < [llength $tmp_new_all_false_msg]} {incr index} {
        set e_msg [lindex $tmp_new_all_false_msg $index]
        set file_line_key "[lindex $e_msg 7] [lindex $e_msg 4]"
        dict lappend e_key_map $file_line_key $index
    }
    for {set index 0} {$index < [llength $tmp_new_all_miss_msg]} {incr index} {
        set e_msg [lindex $tmp_new_all_miss_msg $index]
        set file_line_key "[lindex $e_msg 7] [lindex $e_msg 4]"
        dict lappend s_key_map $file_line_key $index
    }
    dict for {k v} $e_key_map {
        if {[dict exists $s_key_map $k]} {
            foreach idx $v {
                lappend tmp_new_all_objunmatch_msg [lindex $tmp_new_all_false_msg $idx]
            }
            foreach idx [dict get $s_key_map $k] {
                lappend tmp_new_all_objunmatch_msg [lindex $tmp_new_all_miss_msg $idx]
            }
            lappend e_pass_idx_list {*}$v
            lappend s_pass_idx_list {*}[dict get $s_key_map $k]
        }
    }
    set tmp_new_all_false_msg [delete_diff_msg ${tmp_new_all_false_msg} ${e_pass_idx_list}]
    set tmp_new_all_miss_msg [delete_diff_msg ${tmp_new_all_miss_msg} ${s_pass_idx_list}]
}
namespace eval logger {
    variable debug_key false
    proc track_proc_enter {args} {
        set ts [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
        puts "$ts [lindex [lindex $args 0] 0] start"
    }
    proc track_proc_leave {args} {
        set ts [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
        if {[lindex $args 1] != "0"} {
            red "error:[lindex $args 2]"
        }
        puts "$ts [lindex [lindex $args 0] 0] end"
    }
}
proc track_proc_log {} {
    if {$logger::debug_key} {
        set proc_list ""
        foreach proc_name [info procs] {
            set no_monitor_list "track_proc_log track_proc_enter track_proc_leave auto_load auto_qualify auto_load_index puts unknown yellow red blue green history is_module_and_equivalent_buffer record_summary get_filelist_path record_fail_message judge_check_severity judge_check_dir judge_check_dir_3rd judge_check_line_number judge_check_line_number_3rd interp ignoreHiercolon ignoreObjectSpace getInstanceName replaceEmptyHier absolutePath"
            if {[lsearch -exact $no_monitor_list $proc_name] == "-1"} {
                lappend proc_list $proc_name
            }
        }
        foreach proc_name $proc_list {
            trace add execution $proc_name enter logger::track_proc_enter
            trace add execution $proc_name leave logger::track_proc_leave
        }
    }
}
proc Diff_ca_029 {obj_list} {
    # return 0
    set inst [lindex $obj_list 9]
    # red $inst
    set inst [join [list [lindex $inst 1] [lindex $inst 0]] .]
    # red $inst
    set inst [get_instances [__s_to_e_obj $inst]]
    # red $inst
    set r_pin [get_pins $inst -filter {@name == "r"}]
    set r_net [get_nets $r_pin]
    if {$r_net == ""} {
        # red fail-1
        return 0
    }
    set const_gate [get_fanin -to $r_net -leaf -depth 1 -tcl_list]
    set const_type [get_attributes $const_gate -attributes view]
    if {$const_type != "VERIFIC_GND"} {
        # red fail-2
        return 0
    }
    set s_pin [get_pins $inst -filter {@name == "s"}]
    set s_net [get_nets $s_pin]
    if {$s_net == ""} {
        # red fail-3
        return 0
    }
    set const_gate [get_fanin -to $s_net -leaf -depth 1 -tcl_list]
    set const_type [get_attributes $const_gate -attributes view]
    if {$const_type != "VERIFIC_GND"} {
        # red fail-4
        return 0
    }
    # green pass
    return 1
}
proc is_sync_ff {ff} {
    set ff_d_net [get_nets [get_pins [get_instances $ff] -filter {@name == "d"}]]
    if {$ff_d_net == ""} {
        return 0
    }
    set like_mux [lindex [get_fanin -to $ff_d_net -leaf -buf_inv_only -tcl_list] end]
    set type [get_attributes $like_mux -attribute view]
    if {$type != "VERIFIC_MUX"} {
        return 0
    }
    set mux_a0_net [get_nets [get_pins $like_mux -filter {@name == "a0"}]]
    if {$mux_a0_net == ""} {
        return 0
    }
    set mux_a1_net [get_nets [get_pins $like_mux -filter {@name == "a1"}]]
    if {$mux_a1_net == ""} {
        return 0
    }
    set mux_sel_net [get_nets [get_pins $like_mux -filter {@name == "c"}]]
    if {$mux_sel_net == ""} {
        return 0
    }
    if {[get_attributes $mux_sel_net -attribute inferred_constant] in {0 1}} {
        return 0
    }
    set mux_a0_gate [lindex [get_fanin -to $mux_a0_net -leaf -buf_inv_only -tcl_list] end]
    set mux_a1_gate [lindex [get_fanin -to $mux_a1_net -leaf -buf_inv_only -tcl_list] end]
    set mux_a0_gate_type [get_attributes $mux_a0_gate -attribute view]
    set mux_a1_gate_type [get_attributes $mux_a1_gate -attribute view]
    if {($mux_a0_gate_type in {VERIFIC_PWR VERIFIC_GND}) ^ ($mux_a1_gate_type in {VERIFIC_PWR VERIFIC_GND})} {
        return 1
    }
    return 0
}
# ######################################################################################### 
# ## time: 20251201
# ## owner: wanghan
# ## description: E0243 - 漏报, 未连接
# ## solution: 判断报告的第一个对象是否有连接第一个ff的复位和置位端, 未连接则属于差异
# ## case: Gen02-m006
# ######################################################################################### 
proc Diff_ca_031 {miss_list} {
    set re 0
    set obj_list [lindex $miss_list 9]
    set rst_type [lindex $obj_list 1]
    if {$rst_type == "asynchronous"} {
        set instance_1 [lindex $obj_list 0]
        set instance_2 [lindex $obj_list 2]
        set instance_1 [get_instances [get_pins [get_fanin -to [get_nets [::__s_to_e_obj $instance_1]] -pin_list] -filter {@name=="q"}]]
        set instance_2 [get_instances [get_pins [get_fanin -to [get_nets [::__s_to_e_obj $instance_2]] -pin_list] -filter {@name=="q"}]]
        if {$instance_2 != "" && $instance_1 != ""} {
            set_param db.stop_at_select true
            set inst_list [get_instances [get_pins [get_fanin -to [get_nets [get_pins $instance_2 -filter {@name=="s"||@name=="r"}]] -pin_list] -filter {@name=="q"}]]
            set_param db.stop_at_select false
            foreach var $instance_1 {
                if {[lsearch -exact $inst_list $var] == -1} {
                    set re 1
                } else {
                    set re 0
                    break
                }
            }
        } else {
            set re 1
        }
    }
    return $re
}
# ######################################################################################### 
# ## time: 20251201
# ## owner: wanghan
# ## description: E0243 - 漏报, 实际有报告, 但是报告的位置不一致
# ## solution: 判断该条是否有在enno中报告过, 有就属于差异
# ## case: Gen02-m006
# ######################################################################################### 
set report_dict_E0243 [dict create]
proc Diff_ca_030 {miss_list} {
    set re 0
    set obj_list [lindex $miss_list 9]
    set rst_type [lindex $obj_list 1]
    global report_dict_E0243
    if {$rst_type == "asynchronous"} {
        set instance_1 [lindex $obj_list 0]
        set instance_1 [get_instances [get_pins [get_fanin -to [get_nets [::__s_to_e_obj $instance_1]] -pin_list] -filter {@name=="q"}]]
        set tmp_instance_1 ""
        foreach var $instance_1 {
            if {[get_attributes [get_instances $var] -attributes view] == "VERIFIC_DFFRS"} {
                lappend tmp_instance_1 $var
            }
        }
        foreach var $tmp_instance_1 {
            if {[dict exists $report_dict_E0243 [join $var -]]} {
                set re 1
            } else {
                set re 0
                break
            }
        }
    }
    return $re
}
proc Diff_ca_check_s_not_E0233 {s_msg} {
    set s_obj [ lindex ${s_msg} 9 ]
    set s_clk [ lindex ${s_obj} 0 ]
    set s_clk [ __s_to_e_obj ${s_clk} ]
    set s_ff [ lindex ${s_obj} 1 ]
    set s_ff [ __s_to_e_obj ${s_ff} ]
    set gate_list { "VERIFIC_AND" "VERIFIC_NAND" "VERIFIC_NOR" "VERIFIC_OR" "VERIFIC_XOR" "VERIFIC_XNOR" "VERIFIC_ADD" }
    # 1. clk 不存在, 不满足E0233
    if {[get_nets ${s_clk}] == ""} {
        return 1
    }
    set s_clk [get_nets ${s_clk}]
    # 2. flop不存在或者不是flop, 不满足E0233
    set inst [get_instances ${s_ff}]
    if {${inst} == ""} {
        return 1
    } else {
        set attribute [get_attributes ${inst} -attribute view]
        if {[llength ${attribute}] > 1} {
            set attribute [lsort -unique ${attribute}]
        }
        if {${attribute} != "VERIFIC_DFFRS"} {
            return 1
        }
    }
    set s_ff [get_instances ${s_ff}]
    # 3. clock的get_fanin中不存在gate, 不满足E0233
    set clk_in_cone [get_instances [get_fanin -to ${s_clk}]]
    set tmp_res ""
    foreach tmp_inst ${clk_in_cone} {
        set type [get_attributes [get_instances ${tmp_inst}] -attribute view]
        if {${type} != "VERIFIC_AND" && ${type} == "VERIFIC_NAND" && ${type} == "VERIFIC_NOR" && ${type} == "VERIFIC_OR" && ${type} == "VERIFIC_XOR" && ${type} == "VERIFIC_XNOR" && ${type} == "VERIFIC_ADD"} {
            lappend tmp_res 1
        }
    }
    if {[llength ${tmp_res}] == [llength ${clk_in_cone}]} {
        return 1
    }
    # 4. 从sg的clock 去get_fanout 没有 flop, 不满足E0233
    set out_cone [get_instances [get_fanout -from ${s_clk} -tcl_list -endpoints_only]]
    if {[lsearch -exact ${out_cone} ${s_clk}] == -1} {
        return 1
    }
    return 0
}
# 临时方案: 判断owner的original_name是不是tsmc_dff或tsmc_mux, 是的话, 就认为是UDP 的综合差异(sg没有把UDP综合出来)
# 后续方案: RD添加UDP的attribute后, 通过attribute判断是否UDP, 而不是判断固定的owner
proc Diff_ca_E0233_is_UDP {e_msg} {
    # hot_pink "开始Diff_check_E0233_UDP"
    set e_obj [lindex ${e_msg} 9]
    set e_clk [lindex ${e_obj} 0]
    set e_ff [lindex ${e_obj} 1]
    set e_ff [string map {" " ""} ${e_ff}]
    set clk_attribute [lsort -unique [get_attributes [get_attributes [get_nets ${e_clk}] -attribute owner] -attribute original_name]]
    set ff_attribute [lsort -unique [get_attributes [get_attributes [get_instances ${e_ff}] -attribute owner] -attribute original_name]]
    if {${clk_attribute} == "tsmc_dff" || ${clk_attribute} == "tsmc_mux" || ${ff_attribute} == "tsmc_dff" || ${ff_attribute} == "tsmc_mux"} {
        return 1
    } else {
        return 0
    }
}
proc Diff_ca_032 {s_msg} {
    if {[regexp {OBJ__TAG} $s_msg]} {
        return 0
    }
    set ret 0
    set rule_id [lindex $s_msg 2]
    if {$rule_id == "E0267"} {
        set obj_list [lindex $s_msg 5]
        set opd1 [lindex $obj_list 2]
        set width1 [lindex $obj_list 1]
        set opd2 [lindex $obj_list 4]
        set width2 [lindex $obj_list 3]
    } else {
        set obj_list [lindex $s_msg 9]
        set opd1 [lindex $obj_list 0]
        set width1 [lindex $obj_list 1]
        set opd2 [lindex $obj_list 2]
        set width2 [lindex $obj_list 3]
    }
    if {[regexp {\-} $opd1] || [regexp {\-} $opd2]} {
        if {[expr abs([expr $width1 - $width2])] == 1} {
            set ret 1
        }
    }
    return $ret
}
# 检查E0233的误报: 第二个obj是gate之一(VERIFIC_AND VERIFIC_NAND VERIFIC_NOR VERIFIC_OR VERIFIC_XOR VERIFIC_XNOR VERIFIC_ADD), 
# 且FLOP的clk去get_fanin, 能找到clock所连接的那个gate, 就视为满足E0233
proc Diff_ca_check_E_E0233 { e_msg } {
    set e_obj [lindex ${e_msg} 9]
    set e_clk [lindex ${e_obj} 0]
    set e_ff [lindex ${e_obj} 1]
    set e_ff [string map {" " ""} ${e_ff}]
    set gate_list { "VERIFIC_AND" "VERIFIC_NAND" "VERIFIC_NOR" "VERIFIC_OR" "VERIFIC_XOR" "VERIFIC_XNOR" "VERIFIC_ADD" }
    # 1. 检查是flop
    set attr [lsort -unique [get_attributes [get_instances ${e_ff}] -attribute view]]
    if {${attr} != "VERIFIC_DFFRS"} {
        return 0
    }
    # 2. 检查clock是连在gate上
    set clk_instance [lindex [get_instances [get_nets ${e_clk}]] 0]
    if {[lsearch -exact ${gate_list} [get_attributes [get_instances ${clk_instance}] -attribute view]] == -1} {
        return 0
    }
    # 3. 检查从FLOP的clk去get_fanin, 能找到刚才的gate instance
    set ff_clk "${e_ff}/clk"
    set ff_clk_pin [get_pins ${ff_clk}]
    if {[llength ${ff_clk_pin}] == 0} {
        # FLOP 是单比特
        set ff_clk_in_cone [get_instances [get_fanin -to ${ff_clk_pin} -tcl_list -leaf]]
        if {[lsearch -exact ${ff_clk_in_cone} ${clk_instance}] != -1} {
            return 1
        } else {
            return 0
        }
    } else {
        # FLOP 是多比特: 每一个bit都满足, 才满足
        set tmp_res {}
        foreach tmp_clk_pin ${ff_clk_pin} {
            set ff_clk_in_cone [get_instances [get_fanin -to ${ff_clk_pin} -tcl_list -leaf]]
            if {[lsearch -exact ${ff_clk_in_cone} ${clk_instance}] != -1} {
                lappend tmp_res 1
            } else {
                return 0
            }
        }
        if {[llength ${tmp_res}] == [llength ${ff_clk_pin}]} {
            return 1
        } else {
            return 0
        }
    }
    return 0
}
# ######################################################################################### 
# ## time: 20251212
# ## owner: wanghan
# ## description: E0228 - 漏报, 报告对象不一致, enno有报告
# ## solution: 记录enno报告的对象, 判断三方报告的是否在enno中报告过, 有则属于差异
# ## case: Gen02-m006
# ######################################################################################### 
proc Diff_ca_033 {miss_list} {
    global report_dict_E0228
    set re 0
    set obj_list [lindex $miss_list 9]
    set var [lindex $obj_list 0]
    set tmp_pin_list [get_nets [reformat_s_names_setup $var]]
    if {$tmp_pin_list != ""} {
        foreach tmp_pin $tmp_pin_list {
            if {[dict exists $report_dict_E0228 [join $tmp_pin -]]} {
                set re 1
            } else {
                set re 0
                break
            }
        }
    }
    return $re
}
# ######################################################################################### 
# ## time: 20251212
# ## owner: wanghan
# ## description: E0236 - 漏报, 报告对象不一致, enno有报告
# ## solution: 记录enno报告的对象, 判断三方报告的是否在enno中报告过, 有则属于差异
# ## case: Gen02-m006
# ######################################################################################### 
proc Diff_ca_034 {miss_list} {
    global report_dict_E0236
    set tmp_report_dict_E0236 $report_dict_E0236
    set re 0
    set obj_list [lindex $miss_list 9]
    set var [lindex $obj_list 0]
    set tmp_pin_list [get_nets [reformat_s_names_setup $var]]
    if {$tmp_pin_list != ""} {
        foreach tmp_pin $tmp_pin_list {
            if {[dict exists $tmp_report_dict_E0236 [join $tmp_pin -]]} {
                set re 1
            } else {
                set re 0
                break
            }
        }
    }
    return $re
}
proc Diff_ca_035 {e_msg} {
    if {[regexp {OBJ__TAG} $e_msg]} {
        return 0
    }
    set obj_list [lindex $e_msg 5]
    set file [lindex $e_msg 7]
    set line [lindex $e_msg 4]
    set expr1 [lindex $obj_list 1]
    set expr2 [lindex $obj_list 3]
    set hier [lindex $obj_list 5]
    set expr1_type ""
    set expr2_type ""
    set expr1_node [lindex [get_ast_node -expr $expr1 -file $file -line $line] 0]
    set expr2_node [lindex [get_ast_node -expr $expr2 -file $file -line $line] 0]
    if {$expr1_node eq "" || $expr2_node eq ""} {
        return 0
    }
    set expr1_define_node [get_ast_attributes $expr1_node -attributes define]
    set expr2_define_node [get_ast_attributes $expr2_node -attributes define]
    if {$expr1_define_node ne ""} {
        set expr1_type [get_ast_attributes $expr1_define_node -attribute type]
    }
    if {$expr2_define_node ne ""} {
        set expr2_type [get_ast_attributes $expr2_define_node -attribute type]
    }
    if {$expr1_type eq "param" || $expr2_type eq "param"} {
        return 1
    }
    return 0
}
proc get_fanin_stop_at_mux {start_obj} {
    set a 1
    set all_fanin ""
    while {$a == "1"} {
        set start_obj [get_fanin -to $start_obj -depth 1 -pin_list]
        set all_fanin [concat $all_fanin $start_obj]
        set tmp_inst_list [get_instances $start_obj]
        foreach inst $tmp_inst_list {
            if {[get_attributes $inst -attributes view] == "VERIFIC_MUX"} {
                set a 0
                break
            }
        }
    }
    return $all_fanin
}
proc get_fanout_stop_at_mux {start_obj} {
    set a 1
    set all_fanin ""
    while {$a == "1"} {
        set start_obj [get_fanout -from $start_obj -depth 1 -pin_list]
        set all_fanin [concat $all_fanin $start_obj]
        set tmp_inst_list [get_instances $start_obj]
        foreach inst $tmp_inst_list {
            if {[get_attributes $inst -attributes view] == "VERIFIC_MUX"} {
                set a 0
                break
            }
        }
    }
    return $all_fanin
}
proc is_module_and_equivalent_buffer {pin} {
    set inst [get_instances [get_pins $pin]]
    set re 0
    if {[get_modules $inst] == ""} {
        set re [check_for_equivalent_buffer $inst]
    } else {
        set re 1
    }
    return $re
}
proc check_for_equivalent_buffer {inst} {
    set re 0
    set in_pins [get_pins [get_instances $inst] -filter {@dir == "in"}]
    set inst_type [get_attributes [get_instances $inst] -attributes view]
    switch ${inst_type} {
        "VERIFIC_BUF" {
            set re 1
        }
        "VERIFIC_AND" {
            set a0 [get_attributes [get_nets [get_pins $in_pins -filter {@name == "a0"}]] -attributes inferred_constant]
            set a1 [get_attributes [get_nets [get_pins $in_pins -filter {@name == "a1"}]] -attributes inferred_constant]
            if {$a0 == "" && $a1 == "1" || $a0 == "1" && $a1 == ""} {
                set re 1
            }
        }
        "VERIFIC_OR" {
            set a0 [get_attributes [get_nets [get_pins $in_pins -filter {@name == "a0"}]] -attributes inferred_constant]
            set a1 [get_attributes [get_nets [get_pins $in_pins -filter {@name == "a1"}]] -attributes inferred_constant]
            if {$a0 == "" && $a1 == "0" || $a0 == "0" && $a1 == ""} {
                set re 1
            }
        }
        "VERIFIC_MUX" {
            set c [get_attributes [get_nets [get_pins $in_pins -filter {@name == "c"}]] -attributes inferred_constant]
            if {$c == "0" || $c == "1"} {
                set re 1
            }
        }
        default {
            set re 0
        }
    }
    return $re
}
proc get_fanin_only_qequivalent_buffer {start_obj} {
    set all_fanin ""
    set judged_dict ""
    set all_start_obj $start_obj
    while {[llength $all_start_obj] > 0} {
        set obj [lindex $all_start_obj 0]
        if {[dict exists $judged_dict $obj]} {
            if {[dict get $judged_dict $obj] == "1"} {
                lappend all_fanin $obj
            }
        } else {
            set tmp_start_obj [get_fanin -to [get_pins $obj] -depth 1 -pin_list]
            dict set judged_dict $obj 1
            foreach var $tmp_start_obj {
                if {[is_module_and_equivalent_buffer [get_instances $var]]} {
                    lappend all_start_obj $var
                    lappend all_fanin $var
                }
            }
        }
        set all_start_obj [lreplace $all_start_obj 0 0]
    }
    return [lsort -unique $all_fanin]
}
# E0246: 只要e_msg中的obj包含点, 就视为不是integer, 该条PASS
# author: xiakangkai
# 适配了TOP_LGC的481条误报
proc Diff_ca_036 {e_msg} {
    set obj [lindex ${e_msg} 9]
    if {[string first "." ${obj}] != -1} {
        return 1
    } else {
        return 0
    }
}
