local parse
local fmt = string.format
local function skipSpace(str) return 'space',nil,str:match("^[ \t\n]*(.*)") end
local function getNum(str,sign) local n,r = str:match("^(%d+%.?%d*)(.*)") return 'number',tonumber(n)*(sign or 1),r end
local function getAtom(str) return 'atom',str:match("^(.[%w!$%%&*/:<=>%?^_~%+%-]*)(.*)") end
local tokenTab = {}
for c in (" \t\n"):gmatch(".") do tokenTab[c] = skipSpace end
for c in ("0123456789"):gmatch(".") do tokenTab[c] = getNum end
for c in ("!$%&*/:<=>?^_~abcdefghijklmnopqrstuvxyzwABCDEFGHIJKLMNOPQRSTUVXYZW"):gmatch(".") do tokenTab[c] = getAtom end
tokenTab['('] = function(str) return 'lpar','(',str:sub(2) end
tokenTab[')'] = function(str) return 'rpar',')',str:sub(2) end
tokenTab['.'] = function(str) return 'dot','.',str:sub(2) end
tokenTab[','] = function(str) return 'comma','.',str:sub(2) end
tokenTab['"'] = function(str) return 'string',str:match('^"([^"]*)"(.*)') end
tokenTab["'"] = function(str) return 'string',str:match("^'([^']*)'(.*)") end
for c in ("+"):gmatch(".") do tokenTab[c] = function(str) return 'atom',str:sub(1,1),str:sub(2) end end
tokenTab['-'] = function(str) if str:sub(2,2):match("%d") then return getNum(str:sub(2),-1) else return 'atom','-',str:sub(2) end end
tokenTab[';'] = function(str) return 'space',nil,str:match("^[^%\n]*(.*)") end

local function nextToken(str)
  if str == "" then return 'eof',nil,str end
  local tf = tokenTab[str:sub(1,1)]
  if tf then
    local typ,tkn,str = tf(str)
    if typ=='space' then return nextToken(str) end
    return typ,tkn,str
  end
  error("Unknown token: "..str:sub(1,1))
end

local function createTokenizer(str)
  local function nxt()
    local typ, tkn
    typ, tkn,str = nextToken(str)
    local r = {type=typ, value=tkn}
    setmetatable(r, {__tostring = function() return (r.value or r.type) end})
    return r
  end
  local self,lt = {},nxt()
  function self.peek() return lt end
  function self.isType(t) return lt.type == t end
  function self.next() local v = lt; lt = nxt() return v end
  function self.mustBeType(t) 
    assert(self.isType(t), "Expected '"..t.."', got '"..(lt.value or lt.type).."'")
    self.next()
  end
  return self
end

function parse(tkns) 
  local t = tkns.next()
  if t.type=='atom' then
    if t.value == 't' then return true
    elseif t.value == 'false' then return false
    elseif t.value == 'nil' then return {'quote',nil}
    else  return t.value end
  elseif t.type=='number' then
    return t.value
  elseif t.type=='string' then
    return t.value
  elseif t.type=='lpar' then
    local lst = {}
    while not (tkns.isType('rpar') or tkns.isType('dot')) do
      local sexpr = parse(tkns)
      table.insert(lst,sexpr)
    end
    if tkns.isType('dot') then
      tkns.next()
      lst.cdr = parse(tkns)
    end
    tkns.mustBeType('rpar')
    return lst
  else 
    error("Unexpected token: "..tkns.peek().type)
  end
end

local function parser(str) return parse(createTokenizer(str)) end

local str = "(fact 20 fact)"
local parsed = parser(str)
print(json.encode(parsed))