--%%offline:true 
fibaro.ER = fibaro.ER or {}
local ER = fibaro.ER

local keywords = {
  ["&"] = {type='op',value='and'},
  ["|"] = {type='op',value='or'},
  ["!"] = {type='op',value='not'},
  ["=>"] = {type='rule',value='rule'},
  ["="] = {type='assign',value='assign'},
  [">"] = {type='op',value='greater_than'},
  ["<"] = {type='op',value='less_than'},
  [">="] = {type='op',value='greater_equal'},
  ["<="] = {type='op',value='less_equal'},
  ["=="] = {type='op',value='equal'},
  ["~="] = {type='op',value='not_equal'},
  ["+"] = {type='op',value='plus'},
  ["-"] = {type='op',value='minus'},
  ["*"] = {type='op',value='multiply'},
  ["/"] = {type='op',value='divide'},
  ["{"] = {type='lbra',value='table_start'},
  ["}"] = {type='rbra',value='table_end'},
  [":"] = {type='colon',value='colon'},
  [";"] = {type='semicolon',value='semicolon'},
  [","] = {type='comma',value='comma'},
  ["."] = {type='dot',value='dot'},
  ["("] = {type='lpar',value='paren_open'},
  [")"] = {type='rpar',value='paren_close'},
  ["["] = {type='lsqb',value='bracket_open'},
  ["]"] = {type='rsqb',value='bracket_close'},
  ['local'] = {type='local',value='local'},
  ['function'] = {type='function',value='function'},
  ['end'] = {type='end',value='end'},
  ['if'] = {type='if',value='if'},
  ['then'] = {type='then',value='then'},
  ['else'] = {type='else',value='else'},
  ['elseif'] = {type='elseif',value='elseif'},
  ['while'] = {type='while',value='while'},
  ['do'] = {type='do',value='do'},
  ['loop'] = {type='loop',value='loop'},
  ['repeat'] = {type='repeat',value='repeat'},
  ['until'] = {type='until',value='until'},
  ['return'] = {type='return',value='return'},
  ['break'] = {type='break',value='break'},
  ['nil'] = {type='nil',value=false},
  ['true'] = {type='true',value=true},
  ['false'] = {type='false',value=false},
  ['for'] = {type='for',value='for'},
  ['in'] = {type='in',value='in'},
  ['not'] = {type='op',value='not'},
  ['and'] = {type='op',value='and'},
  ['or'] = {type='op',value='or'},

  ['t/'] = {type='today',value='today'},  -- unary, today time constant, t/10:00
  ['n/'] = {type='nexttime',value='nexttime'},  -- unary, next today time constant, n/10:00
  ['+/'] = {type='plustime',value='plustime'},  -- unary, from today time constant, +/10:00
  ['$'] = {type='gv',value='gv'}, -- unary, global variable, $var
  ['$$'] = {type='qv',value='qv'},  -- unary, quickApp variable, $var
  ['$$$'] = {type='pv',value='pv'}, -- unary, Persistent variable, $var
  ['..'] = {type='betw',value='betw'}, -- binary, between operator, 10:00..11:00
  ['@'] = {type='daily',value='daily'}, -- unary, day rule, @10:00
  ['@@'] = {type='interv',value='interv'}, -- unary, interval rule, @@00:05
  ['++'] = {type='conc',value='conc'}, -- binary, string concatenation
  ['==='] = {type='match',value='match'}, -- binary, string match
  ['??'] = {type='op',value='nilco'}, -- binary, nil coalescing
  ['+='] = {type='incvar',value='plus'}, -- binary, variable increment, var += exp
  ['-='] = {type='incvar',value='minus'}, -- binary, variable decrement, var -= exp
  ['*='] = {type='incvar',value='multiply'}, -- binary, variable multiplication assignment, var *= exp
  ['/='] = {type='incvar',value='divide'}, -- binary, variable division assignment, var /= exp
  ['case'] = {type='case',value='case'},   -- case statement keyword
  ['||'] = {type='case_bar',value='case_bar'}, -- case branch separator
  ['>>'] = {type='case_arrow',value='case_arrow'}, -- case branch arrow (condition >> block)
}

