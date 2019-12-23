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
    /count ct [integer! time! none!] "Eval the code this many times, rather than once; if time! determine automatically"
][
    if word? :code [code: get code]
    cd: either block? :code [code] [[code]]
    ct: any [ct 0:00:00.1]
    either time? ct [
        run-time: to float! ct
        time: 0
        count: 1
        while [time < run-time] [
            time: to float! delta-time* cd count
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
        ; because of time! limited accuracy, we return time needed to run 10000 times.
        to time! 10000 * result
    ] [
        delta-time* cd ct
    ]
]

runs-per: function [
    "Return the number of times code can run in a given period"
    code [block! word! function!] "Code to evaluate"
    time [time!]
][
    t: delta-time/count :code time
    to integer! 10000 * time / t
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
    "Profile code, returning [total-time time memory source] results"
    blocks [block!] "Block of code values (block, word, or function) to profile"
    /count ct [integer! time!] "Eval code this many times, rather than determine automatically; or time! for accuracy (longer = more accurate)"
    /show "Display results, instead of returning them as a block"
][
    ct: any [ct 0:00:00.1]
    baseline: delta-time/count [] ct
    count: either time? ct [10000] [ct]
    res: collect [
        foreach blk blocks [
            ; I'm not convinced about the significance of memory stats when computed this way,
            ; but I'm going to leave it here -Gab
            stats-1: stats                              ; get current stats before evaluation
            n: subtract delta-time/count :blk ct baseline
            keep/only reduce [
                round/to n .001
                round/to n / count .001
                stats - stats-1
                ; any practical purpose for copying blk here? -Gab
                either block? :blk [copy blk][:blk]
            ]
        ]
    ]
    sort res                                            ; sort by time
    either show [
        print ["Count: " count]
        template: [pad (time) 12 #"|" pad (time-per) 12 #"|" pad (memory) 11 #"|" (mold/flat :code)]
        insert/only res ["Time" "Time (Per)" "Memory" Code] ; last column is molded, so not a string here
        foreach blk res [
            set [time: time-per: memory: code:] blk
            print compose template
        ]
    ][
        insert/only res compose [count: (count) fields: [Time Time-Per Memory Code]]
        new-line/all res on                             ; Return formatted results
    ]
]
e.g. [
    profile []
    profile/show []
    
    profile [[wait 1] [wait .25] [wait .5]]
    profile/count [[100 / 1 * (100 / 1)] [100.0 / 1.0 ** 2] [100% / 1%]] 1000000
    
    one: [1 + 1]
    two: [2 + 2]
    profile [one two]

    profile/show [[wait 1] [wait .25] [wait .5]]
    profile/show/count [[100 / 1 * (100 / 1)] [100.0 / 1.0 ** 2] [100% / 1%]] 1000000
    profile/show [one two]
    
    b1: [wait .25]
    b2: [wait .5]
    profile/show/count reduce [b1 b2] 2

    f1: does [wait .25]
    f2: does [wait .5]
    profile/show/count reduce [:f1 :f2] 2
    
]