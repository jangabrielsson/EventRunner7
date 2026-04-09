--%%offline:true
-- Parser.lua: Recursive descent parser for EventScript
-- Outputs {opcode, ...} AST tables (matching CSP.lua compile format)
ER = ER or { _tools = {} }

local function makeParser(src)
  local ts      = ER._tools.tokenStream(src)
  local peek    = ts.peek
  local next    = ts.next
  local match   = ts.match
  local expect  = ts.expect
  local sourceAt = ts.sourceAt

  local function parseError(msg)
    local t = peek(1)
    error(msg .. (sourceAt(t) or " at end of input"), 2)
  end

  -- Forward declarations
  local parseExp, parseBlock, parseTableConstructor

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
      parseError("Expected function arguments")
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
    return {'FUNCTION', params, body}
  end

  --------------------------------------------------------------------------
  -- Prefix expressions: calls, indexing, field access
  --------------------------------------------------------------------------

  -- primaryprefix ::= Name | '$'Name | '$$'Name | '$$$'Name | '(' exp ')' | Number
  local function parsePrimaryprefix()
    local t = peek(1)
    if t and t.type == 'identifier' then
      next()
      return {'NAME', t.value}
    elseif t and t.type == 'number' then
      next(); return {'NUMBER', t.value}    -- e.g. 88:value
    elseif t and t.type == 'gv' then
      next(); return {'GV', expect('identifier').value}
    elseif t and t.type == 'qv' then
      next(); return {'QV', expect('identifier').value}
    elseif t and t.type == 'pv' then
      next(); return {'PV', expect('identifier').value}
    elseif t and t.type == 'lpar' then
      next()
      local e = parseExp()
      expect('rpar')
      return {'PAREN', e}
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
        next()
        local idx = parseExp()
        expect('rsqb')
        base = {'INDEX', base, idx}
        isCall = false
      elseif t.type == 'dot' then
        -- '.' Name
        next()
        base = {'FIELD', base, expect('identifier').value}
        isCall = false
      elseif t.type == 'colon' then
        -- ':' Name args  OR  ':' Name  (getprop)
        next()
        local name = expect('identifier').value
        local t2 = peek(1)
        if t2 and (t2.type == 'lpar' or t2.type == 'lbra' or t2.type == 'string') then
          local args = parseArgs()
          base = {'METHODCALL', base, name, table.unpack(args)}
          isCall = true
        else
          base = {'GETPROP', base, name}
          isCall = false
        end
      elseif t.type == 'lpar' or t.type == 'lbra' or t.type == 'string' then
        -- args
        local args = parseArgs()
        base = {'CALL', base, table.unpack(args)}
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

  -- primaryexp ::= nil | false | true | Number | String |
  --                function | tableconstructor | '#'Name ['{' fields '}'] | prefixexp
  local function parsePrimaryexp()
    local t = peek(1)
    if not t then parseError("Unexpected end of input") end
    local ty = t.type
    if ty == 'nil' then
      next(); return {'NIL'}
    elseif ty == 'true' then
      next(); return {'BOOL', true}
    elseif ty == 'false' then
      next(); return {'BOOL', false}
    elseif ty == 'string' then
      next(); return {'STRING', t.value}
    elseif ty == 'function' then
      next(); return parseFuncbody()
    elseif ty == 'lbra' then
      return parseTableConstructor()
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
    else
      -- number literals also go through parsePrefixexpFull so that
      -- 88:field postfix syntax is handled correctly
      local node = parsePrefixexpFull()
      return node
    end
  end

  -- unaryexp ::= unop unaryexp | primaryexp
  -- unop ::= '-' | '!' | 't/' | 'n/' | '+/'
  local function parseUnaryexp()
    local t = peek(1)
    if t and t.type == 'op' then
      if t.value == 'minus' then
        next(); return {'NEG', parseUnaryexp()}
      elseif t.value == 'not' then
        next(); return {'NOT', parseUnaryexp()}
      end
    elseif t and t.type == 'today' then
      next(); return {'TODAY', parseUnaryexp()}
    elseif t and t.type == 'nexttime' then
      next(); return {'NEXTTIME', parseUnaryexp()}
    elseif t and t.type == 'plustime' then
      next(); return {'PLUSTIME', parseUnaryexp()}
    elseif t and t.type == 'daily' then
      next(); return {'DAILY', parseUnaryexp()}
    elseif t and t.type == 'interv' then
      next(); return {'INTERV', parseUnaryexp()}
    end
    return parsePrimaryexp()
  end

  -- mulexp ::= unaryexp {mulop unaryexp}
  -- mulop ::= '*' | '/'
  local mulops = { multiply = 'MUL', divide = 'DIV' }
  local function parseMulexp()
    local left = parseUnaryexp()
    while true do
      local t = peek(1)
      if t and t.type == 'op' and mulops[t.value] then
        left = {mulops[next().value], left, parseUnaryexp()}
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
        left = {addops[next().value], left, parseMulexp()}
      else break end
    end
    return left
  end

  -- concatexp ::= addexp {('..' | '++') addexp}
  -- '..' => betw token, '++' => conc token
  local function parseConcatexp()
    local left = parseAddexp()
    while true do
      local t = peek(1)
      if t and (t.type == 'betw' or t.type == 'conc') then
        next()
        left = t.type == 'betw' and {'BETW', left, parseAddexp()}
                                 or {'CONCAT', left, parseAddexp()}
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
      left = {relops[next().value], left, parseConcatexp()}
    end
    return left
  end

  -- andexp ::= relexp {'&' relexp}
  local function parseAndexp()
    local left = parseRelexp()
    while peek(1) and peek(1).type == 'op' and peek(1).value == 'and' do
      next()
      left = {'AND', left, parseRelexp()}
    end
    return left
  end

  -- orexp ::= andexp {'|' andexp}
  local function parseOrexp()
    local left = parseAndexp()
    while peek(1) and peek(1).type == 'op' and peek(1).value == 'or' do
      next()
      left = {'OR', left, parseAndexp()}
    end
    return left
  end

  parseExp = parseOrexp

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

  local function parseStat()
    local t = peek(1)
    if not t then return nil end
    local ty = t.type

    if ty == 'do' then
      next()
      local body = parseBlock()
      expect('end')
      return {'DO', body}

    elseif ty == 'while' then
      next()
      local cond = parseExp()
      expect('do')
      local body = parseBlock()
      expect('end')
      return {'WHILE', cond, body}

    elseif ty == 'repeat' then
      next()
      local body = parseBlock()
      expect('until')
      return {'REPEAT', body, parseExp()}

    elseif ty == 'if' then
      next()
      local cond = parseExp()
      expect('then')
      local body = parseBlock()
      local elseifs = {}
      local else_block = nil
      while peek(1) and peek(1).type == 'elseif' do
        next()
        local ec = parseExp()
        expect('then')
        table.insert(elseifs, {ec, parseBlock()})
      end
      if match('else') then
        else_block = parseBlock()
      end
      expect('end')
      return {'IF', cond, body, elseifs, else_block}

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
        expect('do')
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
        expect('do')
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

    elseif ty == 'function' then
      next()
      local name = expect('identifier').value
      return {'FUNCTION_STAT', name, parseFuncbody()}

    else
      -- varlist '=' explist  |  functioncall  |  setprop
      local base, isCall = parsePrefixexpFull()

      -- setprop: GETPROP followed by '='
      if base[1] == 'GETPROP' and peek(1) and peek(1).type == 'assign' then
        next()  -- consume '='
        return {'SETPROP', base[2], base[3], parseExp()}
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
      expect('assign')
      return {'ASSIGN', vars, parseExplist()}
    end
  end

  --------------------------------------------------------------------------
  -- Block and script
  --------------------------------------------------------------------------

  local terminators = {
    ['end'] = true, ['else'] = true, ['elseif'] = true, ['until'] = true,
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
    local block = parseBlock()
    if peek(1) then
      parseError("Unexpected token at top level")
    end
    return {'SCRIPT', block}
  end

  return parseScript
end

local function parse(src)
  return makeParser(src)()
end

ER._tools.parse = parse
