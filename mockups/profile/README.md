Command-line Red profiler ;)

`>cli-profile "1 + 1" "sqrt 2" "wait 0.01" --accuracy 0:0:1 --show`
```
Time                 | Memory      | Code
1.0x (151ns)         | 1000        | [1 + 1]
1.65x (249ns)        | 328         | [sqrt 2]
66371.84x (10ms)     | 404         | [wait 0.01]
unset
```