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

local music = require 'musicutil'
local TU = require 'tabutil'
local UI = require "ui"

local running = false
local divisor = 4
local grid_buttons_pressed = {}
local pages = {pitch = 1, offset = 2}
local page = "pitch"

-- Tracks
tracks = {}
-- for i = 1,3 do
tracks[1] = {}
tracks[1].pitch = {}
tracks[1].pitch.pitches = {}
tracks[1].pitch.triggers = {}
tracks[1].pitch.position = 1
tracks[1].pitch.loop_start = 1 -- or start_point and end_point?
tracks[1].pitch.loop_end = 16
tracks[1].pitch.transpose = {}
tracks[1].offset = {}
tracks[1].offset.pitches = {}
tracks[1].offset.triggers = {}
tracks[1].offset.position = 1
tracks[1].offset.loop_start = 1
tracks[1].offset.loop_end = 16
-- end


local task_id = nil
local playback_icon = UI.PlaybackIcon.new(121, 55)

-- Create a fake local table just like _G
-- _L = {pitch = pitch, offset = offset}

-- mode = math.random(#music.SCALES)
-- TU.print(music.SCALES)
scale = music.generate_scale_of_length(8, "major", 14)
-- TU.print(scale)

function init()
  for i=1,16 do
    table.insert(tracks[1].pitch.pitches, math.random(7))
    table.insert(tracks[1].pitch.triggers, true)
    table.insert(tracks[1].pitch.transpose, 0)
    table.insert(tracks[1].offset.pitches, 0)
    table.insert(tracks[1].offset.triggers, false)
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
      -- print(tracks[1].pitch.position)
      -- print(tracks[1].pitch.pitches[tracks[1].pitch.position])
      if tracks[1].pitch.triggers[tracks[1].pitch.position] then
        local note_num = 8 - tracks[1].pitch.pitches[tracks[1].pitch.position]
        if tracks[1].offset.triggers[tracks[1].offset.position] then
          note_num = note_num + (8 - tracks[1].offset.pitches[tracks[1].offset.position])
        end
        local note_value = scale[note_num]/12
        -- print(tracks[1].pitch.transpose[tracks[1].pitch.position])
        -- print(note_num)
        crow.output[2].volts = note_value + tracks[1].pitch.transpose[tracks[1].pitch.position]
        crow.output[1].execute()
        -- grid_redraw()
      end
      -- print(tracks[1].pitch.position)
      -- tracks[1].pitch.position = util.clamp(tracks[1].pitch.position + 1, tracks[1].pitch.loop_start, tracks[1].pitch.loop_end)
      -- Increment tracks[1].pitch.position. Wrap tracks[1].pitch.loop_start in case the current tracks[1].pitch.position is tracks[1].pitch.loop_end
      tracks[1].pitch.position = math.max((tracks[1].pitch.position % tracks[1].pitch.loop_end) + 1, tracks[1].pitch.loop_start)
      tracks[1].offset.position = math.max((tracks[1].offset.position % tracks[1].offset.loop_end) + 1, tracks[1].offset.loop_start)
      -- print(tracks[1].pitch.position)
      -- print(tracks[1].offset.position)
    end
  end
end

function key(n,z)
  if n == 2 and z == 1 then
      -- clock.cancel(task_id)
      -- task_id = clock.run(step)
      tracks[1].pitch.position = 1
      tracks[1].offset.position = 1
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
    -- TU.print(tracks[1].pitch.transpose)
    for k, v in pairs(tracks[1].pitch.pitches) do
      if v ~= 0 then
        local new_v = v - d
        if new_v < 1 then
          tracks[1].pitch.pitches[k] = 7
          tracks[1].pitch.transpose[k] = util.clamp(tracks[1].pitch.transpose[k] + 1, -3, 3)
        elseif new_v > 7 then
          tracks[1].pitch.pitches[k] = 1
          tracks[1].pitch.transpose[k] = util.clamp(tracks[1].pitch.transpose[k] - 1, -3, 3)
        else
          tracks[1].pitch.pitches[k] = new_v
        end
      end
      -- print(k, tracks[1].pitch.pitches[k])
      -- TU.print(tracks[1].pitch.transpose)
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
  -- screen.text("transp: "..tracks[1].pitch.transpose)
  playback_icon:redraw()
  screen.update()
end


g = grid.connect()

g.key = function(x,y,z)
  if y == 8 then -- control row key pressed
    if x == 1 then
      page = "pitch"
    elseif x == 2 then
      page = "offset"
    end
  else
    if z == 1 then -- key pressed
      -- Allow setting loop start and end points
      -- Not really sure how best to handle this/how to combine being able to enable/disable
      -- pitch/keys with being able to pick loop start and end points?
      if #grid_buttons_pressed == 1 then
        grid_buttons_pressed[2] = x
        tracks[1][page].loop_start = math.min(grid_buttons_pressed[1], x)
        tracks[1][page].loop_end = math.max(grid_buttons_pressed[1], x)
        grid_buttons_pressed = {}
      else
        grid_buttons_pressed[1] = x
      end
    elseif z == 0 then
      -- If the current key is in grid_buttons_pressed it's not being used for a loop so use it for setting a step value
      if TU.contains(grid_buttons_pressed, x) then
        -- if y == 8 then -- control row
        --   -- print(x)
        if tracks[1][page].triggers[x] and tracks[1][page].pitches[x] == y then
          -- Existing note pressed, turn off step
          tracks[1][page].triggers[x] = false
        else
          -- New note pressed
          tracks[1][page].pitches[x] = y
          tracks[1][page].triggers[x] = true
        end
        -- grid_redraw()
        -- TU.print(tracks[1][page].triggers)
        table.remove(grid_buttons_pressed, TU.key(grid_buttons_pressed, x))
      end
    end
  end
  -- TU.print(tracks[1].offset.triggers)
  -- TU.print(offset)
end

function grid_redraw()
  g:all(0)
  for i=1,16 do
    local low_value = 7
    if i < tracks[1][page].loop_start or i > tracks[1][page].loop_end then
      low_value = 4
    end
    if tracks[1][page].triggers[i] then
      g:led(i,tracks[1][page].pitches[i],i==tracks[1][page].position and 15 or low_value)
    else
      g:led(i,1,i==tracks[1][page].position and 3 or 0)
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
