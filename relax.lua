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

-- TODO Use octave or 8(or 7) scale "steps" (as many as fit on a grid) for transposing?
-- TODO Use absolute value per step or grid based value (1-8) together with separate transpose table?

engine.name = 'PolyPerc'

local music = require 'musicutil'
local TU = require 'tabutil'
local UI = require "ui"

local running = false
local position = 1
local divisor = 4
grid_buttons_pressed = {}

-- Track properties
local steps = {}
local triggers = {}
local transpose = {}
loop_start = 3
loop_end = 11

local task_id = nil
local playback_icon = UI.PlaybackIcon.new(121, 55)

-- mode = math.random(#music.SCALES)
-- TU.print(music.SCALES)
scale = music.generate_scale_of_length(8, "major", 7)
-- TU.print(scale)

function init()
  for i=1,16 do
    table.insert(steps, math.random(7))
    table.insert(triggers, true)
    table.insert(transpose, 0)
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
      -- print(position)
      -- print(steps[position])
      if triggers[position] then
        -- print(steps[position])
        local note_num = scale[8 - steps[position]]
        -- print(steps[position])
        -- print(transpose[position])
        -- print(note_num)
        -- engine.hz(music.note_num_to_freq(note_num))
        crow.output[2].volts = (note_num)/12 + transpose[position]
        crow.output[1].execute()
        -- grid_redraw()
      end
      -- print(position)
      -- position = util.clamp(position + 1, loop_start, loop_end)
      -- Increment position. Wrap loop_start in case the current position is loop_end
      position = math.max((position % loop_end) + 1, loop_start)
    end
  end
end

function key(n,z)
  if n == 2 and z == 1 then
      -- clock.cancel(task_id)
      -- task_id = clock.run(step)
      position = 1
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
  screen.move(0,30)
  screen.text("bpm: "..params:get("clock_tempo"))
  screen.move(0,40)
  screen.text("div: 1/".. divisor*4)
  -- screen.move(0,50)
  -- screen.text("transp: "..transpose)
  playback_icon:redraw()
  screen.update()
end


g = grid.connect()

g.key = function(x,y,z)
  if z == 1 then -- key pressed
    -- Allow setting loop start and end points
    -- Not really sure how best to handle this/how to combine being able to enable/disable
    -- steps/keys with being able to pick loop start and end points?
    if #grid_buttons_pressed == 1 then
      grid_buttons_pressed[2] = x
      loop_start = math.min(grid_buttons_pressed[1], x)
      loop_end = math.max(grid_buttons_pressed[1], x)
      grid_buttons_pressed = {}
    else
      grid_buttons_pressed[1] = x
    end
  elseif z == 0 then
    -- If the current key is in grid_buttons_pressed it's not being used for a loop so use it for setting a step value
    if TU.contains(grid_buttons_pressed, x) then
      -- if y == 8 then -- control row
      --   -- print(x)
      if y < 8 then
        if triggers[x] and steps[x] == y then
          -- Existing note pressed, turn off step
          triggers[x] = false
        else
          -- New note pressed
          steps[x] = y
          triggers[x] = true
        end
      end
      -- grid_redraw()
      -- TU.print(triggers)
      table.remove(grid_buttons_pressed, TU.key(grid_buttons_pressed, x))
    end
  end
end

function grid_redraw()
  g:all(0)
  for i=1,16 do
    if triggers[i] then
      g:led(i,steps[i],i==position and 15 or 5)
    else
      g:led(i,1,i==position and 3 or 0)
    end
  end
  g:refresh()
end
