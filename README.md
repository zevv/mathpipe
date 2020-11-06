
Mathpipe is a simple command line tool to do batch calculations and
transformations on numbers found in plain text files. One or more expressions
are passed which are evaluated, the input is read anything that looks like a
number on standard input.

Kind of like a streaming spreadsheet.

## Examples

- Create a running sum: `mp  sum(%1)"`
- Low pass filter noisy data: `mp "lowpass %1"`
- Basic arithmatic with multiple columns: `mp "$1 * ($2 + $3)"`
- Quickly generate a histogram of data: `mp "histogram($1)"`
- Get the sum and difference of two values: `mp "%1+%2" "%1-%2"`


## Function reference

### Trigonomety

- `cos(val)`
- `sin(val)`
- `tan(val)`
- `atan(val)`
- `hypot(val1, val2)`

### Bit arithmetic

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

### Signal processing

- `lowpass(val [,alpha [,Q]])`: Biquad lowpass filter. `alpha` is the frequency
  in range `0..0.5`, `Q` is the filter Q factor.
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
