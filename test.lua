--%%name:Continuation test

--%%file:cont.lua,cont

local CONT = fibaro.CONT
local eval    = CONT.eval
local resume  = CONT.resume
local compile = CONT.compile

local run,result

function print2(a,b)
  print(a,b)
  return a..b, #a  -- return two values
end

function multi() return "x", "y", "z" end -- returns 3 values

local function main()
  
  -- ---- test original ----
  local fun = compile{
    "PROGN",
    {"CALL", print2, "hello", " world"},
    {
      "IF",
      {"GT", {"ADD", 2, 2}, 3},
      {
        "PROGN",
        {"PRINT", "niice"},
        {"YIELD", "sleep", 3000},
        {"CALL", print2, "yes", " ok"}
      },
      {"CALL", print2, "no", " nop"}
    }
  }
  
  -- ---- test multi-value resume and multi-value return ----
  local fmulti = compile{
    "PROGN",
    {"PRINT", "before yield"},
    {"PRINT", "VALS:", {"YIELD", "sleep", 2000}},
    {"CALL", multi}
  }  -- returns 3 values
  
  -------- Test LOOP ----
  local loop = compile{
    "PROGN",
    {"PRINT", "LOOP START"},
    {"DEFGLOBAL", "i", 0},
    {"LOOP",
        {"PRINT", "i =", {"GET", "i"}},
        {"SET", "i", {"ADD", {"GET", "i"}, 1}},
        {"IF",
          {"GT", {"GET", "i"}, 5},
          {"PROGN",
            {"PRINT", "LOOP END"},
            {"BREAK",8}},
        }}
  }
  
  -- run(fun,result)
  -- run(fmulti,result)
  run(loop,result)
end

local resumeRunner

local yieldHandlers = {
  sleep = function(cf,cb,ms)
    setTimeout(function()
      resumeRunner({resume(cf,ms)}, cb)
    end, ms)
  end,
}

function resumeRunner(res, cb)
  if res[1] == 'suspended' then
    local cf,tag = res[2],res[3]
    if yieldHandlers[tag] then
      return yieldHandlers[tag](cf,cb,table.unpack(res, 4, res.n))
    else
      print("no yield handler for tag:", tag)
      return
    end
  end
  cb(table.unpack(res, 2, res.n))
end

function run(f, cb) resumeRunner({eval(f)}, cb) end
function result(...) print("RESULT:", ...) end

function QuickApp:onInit()
  main()
end