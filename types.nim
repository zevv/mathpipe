
import strformat
import sequtils
import strutils

type

  NodeKind* = enum
    nkVoid, nkFloat, nkVar, nkCol, nkCall, nkString, nkBool

  Node* = ref object
    case kind*: NodeKind
    of nkVoid:
      discard
    of nkBool:
      vBool: bool
    of nkFloat:
      vFloat*: float
    of nkString:
      vString: string
    of nkVar:
      varIdx*: int
    of nkCol:
      colIdx*: int
    of nkCall:
      fd*: FuncDesc
      fn*: Func
      args*: seq[Node]

  Func* = proc(val: openArray[Node]): Node

  FuncDesc* = object
    name*: string
    argKinds*: seq[NodeKind]
    retKind*: NodeKind
    factory*: proc(): Func


proc toNode*(v: SomeNumber): Node =
  Node(kind: nkFloat, vFloat: v.float)

proc toNode*(v: string): Node =
  Node(kind: nkString, vString: v)

proc toNode*(v: bool): Node =
  Node(kind: nkBool, vBool: v)

proc getFloat*(n: Node): float =
  assert n.kind == nkFloat
  n.vFloat

proc getInt*(n: Node): int =
  let f = n.getFloat
  result = f.int
  if result.float != f:
    raise newException(ValueError, "Value " & $f & " has no integer representation")

proc getString*(n: Node): string =
  assert n.kind == nkString
  n.vString

proc getBool*(n: Node): bool =
  assert n.kind == nkBool
  n.vBool

proc `$`*(k: NodeKind): string =
  system.`$`(k)[2..^1].toLowerAscii()

proc `$`*(fd: FuncDesc): string =
  result = fd.name & "(" & fd.argKinds.mapit($it).join(", ") & "): " & $fd.retKind

proc `$`*(n: Node): string =
  case n.kind:
  of nkCall: $n.fd
  of nkFloat: &"{n.vFloat:g}"
  of nkBool: (if n.vBool: "true" else: "false")
  of nkString: n.vString.escape
  of nkVar: "$" & $n.varIdx
  of nkCol: "#" & $n.colIdx
  else: ""