local function lookupTkType(t)
  for k,v in pairs(keywords) do
    if v.type == t then return k end
  end
  return nil
end

local identifierChars = "abcdefghijklmnopqrstuvwxyzåäöøABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖØ"

local function kwHandler(t)
  local k = keywords[t]
  if not k then error("Bad token:"..t) end
  return {type=k.type, value=k.value, tk=t}
end

local tknsStrs = {
  -- Multi-char tokens that share a first char with simpler tokens must come
  -- BEFORE those simpler entries so they are tried first in tokenLookup.
  {"#", "#["..identifierChars.."]+["..identifierChars.."_%d]*", function(s)
    return {type='event', value=s:sub(2)}   -- strip leading '#'
  end},
  {"@",  "@@?",   kwHandler},   -- @@ interval | @ daily (greedy: @@ matched before @)
  {"$",  "%$+",   kwHandler},   -- $var (gv), $$var (qv), $$$var (pv)
  {"t",  "t/",    kwHandler},   -- t/HH:MM  today-at
  {"n",  "n/",    kwHandler},   -- n/HH:MM  next-occurrence
  {"+",  "%+[+/]",kwHandler},   -- ++  string concat  |  +/HH:MM  plus-from-now
  -- HH:MM:SS time literal → seconds since midnight (must precede plain number)
  {"0123456789", "%d%d:%d%d:%d%d", function(s)
    local h,m,sec = s:match("(%d+):(%d+):(%d+)")
    return {type='number', value=tonumber(h)*3600+tonumber(m)*60+tonumber(sec)}
  end},
  -- HH:MM time literal → seconds since midnight (must precede plain number)
  {"0123456789", "%d%d:%d%d", function(s)
    local h,m = s:match("(%d+):(%d+)")
    return {type='number', value=tonumber(h)*3600+tonumber(m)*60}
  end},
  {"0123456789","%d+%.%d+",function(n) 
    return {type='number',value=tonumber(n)} 
  end
},
{"0123456789","%d+",function(n) 
    return {type='number',value=tonumber(n)} 
  end
},
{"><!=~","[><!=~][>=]", function(t) 
  local k = keywords[t]
  if not k then error("Bad token:"..t) end
  return {type=k.type, value=k.value, tk=t}
end
},
{".","%.%.",  kwHandler},   -- .. between operator (must precede single '.')
{"?","%?%?",  kwHandler},   -- nilco, nil coalescing
{"+-*/",".=",function(t) 
  local k = keywords[t]
  if not k then error("Bad token:"..t) end
  return {type=k.type, value=k.value, tk=t}
end
},
{"|",'||?',  kwHandler},  -- '||' case_bar (before single '|' catch-all)
{"+-*/(){}&|!:;,.<>=[]",".",function(t) 
  local k = keywords[t]
  if not k then error("Bad token:"..t) end
  return {type=k.type, value=k.value, tk=t}
end
},
{" \t\n","%s+",function(t) 
  return nil end
},
{'"\n"','"(.-)"',function(s) 
  return {type='string', value=s:sub(2,-2)} end
},
{"'\n'","'(.-)'",function(s) 
  return {type='string', value=s:sub(2,-2)} end
},
{identifierChars,"["..identifierChars.."]["..identifierChars.."_%d]*",function(id) 
  local k = keywords[id]
  if k then
    return {type=k.type, value=k.value, tk=id}
  end
  return {type='identifier', value=id} end
},
}

local tokenLookup = {}
for _,v in ipairs(tknsStrs) do
  local prefixes = v[1]
  local pattern = v[2]
  local handler = v[3]
  for i = 1, #prefixes do
    local c = prefixes:sub(i,i)
    if not tokenLookup[c] then
      tokenLookup[c] = {}
    end
    table.insert(tokenLookup[c], {pattern="^"..pattern, handler=handler})
  end
end

local tokenMT = {
  __tostring = function(self)
    return string.format("[%s:%s]", self.type, tostring(self.value))
  end
}

