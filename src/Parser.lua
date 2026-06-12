-- Parser.lua: Recursive descent parser for EventScript
-- Outputs {opcode, ...} AST tables (matching CSP.lua compile format)

MODULE = MODULE or {}
local CFOR,LFOR = "FOR","for"
local CWHILE,LWHILE = "WHILE","while"
local CREPEAT, LREPEAT = "REP".."EAT", "rep".."eat"
local CIF, LIF = "IF", "if"
local CFUN,LFUN = "FUNC".."TION", "fun".."ction"
local CDO,LDO = "D".."O", "d".."o"
local CTHEN,LTHEN = "TH".."EN", "th".."en"

local function module(ER)
  
  local function makeParser(src)
    local ts      = ER.tokenStream(src)
    local peek    = ts.peek
    local next    = ts.next
    local match   = ts.match
    local expect  = ts.expect
    local savePos    = ts.savePos
    local restorePos = ts.restorePos
    
    -- Tag an AST node with source position from a token.
    local function P(node, tok)
      if tok then node._pos = tok.pos; node._len = tok.len end
      return node
    end
    
    local function parseError(msg)
      local t = peek(1)
      error(msg .. (ts.sourceAt(t) or " at end of input"), 2)
    end
    
    -- Forward declarations
    local parseExp, parseBlock, parseTableConstructor
    
    -- Gensym counter for list-comprehension accumulator variables.
    local _lc_count = 0
    -- Tracks whether we are currently inside a 'case' body so that '||'
    -- at expression end is not mistaken for a bad OR operator.
    local inCase = 0
    
    --------------------------------------------------------------------------
    -- Helpers
    --------------------------------------------------------------------------
    
    local function parseExplist()
      local list = { parseExp() }
      while match('comma') do
        table.insert(list, parseExp())
      end
      return list
    end
    
    -- args ::= '(' [explist] ')' | tableconstructor | String
    local function parseArgs()
      local t = peek(1)
      if t and t.type == 'lpar' then
        next()
        if peek(1) and peek(1).type == 'rpar' then
          next()
          return {}
        end
        local list = parseExplist()
        expect('rpar')
        return list
      elseif t and t.type == 'lbra' then
        return { parseTableConstructor() }
      elseif t and t.type == 'string' then
        local s = next()
        return { {'STRING', s.value} }
      else
        parseError("Expected func".."tion arguments")
      end
    end
    
    -- tableconstructor ::= '{' [fieldlist] '}'
    -- Shared inner field-list parser: reads fields until '}', returns list of field AST nodes.
    -- Called with the opening '{' already consumed.
    local function parseFieldList()
      local fields = {}
      while peek(1) and peek(1).type ~= 'rbra' do
        local f = peek(1)
        local field
        if f.type == 'lsqb' then
          next(); local k = parseExp(); expect('rsqb'); expect('assign')
          field = {'TFIELD_EXPR', k, parseExp()}
        elseif f.type == 'identifier' and peek(2) and peek(2).type == 'assign' then
          local name = next().value; next()
          field = {'TFIELD_NAME', name, parseExp()}
        else
          field = {'TFIELD_VAL', parseExp()}
        end
        table.insert(fields, field)
        if not (match('comma') or match('semicolon')) then break end
      end
      expect('rbra')
      return fields
    end
    
    parseTableConstructor = function()
      expect('lbra')
      local fields = parseFieldList()
      return {'TABLE', table.unpack(fields)}
    end
    
    -- funcbody ::= '(' [namelist] ')' block 'end'
    local function parseFuncbody()
      expect('lpar')
      local params = {}
      if peek(1) and peek(1).type ~= 'rpar' then
        table.insert(params, expect('identifier').value)
        while match('comma') do
          table.insert(params, expect('identifier').value)
        end
      end
      expect('rpar')
      local body = parseBlock()
      expect('end')
      return {CFUN, params, body}
    end
    
    --------------------------------------------------------------------------
    -- Prefix expressions: calls, indexing, field access
    --------------------------------------------------------------------------
    local parseListComprehension
    
    -- primaryprefix ::= Name | '$'Name | '$$'Name | '$$$'Name | '(' exp ')' | Number
    local function parsePrimaryprefix()
      local t = peek(1)
      if t and t.type == 'identifier' then
        next()
        if t.value == 'now' then return {'NOW'}
        else return P({'NAME', t.value}, t) end
      elseif t and t.type == 'number' then
        next(); return P({'NUMBER', t.value}, t)    -- e.g. 88:value
      elseif t and t.type == 'gv' then
        next(); local id = expect('identifier'); local n = {'GV', id.value}; n._pos = t.pos; n._len = id.pos + id.len - t.pos; return n
      elseif t and t.type == 'qv' then
        next(); local id = expect('identifier'); local n = {'QV', id.value}; n._pos = t.pos; n._len = id.pos + id.len - t.pos; return n
      elseif t and t.type == 'pv' then
        next(); local id = expect('identifier'); local n = {'PV', id.value}; n._pos = t.pos; n._len = id.pos + id.len - t.pos; return n
      elseif t and t.type == 'lsqb' then
        return parseListComprehension()
      elseif t and t.type == 'lpar' then
        next()
        local e = parseExp()
        expect('rpar')
        return {'PAREN', e}
      elseif t and t.type == 'lbra' then
        return parseTableConstructor()
      else
        parseError("Expected identifier or '('")
      end
    end
    
    -- prefixexp ::= primaryprefix {postfix}
    -- Returns (node, isCall): isCall=true when last postfix was a call/method-call
    local function parsePrefixexpFull()
      local base = parsePrimaryprefix()
      local isCall = false
      while true do
        local t = peek(1)
        if not t then break end
        if t.type == 'lsqb' then
          -- '[' exp ']'
          local lsqb = next()
          local idx = parseExp()
          expect('rsqb')
          base = P({'INDEX', base, idx}, lsqb)
          isCall = false
        elseif t.type == 'dot' then
          -- '.' Name
          next()
          local ident = expect('identifier')
          base = P({'FIELD', base, ident.value}, ident)  -- pos at the field name
          isCall = false
        elseif t.type == 'colon' then
          -- ':' Name args  OR  ':' Name  (getprop)
          next()
          local nametok = expect('identifier')
          local name = nametok.value
          local t2 = peek(1)
          if t2 and (t2.type == 'lpar' or t2.type == 'lbra' or t2.type == 'string') then
            local args = parseArgs()
            base = P({'METHODCALL', base, name, table.unpack(args)}, nametok)
            isCall = true
          else
            base = P({'GETPROP', base, name}, nametok)
            isCall = false
          end
        elseif t.type == 'lpar' or t.type == 'lbra' or t.type == 'string' then
          -- args
          local args = parseArgs()
          base = P({'CALL', base, table.unpack(args)}, t)
          isCall = true
        else
          break
        end
      end
      return base, isCall
    end
    
    --------------------------------------------------------------------------
    -- Expression tower (precedence climbing, low → high)
    --------------------------------------------------------------------------
    
    -- helper, placed just before parsePrimaryexp
    function parseListComprehension()
      local t = peek(1)  -- the 'lsqb' token
      next()  -- consume '['
      local expr1 = parseExp()
      expect('for')
      local firstName = expect('identifier').value
      local keyVar, valVar
      if peek(1) and peek(1).type == 'comma' then
        next()
        keyVar = firstName
        valVar = expect('identifier').value
      else
        _lc_count = _lc_count + 1
        keyVar = '_lc_' .. _lc_count
        valVar = firstName
        _lc_count = _lc_count - 1
      end
      expect('in')
      local expr2 = parseExp()
      local guard = nil
      if peek(1) and peek(1).type == 'if' then
        next()
        guard = parseExp()
      end
      expect('rsqb')
      _lc_count = _lc_count + 1
      local acc = '_lc' .. _lc_count
      if keyVar:match('^_lc_') then keyVar = '_lc_' .. _lc_count end
      local addCall = {'CALL', {'NAME','adde'}, {'NAME',acc}, expr1}
      local loopBody
      if guard then
        loopBody = {'BLOCK', {'IF', guard, {'BLOCK', addCall}, {}, nil}}
      else
        loopBody = {'BLOCK', addCall}
      end
      local forNode = {'FOR_IN', {keyVar, valVar},
      {{'CALL', {'NAME','pairs'}, expr2}},
      loopBody}
      return P({'BLOCK',{'LOCAL', {acc}, {{'TABLE'}}},
      forNode,
      {'NAME', acc}}, t)
    end
    
    -- primaryexp ::= nil | false | true | Number | String |
    --                function | tableconstructor | '#'Name ['{' fields '}'] | prefixexp
    local function parsePrimaryexp()
      local t = peek(1)
      if not t then parseError("Unexpected end of input") end
      local ty = t.type
      if ty == 'nil' then
        next(); return P({'NIL'}, t)
      elseif ty == 'true' then
        next(); return P({'BOOL', true}, t)
      elseif ty == 'false' then
        next(); return P({'BOOL', false}, t)
      elseif ty == 'string' then
        next(); return P({'STRING', t.value}, t)
      elseif ty == LFUN then
        next(); return parseFuncbody()
      elseif ty == 'event' then
        -- #EventName  or  #EventName{field,...}
        next()
        local fields = { {'TFIELD_NAME', 'type', {'STRING', t.value}} }
        if peek(1) and peek(1).type == 'lbra' then
          next()  -- consume '{'
          for _, f in ipairs(parseFieldList()) do
            table.insert(fields, f)
          end
        end
        return {'TABLE', table.unpack(fields)}
      elseif ty == 'identifier' and peek(2) and peek(2).type == 'lambda_arrow' then
        -- lambda: x -> expr  (single-param, no parens)
        local param = next().value  -- consume identifier
        next()                      -- consume '->'
        local body = parseExp()
        return P({CFUN, {param}, body}, t)
      elseif ty == 'lpar' then
        -- Try to parse (() -> expr) or ((x, y) -> expr); fall back to parsePrefixexpFull
        local saved = savePos()
        local params = {}
        local is_lambda = false
        next()  -- consume '('
        if peek(1) and peek(1).type == 'rpar' then
          next()  -- consume ')' — zero-param lambda candidate
          if peek(1) and peek(1).type == 'lambda_arrow' then is_lambda = true end
        elseif peek(1) and peek(1).type == 'identifier' then
          table.insert(params, next().value)
          local ok = true
          while peek(1) and peek(1).type == 'comma' do
            next()  -- consume ','
            if peek(1) and peek(1).type == 'identifier' then
              table.insert(params, next().value)
            else ok = false; break end
          end
          if ok and peek(1) and peek(1).type == 'rpar' then
            next()  -- consume ')'
            if peek(1) and peek(1).type == 'lambda_arrow' then is_lambda = true end
          end
        end
        if is_lambda then
          next()  -- consume '->'
          local body = parseExp()
          return P({CFUN, params, body}, t)
        else
          restorePos(saved)
          return parsePrefixexpFull()
        end
        -- List comprehension: [expr for var in iter [if guard]]
        -- Desugars inline (no wrapping lambda) so nested comprehensions share scope.
        -- Compiles to: LET(acc, {}, PROGN(FOR_IN_LOOP, GET(acc)))
        next()  -- consume '['
        local expr1 = parseExp()
        expect('for')
        local firstName = expect('identifier').value
        local keyVar, valVar
        if peek(1) and peek(1).type == 'comma' then
          next()  -- consume ','
          keyVar = firstName
          valVar = expect('identifier').value
        else
          -- single-var form: implicit gensym key
          _lc_count = _lc_count + 1
          keyVar = '_lc_' .. _lc_count
          valVar = firstName
          _lc_count = _lc_count - 1  -- will be bumped again below
        end
        expect('in')
        local expr2 = parseExp()
        local guard = nil
        if peek(1) and peek(1).type == 'if' then
          next()  -- consume 'if'
          guard = parseExp()
        end
        expect('rsqb')  -- consume ']'
        _lc_count = _lc_count + 1
        local acc = '_lc' .. _lc_count
        -- if we used a gensym above, fix it up to match the new count
        if keyVar:match('^_lc_') then keyVar = '_lc_' .. _lc_count end
        local addCall = {'CALL', {'NAME','adde'}, {'NAME',acc}, expr1}
        local loopBody
        if guard then
          loopBody = {'BLOCK', {'IF', guard, {'BLOCK', addCall}, {}, nil}}
        else
          loopBody = {'BLOCK', addCall}
        end
        local forNode = {'FOR_IN', {keyVar, valVar},{{'CALL', {'NAME','pairs'}, expr2}},
        loopBody}
        -- BLOCK ends with {'NAME',acc} — compiles to GET(acc), the expression value.
        return P({'BLOCK',{'LOCAL', {acc}, {{'TABLE'}}},
        forNode,
        {'NAME', acc}}, t)
      else
        -- number literals also go through parsePrefixexpFull so that
        -- 88:field postfix syntax is handled correctly
        local node = parsePrefixexpFull()
        return node
      end
    end
    
    -- powexp ::= primaryexp ['^' unaryexp]
    -- Right-associative: 2 ^ 3 ^ 2  parses as  2 ^ (3 ^ 2) = 512
    local parseUnaryexp  -- Forward declaration since powexp references unaryexp
    local function parsePowexp()
      local left = parsePrimaryexp()
      local t = peek(1)
      if t and t.type == 'op' and t.value == 'power' then
        next()
        return P({'POW', left, parseUnaryexp()}, t)
      end
      return left
    end
    
    -- unaryexp ::= unop unaryexp | powexp
    -- unop ::= '-' | '!' | 't/' | 'n/' | '+/'
    function parseUnaryexp()
      local t = peek(1)
      if t and t.type == 'op' then
        if t.value == 'minus' then
          next(); return {'NEG', parseUnaryexp()}
        elseif t.value == 'not' then
          next(); return {'NOT', parseUnaryexp()}
        elseif t.value == 'and' then
          parseError("Unexpected '&' — use '&' as a binary operator between two expressions (e.g. 'a > 0 & b > 0'), not '&&'")
        elseif t.value == 'or' then
          parseError("Unexpected '|' — use '|' as a binary operator between two expressions (e.g. 'a > 0 | b > 0'), not '||'")
        end
      elseif t and t.type == 'today' then
        next(); return {'TODAY', parseUnaryexp()}
      elseif t and t.type == 'nexttime' then
        next(); return {'NEXTTIME', parseUnaryexp()}
      elseif t and t.type == 'plustime' then
        next(); return {'PLUSTIME', parseUnaryexp()}
      end
      return parsePowexp()
    end
    
    -- mulexp ::= unaryexp {mulop unaryexp}
    -- mulop ::= '*' | '/'
    local mulops = { multiply = 'MUL', divide = 'DIV', modulo = 'MOD' }
    local function parseMulexp()
      local left = parseUnaryexp()
      while true do
        local t = peek(1)
        if t and t.type == 'op' and mulops[t.value] then
          local op = next(); left = P({mulops[op.value], left, parseUnaryexp()}, op)
        else break end
      end
      return left
    end
    
    -- addexp ::= mulexp {addop mulexp}
    -- addop ::= '+' | '-'
    local addops = { plus = 'ADD', minus = 'SUB' }
    local function parseAddexp()
      local left = parseMulexp()
      while true do
        local t = peek(1)
        if t and t.type == 'op' and addops[t.value] then
          local op = next(); left = P({addops[op.value], left, parseMulexp()}, op)
        else break end
      end
      return left
    end
    
    -- dailyexp ::= '@' addexp | '@@' addexp | addexp
    -- '@' and '@@' have lower priority than arithmetic so the operand is
    -- fully evaluated before the daily/interval operator is applied.
    -- e.g.  @sunset-01:00  =>  @(sunset - 01:00)
    local function parseDailyexp()
      local t = peek(1)
      if t and t.type == 'daily' then
        next(); return {'DAILY', parseAddexp()}
      elseif t and t.type == 'interv' then
        next(); return {'INTERV', parseAddexp()}
      end
      return parseAddexp()
    end
    
    -- concatexp ::= dailyexp {('..' | '++') dailyexp}
    -- '..' => betw token, '++' => conc token
    local function parseConcatexp()
      local left = parseDailyexp()
      while true do
        local t = peek(1)
        if t and (t.type == 'betw' or t.type == 'conc') then
          local op = next()
          left = P(op.type == 'betw' and {'BETW', left, parseDailyexp()}
          or {'CONCAT', left, parseDailyexp()}, op)
        else break end
      end
      return left
    end
    
    -- relexp ::= concatexp [relop concatexp]
    -- relop ::= '<' | '<=' | '>' | '>=' | '==' | '~='
    local relops = {
      equal        = 'EQ',  not_equal    = 'NEQ',
      less_than    = 'LT',  less_equal   = 'LTE',
      greater_than = 'GT',  greater_equal = 'GTE',
    }
    local function parseRelexp()
      local left = parseConcatexp()
      local t = peek(1)
      if t and t.type == 'op' and relops[t.value] then
        local op = next(); left = P({relops[op.value], left, parseConcatexp()}, op)
      end
      return left
    end
    
    -- nilcoexp ::= relexp {'??' relexp}
    local function parseNilcoexp()
      local left = parseRelexp()
      while peek(1) and peek(1).type == 'op' and peek(1).value == 'nilco' do
        local op = next()
        left = P({'NILCO', left, parseRelexp()}, op)
      end
      return left
    end
    
    -- andexp ::= relexp {'&' relexp}
    local function parseAndexp()
      local left = parseNilcoexp()
      while peek(1) and peek(1).type == 'op' and peek(1).value == 'and' do
        local op = next()
        left = P({'AND', left, parseNilcoexp()}, op)
      end
      return left
    end
    
    -- orexp ::= andexp {'|' andexp}
    local function parseOrexp()
      local left = parseAndexp()
      while peek(1) and peek(1).type == 'op' and peek(1).value == 'or' do
        local op = next()
        left = P({'OR', left, parseAndexp()}, op)
      end
      if peek(1) and peek(1).type == 'case_bar' and inCase == 0 then
        parseError("Use '|' for OR (not '||') in EventScript expressions")
      end
      return left
    end
    
    parseExp = parseOrexp -- parseNilcoexp
    
    --------------------------------------------------------------------------
    -- Statements
    --------------------------------------------------------------------------
    
    local function parseNamelist()
      local names = { expect('identifier').value }
      while match('comma') do
        table.insert(names, expect('identifier').value)
      end
      return names
    end
    
    --------------------------------------------------------------------------
    -- Scene declaration: scene <Name> = { [activate: {entries}] [deactivate: {entries}] }
    --   Desugars to:  <Name> = Scene({ activate={...}, deactivate={...} })
    --------------------------------------------------------------------------
    local function parseSceneDecl(name)
      local function isLiteralNode(node)
        local op = node[1]
        return op == 'NUMBER' or op == 'STRING' or op == 'BOOL' or op == 'NIL'
      end
      local function maybeThunk(expr)
        if isLiteralNode(expr) then return expr end
        return {CFUN, {}, {'BLOCK', {'RETURN', expr}}}
      end
      -- Parse  obj:prop=expr  entries until '}'
      local function parseEntries()
        local fields = {}
        while peek(1) and peek(1).type ~= 'rbra' do
          local obj_ast = parsePrimaryprefix()
          expect('colon')
          local prop = expect('identifier').value
          expect('assign')
          local val_ast = maybeThunk(parseExp())
          table.insert(fields, {'TFIELD_VAL', {'TABLE',
          {'TFIELD_VAL', obj_ast},{'TFIELD_VAL', {'STRING', prop}},{'TFIELD_VAL', val_ast},}})
          match('comma')
        end
        return {'TABLE', table.unpack(fields)}
      end
      
      expect('lbra')
      local activate_ast, deactivate_ast
      -- Detect subsection form:  activate: { ... }  or  deactivate: { ... }
      if peek(1) and peek(1).type == 'identifier'
      and (peek(1).value == 'activate' or peek(1).value == 'deactivate')
      and peek(2) and peek(2).type == 'colon' then
        while peek(1) and peek(1).type ~= 'rbra' do
          local kw = next().value   -- 'activate' or 'deactivate'
          expect('colon')
          expect('lbra')
          local entries = parseEntries()
          expect('rbra')
          match('comma')
          if kw == 'activate' then activate_ast = entries
          else deactivate_ast = entries end
        end
      else
        activate_ast = parseEntries()  -- flat list = activate-only
      end
      expect('rbra')
      
      local tfields = { {'TFIELD_NAME', 'activate', activate_ast} }
      if deactivate_ast then
        table.insert(tfields, {'TFIELD_NAME', 'deactivate', deactivate_ast})
      end
      local call_ast = {'CALL', {'NAME','Scene'}, {'TABLE', table.unpack(tfields)}}
      return {'ASSIGN', {{'NAME', name}}, {call_ast}}
    end
    
    local function parseStat()
      local t = peek(1)
      if not t then return nil end
      local ty = t.type
      
      -- 'scene' soft keyword: scene <Name> = { ... }
      if ty == 'identifier' and t.value == 'scene'
      and peek(2) and peek(2).type == 'identifier'
      and peek(3) and peek(3).type == 'assign' then
        next()                  -- consume 'scene'
        local sname = next().value  -- consume Name
        next()                  -- consume '='
        return parseSceneDecl(sname)
      end
      
      if ty == LDO then
        next()
        local body = parseBlock()
        expect('end')
        return {'DO', body}
        
      elseif ty == LWHILE then
        next()
        local cond = parseExp()
        expect(LDO)
        local body = parseBlock()
        expect('end')
        return {CWHILE, cond, body}
        
      elseif ty == 'repeat' then
        next()
        local body = parseBlock()
        expect('until')
        return {CREPEAT, body, parseExp()}
        
      elseif ty == 'if' then
        next()
        local cond = parseExp()
        expect(LTHEN)
        local body = parseBlock()
        local elseifs = {}
        local else_block = nil
        while peek(1) and peek(1).type == 'elseif' do
          next()
          local ec = parseExp()
          expect(LTHEN)
          table.insert(elseifs, {ec, parseBlock()})
        end
        if match('else') then
          else_block = parseBlock()
        end
        expect('end')
        return {'IF', cond, body, elseifs, else_block}
        
      elseif ty == 'case' then
        -- case { '||' exp '>>' block } end
        -- Syntactic sugar for if-elseif chain: each '|| exp >> block' becomes a branch.
        next()
        local branches = {}
        inCase = inCase + 1
        while match('case_bar') do
          local cond = parseExp()
          expect('case_arrow')
          table.insert(branches, {cond, parseBlock()})
        end
        inCase = inCase - 1
        expect('end')
        if #branches == 0 then
          return {'BLOCK'}
        end
        local elseifs = {}
        for i = 2, #branches do table.insert(elseifs, branches[i]) end
        return {'IF', branches[1][1], branches[1][2], elseifs, nil}
        
      elseif ty == 'for' then
        next()
        local name = expect('identifier').value
        if match('assign') then
          -- numeric for: for Name '=' exp ',' exp [',' exp] do block end
          local start = parseExp()
          expect('comma')
          local limit = parseExp()
          local step = nil
          if match('comma') then step = parseExp() end
          expect(LDO)
          local body = parseBlock()
          expect('end')
          return {'FOR_NUM', name, start, limit, step, body}
        else
          -- generic for: for namelist in explist do block end
          local names = {name}
          while match('comma') do
            table.insert(names, expect('identifier').value)
          end
          expect('in')
          local iters = parseExplist()
          expect(LDO)
          local body = parseBlock()
          expect('end')
          return {'FOR_IN', names, iters, body}
        end
        
      elseif ty == 'local' then
        next()
        if peek(1) and peek(1).type == 'function' then
          next()
          local name = expect('identifier').value
          return {'LOCAL_FUNCTION', name, parseFuncbody()}
        else
          local names = parseNamelist()
          local vals = nil
          if match('assign') then vals = parseExplist() end
          return {'LOCAL', names, vals}
        end
        
      elseif ty == LFUN then
        next()
        local name = expect('identifier').value
        return {'FUNCTION_STAT', name, parseFuncbody()}
        
      else
        -- varlist '=' explist  |  functioncall  |  setprop
        local base, isCall = parsePrefixexpFull()
        
        -- Unwrap a single PAREN layer for getprop/setprop statement detection
        -- so ({table}:prop) and ({table}:prop = expr) work like the unparenthesised form
        local inner = (base[1] == 'PAREN') and base[2] or base
        
        -- setprop: GETPROP followed by '='
        if inner[1] == 'GETPROP' and peek(1) and peek(1).type == 'assign' then
          next()  -- consume '='
          return P({'SETPROP', inner[2], inner[3], parseExp()}, inner)
        end
        
        -- getprop as statement: expr:tag  (no '=' follows; acts as a function call)
        if inner[1] == 'GETPROP' then
          return inner
        end
        
        if isCall then
          -- function call as statement — return call node directly
          return base
        end
        
        -- assignment: varlist '=' explist
        local vars = {base}
        while match('comma') do
          local v = parsePrefixexpFull()
          table.insert(vars, v)
        end
        if peek(1) and peek(1).type == 'incvar' then
          expect('incvar')
          if vars[1][1] ~= 'NAME' then
            parseError("Left-hand side of increment/decrement must be a variable")
          end
          return {'INCVAR', vars[1], parseExp(), peek(-1).value}
        end
        expect('assign')
        return {'ASSIGN', vars, parseExplist()}
      end
    end
    
    --------------------------------------------------------------------------
    -- Block and script
    --------------------------------------------------------------------------
    
    local terminators = {
      ['end'] = true, ['else'] = true, ['elseif'] = true, ['until'] = true,
      ['case_bar'] = true,  -- '||' terminates a case branch block
      ['rule'] = true,      -- '=>' stops block parsing so parseScript can give a better error
    }
    
    parseBlock = function()
      local stats = {}
      while true do
        while match('semicolon') do end  -- consume optional semicolons
        local t = peek(1)
        if not t or terminators[t.type] then break end
        
        if t.type == 'return' then
          next()
          local t2 = peek(1)
          local vals = {}
          if t2 and not terminators[t2.type] and t2.type ~= 'semicolon' then
            vals = parseExplist()
          end
          match('semicolon')
          table.insert(stats, {'RETURN', table.unpack(vals)})
          break
        end
        
        if t.type == 'break' then
          next()
          match('semicolon')
          table.insert(stats, {'BREAK'})
          break
        end
        
        local s = parseStat()
        if s then
          table.insert(stats, s)
          match('semicolon')
        else
          break
        end
      end
      return {'BLOCK', table.unpack(stats)}
    end
    
    local function parseScript()
      -- script ::= exp {modifier} '=>' action   →  {'RULE', cond, action [,{single=true}]}
      --          | block                         →  {'SCRIPT', block}
      -- Speculatively parse a leading expression; if modifiers and/or '=>' follow it's a rule.
      -- On failure or no '=>', restore and re-parse as a plain block.
      if peek(1) and peek(1).type == 'rule' then
        parseError("Rule requires a condition before '=>'")
      end
      local snap = savePos()
      local ok, cond = pcall(parseExp)
      if ok and peek(1) then
        -- '=' immediately after an expression in a rule context means the user
        -- likely wrote 'x = val => ...' instead of 'x == val => ...'.
        -- Confirm by peeking ahead: skip '= expr' and check if '=>' follows.
        if peek(1).type == 'assign' then
          local snap2 = savePos()
          next()  -- skip '='
          local ok2 = pcall(parseExp)  -- skip RHS
          local hasArrow = ok2 and peek(1) and peek(1).type == 'rule'
          restorePos(snap2)
          if hasArrow then
            parseError("Did you mean '==' instead of '='? Use '==' for equality in conditions")
          end
        end
        local modifiers = {}
        local consumedModifier = false
        while peek(1) do
          local tok = peek(1)
          if tok.type == 'single' then
            next(); modifiers.single = true; consumedModifier = true
          elseif tok.type == 'since' then
            next()
            if not peek(1) or peek(1).type == 'rule' then
              parseError("'since' requires a duration (e.g. since 5)")
            end
            local T = parseExp()
            cond = {'CALL', {'NAME','trueFor'}, T, cond}
            consumedModifier = true
          elseif tok.type == 'debounce' then
            next()
            if not peek(1) or peek(1).type == 'rule' then
              parseError("'debounce' requires a duration (e.g. debounce 5)")
            end
            local T = parseExp()
            modifiers.single = true; modifiers.debounce = T; consumedModifier = true
          elseif tok.type == 'cooldown' then
            next()
            if not peek(1) or peek(1).type == 'rule' then
              parseError("'cooldown' requires a duration (e.g. cooldown 5)")
            end
            local T = parseExp()
            cond = {'AND', cond, {'CALL', {'NAME','cool_down'}, T}}
            consumedModifier = true
          elseif tok.type == 'every' then
            next()
            if not peek(1) or peek(1).type == 'rule' then
              parseError("'every' requires a count (e.g. every 3)")
            end
            local N = parseExp()
            cond = {'AND', cond, {'CALL', {'NAME','every_other'}, N}}
            consumedModifier = true
          elseif tok.type == 'first_in' then
            next(); local W = parseExp()
            if W[1] ~= 'BETW' then
              parseError("'first_in' requires a time window expression (e.g. 07:00..08:00)")
            end
            -- pass both the BETW result and the raw stop expression so
            -- first_in_win can schedule a proactive reset at window end
            cond = {'AND', cond, {'CALL', {'NAME','first_in_win'}, W, W[3]}}
            consumedModifier = true
          else
            break
          end
        end
        if peek(1) and peek(1).type == 'rule' then
          next()  -- consume '=>'
          local action = parseBlock()
          -- debounce: prepend wait(T) to the action block
          if modifiers.debounce then
            table.insert(action, 2, {'CALL', {'NAME','wait'}, modifiers.debounce})
          end
          if peek(1) then parseError("Unexpected token after rule action") end
          local node = {'RULE', cond, action}
          if modifiers.single then node[4] = {single=true} end
          return node
        elseif consumedModifier then
          parseError("Expected '=>' after rule modifiers")
        end
      end
      -- Not a rule: restore and parse as a plain block.
      restorePos(snap)
      local block = parseBlock()
      if peek(1) then
        if peek(1).type == 'rule' then
          parseError("Unexpected '=>': did you mean '==' instead of '=' in the condition?")
        end
        parseError("Unexpected token at top level")
      end
      return {'SCRIPT', block}
    end
    
    return parseScript
  end
  
  local function parse(src)
    return makeParser(src)()
  end
  
  ER.parse = parse
end

MODULE[#MODULE+1] = { name = "Parser", sys = true, code = module }