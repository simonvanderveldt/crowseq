-- physical: clock edition
-- norns study 4
--
-- grid controls arpeggio
-- midi controls root note
-- ENC1 = bpm
-- ENC2 = divisor
-- ENC3 = scale
-- KEY2 = hold
-- KEY3 = restart sequence

-- TODO Keep transpose and offset separate? Not sure of the pros and cons
-- TODO Use octave or 8(or 7) scale "steps" (as many as fit on a grid) for transposing?
-- TODO Use absolute value per step or grid based value (1-8) together with separate transpose table?

engine.name = 'PolyPerc'

local music = require 'musicutil'
local TU = require 'tabutil'
local UI = require "ui"

local running = false
local divisor = 4
local grid_buttons_pressed = {}
local pages = {steps = 1, offsets = 2}
local page = "steps"

-- Track properties
local steps = {}
local steps_triggers = {}
local steps_position = 1
local steps_start = 1
local steps_end = 16
local transpose = {}
local offsets = {}
local offsets_triggers = {}
local offsets_position = 1
local offsets_start = 1
local offsets_end = 16

local task_id = nil
local playback_icon = UI.PlaybackIcon.new(121, 55)

-- Create a fake local table just like _G
_L = {steps = steps, steps_triggers = steps_triggers, steps_position = steps_position, steps_start = steps_start, steps_end = steps_end,
      offsets = offsets, offsets_triggers = offsets_triggers, offsets_position = offsets_position, offsets_start = offsets_start, offsets_end = offsets_end}

