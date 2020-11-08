
import npeg
import tables
import strutils
import math
import os
import sequtils
import strformat
import stats
import strutils

import primitives
import types


# Common grammar

proc parseNumber(s: string): float =
  if s.len > 2 and s[1] in {'x','X'}:
    result = s.parseHexInt.float
  else:
    result = s.parseFloat


grammar numbers:

  exponent <- {'e','E'} * ?{'+','-'} * +Digit

  fraction <- '.' * +Digit * ?exponent

  number <- '0' * ({'x','X'} * Xdigit | ?fraction) |
            {'1'..'9'} * *Digit * ?fraction |
            fraction


# Parse list of expressions into a seq of AST Nodes

const exprParser = peg(exprs, st: seq[Node]):

  S <- *Space

  number <- >numbers.number:
    st.add newFloat parseNumber($1)

  column <- '#' * >+Digit:
    st.add Node(kind: nkCol, colIdx: parseInt($1))

  variable <- '$' * >+Digit:
    st.add Node(kind: nkVar, varIdx: parseInt($1))

  args <- *(arg * ?"," * S)

  arg <- exp:
    st[^2].args.add st.pop

  functionName <- Alpha * *Alnum:
    # temporary placeholder to collect arguments
    st.add Node(kind: nkCall)

  call <- >functionName * ( "(" * args * ")" | args):
    # replace placeholder with full nkCall node
    st[^1] = newCall($1, st[^1].args)


  bool <- "true" | "false":
    st.add newBool($0 == "true")

  string <- '"' * >*(1 - '"') * '"':
    st.add newString $1

  atom <- (variable | column | number | bool | string | call | parenExp | uniop) * S

  parenExp <- ( "(" * exp * ")" )                                 ^   0
  
  uniop <- '-' * exp:
    st.add newCall("neg", @[st.pop])

  binop <- >("|" | "or" | "xor")                            * exp ^   3 |
           >("&" | "and")                                   * exp ^   4 |
           >("+" | "-")                                     * exp ^   8 |
           >("*" | "/" | "%" | "<<" | ">>" | "shl" | "shr") * exp ^   9 |
           >("^")                                           * exp ^^ 10 :

    let (a2, a1) = (st.pop, st.pop)
    let args = @[a1, a2]
    st.add newCall($1, args)

  exp <- S * atom * *binop * S

  exprs <- exp * *( ',' * S * exp) * !1


# Input parser: finds all numbers in a line

const inputParser = peg line:
  line <- *@>numbers.number


# Evaluate AST tree

proc eval(n: Node, args: seq[float], cols: seq[string]): Node =
  proc aux(n: Node): Node =
    case n.kind
    of nkVar: newFloat args[n.varIdx-1]
    of nkCol: newString cols[n.colIdx-1]
    of nkCall: n.fn(n.args.map(aux))
    else: n
  result = aux(n)


# Main code

proc main() =

  # Parse all expressions from the command line

  var root: seq[Node]
  let expr = commandLineParams().join(" ")
  try:
    let r = exprParser.match(expr, root)
    if not r.ok:
      echo "Error: ", expr
      echo "       " & repeat(" ", r.matchMax) & "^"
      quit 1
  except:
    stderr.write getCurrentExceptionMsg() & "\n"
    quit 1

  # Parse stdin to find all numbers, and for each line evaluate the
  # expressions

  for l in lines(stdin):
    let r = inputParser.match(l)
    if r.ok:
      try:
        let vars = r.captures.mapIt(it.parseNumber)
        let cols = l.splitWhitespace()
        echo root.mapIt($it.eval(vars, cols)).join(" ")
      except:
        #stderr.write("warning: " & getCurrentExceptionMsg() & "\n")
        discard


main()
