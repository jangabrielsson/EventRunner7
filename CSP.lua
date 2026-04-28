fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER

local unpack = table.unpack

local YIELD_TAG = {}  -- unique sentinel for yield detection

local _ctx   -- forward-declared so trace() can close over it

local function trace(label, ...)
  if _ctx:getTrace() then print("[TRACE]", label, ...) end
end

-- ── execution context ────────────────────────────────────────────────────
-- Saved and restored atomically at every eval / yield / resume boundary so
-- that parallel expressions never corrupt each other's state.
-- Raw fields are kept private inside the do/end block; all access goes
-- through the methods so the internal representation can change freely.
_ctx = {}
do
  local _break_stack   = {}
  local _error_handler = nil
  local _exit_cont     = nil
  local _var_env       = {}
  local _global_env = {}   -- { [name] = {v} }  (boxed, same as locals)
  local _trace = false

  function _ctx:getTrace()   return _trace end
  function _ctx:setTrace(on) _trace = on end

  function _ctx:setExitCont(c) _exit_cont = c end
  function _ctx:getExitCont()  return _exit_cont end

  -- loop stack (LOOP / BREAK)
  function _ctx:pushLoopStack(cont)  table.insert(_break_stack, cont) end
  function _ctx:popLoopStack()
    assert(#_break_stack > 0, "BREAK used outside LOOP")
    return table.remove(_break_stack)
  end
  
  -- error handler (TRY / THROW)
  function _ctx:pushErrorHandler(h)
    local outer = _error_handler
    _error_handler = h
    return outer                     -- caller must keep this to restore
  end
  function _ctx:popErrorHandler(saved) _error_handler = saved end
  function _ctx:getErrorHandler()      return _error_handler end
  
  -- variable environment (LET / GET / SET)
  -- Values are boxed as {v} so nil is a valid binding and inner frames
  -- always shadow outer frames regardless of value.
  --
  -- _global_env  : single shared frame, never snapshotted — all expressions
  --                see the same globals.  Locals shadow globals.
  -- _var_env     : per-expression metatable chain, saved/restored on yield.
  
  function _ctx:defGlobal(name, v)  _global_env[name] = {v} end
  function _ctx:getGlobal(name)
    local box = _global_env[name]
    if box ~= nil then return true, box[1] end
    return false
  end
  function _ctx:setGlobal(name, v)
    local box = _global_env[name]
    if box ~= nil then box[1] = v; return true end
    return false
  end
  
  function _ctx:pushVarFrame(name, v)
    _var_env = setmetatable({ [name] = {v} }, { __index = _var_env })
  end
  function _ctx:pushVarsFrame(vars)
    local frame = {}
    for name, v in pairs(vars) do frame[name] = {v} end
    _var_env = setmetatable(frame, { __index = _var_env })
  end
  function _ctx:popVarFrame()  
    _var_env = getmetatable(_var_env).__index
  end
  
  function _ctx:getVar(name)
    local box = _var_env[name]          -- search local chain first
    if box ~= nil then return true, box[1] end
    return self:getGlobal(name)         -- fall through to globals
  end
  
  function _ctx:setVar(name, newval)
    local box = _var_env[name]          -- search local chain first
    if box ~= nil then box[1] = newval; return true end
    return self:setGlobal(name, newval) -- fall through to globals
  end
  
  -- snapshot / restore for parallel eval (called by trampoline / eval / resume)
  -- We walk the metatable chain to collect all frames in order.
  local function chain_to_list(env)
    local frames, mt = {}, getmetatable(env)
    while mt do
      table.insert(frames, 1, env)   -- prepend so index 1 = outermost
      env, mt = mt.__index, getmetatable(mt.__index)
    end
    return frames
  end
  
  local function list_to_chain(frames)
    local env = {}
    for _, frame in ipairs(frames) do
      env = setmetatable(frame, { __index = env })
    end
    return env
  end
  
  function _ctx:snapshot()
    return {
      break_stack   = {table.unpack(_break_stack)},
      error_handler = _error_handler,
      exit_cont     = _exit_cont,
      var_env       = chain_to_list(_var_env),
      trace         = _trace,
    }
  end

  function _ctx:restore(snap)
    _break_stack   = {table.unpack(snap.break_stack)}
    _error_handler = snap.error_handler
    _exit_cont     = snap.exit_cont
    _var_env       = list_to_chain(snap.var_env)
    _trace         = snap.trace or false
  end
end

-- ─────────────────────────────────────────────────────────────────────────

local function TR(trf)
  return function(...)
    return trf, ...          -- pass all values as extra returns
  end
end

local function evalArgs(args, n, vals, nv, done)
  if args[n] == nil then
    return done(table.unpack(vals, 1, nv))
  else
    return args[n](TR(function(v, ...)
      vals[n] = v
      local new_nv = n
      if args[n+1] == nil then -- no more args, pass through any extra returns from the last one
        local nextra = select('#', ...)
        for i = 1, nextra do vals[n+i] = select(i, ...) end
        new_nv = n + nextra
      end
      return evalArgs(args, n+1, vals, new_nv, done)
    end))
  end
end

local function CONST(c)
  return function(cont)
    trace("CONST", c)
    return cont(c)
  end
end

local OPS = {
  ADD = function(av, bv) return av+bv end,
  SUB = function(av, bv) return av-bv end,
  MUL = function(av, bv) return av*bv end,
  DIV = function(av, bv) return av/bv end,
  MOD = function(av, bv) return av%bv end,
  POW = function(av, bv) return av^bv end,
  EQ = function(av, bv) return av==bv end,
  LT = function(av, bv) return av<bv end,
  LTE = function(av, bv) return av<=bv end,
  GT = function(av, bv) return av>bv end,
  GTE = function(av, bv) return av>=bv end,
}

local function BINOP(name, a,b)
  local op = OPS[name]
  assert(op, "Unknown operator: "..tostring(name))
  return function(cont)
    return a(TR(function(av)
      return b(TR(function(bv)
        local result = op(av, bv)
        trace(name, av, bv, "=", result)
        return cont(result)
      end))
    end))
  end
end

local function ADD(a,b) return BINOP("ADD", a,b) end
local function SUB(a,b) return BINOP("SUB", a,b) end
local function MUL(a,b) return BINOP("MUL", a,b) end
local function DIV(a,b) return BINOP("DIV", a,b) end
local function MOD(a,b) return BINOP("MOD", a,b) end
local function POW(a,b) return BINOP("POW", a,b) end
local function GT(a,b) return BINOP("GT", a,b) end
local function LT(a,b) return BINOP("LT", a,b) end
local function EQ(a,b) return BINOP("EQ", a,b) end
local function LTE(a,b) return BINOP("LTE", a,b) end
local function GTE(a,b) return BINOP("GTE", a,b) end

-- AND returns the first falsy value, or the last value if all are truthy (Lua semantics).
local function AND(a, b)
  return function(cont)
    return a(TR(function(av)
      if not av then return cont(av) end
      return b(TR(cont))
    end))
  end
end

-- OR returns the first truthy value, or the last value if all are falsy (Lua semantics).
local function OR(a, b)
  return function(cont)
    return a(TR(function(av)
      if av then return cont(av) end
      return b(TR(cont))
    end))
  end
end

-- NOT returns the boolean negation of its argument.
local function NOT(a)
  return function(cont)
    return a(TR(function(av)
      return cont(not av)
    end))
  end
end

-- NEG returns the arithmetic negation of its argument.
local function NEG(a)
  return function(cont)
    return a(TR(function(av)
      return cont(-av)
    end))
  end
end

-- CONCAT concatenates two values as strings (mirrors Lua's .. operator).
local function CONCAT(a, b)
  return function(cont)
    return a(TR(function(av)
      return b(TR(function(bv)
        return cont(tostring(av) .. tostring(bv))
      end))
    end))
  end
end

-- DAILY wraps a time value into a Daily event descriptor {type='Daily', time=v}.
local function DAILY(a)
  return function(cont)
    return a(TR(function(v)
      trace("DAILY", v)
      return cont(true)
    end))
  end
end

-- INTERV wraps a time value into an Interval event descriptor {type='Interval', interval=v}.
local function INTERV(a)
  return function(cont)
    return a(TR(function(v)
      trace("INTERV", v)
      return cont({type='Interval', interval=v})
    end))
  end
end

-- BETW checks whether the current time falls within [start, stop].
-- Delegates to ER.betw which handles both epoch timestamps (arg > T2020)
-- and seconds-since-midnight values, including midnight wrap-around.
local function BETW(start_expr, stop_expr)
  return function(cont)
    return start_expr(TR(function(start)
      return stop_expr(TR(function(stop)
        trace("BETW", start, "..", stop)
        return cont(ER.betw(start, stop))
      end))
    end))
  end
end

local function IF(i,t,e)
  return function(cont)
    return i(TR(function(iv)
      trace("IF", iv, "->", iv and "then" or "else")
      if iv then
        return t(TR(cont))
      elseif e then
        return e(TR(cont))
      else
        return cont(nil)
      end
    end))
  end
end

-- INDEX evaluates obj_expr and key_expr, then returns obj[key].
-- Used for both 'obj.field' (key is a CONST string) and 'obj[expr]' indexing.
local function INDEX(obj_expr, key_expr)
  return function(cont)
    return obj_expr(TR(function(obj)
      return key_expr(TR(function(key)
        trace("INDEX", tostring(obj), "[", tostring(key), "]")
        return cont(obj[key])
      end))
    end))
  end
end

-- GETPROP(obj_expr, key) reads a device property via ER._funs.getProp.
-- key is a plain string (not an expression).
local function GETPROP(obj_expr, key)
  return function(cont)
    return obj_expr(TR(function(obj)
      trace("GETPROP", tostring(obj), key)
      return cont(ER.getProp(obj, key))
    end))
  end
end

-- SETPROP(obj_expr, key, val_expr) writes a device property via ER._funs.setProp.
-- key is a plain string (not an expression).
local function SETPROP(obj_expr, key, val_expr)
  return function(cont)
    return obj_expr(TR(function(obj)
      return val_expr(TR(function(v)
        trace("SETPROP", tostring(obj), key, "=", tostring(v))
        ER.setProp(obj, key, v)
        return cont(v)
      end))
    end))
  end
end

local function CALL(f_expr,...) -- f_expr is an expression that evaluates to a Lua function
  local fargs = {...}
  return function(cont)
    return f_expr(TR(function(f)
      return evalArgs(fargs, 1, {}, 0, TR(function(...)
        trace("CALL", tostring(f), ...)
        ER._ctx = _ctx  -- make current context available to the called function
        local rets = {f(...)}
        ER._ctx = nil
        trace("CALL->", table.unpack(rets))
        return cont(table.unpack(rets))
      end))
    end))
  end
end

local function PROGN(...)
  local args = {...}
  local n = #args
  return function(cont)
    return evalArgs(args, 1, {}, 0, TR(function(...)
      return cont(select(n, ...))
    end))
  end
end

-- YIELD evaluates its args and yields their values to the caller.
-- The YIELD expression inside the chain evaluates to whatever resume() is called with.
local function YIELD(...)
  local yargs = {...}
  return function(cont)
    return evalArgs(yargs, 1, {}, 0, TR(function(...)
      local yvals = table.pack(...)
      trace("YIELD", "suspending with", table.unpack(yvals, 1, yvals.n))
      return YIELD_TAG, function(...)
        trace("YIELD", "resuming with", ...)
        return cont(...)
      end, table.unpack(yvals, 1, yvals.n)
    end))
  end
end

-- ── LOOP / BREAK ─────────────────────────────────────────────────────────
local function BREAK(...)
  local bargs = {...}
  return function(_cont)
    return evalArgs(bargs, 1, {}, 0, TR(function(...)
      local bc = _ctx:popLoopStack()
      return bc(...)
    end))
  end
end

local function LOOP(...)
  local body
  if select("#", ...) == 1 then
    body = ...
  else
    body = PROGN(...)
  end
  return function(cont)
    _ctx:pushLoopStack(cont)
    local function step()
      return body(TR(function(_)
        return step()
      end))
    end
    return step()
  end
end

-- ── GLOBAL VARIABLES ─────────────────────────────────────────────────────
-- DEFGLOBAL defines (or resets) a global variable from within an expression.
local function DEFGLOBAL(name, val_expr)
  return function(cont)
    return val_expr(TR(function(v)
      _ctx:defGlobal(name, v)
      return cont(v)
    end))
  end
end

-- TRACE evaluates val_expr and sets the trace flag to its (boolean) result.
local function TRACE(val_expr)
  return function(cont)
    return val_expr(TR(function(v)
      _ctx:setTrace(v and true or false)
      return cont(v)
    end))
  end
end

local _PRINT_CONST  -- cached CONST(print) so PRINT doesn't allocate on every call
local function PRINT(...)
  _PRINT_CONST = _PRINT_CONST or CONST(print)
  return CALL(_PRINT_CONST, ...)
end

-- CFUN calls a raw Lua function with (cont, ctx_snapshot, ...evaluated_args).
-- The Lua function is responsible for calling cont(value) to produce a result.
local function CFUN(lua_fn, ...)
  local fargs = {...}
  return function(cont)
    return evalArgs(fargs, 1, {}, 0, TR(function(...)
      local snap = _ctx --:snapshot()
      trace("CFUN", tostring(lua_fn), ...)
      return lua_fn(cont, snap, ...)
    end))
  end
end

-- ── VARIABLE ENVIRONMENT ──────────────────────────────────────────────────
-- Values are boxed as {val} so nil is a valid binding and inner frames always
-- shadow outer frames regardless of value.

-- LET introduces name=val in a new frame scoped to body.
local function LET(name, val_expr, body)
  return function(cont)
    return val_expr(TR(function(v)
      _ctx:pushVarFrame(name, v)
      return body(TR(function(...)
        _ctx:popVarFrame()
        return cont(...)
      end))
    end))
  end
end

-- GET reads the innermost binding for name.
local function GET(name)
  return function(cont)
    local found, v = _ctx:getVar(name)
    if found then return cont(v) end
    error("Undefined variable: " .. tostring(name))
  end
end

-- SET writes to the innermost binding for name.
local function SET(name, val_expr)
  return function(cont)
    return val_expr(TR(function(v)
      local found = _ctx:setVar(name, v)
      if ER._triggerVars and ER._triggerVars[name] then
        ER.sourceTrigger:post({type='trigger-variable', name = name, value = v})
        trace("SET trigger var", name, "=", v)
      end
      if found then return cont(v) end
      error("Undefined variable: " .. tostring(name))
    end))
  end
end

-- GETVAR reads special vars.
local function GETVAR(typ,name)
  return function(cont)
    return name(TR(function(n)
      local v = ER.getVar(typ,n)
      return cont(v)
    end))
  end
end

-- SETVAR mutates special vars.
local function SETVAR(typ, name, val_expr)
  return function(cont)
    return name(TR(function(n)
      return val_expr(TR(function(v)
        ER.setVar(typ, n, v)
        return cont(v)
      end))
    end))
  end
end

-- ── ERROR HANDLING ────────────────────────────────────────────────────────
-- THROW evaluates its args then calls the active error handler.
local function THROW(...)
  local targs = {...}
  return function(_cont)
    return evalArgs(targs, 1, {}, 0, TR(function(...)
      local h = _ctx:getErrorHandler()
      if h then return h(...) end
      error(tostring((...)))
    end))
  end
end

-- RETURN evaluates its args and exits the current expression immediately.
local function RETURN(...)
  local rargs = {...}
  return function(_cont)
    return evalArgs(rargs, 1, {}, 0, TR(function(...)
      return _ctx:getExitCont()(...)
    end))
  end
end

-- TRY runs body; if THROW fires, handler_fn(err...) -> CONT expr is used instead.
local function TRY(body, handler_fn)
  return function(cont)
    local snap = _ctx:snapshot()   -- capture ctx at TRY entry so THROW can unwind frames
    local outer
    outer = _ctx:pushErrorHandler(TR(function(...)
      _ctx:restore(snap)           -- unwind any LET/LOOP frames pushed inside body
      _ctx:popErrorHandler(outer)  -- then reinstall the pre-TRY handler
      return handler_fn(...)(TR(cont))
    end))
    return body(TR(function(...)
      _ctx:popErrorHandler(outer)
      return cont(...)
    end))
  end
end

-- ── TRAMPOLINE / EVAL / RESUME ────────────────────────────────────────────
--   eval(expr)          -> 'ok', val...   or  'suspended', token, yieldvals...
--   resume(token, val)  -> same shape; val becomes what YIELD evaluates to

local function trampoline(f, ...)
  local args = table.pack(...)
  while f ~= nil do
    if f == YIELD_TAG then
      return 'suspended', 
      { resumeFn = args[1], ctx = _ctx:snapshot() },
      table.unpack(args, 2, args.n)
    end
    args = table.pack(f(table.unpack(args, 1, args.n)))
    f = table.remove(args, 1)
    args.n = args.n - 1
  end
  return 'ok', table.unpack(args, 1, args.n)
end

local function eval(expr, opts)
  local outer = _ctx:snapshot()
  local top_cont = function(...) return nil, ... end
  _ctx:restore({ break_stack = {}, error_handler = nil, exit_cont = TR(top_cont), var_env = {}, trace = opts and opts.trace or false })
  if opts and opts.vars then
    _ctx:pushVarsFrame(opts.vars)
  end
  local result = table.pack(trampoline(expr(top_cont)))
  _ctx:restore(outer)
  return table.unpack(result, 1, result.n)
end

local function resume(token, ...)
  local outer = _ctx:snapshot()
  _ctx:restore(token.ctx)     -- restore this expression's saved context
  local result = table.pack(trampoline(token.resumeFn(...)))
  _ctx:restore(outer)
  return table.unpack(result, 1, result.n)
end

-- MAKETABLE builds a fresh table from alternating key/value expression pairs.
-- MAKETABLE(k1,v1, k2,v2, ...) → evaluates all, returns {[k1]=v1, [k2]=v2, ...}
local function MAKETABLE(...)
  local field_exprs = {...}
  assert(#field_exprs % 2 == 0, "MAKETABLE: odd number of args")
  return function(cont)
    return evalArgs(field_exprs, 1, {}, 0, TR(function(...)
      local n = select('#', ...)
      local tbl = {}
      for i = 1, n, 2 do
        tbl[select(i, ...)] = select(i+1, ...)
      end
      return cont(tbl)
    end))
  end
end

local expr = {
  TR    = TR,
  PROGN = PROGN,
  CALL  = CALL,
  CONST = CONST,
  ADD = ADD, SUB = SUB, MUL = MUL, DIV = DIV, MOD = MOD, POW = POW,
  EQ  = EQ,  LT  = LT,  LTE = LTE, GT  = GT,  GTE = GTE,
  AND = AND, OR  = OR,  NOT = NOT,  NEG = NEG,  CONCAT = CONCAT, BETW = BETW,
  INDEX = INDEX,  MAKETABLE = MAKETABLE,
  DAILY = DAILY,  INTERV = INTERV,
  GETPROP = GETPROP,  SETPROP = SETPROP,
  IF    = IF,
  YIELD = YIELD,
  LOOP  = LOOP,  BREAK = BREAK,
  DEFGLOBAL = DEFGLOBAL,
  TRACE     = TRACE,
  PRINT     = PRINT,
  LET   = LET,   GET   = GET,   SET = SET,
  GETVAR = GETVAR, SETVAR = SETVAR,
  TRY   = TRY,   THROW = THROW,  RETURN = RETURN,
  CFUN  = CFUN,
}

-- ── SIMPLE COMPILER ──────────────────────────────────────────────────────────────
-- Turns {"OPCODE", args...} tables into expression trees.
-- Scalar args (number, string, boolean, function) are auto-wrapped in CONST.
-- Table args are compiled recursively as sub-expressions.
-- Exception: {"CONST", v} always treats v as a literal (even a table).
-- Exception: SET, GET, DEFGLOBAL, LET treat their first arg as a raw name.
local function compile(t)
  local tv = type(t)
  if tv == "number" or tv == "string" or tv == "boolean" or tv == "function" then
    return CONST(t)
  end
  if tv ~= "table" then
    error("compile: unexpected value: " .. tv)
  end
  local op = t[1]
  assert(expr[op], "compile: unknown opcode: " .. tostring(op))

  -- helper: compile or auto-wrap a positional arg
  local function ca(i)
    local v = t[i]
    local vt = type(v)
    if vt == "number" or vt == "string" or vt == "boolean" or vt == "function" then
      return CONST(v)
    end
    return compile(v)
  end

  -- ops where the first arg is a raw name string
  if     op == "CONST"     then return CONST(t[2])
  elseif op == "GET"       then return GET(t[2])
  elseif op == "SET"       then return SET(t[2], ca(3))
  elseif op == "GETVAR"    then return GETVAR(t[2], ca(3))
  elseif op == "SETVAR"    then return SETVAR(t[2], ca(3), ca(4))
  elseif op == "DEFGLOBAL" then return DEFGLOBAL(t[2], ca(3))
  elseif op == "LET"       then return LET(t[2], ca(3), ca(4))
  elseif op == "GETPROP"   then return GETPROP(ca(2), t[3])   -- t[3] is raw key string
  elseif op == "SETPROP"   then return SETPROP(ca(2), t[3], ca(4))  -- t[3] is raw key string
  elseif op == "CALL"      then
    -- all args including the function are compiled (scalars auto-wrapped in CONST)
    local cargs = {}
    for i = 2, #t do cargs[#cargs+1] = ca(i) end
    return CALL(table.unpack(cargs))
  elseif op == "TRY"       then
    return TRY(ca(2), t[3])   -- t[3] is raw Lua handler_fn
  elseif op == "CFUN"      then
    -- t[2] is a raw Lua function; t[3..n] are compiled as expressions
    local cargs = {}
    for i = 3, #t do cargs[#cargs+1] = ca(i) end
    return CFUN(t[2], table.unpack(cargs))
  else
    local cargs = {}
    for i = 2, #t do cargs[#cargs+1] = ca(i) end
    return expr[op](table.unpack(cargs))
  end
end

local vm = {
  eval      = eval,
  resume    = resume,
  compile   = compile,
  expr      = expr,
  defGlobal = function(name, v) _ctx:defGlobal(name, v) end,
  getGlobal = function(name)    return (_ctx:getGlobal(name)) end,
  setGlobal = function(name, v) return _ctx:setGlobal(name, v) end,
}

fibaro.ER.csp = vm