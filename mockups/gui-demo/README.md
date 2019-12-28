**GUI+CLI mixed mode program demo**

- on normal run, it does not spawn any console windows
- when given an argument, it directs output to a console (creates one if it has to)
- full control over console usage
- COMPILE it, as run from Red it works anyways

Implemented for Windows only, otherwise output behavior is unchanged.
I'm not sure how MacOS target should handle that properly.

Bug: in FAR to see the output run it from a shell (`cmd /c gooey --help` etc). Or using redirection (`view:<gooey --help`). Looks like a FAR bug to me.
