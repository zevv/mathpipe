
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

  number <- ?'-' * (
            '0' * ({'x','X'} * Xdigit | ?fraction) |
            {'1'..'9'} * *Digit * ?fraction |
            fraction
          )


# Parse list of expressions into a seq of AST Nodes

const exprParser = peg(exprs, st: seq[Node]):

  S <- *Space

  number <- >numbers.number:
    st.add parseNumber($1).toNode

  column <- '#' * >+Digit:
    st.add Node(kind: nkCol, colIdx: parseInt($1))

  variable <- ('$' | '%') * >+Digit:
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
    st.add ($0 == "true").toNode

  string <- '"' * >*(1 - '"') * '"':
    st.add ($1).toNode

  atom <- (variable | column | number | bool | string | call | parenExp | uniop) * S

  parenExp <- ( "(" * exp * ")" )                                 ^   0

  uniop <- >'-' * exp:
    st.add newCall($1, @[st.pop])

  binop <- >("|" | "or" | "xor")                            * exp ^   3 |
           >("&" | "and")                                   * exp ^   4 |
           >("+" | "-")                                     * exp ^   8 |
           >("*" | "/" | "%" | "<<" | ">>" | "shl" | "shr") * exp ^   9 |
           >("^")                                           * exp ^^ 10 :

    let (a2, a1) = (st.pop, st.pop)
    st.add newCall($1, @[a1, a2])

  exp <- S * atom * *binop * S

  exprs <- exp * *( ',' * S * exp) * !1


# Input parser: finds all numbers in a line

const inputParser = peg line:
  line <- *@>numbers.number


# Evaluate AST tree

proc eval(n: Node, args: seq[float], cols: seq[string]): Node =
  proc aux(n: Node): Node =
    case n.kind
    of nkVar: args[n.varIdx-1].toNode
    of nkCol: cols[n.colIdx-1].toNode
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
