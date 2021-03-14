This is a sample Red script which purpose is to *automatically hook an external audio track for any video file played*.
It works transparently by finding the appropriate audio and invoking your favorite media player, presenting you with a choice when appropriate.

### Binaries

- [Windows](https://gitlab.com/hiiamboris/red-cli/raw/master/mockups/a+v/a+v.exe)
- [Linux](https://gitlab.com/hiiamboris/red-cli/raw/master/mockups/a+v/a+v)

### CLI usage
```
Syntax: a+v [options] <vfile>

Options:
      --config      <conffile>    default: <exe-name>.conf
      --player      <plcmd>       default: mpv
      --avcall      <avcmd>       default: "(player)" "(vfile)" --audio-file
                                  "(afile)"
      --vcall       <vcmd>        default: "(player)" "(vfile)"
      --size        <query-size>  default: 400x150
      --font-name   <query-font-name>
      --font-size   <query-font-size> default: 12
  -x, --exclude     <xmasks>      Don't treat files with this mask as audio
      --version                   Display program version and exit
  -h, --help                      Display this help text and exit
```

### Usage for Windows noobs
- Optionally, edit `a+v.conf` to set your `player` or other stuff. Almost any value defined by `a+v` function can be overridden in config.
- Use `assoc` and `ftype` commands to invoke the `a+v.exe`, like this:
```
for %i in (.mkv .mp4 .wmv) do assoc %i=player
ftype player=c:\bin\a+v.exe "%1"
```

### Compilation
1. [Download Red (use nightly builds!)](https://www.red-lang.org/p/download.html)
2. Clone this repository
3. Download all the dependencies. To do that in Red console type:
```
foreach url [
	https://gitlab.com/hiiamboris/red-cli/-/raw/master/cli.red
	https://gitlab.com/hiiamboris/red-mezz-warehouse/-/raw/master/glob.red
	https://gitlab.com/hiiamboris/red-mezz-warehouse/-/raw/master/composite.red
	https://gitlab.com/hiiamboris/red-mezz-warehouse/-/raw/master/setters.red
	https://gitlab.com/hiiamboris/red-mezz-warehouse/-/raw/master/with.red
][
	set [_ file] split-path url
	write probe file read url
]
```
4. Compile the exe: `red -r -e a+v.red`

### Preview
<img src="https://i.gyazo.com/5ab3f989c9941a6291b614185d6d880b.png" alt="screenshot" width=400 height=300>
