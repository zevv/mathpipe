
Kind of like a spreadsheet for text pipes.

## Usage

Mathpipe takes one or more expressions as command line arguments and reads data
from standard input. The input can contain anything, and is scanned for
everything resembling decimal or hexadecimal numbers. The numbers found in each
lines are available as variables for the expressions through the variables `$1`
.. `$9`.

The expressions can contain the usual arithmatic and binary operators and allow
calling of various built-in functions as described below.

Some of these functions save state over lines, allowing things like
averaging, integration, filtering, etc.

## Examples

- Multiply column #1 by a fixed number: `mp "$1*8"`
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
- `median(val)`: Running median
- `variance(val)`: Running variance
- `stddev(val)`: Running sandard deviation

### Bit arithmetic

The functions below all require the input data to be representable
as integers.

- `x << y` / `x shl y`: Binary shift left
- `x >> y` / `x shr y`: Binary shift right
- `x and y` / `x & y`: Binary and
- `x or y` / `x | y`: Binary or
- `x xor y`: Binary xor

### Generators

- count([stepsize])
- rand([min [, max]])
- gauss([mu [, sigma]])

### Utilities

- `histogram(val)`: Render ASCII historgram of input data
- `histogram(val, width)`: As above, but set width to `width` * stddev

### Logarithms

- `log(val, base)`
- `log2(val)`
- `log10(val)`
- `ln(val)`
- `exp(val)`

### Rounding

- `floor(val)`
- `ceil(val)`
- `round(val)`

### Trigonomety

- `cos(val)`
- `sin(val)`
- `tan(val)`
- `atan(val)`
- `hypot(val1, val2)`