local function sourceMarker(str, pos, len)
  local lines = str:split("\n")
  local tot = 0
  for i, line in ipairs(lines) do
    local lineStart = tot + 1
    local lineEnd   = tot + #line
    if pos >= lineStart and pos <= lineEnd + 1 then
      local col = pos - lineStart + 1
      -- Clamp marker to end of line
      local markLen = math.min(len or 1, #line - col + 1)
      if markLen < 1 then markLen = 1 end
      local marker = string.rep(" ", col - 1) .. string.rep("^", markLen)
      return "\n" .. line .. "\n" .. marker
    end
    tot = tot + #line + 1  -- +1 for the newline character
  end
  return ""
end

local function tokenizer(str)
  local pos,orgStr = 1, str
  local function tkns()
    if pos > #str then return nil end
    local c = str:sub(pos,pos)
    local candidates = tokenLookup[c]
    if not candidates then
      error("Parser: Unexpected character at position "..pos..": "..c..sourceMarker(orgStr,pos,1))
    end
    for _,cand in ipairs(candidates) do
      local s, e = str:find(cand.pattern, pos)
      if s == pos then
        local tokenStr = str:sub(s, e)
        local start,len = pos, e - pos + 1
        pos = e + 1
        local tokenVal = cand.handler(tokenStr)
        if tokenVal ~= nil then
          tokenVal.pos, tokenVal.len = start, len
          return setmetatable(tokenVal,tokenMT)
        else
          return tkns() -- Skip token (e.g. whitespace)
        end
      end
    end
    error("Parser: Unexpected character at position "..pos..": "..c..sourceMarker(orgStr,pos,1))
  end
  return tkns
end

local function tokenStream(str)
  local tkns = tokenizer(str)
  -- Eagerly collect all tokens so savePos/restorePos can work as a simple index.
  local allTokens = {}
  while true do
    local t = tkns()
    if t == nil then break end
    allTokens[#allTokens + 1] = t
  end
  local pos = 1
  local ctxStack = {}

  local function posToLineCol(pos)
    local line, col = 1, 1
    for i = 1, pos - 1 do
      if str:sub(i,i) == '\n' then line = line + 1; col = 1
      else col = col + 1 end
    end
    return line, col
  end

  local function sourceAt(token)
    if not token then return " at end of input" end
    local line, col = posToLineCol(token.pos)
    local marker = sourceMarker(str, token.pos, token.len)
    return string.format(" at line %d, col %d%s", line, col, marker)
  end

  local function ctxHint()
    if #ctxStack == 0 then return nil end
    return "In " .. table.concat(ctxStack, " > ") .. ": "
  end

  local function peek(n)
    n = n or 1
    return allTokens[pos + n - 1]
  end
  local function next()
    local t = allTokens[pos]
    if t then pos = pos + 1 end
    return t
  end
  local function match(expectedType)
    local t = allTokens[pos]
    if t and t.type == expectedType then
      pos = pos + 1
      return t
    end
    return nil
  end
  local function expect(expectedType)
    local t = allTokens[pos]
    if t and t.type == expectedType then
      pos = pos + 1
      return t
    else
      local exp = lookupTkType(expectedType) or expectedType
      local gotStr = t and ("'" .. (t.tk or tostring(t.value)) .. "'") or "end of input"
      local ctx = ctxHint() or ""
      local loc = t and sourceAt(t) or " at end of input"
      error(ctx .. "Expected '" .. exp .. "', got " .. gotStr .. loc, 2)
    end
  end
  local function pushCtx(s) table.insert(ctxStack, s) end
  local function popCtx()  table.remove(ctxStack) end

  -- Save / restore the current position in the token list (for speculative parsing).
  local function savePos()    return pos end
  local function restorePos(snap) pos = snap end

  return {
    peek = peek,
    next = next,
    match = match,
    expect = expect,
    pushCtx = pushCtx,
    popCtx = popCtx,
    sourceAt = sourceAt,
    ctxHint = ctxHint,
    lookupTkType = lookupTkType,
    savePos = savePos,
    restorePos = restorePos,
  }
end

ER.tokenizer = tokenizer
ER.tokenStream = tokenStream
ER.sourceMarker = sourceMarker
