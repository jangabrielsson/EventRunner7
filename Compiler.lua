--%%offline:true
-- Compiler.lua: Compiles the EventScript parser AST to CSP table notation.
-- Output is consumed by fibaro.CONT.compile() (CSP.lua's simple compiler).
--
-- Pipeline:  source → Parser → AST → compileAST() → CSP tables → CSP.compile() → expr

ER = ER or { _tools = {} }

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
    local result = body
    for j = #names, 1, -1 do
      local val_csp = vals[j] and compile(vals[j]) or {'CONST', nil}
      result = {'LET', names[j], val_csp, result}
    end
    return result
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
  local stmts = {'PROGN'}
  for i, v in ipairs(vars) do
    stmts[#stmts + 1] = compileTarget(v, compile(vals[i] or {'NIL'}))
  end
  return stmts
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
  return {'LOOP', {'IF', cond, body, {'BREAK'}}}
end

-- ── CALL ──────────────────────────────────────────────────────────────────
-- {'CALL', f_expr, a1, a2, ...}
local function compCall(ast)
  local res = {'CALL', compile(ast[2])}
  for i = 3, #ast do res[#res + 1] = compile(ast[i]) end
  return res
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

comp.BREAK  = function() return {'BREAK'} end
comp.ASSIGN = compAssign
comp.IF     = compIf
comp.WHILE  = compWhile
comp.CALL   = compCall

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

ER._tools.compileAST = compile
