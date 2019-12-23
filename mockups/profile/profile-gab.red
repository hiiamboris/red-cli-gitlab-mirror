Red []

e.g.: :comment

; ideally not exported on the global context
delta-time*: function [code count] [
    start: now/precise
    loop count code
    difference now/precise start
]
delta-time: function [
    "Return the time it takes to evaluate a block"
    code [block! word! function!] "Code to evaluate"
    /accuracy run-time [time! none!] "Longer time gives more accurate results, but takes longer to compute. Default 0:00:00.1"
][
    run-time: any [run-time 0:00:00.1]
    time: 0:00:00
    count: 1
    if word? :code [code: get code]
    cd: either block? :code [code] [[code]]
    while [time < run-time] [
        time: delta-time* cd count
        ; if your computer is really really fast, or now/precise is not accurate enough
        ; (hello Windows users!)
        either time > 0 [
            result: time / count
            ; multiply by 1.5 for faster convergence
            ; (ie. aim for 1.5*run-time)
            count: to integer! run-time * count * 1.5 / time
        ] [
            count: count * 10
        ]
    ]
    result
]

runs-per: function [
    "Return the number of times code can run in a given period"
    code [block! word! function!] "Code to evaluate"
    time [time!]
][
    t: delta-time/accuracy :code time
    to integer! time / t
]

format-time: function [
    "Convert a time value to a human readable string"
    time [time!]
] [
    if time >= 0:00:01 [
        ; work around a bug in the current stable release
        time: form round/to time 0.001
        if decimals: find/tail time #"." [
            clear skip decimals 3
        ]
        return time
    ]
    units: ["ms" "μs" "ns" "ps"]
    foreach u units [
        time: time * 1000
        if time >= 0:00:01 [
            time: to integer! round time
            return append form time u
        ]
    ]
]

print-table: function [
    "Print a block of blocks as an ASCII table"
    headers [block!]
    block [block!]
] [
    format: clear []
    header: clear []
    sep:    []
    i:      1
    unless parse headers [
        some [
            (text: width: fmt-func: none)
            set text string! any [set width integer! | set fmt-func word! | set fmt-func path!]
            (
                append header sep
                append header either width [pad text width] [text]
                either width [
                    either fmt-func [
                        append format compose [(sep) pad (fmt-func) pick block (i) (width)]
                    ] [
                        append format compose [(sep) pad pick block (i) (width)]
                    ]
                ] [
                    either fmt-func [
                        append format compose [(sep) (fmt-func) pick block (i)]
                    ] [
                        append format compose [(sep) pick block (i)]
                    ]
                ]
                sep: "|"
                i:   i + 1
            )
        ]
    ] [
        cause-error "Invalid headers spec"
    ]
    print header
    format: func [block] reduce ['print format]
    foreach row block [format row]
]

; Putting the runtime first in results, and memory second, helps things
; line up nicely. It's a problem if we want to add more stats though, 
; as any code using the data with expected field indexes will break if
; we don't add the new stats at the end. We could use named fields as
; well but, for now, we'll stick with this and let this comment serve
; as a warning. More stats will certainly come in the future, as will
; GC, but this is just a quickie function in any case.
; Memory stats and formatted output added by @toomasv.
profile: function [
    "Profile code, returning [time memory source] results"
    blocks [block!] "Block of code values (block, word, or function) to profile"
    /accuracy run-time [time!] "Longer time gives more accurate results, but takes longer to compute. Default 0:00:00.1"
    /show "Display results, instead of returning them as a block"
][
    baseline: delta-time/accuracy [] run-time
    res: collect [
        foreach blk blocks [
            ; I'm not convinced about the significance of memory stats when computed this way,
            ; but I'm going to leave it here -Gab
            stats-1: stats                              ; get current stats before evaluation
            n: subtract delta-time/accuracy :blk run-time baseline
            keep/only reduce [
                n
                stats - stats-1
                ; any practical purpose for copying blk here? -Gab
                either block? :blk [copy blk][:blk]
            ]
        ]
    ]
    sort res                                            ; sort by time
    either show [
        unless empty? res [
            reference: res/1/1
        ]
        fmt-time: function [time] [
            rel: time / reference
            rejoin [round/to rel 0.01 "x (" format-time time ")"]
        ]
        print-table [
            "Time" 20 fmt-time
            "Memory" 11
            "Code" mold/flat
        ] res
    ][
        insert/only res copy [Time Memory Code]
        new-line/all res on                             ; Return formatted results
    ]
]

e.g. [
    probe profile []
    profile/show []
    
    print ""
    probe profile [[wait 1] [wait .25] [wait .5]]
    probe profile [[100 / 1 * (100 / 1)] [100.0 / 1.0 ** 2] [100% / 1%]]
    
    one: [1 + 1]
    two: [2 + 2]
    probe profile [one two]

    print ""
    profile/show [[wait 1] [wait .25] [wait .5]]
    print ""
    profile/show [[100 / 1 * (100 / 1)] [100.0 / 1.0 ** 2] [100% / 1%]]
    print ""
    profile/show [one two]
    print ""
    
    b1: [wait .25]
    b2: [wait .5]
    profile/show reduce [b1 b2]
    print ""

    f1: does [wait .25]
    f2: does [wait .5]
    profile/show reduce [:f1 :f2]
]