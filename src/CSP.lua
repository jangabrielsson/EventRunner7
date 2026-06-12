MODULE = MODULE or {}

local function module(ER)
  
  local unpack = table.unpack
  
  local YIELD_TAG = {}  -- unique sentinel for yield detection
  
  local _ctx   -- forward-declared so trace() can close over it
  local vm -- forward-declared 
  
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
    local _opts = nil
    local _curpos = nil   -- current source position {pos,len}; set by instrumented closures
    
    function _ctx:getTrace()   return _trace end
    function _ctx:setTrace(on) _trace = on end
    function _ctx:getOpts()    return _opts end
    function _ctx:getCurpos()  return _curpos end
    function _ctx:setCurpos(p) _curpos = p end
    
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
    function _ctx:setGlobal(name, v, force)
      local box = _global_env[name]
      if box ~= nil then box[1] = v; return true end
      if force then _global_env[name] = {v}; return true end
      return false
    end
    
    function _ctx:pushVarFrame(name, v)
      _var_env = setmetatable({ [name] = {v} }, { __index = _var_env })
    end
    function _ctx:pushVarsFrame(vars)
      local frame = {}
      for name, v in pairs(vars) do frame[name] = v end -- v is boxed
      _var_env = setmetatable(frame, { __index = _var_env })
    end
    function _ctx:popVarFrame()  
      _var_env = getmetatable(_var_env).__index
    end
    
    function _ctx:getVar(name)
      local box = _var_env[name]          -- search local chain first
      if box ~= nil then return true, box[1] end
      local found, box2 = self:getGlobal(name)         -- fall through to globals
      if found then return true, box2 end
      if _G[name] ~= nil then return true, _G[name] end  -- fall back to raw global (for builtins)
      return false
    end
    
    function _ctx:setVar(name, newval)
      local box = _var_env[name]          -- search local chain first
      if box ~= nil then box[1] = newval; return true end
      return self:setGlobal(name, newval, true) -- fall through to globals
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
        break_stack   = {unpack(_break_stack)},
        error_handler = _error_handler,
        exit_cont     = _exit_cont,
        var_env       = chain_to_list(_var_env),
        trace         = _trace,
        opts          = _opts,
        curpos        = _curpos,
      }
    end
    
    function _ctx:restore(snap)
      _break_stack   = {unpack(snap.break_stack)}
      _error_handler = snap.error_handler
      _exit_cont     = snap.exit_cont
      _var_env       = list_to_chain(snap.var_env)
      _trace         = snap.trace or false
      _opts          = snap.opts or nil
      _curpos        = snap.curpos or nil
    end
  end
  
  -- ─────────────────────────────────────────────────────────────────────────
  
  -- rterror: routes a runtime error through the active error handler so that
  -- TRY blocks can intercept it.  Falls back to plain Lua error() when no
  -- handler is installed.  Primitives use this instead of error() so that all
  -- runtime failures flow through the same enrichment path.
  local function rterror(msg)
    local h = _ctx:getErrorHandler()
    if h then return h(msg) end
    error(msg, 2)
  end
  
  local function TR(trf)
    return function(...)
      return trf, ...          -- pass all values as extra returns
    end
  end
  
  local function evalArgs(args, n, vals, nv, done)
    if args[n] == nil then
      return done(unpack(vals, 1, nv))
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
  
  local function msstr(v) 
    local mt = getmetatable(v)
    return mt and mt.__tostring and mt.__tostring(v) or v
  end
  local OPS = {
    ADD = function(left_hand, right_hand) return left_hand+right_hand end,
    SUB = function(left_hand, right_hand) return left_hand-right_hand end,
    MUL = function(left_hand, right_hand) return left_hand*right_hand end,
    DIV = function(left_hand, right_hand) return left_hand/right_hand end,
    MOD = function(left_hand, right_hand) return left_hand%right_hand end,
    POW = function(left_hand, right_hand) return left_hand^right_hand end,
    EQ = function(left_hand, right_hand) return msstr(left_hand)==msstr(right_hand) end,
    LT = function(left_hand, right_hand) return msstr(left_hand)<msstr(right_hand) end,
    LTE = function(left_hand, right_hand) return msstr(left_hand)<=msstr(right_hand) end,
    GT = function(left_hand, right_hand) return msstr(left_hand)>msstr(right_hand) end,
    GTE = function(left_hand, right_hand) return msstr(left_hand)>=msstr(right_hand) end,
    NILCO = function(left_hand, right_hand) if left_hand~=nil then return left_hand else return right_hand end end,
  }
  
  local function BINOP(name, a,b)
    local op = OPS[name]
    assert(op, "Unknown operator: "..tostring(name))
    return function(cont)
      return a(TR(function(left_hand)
        return b(TR(function(right_hand)
          local result = op(left_hand, right_hand)
          trace(name, left_hand, right_hand, "=", result)
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
  local function NILCO(a,b) return BINOP("NILCO", a,b) end
  
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
          return cont(tostring(msstr(av)) .. tostring(msstr(bv)))
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
        local idx_pos = _ctx:getCurpos()  -- capture pos set by maybeWrap (e.g. field name)
        return obj_expr(TR(function(obj)
          return key_expr(TR(function(key)
            _ctx:setCurpos(idx_pos)  -- restore: inner GET evaluation clobbers curpos
            trace("INDEX", tostring(obj), "[", tostring(key), "]")
            -- print(type(obj))
            -- print(obj.__USERDATA)
            if type(obj) ~= 'table' then
              return rterror("#Attempt to index a non-table value: " .. tostring(obj).. " with key '"..tostring(key).."'" )
            end
            return cont(obj[key])
          end))
        end))
      end
    end
    
    local function SETINDEX(obj_expr, key_expr, val_expr)
      return function(cont)
        return obj_expr(TR(function(obj)
          return key_expr(TR(function(key)
            return val_expr(TR(function(val)
              trace("SETINDEX", tostring(obj), "[", tostring(key), "] =", tostring(val))
              if type(obj) ~= 'table' then
                return rterror("#Attempt to index a non-table value: " .. tostring(obj).. " with key '"..tostring(key).."'" )
              end
              obj[key] = val
              return cont(val)
            end))
          end))
        end))
      end
    end
    
    local function SETFIELD(obj_expr, field, val_expr)
      return function(cont)
        return obj_expr(TR(function(obj)
          return val_expr(TR(function(val)
            trace("SETFIELD", tostring(obj), ".", field, "=", tostring(val))
            if type(obj) ~= 'table' then
              return rterror("#Attempt to set a non-table value: " .. tostring(obj).. " with key '"..tostring(field).."'" )
            end
            obj[field] = val
            return cont(val)
          end))
        end))
      end
    end
    
    local function CALL(f_expr,...) -- f_expr is an expression that evaluates to a Lua function
      local fargs = {...}
      return function(cont)
        return f_expr(TR(function(f)
          return evalArgs(fargs, 1, {}, 0, TR(function(...)
            if vm.host.isAsync(f) then
              local yvals = table.pack(...)
              return YIELD_TAG, function(...)
                trace("ASYNC", "resuming with", ...)
                return cont(...)
              end, "asyncFun",f,unpack(yvals, 1, yvals.n)
            end
            trace("CALL", tostring(f), ...)
            local rets = table.pack(pcall(f, ...))
            if not rets[1] then 
              error(rets[2], 0) -- re-raise; eval()'s pcall enriches
            end  
            trace("CALL->", unpack(rets, 2, rets.n))
            return cont(unpack(rets, 2, rets.n))
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
          trace("YIELD", "suspending with", unpack(yvals, 1, yvals.n))
          return YIELD_TAG, function(...)
            trace("YIELD", "resuming with", ...)
            return cont(...)
          end, unpack(yvals, 1, yvals.n)
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
    
    -- ── LAMBDA ────────────────────────────────────────────────────────────────
    -- Forward-declare eval so LAMBDA (defined before eval) can close over it.
    local eval  -- assigned below
    
    -- LAMBDA(params, body) captures the current var-env snapshot and returns a
    -- Lua function.  When the function is called with args, each param is bound
    -- to the corresponding arg in a fresh frame, body is evaluated, and its
    -- return value(s) are returned to the Lua caller.
    local function LAMBDA(params, body)
      return function(cont)
        local f = function(...)
          local vars = nil
          if #params > 0 then
            local call_args = table.pack(...)
            vars = {}
            for i, name in ipairs(params) do vars[name] = {call_args[i]} end
          end
          return select(2, eval(body, vars and {vars = vars} or nil))
        end
        return cont(f)
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
    
    -- LETS introduces list of names=exprs in a new frame scoped to body.
    local function LETS(names, val_exprs, body)
      return function(cont)
        return evalArgs(val_exprs, 1, {}, 0, TR(function(...)
          local vals = table.pack(...)
          local vars = {}
          for i, name in ipairs(names) do vars[name] = {vals[i]} end
          _ctx:pushVarsFrame(vars)
          return body(TR(function(...) _ctx:popVarFrame() return cont(...) end))
        end))
      end
    end
    
    -- GET reads the innermost binding for name.
    local function GET(name)
      return function(cont)
        local found, v = _ctx:getVar(name)
        if found then return cont(v) end
        return rterror("#Undefined variable: '" .. tostring(name) .. "'")
      end
    end
    
    -- SET writes to the innermost binding for name.
    local function SET(name, val_expr)
      return function(cont)
        return val_expr(TR(function(v)
          local found = _ctx:setVar(name, v)
          vm.host.onVarWrite(name, v)
          if found then return cont(v) end
          return rterror("#Undefined variable: '" .. tostring(name) .. "'")
        end))
      end
    end
    
    -- INCVAR writes to the innermost binding for name.
    local function INCVAR(name, op, val_expr)
      return function(cont)
        return val_expr(TR(function(v)
          local found, currVal = _ctx:getVar(name)
          if not found then return rterror("#Undefined variable: '" .. tostring(name) .. "'") end
          local result = OPS[op](currVal, v)
          _ctx:setVar(name, result)
          vm.host.onVarWrite(name, result)
          trace("INCVAR  var", name, "=", result, op)
          return cont(result)
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
          unpack(args, 2, args.n)
        end
        args = table.pack(f(unpack(args, 1, args.n)))
        f = table.remove(args, 1)
        args.n = args.n - 1
      end
      return 'ok', unpack(args, 1, args.n)
    end
    
    local taggableErrors = {
      --"attempt to perform arithmetic on a",
      "attempt to",
    }
    
    eval = function(expr, opts)   -- NOTE: forward-declared above for LAMBDA
      local outer = _ctx:snapshot()
      local top_cont = function(...) return nil, ... end
      _ctx:restore({ break_stack = {}, error_handler = nil, exit_cont = TR(top_cont), var_env = {}, trace = opts and opts.trace or false, opts = opts })
      -- TRY blocks push handlers on top of this; for unhandled errors the bottom
      -- handler just re-raises so the pcall below can do enrichment in one place.
      _ctx:pushErrorHandler(TR(function(msg) error(msg, 0) end))
      if opts and opts.vars then
        _ctx:pushVarsFrame(opts.vars)
      end
      
      -- Single pcall catches everything: raw Lua errors (7/nil), rterror(),
      -- THROW(), and user error() calls — all with the last _curpos intact.
      local packed = table.pack(pcall(function()
        return trampoline(expr(top_cont))
      end))
      local ok = table.remove(packed, 1); packed.n = packed.n - 1
      
      local curpos = _ctx:getCurpos()  -- read before restore wipes it
      _ctx:restore(outer)
      
      if not ok then
        local enriched = tostring(packed[1])
        local src = opts and (opts.src or (opts.rule and opts.rule.src))
        if src then
          if curpos then
            enriched = enriched .. vm.host.formatSource(src, curpos.pos, curpos.len)
          else
            enriched = enriched .. "</br>  source: " .. src
          end
        end
        -- Could we tag some error messages here?
        for _,p in ipairs(taggableErrors) do
          if enriched:find(p) then
            enriched = "#"..(enriched:match(".*:%d+: (.*)") or enriched)
            break
          end
        end
        error(enriched, 0)
      end
      return unpack(packed, 1, packed.n)
    end
    
    local function resume(token, ...)
      local outer = _ctx:snapshot()
      _ctx:restore(token.ctx)     -- restore this expression's saved context
      local args = table.pack(...)
      local packed = table.pack(pcall(function()
        return trampoline(token.resumeFn(unpack(args, 1, args.n)))
      end))
      local ok = table.remove(packed, 1); packed.n = packed.n - 1
      
      local curpos = _ctx:getCurpos()  -- read before restore wipes it
      _ctx:restore(outer)
      
      if not ok then
        local enriched = tostring(packed[1])
        local opts = token.ctx.opts
        local src = opts and (opts.src or (opts.rule and opts.rule.src))
        if src then
          if curpos then
            enriched = enriched .. vm.host.formatSource(src, curpos.pos, curpos.len)
          else
            enriched = enriched .. "</br>  source: " .. src
          end
        end
        for _,p in ipairs(taggableErrors) do
          if enriched:find(p) then
            enriched = "#"..(enriched:match(".*:%d+: (.*)") or enriched)
            break
          end
        end
        error(enriched, 0)
      end
      return unpack(packed, 1, packed.n)
    end
    
    -- MAKETABLE builds a fresh table from alternating key/value expression pairs.
    -- MAKETABLE(k1,v1, k2,v2, ...) → evaluates all, returns {[k1]=v1, [k2]=v2, ...}
    local function MAKETABLE(...)
      local field_exprs = {...}
      assert(#field_exprs % 2 == 0, "MAKETABLE: odd number of args")
      local nf = #field_exprs
      return function(cont)
        return evalArgs(field_exprs, 1, {}, 0, TR(function(...)
          local args,nf0 = table.pack(...),nf
          local n = select('#', ...)
          if n > nf0 then
            nf0 = nf0-2
          end
          local tbl = {}
          for i = 1, nf0, 2 do
            tbl[select(i, ...)] = select(i+1, ...)
          end
          if n > nf0 then
            for i = nf0+2, n do
              tbl[#tbl+1] = select(i, ...)
            end
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
      EQ  = EQ,  LT  = LT,  LTE = LTE, GT  = GT,  GTE = GTE, NILCO = NILCO,
      AND = AND, OR  = OR,  NOT = NOT,  NEG = NEG,  CONCAT = CONCAT,
      INDEX = INDEX, SETINDEX = SETINDEX, SETFIELD = SETFIELD, INCVAR = INCVAR,
      MAKETABLE = MAKETABLE,
      IF    = IF,
      YIELD = YIELD,
      LOOP  = LOOP,  BREAK = BREAK,
      DEFGLOBAL = DEFGLOBAL,
      TRACE     = TRACE,
      PRINT     = PRINT,
      LET   = LET,   LETS = LETS, GET   = GET,   SET = SET,
      TRY   = TRY,   THROW = THROW,  RETURN = RETURN,
      CFUN  = CFUN,
      LAMBDA = LAMBDA,
      NOW  = function() 
        return CFUN(function(cb) 
          local t = os.date("*t")
          return cb(t.hour*3600 + t.min*60 + t.sec) 
        end) 
      end,
    }
    
    local function checkProgn(t)
      if #t == 2 then print("PROGN SINGLE ARG") end
      for i=2,#t do
        local op = t[i][1]
        if op == 'PROGN' then print("DOUBLE PROGN") end
      end
    end
    
    -- ── SIMPLE COMPILER ──────────────────────────────────────────────────────────────
    -- Turns {"OPCODE", args...} tables into expression trees.
    -- Scalar args (number, string, boolean, function) are auto-wrapped in CONST.
    -- Table args are compiled recursively as sub-expressions.
    -- Exception: {"CONST", v} always treats v as a literal (even a table).
    -- Exception: SET, GET, DEFGLOBAL, LET treat their first arg as a raw name.
    
    -- _cspsrcmap: set by vm.compile(tree, srcmap); maps CSP instruction table
    -- references to {pos,len} source positions.  nil during normal compile().
    local _cspsrcmap = nil
    
    -- After building a closure f from instruction table t, if a srcmap is
    -- active and t has a position entry, wrap f to update _ctx._curpos first.
    local function maybeWrap(f, t)
      if _cspsrcmap and type(t) == 'table' then
        local sp = _cspsrcmap[t]
        if sp then
          local inner = f
          return function(cont)
            _ctx:setCurpos(sp)
            return inner(cont)
          end
        end
      end
      return f
    end
    
    local compile  -- forward-declared for recursive calls
    local specialCompilers = {}  -- specialCompilers[opcode] = function(t) -> compiled expr
    -- If present, this overrides the default compile() behavior for that opcode.
    -- Used for added inststructions in ER that need special handling, e.g. to support new syntax without
    
    -- helper: compile or auto-wrap a positional arg
    function ca(v)
      local vt = type(v)
      if vt == "number" or vt == "string" or vt == "boolean" or vt == "function" then
        return CONST(v)
      end
      return compile(v)
    end
    
    local function cal(list,offset) -- compile a list of exprs - see LETS
      local cargs = {}
      offset = offset or 1
      for i = offset,#list do cargs[#cargs+1] = ca(list[i]) end
      return cargs
    end
    
    function compile(t)
      local tv = type(t)
      if tv == "number" or tv == "string" or tv == "boolean" or tv == "function" then
        return CONST(t)
      end
      if tv ~= "table" then
        error("compile: unexpected value: " .. tv)
      end
      local op = t[1]
      assert(expr[op], "compile: unknown opcode: " .. tostring(op))
      
      local f
      
      local special = specialCompilers[op]
      if special then
        return maybeWrap(special(t), t)
      end
      
      -- ops where the first arg is a raw name string
      if     op == "CONST"     then f = CONST(t[2])
      elseif op == "GET"       then f = GET(t[2])
      elseif op == "SET"       then f = SET(t[2], ca(t[3]))
      elseif op == "SETFIELD"  then f = SETFIELD(ca(t[2]), t[3], ca(t[4]))
      elseif op == 'INCVAR'    then f = INCVAR(t[2], t[3], ca(t[4]))
      elseif op == "DEFGLOBAL" then f = DEFGLOBAL(t[2], ca(t[3]))
      elseif op == "LET"       then f = LET(t[2], ca(t[3]), ca(t[4]))
      elseif op == "LETS"      then f = LETS(t[2], cal(t[3]), ca(t[4]))
      elseif op == "CALL"      then
        -- all args including the function are compiled (scalars auto-wrapped in CONST)
        local cargs = cal(t, 2)
        f = CALL(unpack(cargs))
      elseif op == "TRY"       then
        f = TRY(ca(t[2]), t[3])   -- t[3] is raw Lua handler_fn
      elseif op == "CFUN"      then
        -- t[2] is a raw Lua function; t[3..n] are compiled as expressions
        local cargs = cal(t, 3)
        f = CFUN(t[2], unpack(cargs))
      elseif op == "PROGN"      then
        checkProgn(t)
        local cargs = cal(t, 2)
        f = PROGN(unpack(cargs))
      elseif op == "LAMBDA"    then
        -- t[2] is a raw list of param name strings; t[3] is the compiled body CSP tree
        f = LAMBDA(t[2], ca(t[3]))
      else
        local cargs = cal(t, 2)
        f = expr[op](unpack(cargs))
      end
      return maybeWrap(f, t)
    end
    
    local _CSP_IR_VERSION = 1

    vm = {
      irVersion = _CSP_IR_VERSION,
      eval      = eval,
      resume    = resume,
      compile   = function(tree, srcmap)
        _cspsrcmap = srcmap or nil
        local ok, result = pcall(compile, tree)
        _cspsrcmap = nil
        if not ok then error(result, 2) end
        return result
      end,
      expr      = expr,
      ca        = ca,
      trace     = trace,
      rterror   = rterror,
      getCTX    = function() return _ctx end,
      defGlobal    = function(name, v) _ctx:defGlobal(name, v) end,
      getGlobal    = function(name)    return (_ctx:getGlobal(name)) end,
      lookupGlobal = function(name)    local _, v = _ctx:getGlobal(name); return v end,
      setGlobal    = function(name, v) return _ctx:setGlobal(name, v) end,
      resetGlobals = function()     _global_env = {} end,
    }
    
    vm.registerInstruction = function(name, impl, specialCompiler)
      expr[name] = impl                    -- the CPS function
      if specialCompiler then
        specialCompilers[name] = specialCompiler  -- non-standard arg handling
      end
    end
    
    vm.registerInstructions = function(table)
      for name, def in pairs(table) do
        vm.registerInstruction(name, def.impl, def.compile)
      end
    end
    
    vm.host = {
      isAsync = function(fn) return false end,
      onVarWrite = function(name, val) end,
      formatSource = function(src, pos, len) return src .. " :" .. pos end
    }
    
    ER.csp = vm
  end
  
  MODULE[#MODULE+1] = { name = "CSP", sys = true, code = module }