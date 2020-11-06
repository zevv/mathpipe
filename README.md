
Mathpipe is a simple command line tool to do batch calculations and
transformations on numbers found in plain text files. One or more expressions
are passed which are evaluated, the input is read anything that looks like a
number on standard input.

Kind of like a streaming spreadsheet.

## examples

- Create a running sum: `mp  sum(%1)"`
- Low pass filter noisy data: `mp "lowpass %1"`
- Basic arithmatic with multiple columns: `mp "$1 * ($2 + $3)"`
- Quickly generate a histogram of data: `mp "histogram($1)"`
- Get the sum and difference of two values: `mp "%1+%2" "%1-%2"`

