# MAPCONV

The tool to convert `#()` to `#[]` and vice versa.

Helps repair your code after the breaking change of swapping map `#()` and datatype `#[]` syntaxes.

What it does is converts every `#()` into `#[]`, and every `#[]` into `#()`. So it can both convert and restore the original.

```
$ mapconv --help
mapconv 14-Jan-2022 Analyze & convert #() and #[] syntax constructs

Syntax: mapconv [options] <root>

Options:
                    <root>        File, mask or directory
  -a, --analyze                   Only count occurrences & show (default)
  -c, --convert                   Swap #() and #[] syntax in files
      --version                   Display program version and exit
  -h, --help                      Display this help text and exit
```

Example:
```
$ mapconv red/code
Library\SWF\swf-io.red: #[0] #(1)
Total: #[0] #(1) across 54 files 

$ mapconv -c red/code
written Library\SWF\swf-io.red
Written total 1 of 54 files
```