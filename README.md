
Mathpipe is a simple command line tool to do batch calculations and
transformations on numbers found in plain text files. One or more expressions
are passed which are evaluated, the input is read anything that looks like a
number on standard input.

Kind of like a streaming spreadsheet.

## Usage

Mathpipe takes one or more expressions as command line arguments and reads
data from standard input. The numbers found in the input lines are available
as variables for the expressions through the notation `$1` .. `$9`.

The expressions can contain the usual arithmatic operators with normal
precedence, and allow calling of various built-in functions as described below.


## Examples

- Multiply column #1 by a fixed number: `mp "%1*2"`
- Create a running sum: `mp sum(%1)"`
- Low pass filter to smooth noisy data: `mp "lowpass(%1)"`
- Basic arithmatic combining multiple columns: `mp "$1 * ($2 + $3)"`
- Render a histogram of input data: `mp "histogram($1)"`


## Function reference

### Signal processing

- `lowpass(val [,alpha [,Q]])`: Biquad lowpass filter. `alpha`: frequency `0..0.5`, `Q`: Q factor.
- `int(val)`: Integrator / summation.
- `diff(val)`: Differentiator

### Statistics

- `min(val)`: Running minimum
- `max(val)`: Running maximum
- `mean(val)`: Running mean / average
- `variance(val)`: Running variance
- `stddef(val)`: Running sandard deviation

### Utilities

- `histogram(val)`: Render ASCII historgram of input data

### Bit arithmetic

The functions below all require the input data to be representable
as integers.

- `x << y` / `x shl y`: Binary shift left
- `x >> y` / `x shr y`: Binary shift right
- `x and y` / `x & y`: Binary and
- `x or y` / `x | y`: Binary or
- `x xor y`: Binary xor

### Logarithms

- `log(val, base)`
- `log2(val)`
- `log10(val)`
- `ln(val)`
- `exp(val)`

### Rounding

- `floor(val)` unOp floor
- `ceil(val)` unOp ceil
- `round(val)` unOp round

### Trigonomety

- `cos(val)`
- `sin(val)`
- `tan(val)`
- `atan(val)`
- `hypot(val1, val2)`

