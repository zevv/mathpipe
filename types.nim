
import strformat

type

  NodeKind* = enum
    nkFloat, nkVar, nkCall, nkString, nkBool

  Node* = ref object
    case kind*: NodeKind
    of nkBool:
      vBool: bool
    of nkFloat:
      vFloat*: float
    of nkString:
      vString: string
    of nkVar:
      varIdx*: int
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


proc newFloat*(v: float): Node =
  Node(kind: nkFloat, vFloat: v)

proc newString*(v: string): Node =
  Node(kind: nkString, vString: v)

proc newBool*(v: bool): Node =
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

proc `$`*(n: Node): string =
  case n.kind:
  of nkFloat:
    &"{n.vFloat:g}"
  of nkBool:
    if n.vBool: "true" else: "false"
  of nkString:
    n.vString
  else: ""

