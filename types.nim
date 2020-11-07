
import strformat

type

  NodeKind* = enum
    nkFloat, nkVar, nkCall, nkString, nkBool

  Node* = ref object
    case kind*: NodeKind
    of nkFloat:
      vFloat*: float
    of nkVar:
      varIdx*: int
    of nkCall:
      fd*: FuncDesc
      fn*: Func
    of nkString:
      vString: string
    of nkBool:
      vBool: bool
    kids*: seq[Node]

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


proc checkKind(n: Node, k: NodeKind) =
  if n.kind != k:
    raise newException(ValueError, "Node " & $n.kind & " is not a " & $k)

proc getFloat*(n: Node): float =
  n.checkKind nkFloat
  n.vFloat

proc getInt*(n: Node): int =
  let f = n.getFloat
  result = f.int
  if result.float != f:
    raise newException(ValueError, "Value " & $f & " has no integer representation")

proc getString*(n: Node): string =
  n.checkKind nkString
  n.vString

proc getBool*(n: Node): bool =
  n.checkKind nkBool
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


