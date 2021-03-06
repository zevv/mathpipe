import macros

#
# This macro transforms and wraps a block of nim code with a proc which
# will be available in the VM as a primitive function or operator
#
#   prim:
#     var vPrev: float
#     proc diff(v: float): float =
#       result = v - vPrev
#       vPrev = v
#
# will be transformed to:
#
#   funcTable.mgetOrPut("diff", @[]).add FuncDesc(name: "diff",
#      argKinds: @[nkfloat], retKind: nkfloat, factory: proc (): Func =
#    var vPrev: float
#    let aux = proc (v: float): float =
#      result = v - vPrev
#      vPrev = v
#    return proc (vs: openArray[Node]): Node =
#      aux(vs[0].getfloat).toNode)


macro prim*(n: untyped) =
  let body = newStmtList()
  var name: NimNode
  var retKind: NimNode
  var argKinds = nnkBracket.newTree()
  let wrapper = ident("aux")
  let vs = ident("vs")
  var wrapcall =  nnkCall.newTree(wrapper)

  proc mpType(n: NimNode): NimNode =
    var name = n.strVal
    if name == "int": name = "float"
    return ident("nk" & name)

  for i, nc in n:
    if i < n.len-1:
      body.add nc
    else:
      nc.expectKind nnkProcDef
      if nc[0].kind == nnkAccQuoted:
        name = newLit(nc[0][0].strVal)
      else:
        name = newLit(nc[0].strVal)
      for i, ti in nc[3]:
        if i == 0:
          retKind = mpType(ti)
        else:
          argKinds.add mpType(ti[1])
          let getter = ident("get" & ti[1].strVal)
          let idx = newLit(i-1)
          wrapcall.add quote do:
            `vs`[`idx`].`getter`
      let lambda = nnkLambda.newTree(newEmptyNode(), newEmptyNode(), newEmptyNode(), nc[3], newEmptyNode(), newEmptyNode(), nc[6])
      body.add quote do:
        let `wrapper` = `lambda`
        return proc(`vs`: openArray[Node]): Node =
          `wrapcall`.toNode

  quote do:
    funcTable.mgetOrPut(`name`, @[]).add FuncDesc(
      name: `name`,
      argKinds: @`argKinds`,
      retKind: `retKind`,
      factory: proc(): Func = `body`
    )
