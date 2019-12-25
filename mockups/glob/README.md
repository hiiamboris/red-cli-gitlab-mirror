CLI for my non-recursive GLOB implementation tested up to 100 directories deep paths.

`>cli-glob --from .. --omit *.exe --omit *.red --omit *.bat`
```
[
    %glob/
    %profile/
    %README.md
    %red-cli/
    %sing/
    %synthetic/
    %tester/
    %glob/README.md
    %profile/README.md
    %red-cli/README.md
    %sing/README.md
    %synthetic/README.md
    %tester/output.saved
    %tester/output.txt
    %tester/scripts/
    %tester/tests/
]
```