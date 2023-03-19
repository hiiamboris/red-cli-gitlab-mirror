**Command-line Screen Grabber**

that leverages GUI+CLI mixed mode (I externalized this functionality as [console-on-demand.red](console-on-demand.red))

Build it with `build-grab.red` script. Make a shortcut to the exe with desired options and put it into a toolbar or somewhere.

```
grab 19-Mar-2023 Screen grabber demo

Syntax: grab [options]

Options:
      --offset      <ofs>         Left top corner (default: 0x0)
      --size        <sz>          Region to capture (default: screen size -
                                  offset)
      --into        <dir>         Save image in a directory path (default:
                                  current directory)
      --select                    Interactively select an area (overrides
                                  offset and size)
      --clip                      Copy filename into clipboard as well
      --version                   Display program version and exit
  -h, --help                      Display this help text and exit
```