Red [needs: 'view]

#include %../../cli.red
reddo: func ["Execute Red code from command line" code] [do expand-directives load code]
cli/process-into reddo