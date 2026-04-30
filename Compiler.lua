--%%offline:true
-- Compiler.lua: Compiles the EventScript parser AST to CSP table notation.
-- Output is consumed by fibaro.CONT.compile() (CSP.lua's simple compiler).
--
-- Pipeline:  source → Parser → AST → compileAST() → CSP tables → CSP.compile() → expr

fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER

local compile  -- forward-declared so handlers can call each other recursively

-- ── Literal nodes ─────────────────────────────────────────────────────────

local function compNumber(ast) return tonumber(ast[2]) end
local function compString(ast) return ast[2] end
local function compBool(ast)   return ast[2] end
local function compNil()       return {'CONST', nil} end
local function compParen(ast)  return compile(ast[2]) end
local function compName(ast)   return {'GET', ast[2]} end
local function compDo(ast)     return compile(ast[2]) end  -- do…end is just its block

-- ── Binary operators that map 1-to-1 to CSP ops ───────────────────────────

local function compUnaryWrap(op)
  return function(ast) return {op, compile(ast[2])} end
end

local DIRECT_BINOPS = {
  ADD='ADD', SUB='SUB', MUL='MUL', DIV='DIV', MOD='MOD', POW='POW',
  EQ='EQ',  LT='LT',  LTE='LTE', GT='GT',  GTE='GTE',
  AND='AND', OR='OR',
  CONCAT='CONCAT', BETW='BETW',
}

local function compBinop(ast)
  return {DIRECT_BINOPS[ast[1]], compile(ast[2]), compile(ast[3])}
end

local function compNEQ(ast)  -- ~= → NOT(EQ(a,b))
  return {'NOT', {'EQ', compile(ast[2]), compile(ast[3])}}
end

local function compNEG(ast)  -- unary minus
  return {'NEG', compile(ast[2])}
end

local function compNOT(ast)  -- logical not
  return {'NOT', compile(ast[2])}
end

-- ── Assignment target helper ───────────────────────────────────────────────
-- Returns a CSP SET table for a supported lvalue node.
local function compileTarget(var, val_csp)
  if var[1] == 'NAME' then
    return {'SET', var[2], val_csp}
  elseif var[1] == 'GV' or var[1] == 'QV' or var[1] == 'PV' then
    return {"SETVAR", var[1], var[2], val_csp}
  elseif var[1] == 'INDEX' then
    return {"SETINDEX", compile(var[2]), compile(var[3]), val_csp}
  elseif var[1] == 'FIELD' then
    return {"SETFIELD", compile(var[2]), var[3], val_csp}  -- var[3] is raw string; ca() wraps it in CONST
  else
    error("Compiler: unsupported assignment target: " .. tostring(var[1]))
  end
end

-- ── Statement-list compiler (handles LOCAL hoisting) ──────────────────────
-- Compiles stats[i..#stats] into a single CSP expression.
-- LOCAL declarations are hoisted: the remaining statements become the LET body.
local function compileStatList(stats, i)
  if i > #stats then
    return {'CONST', nil}   -- empty tail
  end

  local s = stats[i]

  if s[1] == 'LOCAL' then
    local names = s[2]
    local vals  = s[3] or {}
    local body  = compileStatList(stats, i + 1)
    -- Wrap from last to first name so name[1] is the outermost LET.
    -- local result = body
    -- for j = #names, 1, -1 do
    --   local val_csp = vals[j] and compile(vals[j]) or {'CONST', nil}
    --   result = {'LET', names[j], val_csp, result}
    -- end
    -- return result
    if #names == 1 then 
      return {'LET', names[1], vals[1] and compile(vals[1]) or {'CONST', nil}, body}
    else
      local exprs = {}
      for j = 1, #vals do exprs[j] = vals[j] and compile(vals[j]) or {'CONST', nil}
      end
      return {'LETS', names, exprs, body} 
    end
  end

  local compiled = compile(s)

  if i == #stats then
    return compiled   -- last statement, nothing more to sequence
  end

  -- More statements follow → build a PROGN, flattening adjacent PROGNs.
  local rest = compileStatList(stats, i + 1)
  if type(rest) == 'table' and rest[1] == 'PROGN' then
    local new = {'PROGN', compiled}
    for k = 2, #rest do new[#new + 1] = rest[k] end
    return new
  else
    return {'PROGN', compiled, rest}
  end
end

-- ── Block ──────────────────────────────────────────────────────────────────

local function compBlock(ast)
  -- ast = {'BLOCK', s1, s2, ...}
  local stats = {}
  for i = 2, #ast do stats[#stats + 1] = ast[i] end
  if #stats == 0 then return {'CONST', nil} end
  return compileStatList(stats, 1)
end

-- ── ASSIGN ────────────────────────────────────────────────────────────────
-- {'ASSIGN', vars, vals}
-- Simple sequential evaluation (no Lua swap semantics yet).
local function compAssign(ast)
  local vars = ast[2]
  local vals = ast[3]
  if #vars == 1 then
    return compileTarget(vars[1], compile(vals[1]))
  end
--   local stmts = {'PROGN'}
--   for i, v in ipairs(vars) do
-- ---@diagnostic disable-next-line: assign-type-mismatch
--     stmts[#stmts + 1] = compileTarget(v, compile(vals[i] or {'NIL'}))
--   end
  local tableArgs = {}
  for i,v in ipairs(vals) do 
    tableArgs[#tableArgs + 1] = i
    tableArgs[#tableArgs + 1] = compile(v) 
  end
  local body = {'PROGN'}
  for i,v in ipairs(vars) do
---@diagnostic disable-next-line: assign-type-mismatch
    body[#body + 1] = compileTarget(v, {'INDEX', {'GET', '_tmp'}, i})
  end
  return {'LET','_tmp',{'MAKETABLE',table.unpack(tableArgs)}, body}
end

-- ── IF ────────────────────────────────────────────────────────────────────
-- {'IF', cond, then_block, elseifs, else_block}
-- elseifs = list of {cond_exp, block}
local function compIf(ast)
  local cond    = compile(ast[2])
  local then_br = compile(ast[3])
  local elseifs = ast[4]   -- may be {}
  local else_blk = ast[5]  -- may be nil

  local else_br
  if else_blk then else_br = compile(else_blk) end

  -- fold elseifs right-to-left into nested IFs
  for j = #elseifs, 1, -1 do
    local ec = compile(elseifs[j][1])
    local eb = compile(elseifs[j][2])
    if else_br then
      else_br = {'IF', ec, eb, else_br}
    else
      else_br = {'IF', ec, eb}
    end
  end

  if else_br then
    return {'IF', cond, then_br, else_br}
  else
    return {'IF', cond, then_br}
  end
end

  -- ── WHILE ─────────────────────────────────────────────────────────────────
  -- while cond do body end  →  LOOP(IF(cond, body, BREAK()))
  local function compWhile(ast)
    local cond = compile(ast[2])
    local body = compile(ast[3])
    if cond == true then
      return {'LOOP', body}  -- optimize constant true condition
    else return {'LOOP', {'IF', cond, body, {'BREAK'}}} end
  end

  -- ── REPEAT-UNTIL ──────────────────────────────────────────────────────────────────
  -- repeat body until cond  →  LOOP(body, IF(cond, BREAK()))
  local function compRepeat(ast)
    local body = compile(ast[2])
    local cond = compile(ast[3])
    return {'LOOP', body, {'IF', cond, {'BREAK'}}}    
  end

  -- -- FOR-NUM
  -- for var = start, end, step do body end  →  (equivalent to Lua desugaring)
  local function compFor(ast)
    local var = ast[2]
    local start = compile(ast[3])
    local end_ = compile(ast[4])
    local step = ast[5] and compile(ast[5]) or {'CONST', 1}
    local body = compile(ast[6])
    local loop_var = var  
    return {
      'LET', loop_var, start,
      {'LOOP',
        {'IF', {'GT', {'GET', loop_var}, end_}, {'BREAK'}},
        body, 
        {'SET', loop_var, {'ADD', {'GET', loop_var}, step}}
    }
  }
  end  

  -- FOR-IN
  -- for var in iter do body end ->
  -- local fun = function() return pairs(b) end
  -- local f,t,k,v = fun()
  -- while true do
  --   k,v = f(t,k)
  --   if not k then break end
  --   print(k,v)
  -- end

-- ["LETS",["f","t","k","v"],[["CALL",["GET","fun"]],
--   ["LOOP",
--     ["PROGN",
--       ["LET","_tmp",["MAKETABLE",1,["CALL",["GET","f"],["GET","t"],["GET","k"]]],
--         ["PROGN",
--           ["SET","k",["INDEX",["GET","_tmp"],1]],
--           ["SET","v",["INDEX",["GET","_tmp"],2]]
--         ]
--       ],
--       ["IF",["NOT",["GET","k"]],["BREAK"]],
--       ["CALL",["GET","print"],["GET","k"],["GET","v"]]
--     ]
--   ]
-- ]


  local function compForIn(ast)
    local var = ast[2]
    if #var == 1 then var[#var+1] = 'v_val' end
    local fun_exp = compile(ast[3][1])
    local body = compile(ast[4])
    local k,v,f,t = var[1], var[2], 'f_var', 't_var'
    return {'LETS', {f,t,k,v}, {fun_exp},
      {'LOOP',
        {'PROGN',
          compile({'ASSIGN',{{'NAME',k},{'NAME',v}},{{'CALL',{'NAME',f},{'NAME',t},{'NAME',k}}}}),
          {'IF',{'NOT',{'GET',k}},{'BREAK'}},
          body
        }
      }
    }
  end

-- ── CALL ──────────────────────────────────────────────────────────────────
-- {'CALL', f_expr, a1, a2, ...}
--
-- Intrinsic functions: when the callee is a plain NAME whose identifier is
-- registered in `intrinsics`, the handler takes over entirely.  The handler
-- receives the raw arg AST nodes (ast[3], ast[4], ...) and returns a CSP
-- table.  Receiving uncompiled ASTs lets each intrinsic decide exactly what
-- to compile (e.g. inserting a raw string tag, ignoring an arg, etc.).
--
-- Only bare-name calls are intercepted.  (wait)(8), obj.wait(8), obj:wait(8)
-- all fall through to the normal CALL path.

local intrinsics = {}

local function compCall(ast)
  if ast[2][1] == 'NAME' then
    local handler = intrinsics[ast[2][2]]
    if handler then
      return handler(table.unpack(ast, 3))
    end
  end
  local res = {'CALL', compile(ast[2])}
  for i = 3, #ast do res[#res + 1] = compile(ast[i]) end
  return res
end

-- ── Built-in intrinsics ───────────────────────────────────────────────────
-- wait(ms)  →  YIELD('sleep', ms)
-- ms may be a numeric literal or any expression; time literals like 00:05
-- are already converted to seconds by the tokenizer, so wait(00:05) = wait(300).
intrinsics.wait = function(ms_ast)
  return {'YIELD', 'sleep', ms_ast and compile(ms_ast) or 0}
end

-- ── Dispatch table ────────────────────────────────────────────────────────

local comp = {}

comp.NUMBER = compNumber
comp.STRING = compString
comp.BOOL   = compBool
comp.NIL    = compNil
comp.PAREN  = compParen
comp.NAME   = compName
comp.DO     = compDo

for op in pairs(DIRECT_BINOPS) do comp[op] = compBinop end
comp.NEQ  = compNEQ
comp.NEG    = compNEG
comp.NOT    = compNOT
comp.DAILY  = compUnaryWrap('DAILY')
comp.INTERV = compUnaryWrap('INTERV')

comp.SCRIPT = function(ast) return compile(ast[2]) end
comp.BLOCK  = compBlock
comp.DO     = compDo

comp.RETURN = function(ast)
  -- {'RETURN', v1, v2, ...}  (v-args are already unpacked by the parser)
  local res = {'RETURN'}
  for i = 2, #ast do res[#res + 1] = compile(ast[i]) end
  return res
end

comp.NOW = function() return {'NOW'} end
comp.BREAK  = function() return {'BREAK'} end
comp.ASSIGN = compAssign
comp.IF     = compIf
comp.WHILE  = compWhile
comp.REPEAT  = compRepeat
comp.FOR_NUM = compFor
comp.FOR_IN = compForIn
comp.CALL   = compCall

function comp.RULE(ast)
  -- {'RULE', condition, block}
  local rule = compile({'IF',ast[2],ast[3],{},{'RETURN',{'STRING',ER.ruleFail}}}) -- if condition matches, run block; else return failure string
  return {"CALL",{"GET",'compRule'}, {"CONST",rule}}
end

-- TABLE: {[k]=v, name=v, v, ...}  →  MAKETABLE(k1,v1, k2,v2, ...)
-- Positional keys (TFIELD_VAL) are assigned compile-time integer positions.
comp.TABLE = function(ast)
  local args = {'MAKETABLE'}
  local pos = 1
  for i = 2, #ast do
    local f = ast[i]
    if f[1] == 'TFIELD_NAME' then
      args[#args+1] = f[2]           -- raw string key  (ca() wraps in CONST)
      args[#args+1] = compile(f[3])  -- compiled value
    elseif f[1] == 'TFIELD_EXPR' then
      args[#args+1] = compile(f[2])  -- compiled key expression
      args[#args+1] = compile(f[3])  -- compiled value
    elseif f[1] == 'TFIELD_VAL' then
---@diagnostic disable-next-line: assign-type-mismatch
      args[#args+1] = pos            -- integer position (ca() wraps in CONST)
      args[#args+1] = compile(f[2])  -- compiled value
      pos = pos + 1
    end
  end
  return args
end

-- FIELD: obj.name  →  INDEX(obj, CONST(name))
comp.FIELD = function(ast)
  return {'INDEX', compile(ast[2]), ast[3]}  -- ast[3] is raw string; ca() wraps it in CONST
end

-- INDEX: obj[key]  →  INDEX(obj, key)
comp.INDEX = function(ast)
  return {'INDEX', compile(ast[2]), compile(ast[3])}
end

-- METHODCALL: obj:method(a1,...)  →  CALL(INDEX(obj, method), obj, a1, ...)
-- The object is evaluated once; its method is looked up; obj is passed as first arg.
-- GETPROP: obj:key  →  {'GETPROP', obj_csp, key_string}
comp.GETPROP = function(ast)
  return {'GETPROP', compile(ast[2]), ast[3]}
end

-- SETPROP: obj:key = val  →  {'SETPROP', obj_csp, key_string, val_csp}
comp.SETPROP = function(ast)
  return {'SETPROP', compile(ast[2]), ast[3], compile(ast[4])}
end

comp.METHODCALL = function(ast)
  -- ast = {'METHODCALL', obj, method_name, a1, a2, ...}
  local obj_csp = compile(ast[2])
  local method_name = ast[3]
  -- We need obj twice (as receiver and as self).  Use a LET to evaluate once.
  -- LET '__self__' = obj IN CALL(INDEX(GET '__self__', method), GET '__self__', args...)
  local call = {'CALL', {'INDEX', {'GET', '__self__'}, method_name}, {'GET', '__self__'}}
  for i = 4, #ast do call[#call + 1] = compile(ast[i]) end
  return {'LET', '__self__', obj_csp, call}
end

function comp.GV(ast) return {'GETVAR', 'GV', ast[2]} end
function comp.QV(ast) return {'GETVAR', 'QV', ast[2]} end
function comp.PV(ast) return {'GETVAR', 'PV', ast[2]} end

-- ── Entry point ───────────────────────────────────────────────────────────

compile = function(ast)
  if type(ast) ~= 'table' then
    error("Compiler: expected AST table, got " .. type(ast) .. ": " .. tostring(ast))
  end
  local fn = comp[ast[1]]
  if not fn then
    error("Compiler: unknown AST node '" .. tostring(ast[1]) .. "'")
  end
  return fn(ast)
end

ER.compileAST  = compile
ER.intrinsics  = intrinsics  -- mutable: callers may add entries directly
