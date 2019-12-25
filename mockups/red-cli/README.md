This is an example how to make a multiple command CLI with current CLI implementation (although it's not meant for that).

It provides a CLI for all `function!`s globally defined. Evaluates, prints the result.

`>red red-cli.red what --with ab --spec`

```
     ?               function!     Displays information about functions, values, objects, and datatypes.
     about           function!     Print Red version information.
     absolute        action!       Returns the non-negative value.
     call            native!       Executes a shell command to run another process.
     checksum        native!       Computes a checksum, CRC, hash, or HMAC.
     does            native!       Defines a function with no arguments or local variables.
     draw            function!     Draws scalable vector graphics to an image.
     dump-face       function!     Display debugging info about a face and its children.
     fetch-help      function!     Returns information about functions, values, objects, and datatypes.
     get-env         native!       Returns the value of an OS environment variable (for current process).
     has             native!       Defines a function with local variables, but no arguments.
     help            function!     Displays information about functions, values, objects, and datatypes.
     help-string     function!     Returns information about functions, values, objects, and datatypes.
     link-tabs-to-parent function!     Internal Use Only.
     list-env        native!       Returns a map of OS environment variables (for current process).
     mold            action!       Returns a source format string representation of a value.
     normalize-dir   function!     Returns an absolute directory spec.
     oldrab          tuple!        72.72.16
     query           action!       Returns information about a file.
     reflect         action!       Returns internal details about a value via reflection.
     set-env         native!       Sets the value of an operating system environment variable (for current process).
     sort            action!       Sorts a series (modified); default sort order is ascending.
     tab             char!         #"^-"
     to-csv          function!     Make CSV data from input value.

unset
```

---
`>red-cli load red-cli.red`

```
[Red []
    #include %../../cli.red
    context [
        red-cli: function ["Multi-command CLI demo" command arguments [block!]] [if empty? arguments [
            print cli/version-for/brief Red-CLI
            print "The following commands are supported:^/"
            print form cmds
            print rejoin ["^/Type `" cli/default-exename { help <command>` for a syntax of a specific command}]
            quit/return 0
        ]
            if attempt [find cmds command: to word! arguments/1] [help: tail cli/version-for/brief Red-CLI find/tail help lf
                append help cli/syntax-for/no-help/no-version (command) insert find/tail help "red-cli" rejoin [" " command] print head help
                quit/return 0
            ]
            set 'system/words/command command
        ]
        if empty? system/options/args [
            print cli/help-for/no-help Red-CLI
            print rejoin ["Tip: type `" cli/default-exename " help` for a list of a list of supported commands"]
            quit/return 0
        ]
        pos: sws: to block! system/words
        cmds: collect [while [pos: find/tail pos function!] [unless datatype? :pos/-1 [keep to word! :pos/-2]]] remove find cmds 'help
        command: first system/options/args
        if attempt [find cmds command: to word! command] [parse s: spec-of get command [any [
            pos: block! (
                repeat i length? pos/1 [if typeset? ts: get pos/1/:i [change/part at pos/1 i to block! ts 1]]
                pos/1: intersect pos/1 to block! cli/supported-set
                any [last? pos/1 remove find pos/1 'block!]
            ) | skip
        ]]
            probe cli/process-into/args (command) next system/options/args
            quit/return 0
        ]
        if any [
            "help" = form command
            #"-" = first form command
        ] [cli/process-into/no-help Red-CLI] print ["Unrecognized command" uppercase form command] quit/return 1
    ]
]
```