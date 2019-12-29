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
