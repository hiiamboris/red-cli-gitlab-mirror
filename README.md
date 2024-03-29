# Simple & powerful command line argument validation system for [Red](http://red-lang.org/)

## [--> EXAMPLES HERE <--](mockups/)

Prefer to learn by example? Start with the [drinking song](mockups/sing/cli-sing.red) and find your way from there.

## Usage

Navigate:
+ [General idea](#general-idea)
+ [Hello world](#hello-world)
+ [Operand vs option](#operand-vs-option)
+ [Short vs long option names](#short-vs-long-option-names)
+ [Nullary vs unary options](#nullary-vs-unary-options)
+ [Allowed value types](#allowed-value-types)
+ [Aliases](#aliases)
+ [Names and description](#names-and-description)
+ [Default arguments](#default-arguments)
+ [Multiple value collection](#multiple-value-collection)
+ [End of options](#end-of-options)
+ [Commands](#commands)
+ [Shortcut options](#shortcut-options)
+ [Script header](#script-header)
+ [More info](#more-info)
+ [Documentation generators](#documentation-generators)

Old design docs can be found [here](design.md).

### General idea

Command line interface of your program is defined by a **single entry function**:
```
program: function [
	..arguments..
]
```
Arguments it accepts are arguments that can be passed to the program from command line:
```
$ program ..arguments..
```
`cli/process-into` function is used with the program name to convert `system/options/args` block into a function call:
```
cli/process-into program		;) calls `program` function, returns what it returns
```

### Hello world
```
Red [name: %hello.red  title: "hello world CLI script"]
#include %cli.red
program: func [hello world] [
	print ["hello:" hello "^/world:" world]
]
cli/process-into program
```
```
$ red "hello.red" hi red
hello: hi
world: red
```
or when compiled into a binary (`red -c -e hello.red`):
```
$ hello hi red
hello: hi
world: red
```

> NOTE: For brevity, all the other examples imply you've included `cli.red` and added the `cli/process-into program` call to it.

### Operand vs option

Basics:
- **operand** is a mandatory value for the program to run
- **option** is.. optional..
- option may have a single **argument**

How to declare:
```
program: function [
	operand "Operand description"
	/option "Option description"
		argument "Argument to option"
]
```
How to use:
```
$ program 123                   # operand: "123", option: false, argument: none
$ program 123 --option 456		# operand: "123", option: true, argument: "456" 
```
Operand and argument names should be of `word!` type (no lit-args or get-args allowed).

### Short vs long option names

Single-letter options are specified with single hyphen, longer options - with 2 hyphens:
```
program: function [
	/o "Short option"
	/option "Long option"
]
``` 
Is invoked as:
```
$ program -o --option			# both set to true
$ program -o                    # o: true, option: false
$ program --option              # option: true, o: false
$ program                       # both set to false
```

### Nullary vs unary options

Option may accept an argument, in which case it's mandatory to provide it.
```
program: function [/a /b arg /opt arg2]
```
Can be invoked as:
```
$ program -a
$ program -b 123
$ program --opt 234
$ program --opt=234
(or any combination of the above options)
```
Failing to provide the argument is a runtime error:
```
$ program --opt
--opt needs a value
```

### Allowed value types

Normally, function receives arguments of `string!` type.\
CLI however can convert it for you if you specify a typeset:
```
program: func [
	operand [integer!]		;) will receive an integer!, not a string!
	/option x [float!]		;) x will receive a float!
]
```
Allowed typesets so far are:

| Typeset | Meaning |
|-|-|
| `[integer!]` | Value must load as `integer!`, or runtime error is produced |
| `[float!]`   | Value must load as `float!` or as `integer!` (automatically promoted into float), or runtime error is produced |
| `[percent!]` | Value must load as `percent!`, or runtime error is produced |
| `[pair!]`    | Value must load as `pair!`, or runtime error is produced |
| `[logic!]`   | Value must load as `word!` and gets automatically converted into `logic!`, else runtime error is produced |
| `[issue!]`   | Value must load as `issue!`, or runtime error is produced |
| `[time!]`    | Value must load as `time!`, or runtime error is produced |
| `[date!]`    | Value must load as `date!`, or runtime error is produced |
| `[url!]`     | Value must load as `url!`, or runtime error is produced |
| `[tag!]`     | Value must load as `tag!`, or runtime error is produced |
| `[email!]`   | Value must load as `email!`, or runtime error is produced |
| `[file!]`    | Converted into `file!` using `to-red-file` |
| any of the above combined | Allows values of multiple types, e.g. `[float! integer!]` for numbers |
| any of the above + `string!` or `file!` | If value is not loaded as the requested type, it's passed as string or file (no runtime error) |
| any of the above + `block!`, e.g. `[file! block!]` | Collects a block of zero or more values of `file!` type (see [collection](#multiple-value-collection)) |
| `[string!]`  | Value is passed as string |
| no type specified | Value is passed as string |

### Aliases

Any option can have any number of aliases:
```
program: function [
	/option argument
	/o "alias /option"
	/o2 "alias /option"
]
```
Then the following invocations are all equivalent:
```
$ program --option 123
$ program -o 123
$ program --o2 123
```
Aliases cannot have arguments.\
Aliases and options can be defined in any order, but it is advised to keep aliases under the aliased option, for readability.

### Names and description

All data from function spec is used for `--help` output:
```
program: function [
	"Program description"
	operand "Operand description"
	/option "Option description"
		arg "Argument description"
	/alias "alias /option"			;) alias can't have it's own description
]
```
Produces the following:
```
$ red program.red --help
program 8-Nov-2021 Program description

Syntax: program [options] <operand>

Options:
                    <operand>     Operand description
      --option, --alias <arg>     Option description; Argument description
      --version                   Display program version and exit
  -h, --help                      Display this help text and exit
```

### Default arguments

By default, `--help` (aliased to `-h`) and `--version` options are supported automatically, and do not require any effort.\
Use `/no-help` and `/no-version` arguments to suppress automatic addition, or alternatively just override them:
```
program: func [
	/version "Check up"
	/help "HEEELP!"
	/h "alias /help"
][
	if help [
		print [
			cli/help-for program
			"Additional text^/^/"
		]
		quit
	]
	if version [
		print [
			cli/version-for program
			"This is all^/^/"
		]
	]
]
```

### Multiple value collection

Default behavior for duplicate options is to override the result:
```
$ red program.red --option 10 --option 20
argument: "20"
```
If option's typeset contains a `block!` type, it becomes a *collecting* option. It can have *one or more* values:
```
$ red program.red --option 10 --option 20 --option 30
argument: ["10" "20" "30"]
$ red program.red
argument: none
```

Last operand can also be made *collecting* by adding `block!` to it's typeset:
```
program: function [op1 op2 [integer! block!]][
	print [op1 "/" op2]
]
```
```
$ red program 1
1 /                  # op2 can become an empty block

$ red program 1 2 3 4 5
1 / 2 3 4 5
```

### End of options

Passing `--` to the command line marks the end of option processing and the rest is treated as operands. This is useful if you wish to pass e.g. file names beginning with hyphen:
```
program: function [a b c /x /y z] [print mold reduce [a b c x y z]]
cli/process-into program
```
```
$ red program.red -- -x -- -y
["-x" "--" "-y" false false none]

$ red program.red 1 -- -x --
["1" "-x" "--" false false none]
```
You get this behavior out of the box and can't turn it off.

### Shortcut options

Automatically provided `--help` and `--version` options do not require one to fill all the operands. Such *shortcut options* can be created manually by listing option names in `/shortcuts` block:
```
program: function [a b c /x /y z] [print mold reduce [a b c x y z]]
cli/process-into/shortcuts program [x y]
```
```
$ red program.red
Not enough operands given

$ red program.red -x
["" "" "" true false none]			# operands get filled with empty data

$ red program.red -y 1
["" "" "" false true "1"]
``` 

### Commands

It's easy to pack multiple **commands** into a single program, just by calling `process-into` with a context of functions.\
Nested contexts can be used to create sub-commands: 
```
program: context [
	math: context [ 
		sum: func [xs [integer! float! block!]] [
			print ["Sum of" mold xs "=" system/words/sum xs]
		]
		product: function [xs [integer! float! block!]] [
			x: 1
			forall xs [x: x * xs/1]
			print ["Product of" mold xs "=" x] 
		]
	]
	help: func [command] [
		print cli/help-for (append 'program/math to word! command)
	]
]
cli/process-into program
``` 
Each command can have it's own set of operands and options.
```
$ red program.red
program 9-Nov-2021

Supported commands:
  program math sum [options] [xs]
  program math product [options] [xs]
  program help [options] <command>

$ red program.red math
program 9-Nov-2021

Supported commands:
  program math sum [options] [xs]
  program math product [options] [xs]

$ red program.red math sum 1 2 3 4
Sum of [1 2 3 4] = 10

$ red program.red math product 1 2 3 4
Product of [1 2 3 4] = 24

$ red program.red help sum
program 9-Nov-2021

Syntax: program math sum [options] [xs]

Options:
      --version                   Display program version and exit
  -h, --help                      Display this help text and exit
```


### Script header

The following header fields are used to build default `--help` and `--version` output, so you might wanna fill them:
```
Red [
	title:   "Used as 'program name' when not explicitly specified"
	version: "When absent, script modification date or compilation date is used"
	author:  "Who wrote the program"
	rights:  "Who's the rights holder"
	license: {
		License text
		may span multiple lines
		<- but mind the indentation
	}
]
```
Additionally:
- `system/platform` and `system/version` are used in Red version report in `--version`
- `system/build/git/commit` when available nails down Red version further
- name of the function (word or first item in path) is used as default program name (with hyphens replaced by spaces, so it's easy to create a name consisting of multiple words, e.g. `The-ultimate-program`)


### More info

It won't hurt to study the function spec:
```
>> ? cli/process-into
USAGE:
     CLI/PROCESS-INTO 'program

DESCRIPTION:
     Calls PROGRAM with arguments read from the command line. Passes through the returned value.
     CLI/PROCESS-INTO is a function! value.

ARGUMENTS:
     'program     [word! path!] {Name of a function, or of a context with functions to dispatch against.}

REFINEMENTS:
     /no-version  => Suppress automatic creation of --version argument.
     /no-help     => Suppress automatic creation of --help and -h arguments.
     /name        => Overrides program name.
        pname        [string!]
     /exename     => Overrides executable name.
        xname        [string!]
     /version     => Overrides version.
        ver          [tuple! string!]
     /post-scriptum => Add custom explanation after the syntax in help output.
        pstext       [string!]
     /args        => Overrides system/options/args.
        arg-blk      [block!]
     /on-error    => Custom error handler: func [error [block!]] [...].
        handler      [function!]
     /shortcuts   => Options (as words) that allow operands to be absent; default: [help h version].
        s-cuts       [block!]
     /options     => Specify all the above options as a block.
        opts         [block! map! none!]
```
And to play in console:
```
$ red --catch cli.red
>> f: func [x][? x]  cli/process-into/args f ["420"] 
X is a string! value: "420"
>> f: func [x][? x]  cli/process-into/args/on-error f ["420" "mph"] func [e] [print e]
ER_MUCH Extra operands given
>> f: func [x][? x]  cli/process-into/args/on-error f [] func [e] [print e]
ER_FEW Not enough operands given
```

Format of runtime errors is `[code [word!] message [string!]]`, codes can be found [in the source](https://gitlab.com/hiiamboris/red-cli/-/blob/0274075b39e9248375f373d774c2b259ccfd6d65/cli.red#L80-89)


### Documentation generators

These you can use to produce help output when needed and modify it when necessary before printing:
```
>> ? cli/help-for
USAGE:
     HELP-FOR 'program

DESCRIPTION:
     Returns help text (version and syntax) for the PROGRAM.
     HELP-FOR is a function! value.

ARGUMENTS:
     'program     [word! path!] "May refer to a function or context."

REFINEMENTS:
     /no-version  => Suppress automatic creation of --version argument.
     /no-help     => Suppress automatic creation of --help and -h arguments.
     /name        => Overrides program name.
        pname        [string!]
     /exename     => Overrides executable name.
        xname        [string!]
     /version     => Overrides version.
        ver          [tuple! string!]
     /post-scriptum => Add custom explanation after the syntax.
        pstext       [string!]
     /columns     => Specify widths of columns: indent, short option, long option, argument, description.
        cols         [block!]
     /options     => Specify all the above options as a block.
        opts         [block! map! none!]
        
```
---
```        
>> ? cli/version-for
USAGE:
     VERSION-FOR 'program

DESCRIPTION:
     Returns version text for the PROGRAM.
     VERSION-FOR is a function! value.

ARGUMENTS:
     'program     [word! path!] "May refer to a function or context."

REFINEMENTS:
     /name        => Overrides program name.
        pname        [string!]
     /version     => Overrides version.
        ver          [tuple! string!]
     /brief       => Include only the essential info.
     /options     => Specify all the above options as a block.
        opts         [block! map! none!]
```
---        
```
>> ? cli/syntax-for
USAGE:
     SYNTAX-FOR 'program

DESCRIPTION:
     Returns usage text for the PROGRAM.
     SYNTAX-FOR is a function! value.

ARGUMENTS:
     'program     [word! path!] "May refer to a function or context."

REFINEMENTS:
     /no-version  => Suppress automatic creation of --version argument.
     /no-help     => Suppress automatic creation of --help and -h arguments.
     /columns     => Specify widths of columns: indent, short option, long option, argument, description.
        cols         [block!]
     /exename     => Overrides executable name.
        xname        [string!]
     /post-scriptum => Add custom explanation after the syntax.
        pstext       [string!]
     /options     => Specify all the above options as a block.
        opts         [block! map! none!]
```        
---
```        
>> ? cli/synopsis-for
USAGE:
     SYNOPSIS-FOR 'program

DESCRIPTION:
     Returns short synopsis line for the PROGRAM.
     SYNOPSIS-FOR is a function! value.

ARGUMENTS:
     'program     [word! path!] "Must refer to a function."

REFINEMENTS:
     /exename     => Overrides executable name.
        xname        [string!]
     /options     => Specify all the above options as a block.
        opts         [block! map! none!]
```