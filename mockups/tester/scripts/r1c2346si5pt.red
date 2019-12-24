Red [
    Title: "Test program for CLI system" 
    Author: @hiiamboris 
    File: %my-prog-ram.red 
    Tabs: 4 
    Rights: {Copyright (C) 2011-2019 Red Foundation. All rights reserved.} 
    License: {^/^-^-Distributed under the Boost Software License, Version 1.0.^/^-^-See https://github.com/red/red/blob/master/BSL-License.txt^/^-}
] 
    #include %../../../cli.red 
    my-program: function [
        "test program description" 
        string-operand "accepts anything" 
        integer-operands [block! integer!] /switch1 
        /switch2 {docstring here and let it be somewhat longer than necessary} 
        /switch1-alias "alias /switch1" 
        /switch2-alias "alias /switch2" 
        /switch2-alias-2 "alias /switch2" 
        /option1 "overriding option" 
        argument1 [float!] /option2 "collecting option" 
        argument2 [float! block!] /option2-alias "alias /option2" 
        /o "alias /option2"
    ] [
        parse spec-of :my-program [any [set w all-word! (print [pad w 20 get bind to word! w :my-program]) | skip]]
    ] cli/process-into/no-help/name my-program "RE YWQT"

