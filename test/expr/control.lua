--%%name:expr_control
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  -- if-then-else
  test_expr(er, "if 5 > 3 then return 1 else return 2 end", 1, "if true branch")
  test_expr(er, "if 5 < 3 then return 1 else return 2 end", 2, "if false branch")
  test_expr(er, "if 5 < 3 then return 1 elseif 5 > 3 then return 2 else return 3 end", 2, "if elseif")
  test_expr(er, "x = 0; if true then x = 1 end; return x", 1, "if without else")

  -- Numeric for loop
  test_expr(er, "local s=0; for i=1,5 do s=s+1 end; return s", 5, "for loop 1..5")
  test_expr(er, "local s=0; for i=1,5,2 do s=s+i end; return s", 9, "for loop step 2")

  -- While loop
  test_expr(er, "local i=0; while i < 3 do i=i+1 end; return i", 3, "while loop")

  -- Repeat-until
  test_expr(er, "local i=0; repeat i=i+1 until i == 3; return i", 3, "repeat-until")

  -- ipairs (array iteration)
  test_expr(er, "local s=0; for _,v in ipairs({10,20,30}) do s=s+v end; return s", 60, "for-ipairs: sum values")

  -- ipairs with index
  test_expr(er, "local s=0; for i,v in ipairs({10,20,30}) do s=s+i end; return s", 6, "for-ipairs: sum indices (1+2+3)")

  -- pairs (dict iteration — count entries, order is undefined)
  test_expr(er, "local n=0; for k,v in pairs({a=1,b=2,c=3}) do n=n+1 end; return n", 3, "for-pairs: count entries")

  -- pairs (dict iteration — count entries, order is undefined)
  test_expr(er, "case || false >> return 2 || true >> return 3 || false >> return 4 end", 3, "case statement")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
