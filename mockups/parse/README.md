# Parse tool: command line interface to Parse

Binaries: [Windows](parse.exe), [Linux](parse)
Compiling: `red -r parse.red`

```
>parse.exe --help
Parse tool 24-Mar-2021 - Process input using Parse commands -

Syntax: parse [options] <input> <rule>

Options:
                    <input>       File to parse
                    <rule>        Rule to match against, written in Red PARSE
                                  dialect
  -l, --lines                     Parse input line-by-line (default: as a
                                  single string)
  -e, --enum                      Display line numbers together with the text
                                  (implies /lines)
  -c, --collect                   Collect matches and print to the console
  -v, --verbose                   Verbose output
      --version                   Display program version and exit
  -h, --help                      Display this help text and exit


Parse tool works in 2 modes: LINE mode and FILE mode

1. In FILE mode, it matches full file text against the RULE
   and returns 0 if RULE fully covers the file, or 1 if not.

   If COLLECT option is provided, collected tokens (if any)
   are also printed to the console.

2. In LINE mode, it splits text into lines, then matches RULE against every line.

   If COLLECT option is provided, it prints result collected from ALL lines.
   If not, it prints each line that matches the RULE.

Examples:

   Displaying all lines containing 2 consecutive vowels:
parse -e FILE "(cs: charset {AEIOUaeiou}) to 2 cs to end"

   List what datatypes a file contains:
for %%i in (integer! float! tuple! string! file!) do (
    parse FILE "to %%i to end"
    if not errorlevel 1 echo Contains %%i
)

   Collect all mixed-case words:
parse -c FILE "any [thru [any { } copy w word!] (w: to string! w) opt [if (not any [w == uppercase copy w  w == lowercase copy w]) keep (transcode/one w)]] to end"

   Extract columns 8-15 from the text
parse -c -l FILE "0 8 skip keep copy _ 0 8 skip to end"

   Extract all line comments from the script:
parse -c -l parse.red "to {;} keep to end"
```

See `test*.bat` files. Example output:
```
>test1.bat

Displaying all lines containing 2 consecutive vowels:

1       # Parse tool: command line interface to Parse
5       Parse tool 24-Mar-2021 - Process input using Parse commands -
7       Syntax: parse [options] <input> <rule>
9       Options:
11                          <rule>        Rule to match against, written in Red PARSE
12                                        dialect
13        -l, --lines                     Parse input line-by-line (default: as a
16                                        (implies /lines)
18        -v, --verbose                   Verbose output
19            --version                   Display program version and exit
23      Parse tool works in 2 modes: LINE mode and FILE mode
25      1. In FILE mode, it matches full file text against the RULE
28         If COLLECT option is provided, collected tokens (if any)
31      2. In LINE mode, it splits text into lines, then matches RULE against every line.
33         If COLLECT option is provided, it prints result collected from ALL lines.
34         If not, it prints each line that matches the RULE.
38         Displaying all lines containing 2 consecutive vowels:
39      parse -e FILE "(cs: charset {AEIOUaeiou}) to 2 cs to end"
41         List what datatypes a file contains:
42      for %%i in (integer! float! tuple! string! file!) do (
44          if not errorlevel 1 echo Contains %%i
48      parse -c FILE "any [thru [any { } copy w word!] (w: to string! w) opt [if (not any [w == uppercase copy w  w == lowercase copy w]) keep (transcode/one w)]] to end"
51      parse -c -l FILE "0 8 skip keep copy _ 0 8 skip to end"
54      parse -c -l parse.red "to {;} keep to end"
57      See `test*.bat` files. Example output:
```
```
>test2.bat

What datatypes a file contains?

Contains integer!
Contains float!
Contains string!
Contains file!
```
```
>test3.bat

Displaying all mixed-case words:

[
    Parse
    Parse
    Parse
    -Mar-2021
    Process
    Parse
    File
    Rule
    Red
    Parse
    Display
    Collect
    Verbose
    Display
    Display
    Parse
    In
    If
    In
    If
    If
    Displaying
    AEIOUaeiou
    List
    Contains
    Collect
    Extract
    Extract
    See
    Example
]
```
```
>test4.bat |more
Extracting columns 8-15 from the text

[
    "tool: co"
    ""
    ""
    "xe --hel"
    "ol 24-Ma"
    ""
    "parse [o"
    ""
    ""
    "        "
    "        "
    "        "
    "lines   "
    "        "
    "enum    "
    "        "
    "collect "
    "verbose "
    "version "
    "help    "
    ""
    ""
    "ol works"
    ""
    "LE mode,"
    "eturns 0"
    ""
    (...)
]
```
```
>test5.bat
>pfind README.md /
                                  (implies /lines)
parse -c FILE "any [thru [any { } copy w word!] (w: to string! w) opt [if (not any [w == uppercase copy w  w == lowercase copy w]) keep (transcode/one w)]] to end"
```
```
>test6.bat

Extracting all line comments from the script

[
    {;@@ ideally should not be needed, but binary mode allows parsing by datatype, which is cool}
    {;@@ TODO: "-" for stdin? not possible until ports though}
    {; /case    "Use case-sensitive comparison"^-;@@ BUG: always applies - #4862}
    {;-- expose line-number to rule (e.g. `keep (line-number)`)}
    ";-- use uppercased name"
    {;^} keep to end"}
]
```
