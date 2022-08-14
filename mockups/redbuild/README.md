# RedBuild & RedBuildGUI

- `redbuild` provides automation for building Red from sources.

```
$ redbuild --help
red build 14-Aug-2022 Build CLI or GUI Red console from sources

Syntax: redbuild [options] <console>

Options:
                    <console>     CLI or GUI
  -t, --target      <tname>       Specify compilation target (default:
                                  Windows)
  -d, --debug                     Compile in debug mode
  -s, --sources     <spath>       Path to Red sources
  -o, --output      <opath>       Path where to save compiled binary
  -b, --branch      <bname>       Specify alternate branch (otherwise builds
                                  currently active one)
  -m, --module      <mname>       Include given module(s)
      --shortcut    <scut>        Also create a shortcut for everyday usage
      --version                   Display program version and exit
  -h, --help                      Display this help text and exit
```

Usage example: `redbuild cli -m view -b master -s %root%\red\source -o %root%\red\builds --shortcut %root%\bin\redd.exe -d` will build a debug version of CLI console with View module included on top of the `master` branch, shoving the output into `builds` directory and adding a handy `redd` shortcut.

---

- `redbuildgui` is a newbies interface to it, allowing one to compile Red with zero knowledge of the process.

![](https://i.gyazo.com/ccd6045afe019fb46f1771f2030f1586.png)

---

See also [`reddl`](../reddl/) for auto downloads.
