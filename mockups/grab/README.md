**Command-line Screen Grabber**

that leverages GUI+CLI mixed mode (I externalized this functionality as [console-on-demand.red](console-on-demand.red))

Build it with `build-grab.red` script

```
grab 5-Jan-2020

Syntax: grab [options]

Options:
      --offset      <ofs>         Left top corner (default: 0x0)
      --size        <sz>          Region to capture (default: screen size -
                                  offset)
      --into        <dir>         Save image in a directory path (default:
                                  current directory)
      --clip                      Copy image into clipboard as well
      --version                   Display program version and exit
  -h, --help                      Display this help text and exit
```