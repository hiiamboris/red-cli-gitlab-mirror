- [Simple & powerful command line argument validation system](#simple---powerful-command-line-argument-validation-system)
  * [Goals](#goals)
  * [Idea](#idea)
  * [Introduction](#introduction)
    + [Display of similarities](#display-of-similarities)
    + [CLI showcase](#cli-showcase)
  * [Rules](#rules)
    + [Type checking and conversion](#type-checking-and-conversion)
  * [Usage](#usage)
  * [Implementation details](#implementation-details)
  * [Notes](#notes)
    + [Case sensitivity](#case-sensitivity)
    + [Numeric options](#numeric-options)
    + [Option categories](#option-categories)
    + [Conflicting options](#conflicting-options)
  * [Possible extensions](#possible-extensions)
      - [1. Aggregation](#1-aggregation)
      - [2. Abbreviation](#2-abbreviation)
      - [3. Optional option arguments](#3-optional-option-arguments)
      - [4. Unblocking singular values](#4-unblocking-singular-values)
      - [5. Multiple values](#5-multiple-values)
      - [6. Sticking](#6-sticking)
      - [7. Extended character set](#7-extended-character-set)
      - [8. Case sensitivity](#8-case-sensitivity)
      - [9. Raw option names](#9-raw-option-names)
      - [10. Error & output control](#10-error---output-control)
      - [11. Platform-specific option/switch names polymorphism](#11-platform-specific-option-switch-names-polymorphism)
      - [Other](#other)
    + [Intermediate form](#intermediate-form)
  * [References](#references)


# Simple & powerful command line argument validation system

## Goals

- make usage of CLI args **effortless** for most cases
- provide enough **flexibility** so that less common cases won't require one to reinvent the wheel

## Idea

Command line is the API through which program exposes it's facilities to the outside world - users and utilities.
In Red we already have such powerful API: **function spec** DSL, that exposes function's facilities to the rest of Red code.

So why not leverage it?

Think of the **benefits**:
- No need to parse options or deal with them in any way. You get everything out of the box.
- No separate DSL to remember. Just the so familiar function spec DSL.
- You can test your program as a whole, how it will behave with any set of options, by invoking a Red function and checking it's returns and side effects.
- You can turn any Red function into a command line utility with one or two words. Suppose you have a `grep` function that is to be used from Red.
Prefix it with `process-into`, add `print` for the output, compile it, and you have a `grep` utility!

We can:
- reuse it as is
- reuse it with slight modifications if that makes the CLI description cleaner

The **former** will look like this:
- we define a function (e.g. `my-program: func [...]`) using the standard function spec DSL, just keeping in mind a few simple [Rules](#rules)
- `my-program` may either prepare the environment according to given arguments, or contain the whole program code (preferably the higher level logic that will hint the reader what the program does)
- call `cli/process-into my-program` to end up inside `my-program` with everything already set up and verified

If we **deviate** from the function spec DSL, it may look like this:
```
cli/process-into [
	modified
	/spec
		DSL
][
	code that will be bound to the context with the words set to prepared and checked data
]
```
It will prevent us from directly calling `my-program` though. So far I don't have any solid reasons to do that.

This implementation focuses on the 1st option - reuse.


## Introduction

Some **terms**:
- "option" = an optional argument (`--option` or `--option value`)
- "argument to an option" = value that is passed with the option
- "operand" = a mandatory argument to the program

### Display of similarities

Look at the function spec DSL:
```
function-name: func [
	"Describes the function as a whole"
	arg1 [type!]	        	;) arguments can be automatically type checked
	arg2 "Describes argument purpose"
	arg3				;) a fixed number of MANDATORY arguments ("operands")
	/ref1				;) optional flags
	/ref2				;) optional flags with parameters that become mandatory if this flag is specified
		opt2
	/ref3 "Describes flag purpose"
		opt31 "Describes flag parameter"
		opt32			;) we can have multiple parameters
]
```

Function invocation:
```
function-name/ref2 arg1 arg2 arg3 opt1
```

And now compare with usual syntax help output:
```
long-program-name version 1.2.3 "extra description"
Syntax:
	exe-name [-a] [-b <valb>] [--long-opt1=<val1>] [--long-opt2[=<val2>]] <arg1> <arg2> [more-args..]

Some comments can follow....

Options:
	-a		"description of -a"
	-b, --long-opt1=<val1>		;) option can be aliased
			"description of -b"

Other options:					;) can have groups of options with custom names
	--long-opt2[=<val2>]

Comments text and examples....
```

Invocation:
```
exe-name
	-a			;) options can appear before the mandatory arguments
	-b valb1
	-b valb2		;) option can appear multiple or zero times, and is unordered
	arg1
	--long-opt1=val1	;) options can appear anywhere
	arg2
	arg3...			;) can have a variable number of mandatory arguments
	--			;) there's an "end of options" mark that should be "eaten" by the option parser
	--long-opt2=val2	;) options after it will be considered as normal (mandatory) arguments
	--			;) end of options occurring after another end of options is not "eaten"
	arg4...
```

Both DSLs are **equally powerful**, both have mandatory and optional arguments, both have descriptions for each.
It shoudln't be that hard to map one into another.

### CLI showcase

See [References](#references) section for some formal guidelines.

But historically, and still nowadays, CLI is done by everyone in **different flavors**:
- on Windows systems `/a` may be used in place of `-a`, `/abc` in place of `--abc` and `/abc:def` or `/abc def` in place of `--abc=def`
- option arguments can be mandatory (as in `--abc def`) or optional (as in `-Ipath` or `--abc[=def]`)
- core POSIX tools may turn e.g. `-abc 100` into `-a -b -c 100` if all options are defined and one of `-a`, `-b` or `-c` is unary
- options can be ordered (cannot appear randomly/independently), especially widespread on Windows
- GNU long options convention and some Windows programs allow abbreviating long names to the shortest unique substring
- Windows options are usually case-insensitive, while POSIX ones are case-sensitive
- there can be multiple help text pages, and a program will choose one depending on the arguments given
- some programs use a single hyphen with long options (`-option`), some don't use hyphens at all

These are not singular cases, although maybe not very popular either.
We can provide refinements that would support, force or restrict any of these variants.
Yet we should aim for the most portable subset by default.

I recommend the reader to become acquainted with the output from the following commands:
```
	Portable tools:
curl --help (or curl --manual :D)
exiftool
x264 --fullhelp
wget --help
nconvert -help
mpv --list-options

	Windows-specific:
wmic /?:full
sc /?
reg /?
net help
if /?
cmd /?
attrib /?
```
If only to discover that there's no way we can ever cover the whole spectrum of the usage scenarios.
Nor we can cover all the various validation requirements.
We however can provide a set of tools that will aid in these endeavors.

Besides, a program with hundreds of options is so complex that a custom option parser written for it is tiny compared to the whole.
We should target those scenarios where the effort of writing a CLI parser is comparable to that of the whole program.

## Rules

In **general**:
- A function is used as an interface to the outside world
- Function's spec defines all the rules of usage and documents them
- CLI format is derived from the spec automatically
- A command line with all of it's arguments is transformed into a call of this function

**Spec** processing (e.g. for `program: func ["info" a b /xx "docstrings" y /z "alias xx"]`) follow intuitive rules:
- mandatory func arguments (`a b`) become CLI operands
- one-letter refinements (`/z`) become short options (`-z <y>`)
- longer refinements (`/xx`) become long options (`--xx <y>`)
- refinements can have at most one argument (`y`) that becomes an option argument (`-z <y>`, `--xx <y>`)
- `"alias xx"` (or `"alias /xx"`) is a reserved docstring format that declares an alias of another refinement (`/z` as an alias to `/xx` here)
- aliased refinement cannot have arguments of it's own
- if any of the aliased options (`-xx` or `-z`) occur in the command line, all aliased refinements (`/z` and `/xx`) will be set to true
- `program` word itself can be used as Program name or Executable name in help text (in absense of better sources)
- function "info" is used in help text as program description
- refinement/argument "docstrings" other than "alias ref" are used in help text to provide option and argument info (no docstring = same as "")
- `/local`s are ignored


### Type checking and conversion

**Typesets** of function's arguments define accepted data formats.
CLI implementation checks the type of every argument automatically.

In the command line same option can appear **multiple times**: `-t 1 -t 2 -t 3` (maybe interspersed with other options or operands).
We can either **replace** the previous value with the next one (`-t 1 -t 2 -t 3` produces `3`), or **collect** them all (`-t 1 -t 2 -t 3` produces `[1 2 3]`).
Collecting only makes sense for options that accept arguments (`--option value`), not just flags (`--flag`).

If **`block!`** is in the typeset, arguments will be **collected** and passed as a block:
- **1+ values** given are passed as a block
- **zero** values given to an **operand** are passed as an empty block `[]` (only the last operand can be collecting)
- **zero** appearances of an **option** pass cause the corresponding refinement to equal `false` and the argument (if any) to equal `none`, even if it accepts a block

Other than a `block!`, the typeset can contain any **combination** of these **types**:
- `string!` - accepts the argument as is
- `file!` - accepts the result of `to-red-file` on the argument (never fails, but can clean up some bad characters)
- Any subset of **"loadable set"** = `[integer! float! percent! logic! url! email! tag! issue! time! date! pair!]`. In this case argument is `load`ed and it's type checked against the typeset.

Value **type checking** is done in the following order:
1. If typeset contains at least one *loadable* type, try to load it and see if it's loaded type belongs to both the loadable set and the argument typeset. Pass the argument on success.
2. If loaded type is `integer!`, but typeset accepts a `float!`, promote it and pass.
3. If typeset contains `file!`, pass the result of `to-red-file`.
4. If typeset contains `string!`, pass the argument as is.
5. Report an error & quit as all the checks have failed.

`block!` by itself doesn't enforce any type check:
- `[block!]` is same as `[string! block!]`, and each value is passed as is
- `[block! other types..]` will typecheck every argument according to the rules above

If **no** typeset is given, it's treated same as `[string!]` (`default!` includes `string!` so it's no problem).
Do not use `[default!]` explicitly though.


## Usage

Just define a Red function and pass it's name (or path) to `cli/process-into`.

See [mockups/](https://gitlab.com/hiiamboris/red-cli/tree/master/mockups) for a few examples.


## Implementation details

- Operands are **ordered**. Options are not and can be **interleaved** with operands.
- Values given to a collecting option are passed in the **same order** as they occur in command line.
- Options cannot appear between another option and it's argument.

Supported option **formats**:
- `-o value`
- `--option value` (can occur in a single argument if it's quoted)
- `--option=value`

`--` marks the **end of options**, following arguments are considered operands. `--` itself is skipped, but if another `--` occurs in the command line, it will be mapped to the next operand.

Current implementation doesn't help much with **dispatch-type utilities** like Windows' NET, WMIC, etc (unless these utilities also use GNU-like options).
Their logic is to analyze 1st argument, dispatch into a corresponding function.
Like a tree, with each leaf having it's own algorithms and a preformatted locale-specific help page.
On the other hand, these utilities' command line parsing is so straight-forward that there's little we can do at all.
See [Intermediate form](#intermediate-form) for a possible solution.


## Notes

**Default arguments** can be easily handled by the program itself: `option-value: any [option-value default-value]`.
If Red one day starts supporting default argument values in function spec,
we will be able to infer defaults from it automatically, for the help text.

**Example or commentary text** that commands often print at the end of their help can be printed manually.
It's usually too long to appear in a docstring, and although we may repurpose `return:` docstring for that, I don't see it as a particularly bright idea.

### Case sensitivity

Is often used (for short options only).
It cannot be easily provided in Red, as words are case-insensitive.
Even if we modify the function spec, we still can't make a context with both `a` and `A` as separate words.
We can make a map, but it won't be convenient to access.

Easiest thing we can do is prefix (the less frequent) uppercase names with a special char: `/_A`
(if one *badly* needs a `--_a` option, one can write it as `/__a` since `_` will not be uppercased).
Ugliness of `_A` won't matter since `-A` is usually an alias for a longer option `--a-thing`,
and in our code we are going to use the `a-thing` as more descriptive.

In my opinion, writing command lines by hand, without any form of auto-completion, is a thing of the past, and becomes more and more so.
And the inability to do some uppercase shortcuts shouldn't become a showstopper anymore. 21th century around.

### Numeric options

Are also a problem: even though we can have `/1` or `/-1` refinements, we can't use them as words, since `1` and `-1` are integers.
The prefix trick `/_1` may just help to overcome that. Examples apps are `gzip` or `killall`.
But the thing with numerics is that they are ranges, like `-1` to `-9`. It doesn't make any sense to populate words with it as `/_1 /_2 ... /_9`.
Instead the program should use a generic string! placeholder and extract the integer from it. 

Another question is how better to document these numeric options **in help**.
`gzip` documents just `-1` as alias to `--fast` and `-9` as alias to `--best`. So only 2 junk words in function spec.
Not a clue from it's help that one can use `-2` to `-8` as well :)

For now, use a short option that accepts an integer. It's just a bit longer, but way cleaner.


### Option categories

Should we provide a mechanism for **grouping options into categories** in the help text? If so, how?
We could for example pass group info with a refinement, that would be like:
```
[
	/option-x "Group that starts from /option-x and extends up to /option-y"
	/option-y "Group that starts from /option-y and extends up to /option-z"
	/option-z "Group that starts from /option-z and extends up to the end"
]
```

### Conflicting options

If an option `-a` conflicts with `-b`, document it in docstrings and resolve in Red on case to case basis.

**Inverse flags** are trickier.
E.g. you have a `--thing` and `--no-thing` defined, that are mutually exclusive.
The usual approach I think is to use the flag that occurs latest in the command line.
It is sometimes useful: for example you set up a batch file `prog.bat` that will call `prog.exe` with some default arguments, or you have those arguments in the environment, or whatever.
And you want to override these defaults in a call, but it won't work.
In current implementation the receiving function does not possess any positional information, it cannot know if `--no-thing` is after or before `--thing`.
Reporting an error is recommended in such cases, until a better solution is found.

## Possible extensions

These may not be a big advantage, but should be considered nonetheless.

#### 1. Aggregation

Normal for POSIX utilities, see [1]

`/allow-aggregation` will accept `-abc`  as `-a -b -c` if:
- all `/a /b /c` have been defined
- they are nullary (otherwise `-abc` may be read as `-a bc`)
- or we can allow at most one unary argument in the aggregation (Guideline 5 [2])

I think this behavior was popular back in the day, but not anymore.

#### 2. Abbreviation

[1] recommends it

`/allow-abbrev` will accept abbreviations of option names as long as they are unique,
e.g. `--update` and `--upgrade` can be `--upd` and `--upg`.
Note that it's a threat to backward compatibility: a switch introduced in a new version can break old command lines as they become ambiguous.

#### 3. Optional option arguments

`/allow-empty` will allow both `--abc=def` and `--abc` if:
- `/abc def [type! none!]` - includes `none!` in it's type spec

It will forbid `--abc def` form as ambiguous (`program --abc x` - is `x` a mandatory argument or /abc argument?).

Allowing both `-ab` and `-a` will conflict with aggregation.

#### 4. Unblocking singular values

`/unpack-blocks` will, in case of e.g. `/abc def [integer! block!]`, when given a block with single item, pass only that item (e.g. `def = [1]` becomes `def = 1`):
- `arg [integer! block!]` will turn `--arg 1` into `arg = 1` rather than `arg = [1]`, and empty block `arg = []` will become an error
- `arg [integer! block! none!]` will work the same, but empty block `arg = []` will become `arg = none` as it's allowed explicitly

#### 5. Multiple values

`/allow-n-ary` will allow binary, ternary, and more arguments to an option at once: `/abc def ghi` = `--abc <def> <ghi>` (conflicts with `/allow-noarg`, maybe others)

`/allow-multiple` will allow specifying multiple arguments to an option at once, delimited by comma or whitespace: `-a b,c,d` => `-a b -a c -a d` (Guideline 8 [2])

Current implementation is restricted to at most one argument for the following:
- To meaningfully support `--xx=<y>` form, as `--xx=y1 y2 y3` is somewhat confusing, because with the familiar GNU standard, only `y1` is an argument to `xx`, while `y2` and `y3` read as operands.
- I don't recall any utility that would support it
- I didn't decide how to do collection in presence of 2+ arguments: `/x a b`. Maybe `a` and `b` should be either both collecting or both replacing, but not mixed, then it'll work.

#### 6. Sticking

`/allow-sticking` will allow `-ofile` form as an equivalent of `-o file`. Recommended for POSIX compliance [1]


#### 7. Case sensitivity

`/case` so options will be case-sensitive (see [Case sensitivity](#case-sensitivity) notes above)

#### 8. Raw option names

`/no-prefix` will not add `-` and `--` to refinement names automatically (both for help text and cli argument to refinement matching).
A `/--ref` option would constitute what normally would be `/ref`.
This will give full control over option format, but care should be taken for integer options as `/-1` and such can't be words.

#### 9. Error & output control

`/collect-errors` will not report the errors but will collect those into a provided block in some defined format (it's only about those that stem from the command line given).

`/check-all` so it will not stop on the first erroneous argument, but will process as much as possible and report everything at once (may lead to illogical error messages?).

`/output target [string! port!]` will append all output (help, version text, errors) somewhere else than stderr.

#### 10. Platform-specific option/switch names polymorphism

`/platform-specific` will allow `/a` and `/abc:def` instead of `-a` and `--abc def`/`--abc=def` on Windows only (may conflict with other options).

`program /option` syntax looks more reddish, but it's not portable, as everywhere outside of Windows e.g. `/bin` is a directory, not a switch.
Hyphen prefix is a better choice since `-filename` is a rare thing, than can anyway be solved with `--`.
When one writes a Windows-only tool it makes sense though.

#### Other

Should we **list** accepted types of every argument **in the help text**? Or at least provide an option to control that?

Should we allow passing empty strings as **`--option=`**? It can be done with `--option ""` or `--option=""` right now anyway.

Maybe a flag that would **forbid overriding** options that were already encountered? Does this have any use?

If aliasing options by **"alias ..."** string doesn't work for you, propose a better alternative ;)
I'm not totally convinced it's the best approach either. Just the one that seemed simpler to me.

Should **`pair!`** type be added to the [loadable set](#type-checking-and-conversion)?


### Intermediate form

I thought of converting function spec into an intermediate form that would be so general as to **cover all possible CLI cases**. 
But I decided it's only complicating things without giving any tangible advantages.
Filling this intermediate form by hand should be quite tedious, and the level of control it provides is unlikely worth the effort.
CLI implementation could generate it automatically, but what would be the point?

I'm documenting the idea though.

It may look like this in pseudocode.
A set of accepted options would be described by a **forest** - a `block!` of `option!`s (as each `option!` represents a tree).
```
option!: object [
	name:  "name"                         ;) exact option name, formed, as "--option" or "/switch" or whatever
	case?: yes/no	                      ;) case sensitive?
	accept: block of any of [             ;) what this option can match?
		name    - matches only :name word as is (for option names)
		string! - matches anything up to the end of argument, unchecked
		file!   - to-red-file's the string
		type!   - matches a typechecked value (integer! time! etc.)
	]
	next: block of duplets e.g. [         ;) what can follow after this option
		                                  ;) in format [delimiter forest delimiter forest ...]
		                                  ;) an empty `next` would mean the last argument

		sp  [..]                          ;) sp would match [some [sp | tab]] or jump to next argument
		                                  ;) same for any space character in a delimiter string, e.g. ": " or "= "

		":" [..]                          ;) would cover Windows' "/NAME:VALUE" format
		"=" [..]                          ;) would cover GNU "--name=value" format
		""  [..]                          ;) would cover POSIX "-Ipath" sticky format (even if `path` is optional)
	]
	code: [..]                            ;) code to be executed once option is matched (to set refinements, arguments, or whatever)
]
```

**Normal unordered option processing** would be represented by a forest (say, `F`), every tree (option!) of which would refer to the same forest as `next: [sp F]`.

**Dispatch-like utilities** would be described naturally as their logic is tree-like, with every tree and branch possibly unique.
A possible advantage could be in ability to automatically generate multi-page help for these utilities.


## References

- `[1]` "Program Argument Syntax Conventions"
	https://www.gnu.org/software/libc/manual/html_node/Argument-Syntax.html
- `[2]` "POSIX Utility Syntax Guidelines"
	https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html#tag_12_02
- `[3]` "Portable character set"
	https://en.wikipedia.org/wiki/Portable_character_set

