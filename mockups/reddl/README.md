# RedDL

`reddl` automates download of pre-compiled Red binaries.

Pre-built binaries: [Windows](reddl.exe), [Linux 32-bit](reddl), [Mac 32-bit](reddl-mac)

```
$ reddl --help
reddl 14-Aug-2022 Automate Red downloads

Syntax: reddl [options]

Options:
      --gui         <guiname>     Download GUI console and make a shortcut
                                  (e.g. redgui)
      --cli         <cliname>     Download CLI console and make a shortcut
                                  (e.g. red)
      --comp        <compname>    Download compiler and make a shortcut (e.g.
                                  redc)
  -p, --platform    <pname>       Specify the platform (Windows, Linux,
                                  macOS, Raspberry Pi)
  -a, --archive-path <apath>      Specify directory where to save the files
  -b, --binary-path <bpath>       Specify directory where to save the
                                  shortcuts
      --version                   Display program version and exit
  -h, --help                      Display this help text and exit
```

Usage example: `reddl --gui redgui --comp redc -a %root%\red\builds -b %root%\bin` will download GUI console and the toolchain, save both into `builds` directory and create shortcuts in `bin` named `redgui` and `redc` respectively.

---

See also [`redbuild`](../redbuild/) for auto builds.
