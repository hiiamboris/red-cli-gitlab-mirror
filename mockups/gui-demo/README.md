**GUI+CLI mixed mode program demo**

- on normal run, it does not spawn any console windows
- when given an argument, it directs output to a console (creates one if it has to)
- full control over console usage
- COMPILE it, as run from Red it works anyways

Implemented for Windows only, otherwise output behavior is unchanged.
I'm not sure how MacOS target should handle that properly.

Red does not compile printing function when targeting a GUI program (i.e. with `-t Windows`). So, to make it work:
- compile it as a console app: `red -r -t MSDOS gooey.red`
- use Red Console to turn it into GUI app: `>> flip-exe-flag gooey.exe`
- use it! `gooey --help`

There's also a `build-gooey.red` script that does just that.

In case output does not show (if immediately hidden by the parent process), try `cmd /c gooey --help`. But this should not happen.

What the code does:
- it attaches to parent process' console (if any) or creates a new one
- this leads to a change in stdin/stdout handles, so it updates the handles

Unfortunately this works for Red code only, as Red has it's own print system.
Doesn't work in R/S as R/S uses libc's `printf` and I haven't found a way to update libc's standard handles.
They are internal to `msvcrt.dll` and while there's a solution on the web using `_open_osfhandle` function, it doesn't seem to work.
So, keep that in mind when printing from routines or R/S code.
