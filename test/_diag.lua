--%%name:table_diag
--%%headers:EventRunner.inc
--%%offline:true

local function main(er)
  local out = io.open("_diag.txt", "w")
  local function t(label, src, expected)
    local ok, v = pcall(er.eval, src)
    local match = v == expected
    local line = string.format("%-30s %s got=%-8s expected=%s",
      label, match and "OK" or "FAIL", tostring(v), tostring(expected))
    if out then out:write(line .. "\n") end
  end

  t("array [1]",   "return {10, 20, 30}[1]",      10)
  t("array [3]",   "return {10, 20, 30}[3]",      30)
  t("array len",   "local t={1,2,3}; return #t",  3)
  t("dict .a",     "return {a=1, b=2}.a",         1)
  t("dict .b",     "return {a=1, b=2}.b",         2)
  t("dict bracket","return {a=1, b=2}['b']",      2)
  t("dict set/get","local t={}; t.x=5; return t.x", 5)
  t("nested dot",  "return {a={b=3}}.a.b",        3)
  t("update field","local t={x=1}; t.x=99; return t.x", 99)

  if out then out:close() end
  os.exit(0)
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
