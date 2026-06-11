-- Templates.lua - Parameterized home automation templates for EventRunner7
--
-- Provides a high-level template API for common home automation patterns.
-- Users configure templates with simple key-value parameters; the module
-- generates EventScript rule strings and registers them via er.eval().
--
-- Usage inside main(er):
--   er.template("motionLight", { sensor="kitchen.motion", light="kitchen.light", offDelay="00:05" })
--   er.templates({{type="motionLight", sensor=..., light=...}, {type="sunDevice", event="sunset", ...}})
--
-- Deployment:
--   HC3: Add Templates.lua as a file in the EventRunner7 QuickApp
--   plua: Included via --%%file:Templates.lua,templates in EventRunner.inc

local Templates = {}
local fmt = string.format

-- ============================================================
-- Parameter validation
-- ============================================================
local function validate(params, schema, name)
  if type(params) ~= "table" then
    error(fmt("Template '%s': params must be a table, got %s", name, type(params)))
  end
  for _, field in ipairs(schema.required or {}) do
    if params[field] == nil then
      error(fmt("Template '%s': missing required parameter '%s'", name, field))
    end
  end
  for field, default in pairs(schema.defaults or {}) do
    if params[field] == nil then
      params[field] = default
    end
  end
end

-- ============================================================
-- Expression builders
-- ============================================================
local function dev(ref)
  -- Resolve a device reference to an EventScript expression.
  -- Number -> "77", string -> "kitchen.motion", table -> "{66,67,68}"
  if type(ref) == "number" then return tostring(ref) end
  if type(ref) == "table" then
    local parts = {}
    for _, d in ipairs(ref) do parts[#parts+1] = dev(d) end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return ref
end

local function timeGuardExpr(guard)
  -- Map guard shortcuts to EventScript time-range expressions.
  if not guard or guard == "always" then return nil end
  if guard == "night" then return "sunset..sunrise" end
  if guard == "day" then return "sunrise..sunset" end
  return guard  -- literal: "22:00..06:00", "sunset..sunrise", etc.
end

local function dayFilterExpr(days)
  -- Map day shortcuts to wday() patterns.
  if not days or days == "always" or days == "all" then return nil end
  local map = {
    weekdays = "mon-fri", weekday = "mon-fri",
    weekends = "sat-sun", weekend = "sat-sun",
  }
  return map[days] or days
end

-- Build a condition string from trigger, time guard, and day filter.
local function buildCondition(trigger, timeGuard, days)
  local parts = { trigger }
  local tg = timeGuardExpr(timeGuard)
  if tg then parts[#parts+1] = "& " .. tg end
  local df = dayFilterExpr(days)
  if df then parts[#parts+1] = "& wday('" .. df .. "')" end
  return table.concat(parts, " ")
end

-- Build an action string from a list of action segments.
local function buildAction(actions)
  return table.concat(actions, "; ")
end

-- Condition + modifier + => + action
local function ruleStr(condition, modifier, action)
  if modifier and modifier ~= "none" then
    condition = condition .. " " .. modifier
  end
  return condition .. " => " .. action
end

-- Parse action string into EventScript action expression.
-- "on" -> "device:on", "off" -> "device:off", "toggle" -> "device:toggle",
-- "value=N" -> "device:value = N", otherwise treat as raw suffix.
local function deviceAction(deviceExpr, action)
  if action == "on" or action == "off" or action == "toggle" then
    return deviceExpr .. ":" .. action
  elseif action:match("^value=(.+)$") then
    return deviceExpr .. ":value = " .. action:match("^value=(.+)$")
  else
    -- Raw: user passes "scene==S1.single" etc, prepend device
    return deviceExpr .. ":" .. action
  end
end

-- ============================================================
-- Template registry
-- ============================================================
Templates._registry = {}

function Templates.register(name, schema, generate)
  if Templates._registry[name] then
    error(fmt("Template '%s' is already registered", name))
  end
  Templates._registry[name] = { schema = schema, generate = generate }
end

function Templates.apply(er, name, params)
  local entry = Templates._registry[name]
  if not entry then
    local list = {}
    for n in pairs(Templates._registry) do list[#list+1] = n end
    table.sort(list)
    error(fmt("Unknown template: '%s'. Available: %s", name, table.concat(list, ", ")))
  end
  params = params or {}
  validate(params, entry.schema, name)
  return entry.generate(er, params)
end

function Templates.applyBatch(er, tmplList)
  local results = {}
  for _, t in ipairs(tmplList) do
    local name, params
    if t.type then name, params = t.type, t else name, params = t[1], t[2] end
    results[#results+1] = Templates.apply(er, name, params)
  end
  return results
end

function Templates.list()
  local names = {}
  for name in pairs(Templates._registry) do names[#names+1] = name end
  table.sort(names)
  return names
end

function Templates.describe(name)
  if name then
    local entry = Templates._registry[name]
    if not entry then return nil end
    return entry.schema
  end
  local result = {}
  for n, e in pairs(Templates._registry) do
    result[n] = {
      description = e.schema.description,
      required = e.schema.required,
      defaults = e.schema.defaults,
    }
  end
  return result
end

-- ============================================================
-- Template: motionLight
-- Motion sensor triggers light with optional auto-off, time guard,
-- brightness, and modifier.
-- ============================================================
Templates.register("motionLight", {
  description = "Turn on a light when motion is detected, with optional auto-off delay",
  required = { "sensor", "light" },
  defaults = {
    offDelay = nil,      -- auto-off after duration (nil = stays on)
    timeGuard = "always", -- "always", "night", "day", or literal "HH:MM..HH:MM"
    brightness = nil,     -- dim level 0-99 (nil = full on/off)
    modifier = "none",   -- "none", "single", "debounce T"
    group = nil,
  },
}, function(er, p)
  local sensorExpr = dev(p.sensor)
  local lightExpr = dev(p.light)

  local cond = buildCondition(sensorExpr .. ":breached", p.timeGuard)
  local actions = {}

  if p.brightness then
    actions[#actions+1] = lightExpr .. ":value = " .. p.brightness
  else
    actions[#actions+1] = lightExpr .. ":on"
  end

  if p.offDelay then
    actions[#actions+1] = "wait(" .. p.offDelay .. ")"
    actions[#actions+1] = lightExpr .. ":off"
  end

  local rs = ruleStr(cond, p.modifier, buildAction(actions))
  local opts = {}
  if p.group then opts.group = p.group end
  return er.eval(rs, opts)
end)

-- ============================================================
-- Template: thresholdControl
-- Turn actuator on/off based on sensor threshold crossing.
-- Uses two rules: on-above and off-below with optional since/cooldown.
-- ============================================================
Templates.register("thresholdControl", {
  description = "Turn a device on/off when a sensor crosses a threshold",
  required = { "sensor", "actuator", "onAbove", "offBelow" },
  defaults = {
    property = "value",   -- sensor property: "value", "temp", "lux", "humidity"
    holdTime = nil,       -- condition must hold this long (since modifier)
    cooldown = nil,       -- suppress re-trigger cooldown
    group = nil,
  },
}, function(er, p)
  local sensorExpr = dev(p.sensor)
  local actExpr = dev(p.actuator)
  local prop = p.property

  local modParts = {}
  if p.holdTime then modParts[#modParts+1] = "since " .. p.holdTime end
  if p.cooldown then modParts[#modParts+1] = "cooldown " .. p.cooldown end
  local mod = #modParts > 0 and table.concat(modParts, " ") or nil

  local opts = {}
  if p.group then opts.group = p.group end

  -- On rule: sensor > onAbove
  local onCond = sensorExpr .. ":" .. prop .. " > " .. p.onAbove
  local onRule = ruleStr(onCond, mod, actExpr .. ":on")
  local r1 = er.eval(onRule, opts)

  -- Off rule: sensor < offBelow
  local offCond = sensorExpr .. ":" .. prop .. " < " .. p.offBelow
  local offRule = ruleStr(offCond, mod, actExpr .. ":off")
  local r2 = er.eval(offRule, opts)

  return r1, r2
end)

-- ============================================================
-- Template: scheduledDevice
-- Control a device at specific times, with optional day filter and catchup.
-- ============================================================
Templates.register("scheduledDevice", {
  description = "Control a device at scheduled times",
  required = { "time", "device", "action" },
  defaults = {
    days = "always",      -- day filter
    catchup = false,      -- catch missed fires on restart
    group = nil,
  },
}, function(er, p)
  local deviceExpr = dev(p.device)
  local days = dayFilterExpr(p.days)

  -- Build time trigger
  local timeTrigger = p.time
  if timeTrigger:sub(1,1) ~= "@" then
    timeTrigger = (p.catchup and "@{" or "@") .. timeTrigger .. (p.catchup and ",catch}" or "")
  end

  local cond = buildCondition(timeTrigger, nil, p.days)
  local action = deviceAction(deviceExpr, p.action)
  local rs = cond .. " => " .. action

  local opts = {}
  if p.group then opts.group = p.group end
  return er.eval(rs, opts)
end)

-- ============================================================
-- Template: openAlert
-- Alert when a door/window sensor stays open longer than a timeout.
-- ============================================================
Templates.register("openAlert", {
  description = "Alert when a door/window stays open too long",
  required = { "sensor", "timeout" },
  defaults = {
    property = "breached",  -- sensor property: "breached", "isOpen", "open"
    message = nil,          -- custom log message (nil = auto-generated)
    repeatAlert = false,    -- repeat alert periodically
    repeatMax = 10,         -- max repeats (only if repeatAlert=true)
    group = nil,
  },
}, function(er, p)
  local sensorExpr = dev(p.sensor)
  local prop = p.property
  local sensorName = type(p.sensor) == "string" and p.sensor or ("device " .. tostring(p.sensor))

  local cond = "trueFor(" .. p.timeout .. "," .. sensorExpr .. ":" .. prop .. ")"
  local actions = {}

  if p.message then
    actions[#actions+1] = "log('" .. p.message:gsub("'", "\\'") .. "')"
  else
    actions[#actions+1] = "log('" .. sensorName .. " open for " .. p.timeout .. "')"
  end

  if p.repeatAlert then
    -- Re-arm trueFor up to repeatMax more times
    actions[#actions+1] = "again(" .. p.repeatMax .. ")"
  end

  local rs = cond .. " => " .. buildAction(actions)
  local opts = {}
  if p.group then opts.group = p.group end
  return er.eval(rs, opts)
end)

-- ============================================================
-- Template: scheduledScene
-- Activate or deactivate a named scene at scheduled times.
-- ============================================================
Templates.register("scheduledScene", {
  description = "Activate or deactivate a named scene at scheduled times",
  required = { "scene", "time" },
  defaults = {
    action = "activate",    -- "activate" or "deactivate"
    days = "always",
    catchup = false,
    group = nil,
  },
}, function(er, p)
  local timeTrigger = p.time
  if timeTrigger:sub(1,1) ~= "@" then
    timeTrigger = (p.catchup and "@{" or "@") .. timeTrigger .. (p.catchup and ",catch}" or "")
  end

  local cond = buildCondition(timeTrigger, nil, p.days)
  local rs = cond .. " => " .. p.scene .. ":" .. p.action

  local opts = {}
  if p.group then opts.group = p.group end
  return er.eval(rs, opts)
end)

-- ============================================================
-- Template: sunDevice
-- Control a device relative to sunrise/sunset/dawn/dusk.
-- ============================================================
Templates.register("sunDevice", {
  description = "Control a device at sunrise/sunset with optional offset",
  required = { "event", "device", "action" },
  defaults = {
    offset = nil,       -- offset from event, e.g. "-00:30" or "+01:00"
    group = nil,
  },
}, function(er, p)
  local deviceExpr = dev(p.device)
  local event = p.event  -- "sunset", "sunrise", "dawn", "dusk"

  local timeTrigger = "@" .. event
  if p.offset then
    timeTrigger = timeTrigger .. p.offset
  end

  local action = deviceAction(deviceExpr, p.action)
  local rs = timeTrigger .. " => " .. action

  local opts = {}
  if p.group then opts.group = p.group end
  return er.eval(rs, opts)
end)

-- ============================================================
-- Template: buttonScene
-- Map a remote button press or scene activation to a named scene.
-- ============================================================
Templates.register("buttonScene", {
  description = "Map a button/remote press to a scene activation",
  required = { "button", "trigger", "scene" },
  defaults = {
    action = "activate",    -- "activate" or "deactivate"
    group = nil,
  },
}, function(er, p)
  local buttonExpr = dev(p.button)
  local trigger = p.trigger

  -- trigger formats:
  --   "single" / "double" / "triple" / "hold"  -> button:scene == S1.<trigger>
  --   "keyId=N"  -> button:central.keyId == N
  --   "scene==S1.single" (raw) -> button:scene == S1.single
  local cond
  if trigger:match("^keyId=(%d+)$") then
    cond = buttonExpr .. ":central.keyId == " .. trigger:match("^keyId=(%d+)$")
  elseif trigger:match("^scene==") then
    cond = buttonExpr .. ":" .. trigger
  elseif trigger == "single" or trigger == "double" or trigger == "triple" or trigger == "hold" then
    cond = buttonExpr .. ":scene == S1." .. trigger
  else
    -- raw trigger expression like "central.keyId == 2"
    cond = buttonExpr .. ":" .. trigger
  end

  local rs = cond .. " => " .. p.scene .. ":" .. p.action
  local opts = {}
  if p.group then opts.group = p.group end
  return er.eval(rs, opts)
end)

-- ============================================================
-- Template: autoOff
-- When a trigger fires, turn on a device and auto-off after a delay.
-- ============================================================
Templates.register("autoOff", {
  description = "Turn on a device on trigger and auto-off after delay",
  required = { "trigger", "device", "delay" },
  defaults = {
    onAction = "on",        -- what to turn on: "on", "value=N"
    modifier = "single",    -- "single" restarts timer on re-trigger, "none" skips
    group = nil,
  },
}, function(er, p)
  local deviceExpr = dev(p.device)

  local cond = p.trigger
  if p.modifier and p.modifier ~= "none" then
    cond = cond .. " " .. p.modifier
  end

  local actions = {}
  if p.onAction == "on" then
    actions[#actions+1] = deviceExpr .. ":on"
  elseif p.onAction:match("^value=(.+)$") then
    actions[#actions+1] = deviceExpr .. ":value = " .. p.onAction:match("^value=(.+)$")
  else
    actions[#actions+1] = deviceExpr .. ":" .. p.onAction
  end
  actions[#actions+1] = "wait(" .. p.delay .. ")"
  actions[#actions+1] = deviceExpr .. ":off"

  local rs = cond .. " => " .. buildAction(actions)
  local opts = {}
  if p.group then opts.group = p.group end
  return er.eval(rs, opts)
end)

-- ============================================================
-- Template: vacationMode
-- Disable/enable rule groups based on a global variable.
-- ============================================================
Templates.register("vacationMode", {
  description = "Disable/enable rule groups based on a global variable",
  required = { "variable", "groups" },
  defaults = {
    invert = false,         -- invert logic: disable when false instead of true
    group = nil,
  },
}, function(er, p)
  local var = p.variable
  -- Ensure $ prefix for global variable
  if var:sub(1,1) ~= "$" then var = "$" .. var end

  local groups = type(p.groups) == "table" and p.groups or { p.groups }
  local disableActions, enableActions = {}, {}

  for _, g in ipairs(groups) do
    disableActions[#disableActions+1] = "disable('" .. g .. "')"
    enableActions[#enableActions+1] = "enable('" .. g .. "')"
  end

  local opts = {}
  if p.group then opts.group = p.group end

  local onValue = p.invert and "false" or "true"
  local offValue = p.invert and "true" or "false"

  -- Rule: variable == onValue -> disable groups
  local rs1 = var .. " == " .. onValue .. " => " .. buildAction(disableActions)
  er.eval(rs1, opts)

  -- Rule: variable == offValue -> enable groups
  local rs2 = var .. " == " .. offValue .. " => " .. buildAction(enableActions)
  er.eval(rs2, opts)

  -- Also enable on startup (if variable is not set to vacation)
  local rs3 = var .. " ~= " .. onValue .. " => " .. buildAction(enableActions)
  local r3 = er.eval(rs3, {})
  if r3.start then r3:start() end  -- run once at startup
end)

-- ============================================================
-- Template: presenceSim
-- Simulate presence by randomly toggling lights during a time window.
-- ============================================================
Templates.register("presenceSim", {
  description = "Simulate presence by toggling lights randomly",
  required = { "lights" },
  defaults = {
    startTime = "sunset-00:30",
    endTime = "23:00",
    activeDays = "all",
    interval = "00:30",     -- how often to toggle
    group = nil,
  },
}, function(er, p)
  local lightsExpr = dev(p.lights)
  local days = dayFilterExpr(p.activeDays)
  local dayGuard = days and (" & wday('" .. days .. "')") or ""
  local opts = p.group and { group = p.group } or {}

  -- Start simulation at startTime
  local startTime = p.startTime
  if startTime:sub(1,1) ~= "@" then startTime = "@" .. startTime end
  local rs1 = startTime .. dayGuard .. " => post(#_presenceSimTick)"
  er.eval(rs1, opts)

  -- Tick: toggle a random light, then schedule next tick if still in window
  local rs2 = fmt([[
    #_presenceSimTick =>
      local pick = %s[rnd(1,#%s)];
      pick:toggle;
      if %s..%s then post(#_presenceSimTick,+/%s) end
  ]], lightsExpr, lightsExpr, p.startTime, p.endTime, p.interval)
  er.eval(rs2, opts)

  -- End simulation: turn off all lights at endTime
  local endTime = p.endTime
  if endTime:sub(1,1) ~= "@" then endTime = "@" .. endTime end
  local rs3 = endTime .. dayGuard .. " => " .. lightsExpr .. ":off"
  er.eval(rs3, opts)
end)

-- ============================================================
-- Template: nightMode
-- Set house to night state at a scheduled time.
-- ============================================================
Templates.register("nightMode", {
  description = "Set house to night state: turn off lights, arm security, set thermostat",
  required = { "time" },
  defaults = {
    lights = nil,           -- device or list of lights to turn off
    security = nil,         -- partition ID to arm, or true for all
    thermostat = nil,       -- { device = ref, setpoint = N }
    days = "always",
    catchup = false,
    group = nil,
  },
}, function(er, p)
  local timeTrigger = p.time
  if timeTrigger:sub(1,1) ~= "@" then
    timeTrigger = (p.catchup and "@{" or "@") .. timeTrigger .. (p.catchup and ",catch}" or "")
  end

  local cond = buildCondition(timeTrigger, nil, p.days)
  local actions = {}

  if p.lights then
    local lightExpr = dev(p.lights)
    actions[#actions+1] = lightExpr .. ":off"
  end

  if p.security then
    if type(p.security) == "number" then
      actions[#actions+1] = p.security .. ":arm"
    else
      actions[#actions+1] = "0:arm"  -- arm all partitions
    end
  end

  if p.thermostat then
    local thermoExpr = dev(p.thermostat.device)
    actions[#actions+1] = thermoExpr .. ":setpoint = " .. p.thermostat.setpoint
  end

  if #actions == 0 then
    error("Template 'nightMode': at least one of lights, security, or thermostat must be specified")
  end

  local rs = cond .. " => " .. buildAction(actions)
  local opts = {}
  if p.group then opts.group = p.group end
  return er.eval(rs, opts)
end)

-- ============================================================
-- Template: morningRoutine
-- Wake-up routine: lights on, disarm security, set thermostat.
-- ============================================================
Templates.register("morningRoutine", {
  description = "Morning wake-up routine: lights, security, thermostat",
  required = { "time" },
  defaults = {
    lights = nil,           -- device or list of lights
    brightness = 100,       -- dim level for lights
    security = nil,         -- partition ID to disarm, or true for all
    thermostat = nil,       -- { device = ref, setpoint = N }
    days = "always",
    catchup = false,
    group = nil,
  },
}, function(er, p)
  local timeTrigger = p.time
  if timeTrigger:sub(1,1) ~= "@" then
    timeTrigger = (p.catchup and "@{" or "@") .. timeTrigger .. (p.catchup and ",catch}" or "")
  end

  local cond = buildCondition(timeTrigger, nil, p.days)
  local actions = {}

  if p.lights then
    local lightExpr = dev(p.lights)
    actions[#actions+1] = lightExpr .. ":value = " .. p.brightness
  end

  if p.security then
    if type(p.security) == "number" then
      actions[#actions+1] = p.security .. ":disarm"
    else
      actions[#actions+1] = "0:disarm"
    end
  end

  if p.thermostat then
    local thermoExpr = dev(p.thermostat.device)
    actions[#actions+1] = thermoExpr .. ":setpoint = " .. p.thermostat.setpoint
  end

  if #actions == 0 then
    error("Template 'morningRoutine': at least one of lights, security, or thermostat must be specified")
  end

  local rs = cond .. " => " .. buildAction(actions)
  local opts = {}
  if p.group then opts.group = p.group end
  return er.eval(rs, opts)
end)

-- ============================================================
-- Template: groupToggle
-- Toggle a rule group on/off based on a trigger condition.
-- ============================================================
Templates.register("groupToggle", {
  description = "Enable/disable a rule group based on a trigger",
  required = { "trigger", "group", "action" },
  defaults = {
    target = nil,  -- specific rule ID/name within group (nil = whole group)
  },
}, function(er, p)
  local cond = p.trigger
  local target = p.target or ("'" .. p.group .. "'")

  local fnName = p.action  -- "enable" or "disable"
  if fnName ~= "enable" and fnName ~= "disable" then
    error("Template 'groupToggle': action must be 'enable' or 'disable', got '" .. tostring(fnName) .. "'")
  end

  local rs = cond .. " => " .. fnName .. "(" .. target .. ")"
  return er.eval(rs, {})
end)

-- ============================================================
-- Self-integration via MODULE system
-- Patches er.template() / er.templates() onto the EventRunner instance
-- before the user's main(er) function runs.
-- ============================================================
MODULE[#MODULE+1] = {
  name = "_Templates",
  prio = -500,  -- after _StdRules preSetup (-1000), before user main (0)
  code = function(er)
    er.template = function(name, params)
      return Templates.apply(er, name, params)
    end
    er.templates = function(list)
      return Templates.applyBatch(er, list)
    end
    er.templateList = function()
      return Templates.list()
    end
    er.templateDescribe = function(name)
      return Templates.describe(name)
    end
  end,
}

return Templates
