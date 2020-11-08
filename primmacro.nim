import macros

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
    if i == n.len-1:
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
     
    else:
      body.add nc
      discard

  let res = quote do:
    funcTable.mgetOrPut(`name`, @[]).add FuncDesc(
      name: `name`,
      argKinds: @`argKinds`,
      retKind: `retKind`,
      factory: proc(): Func = `body`
    )

  #echo res.repr
  res
