--%%name:rule_groups
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  local st = er.sourceTrigger

  -- Register a rule in a named group
  local r = er.eval("#groupTest => return 'group_fired'", { group = "mygroup" })
  r.verbosity = "silent"

  -- Enable/disable from another rule
  test_rule(er, "#toggleGroup => disable('mygroup')",
    function(er, rule)
      st:post({type='event', name='toggleGroup'})
      -- Now post the group's trigger — should NOT fire because group is disabled
      st:post({type='event', name='groupTest'})
    end,
    nil,
    "group disable: rule in disabled group does not fire")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
