Random stress tests for CLI.
<br>Goal: detect unwanted changes introduced by refactoring, new features, or Red regressions and deep changes.
<br>CLI allows testing the program from within Red (see tests at the bottom of `cli.red`),
it has a lot of tests inside of it,
but the output formatter itself remains not covered because of it's size
(unwise to bloat it with the whole CLI output). So I moved it out.

<br>`run-all-tests.bat` - generates `output.txt` from all tests results
<br>`check-output.bat` - compares `output.txt` to saved result `output.saved`
<br>`save-output.bat` - replaces `output.saved`
<br>`gen-random-test.red` - generates lots of random tests (random operands, options, arguments, refinements to `process-into` func)
<br>`my-prog-ram.red` - (so far the only) test script that is tested
