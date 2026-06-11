--%%name:rule_custom_events
--%%headers:EventRunner.inc
--%%file:test/harness.lua,harness
--%%offline:true

local function main(er)
  local st = er.sourceTrigger

  -- Simple event: post #testEvent → handler fires
  test_rule(er, "#testEvent => return 'handled'",
    function(er, rule)
      st:post({type='event', name='testEvent'})
    end,
    "handled",
    "custom event: handler fires")

  -- Event with parameters
  test_rule(er, "#alert{level='high'} => return level",
    function(er, rule)
      st:post({type='event', name='alert', level='high'})
    end,
    "high",
    "event with params: captures level")

  -- Pattern match with $
  test_rule(er, "#doorEvent{door='$name'} => return name",
    function(er, rule)
      st:post({type='event', name='doorEvent', door='front'})
    end,
    "front",
    "event pattern: $ captures value")

  -- Catch-all: handler fires for any alert regardless of params
  test_rule(er, "#alert => return 'any'",
    function(er, rule)
      st:post({type='event', name='alert', level='low'})
    end,
    "any",
    "event catch-all: fires for any params")

  done()
end

function QuickApp:onInit()
  fibaro.EventRunner(main)
end