-- mode = math.random(#music.SCALES)
-- TU.print(music.SCALES)
scale = music.generate_scale_of_length(8, "major", 14)
-- TU.print(scale)

function init()
  for i=1,16 do
    table.insert(steps, math.random(7))
    table.insert(steps_triggers, true)
    table.insert(transpose, 0)
    table.insert(offsets, 0)
    table.insert(offsets_triggers, false)
  end
  grid_redraw()

  crow.output[1].action = "pulse(0.01, 8, 1)"

  task_id = clock.run(step)

  -- screen refresh
  clock.run(function()
    while true do
      clock.sleep(1/30)
      redraw()
    end
  end)

  -- grid refresh
  clock.run(function()
    while true do
      clock.sleep(1/30)
      grid_redraw()
    end
  end)
end

function step()
  while true do
    clock.sync(1/divisor)
    if running then
      -- print(_L["steps_position"])
      -- print(steps[_L["steps_position"]])
      if steps_triggers[_L["steps_position"]] then
        -- print(steps[_L["steps_position"]])
        local note_num = 8 - steps[_L["steps_position"]]
        if offsets_triggers[_L["offsets_position"]] then
          note_num = note_num + (8 - offsets[_L["offsets_position"]])
        end
        local note_value = scale[note_num]/12
        -- print(steps[_L["steps_position"]])
        -- print(transpose[_L["steps_position"]])
        -- print(note_num)
        -- engine.hz(music.note_num_to_freq(note_num))
        crow.output[2].volts = note_value + transpose[_L["steps_position"]]
        crow.output[1].execute()
        -- grid_redraw()
      end
      -- print(_L["steps_position"])
      -- _L["steps_position"] = util.clamp(_L["steps_position"] + 1, _L["steps_start"], _L["steps_end"])
      -- Increment _L["steps_position"]. Wrap _L["steps_start"] in case the current _L["steps_position"] is _L["steps_end"]
      _L["steps_position"] = math.max((_L["steps_position"] % _L["steps_end"]) + 1, _L["steps_start"])
      _L["offsets_position"] = math.max((_L["offsets_position"] % _L["offsets_end"]) + 1, _L["offsets_start"])
      -- print(_L["steps_position"])
      -- print(_L["offsets_position"])
    end
  end
end

function key(n,z)
  if n == 2 and z == 1 then
      -- clock.cancel(task_id)
      -- task_id = clock.run(step)
      _L["steps_position"] = 1
      _L["offsets_position"] = 1
      if not running then
        playback_icon.status = 4
        -- I don't like this, maybe grid_redraw should also be run as a corouting, just like redraw?
        -- grid_redraw()
      end
  elseif n == 3 and z == 1 then
    -- running = not running
    if running then
				running = false
				playback_icon.status = 3
		else
				running = true
				playback_icon.status = 1
		end
  end
end

function enc(n,d)
  if n == 1 then
    params:delta("clock_tempo",d)
  elseif n == 2 then
    divisor = util.clamp(divisor + d,1,8)
  -- elseif n == 3 then
  --   mode = util.clamp(mode + d, 1, #music.SCALES)
  --   scale = music.generate_scale_of_length(60,music.SCALES[mode].name,8)
  elseif n == 3 then
    -- Transpose
    -- This is wrong/upside down. Not sure what the best way to "flip" the grid is
    -- TU.print(transpose)
    for k, v in pairs(steps) do
      if v ~= 0 then
        local new_v = v - d
        if new_v < 1 then
          steps[k] = 7
          transpose[k] = util.clamp(transpose[k] + 1, -3, 3)
        elseif new_v > 7 then
          steps[k] = 1
          transpose[k] = util.clamp(transpose[k] - 1, -3, 3)
        else
          steps[k] = new_v
        end
      end
      -- print(k, steps[k])
      -- TU.print(transpose)
      -- grid_redraw()
    end
  end
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("bpm: "..params:get("clock_tempo").." | div: 1/".. divisor*4)
  screen.move(0, 14)
  screen.line(128, 14)
  screen.stroke()
  -- screen.text("transp: "..transpose)
  playback_icon:redraw()
  screen.update()
end


g = grid.connect()

g.key = function(x,y,z)
  if y == 8 then -- control row key pressed
    if x == 1 then
      page = "steps"
    elseif x == 2 then
      page = "offsets"
    end
  else
    if z == 1 then -- key pressed
      -- Allow setting loop start and end points
      -- Not really sure how best to handle this/how to combine being able to enable/disable
      -- steps/keys with being able to pick loop start and end points?
      if #grid_buttons_pressed == 1 then
        grid_buttons_pressed[2] = x
        _L[page.."_start"] = math.min(grid_buttons_pressed[1], x)
        _L[page.."_end"] = math.max(grid_buttons_pressed[1], x)
        grid_buttons_pressed = {}
      else
        grid_buttons_pressed[1] = x
      end
    elseif z == 0 then
      -- If the current key is in grid_buttons_pressed it's not being used for a loop so use it for setting a step value
      if TU.contains(grid_buttons_pressed, x) then
        -- if y == 8 then -- control row
        --   -- print(x)
        if _L[page.."_triggers"][x] and _L[page][x] == y then
          -- Existing note pressed, turn off step
          _L[page.."_triggers"][x] = false
        else
          -- New note pressed
          _L[page][x] = y
          _L[page.."_triggers"][x] = true
        end
        -- grid_redraw()
        -- TU.print(_L[page.."_triggers"])
        table.remove(grid_buttons_pressed, TU.key(grid_buttons_pressed, x))
      end
    end
  end
  -- TU.print(offsets_triggers)
  -- TU.print(offsets)
end

function grid_redraw()
  g:all(0)
  for i=1,16 do
    local low_value = 7
    if i < _L[page.."_start"] or i > _L[page.."_end"] then
      low_value = 4
    end
    if _L[page.."_triggers"][i] then
      g:led(i,_L[page][i],i==_L[page.."_position"] and 15 or low_value)
    else
      g:led(i,1,i==_L[page.."_position"] and 3 or 0)
    end
  end
  for k, v in pairs(pages) do
    if k == page then
      g:led(pages[k],8,11)
    else
      g:led(pages[k],8,4)
    end
  end
  g:refresh()
end
