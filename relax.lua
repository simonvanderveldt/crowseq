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


-- TODO Enabling/disabling pitches should not change triggers if any trigger is set (I think)
-- TODO Move some commonly used stuff to functions? Like calculation the step from the click. Or add an attribute to store the step maybe?

-- TODO How to blink grid key when looping single key/position?
-- TODO Keep transpose and offset separate? Not sure of the pros and cons
-- TODO Use octave or 8(or 7) scale "steps" (as many as fit on a grid) for transposing?
-- TODO Use absolute value per step or grid based value (1-8) together with separate transpose table?
-- TODO Use 0 as value for pitches instead of separate triggers table? Advantage of triggers table is slightly easier code (if trigger vs if pitch == 0)
-- TODO Add morph
-- TODO Add randomize

local music = require "musicutil"
local TU = require "tabutil"
local UI = require "ui"

local running = false
local divisor = 4
local grid_buttons_pressed = {}
local pages = {pitch = 1, offset = 2}
local index_to_pages = {"pitch", "offset", "triggers"}
local page = "pitch"
local subpage = "pitches"

-- Tracks
tracks = {}
-- for i = 1,3 do
tracks[1] = {}
tracks[1].pitch = {}
tracks[1].pitch.pitches = {}
tracks[1].pitch.triggers = {}
tracks[1].pitch.position = 1
tracks[1].pitch.loop_start = 1 -- or start_point and end_point?
tracks[1].pitch.loop_end = 96
tracks[1].pitch.new_loop_set = false
tracks[1].pitch.transpose = {}
tracks[1].offset = {}
tracks[1].offset.pitches = {}
tracks[1].offset.triggers = {}
tracks[1].offset.position = 1
tracks[1].offset.loop_start = 1
tracks[1].offset.loop_end = 96
tracks[1].offset.new_loop_set = false
tracks[1].controls = {pitch = false, offset = false, triggers = false}
-- end


local task_id = nil
local playback_icon = UI.PlaybackIcon.new(121, 55)

-- mode = math.random(#music.SCALES)
-- TU.print(music.SCALES)
scale = music.generate_scale_of_length(8, "major", 14)

function init()
  for i=1,16 do
    table.insert(tracks[1].pitch.pitches, math.random(7))
    table.insert(tracks[1].pitch.transpose, 0)
    table.insert(tracks[1].offset.pitches, 0)
  end
  for i=1,96 do
    if i % 6 == 1 then
      table.insert(tracks[1].pitch.triggers, true)
    else
      table.insert(tracks[1].pitch.triggers, false)
    end
    table.insert(tracks[1].offset.triggers, false)
  end
  grid_redraw()
  -- TU.print(tracks[1].pitch.triggers)
  -- print(tracks[1].pitch.triggers[1])

  crow.output[1].action = "pulse(0.01, 8, 1)"

  task_id = clock.run(tick)

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

function tick()
  while true do
    clock.sync(1 / (divisor * 6)) -- 24ppqn = 6 ticks per beat
      if running then
        -- print(tracks[1].pitch.position)
        -- print(tracks[1].pitch.triggers[tracks[1].pitch.position])
        if tracks[1].pitch.triggers[tracks[1].pitch.position] then
          local note_num = 8 - tracks[1].pitch.pitches[math.ceil(tracks[1].pitch.position / 6)]
          if tracks[1].offset.triggers[tracks[1].offset.position] then
            note_num = note_num + (8 - tracks[1].offset.pitches[math.ceil(tracks[1].offset.position / 6)])
          end
          local note_value = scale[note_num]/12
          crow.output[2].volts = note_value + tracks[1].pitch.transpose[math.ceil(tracks[1].pitch.position / 6)]
          crow.output[1].execute()
        end
        -- Increment tracks[1].pitch.position. Wrap tracks[1].pitch.loop_start in case the current tracks[1].pitch.position is at tracks[1].pitch.loop_end
        tracks[1].pitch.position = math.max((tracks[1].pitch.position % tracks[1].pitch.loop_end) + 1, tracks[1].pitch.loop_start)
        tracks[1].offset.position = math.max((tracks[1].offset.position % tracks[1].offset.loop_end) + 1, tracks[1].offset.loop_start)
        -- tracks[1].pitch.position = math.max((tracks[1].pitch.position % 96) + 1, 1)
        -- tracks[1].offset.position = math.max((tracks[1].offset.position % 96) + 1, 1)
      end
    -- end
  end
end

function key(n,z)
  if n == 2 and z == 1 then
      tracks[1].pitch.position = 1
      tracks[1].offset.position = 1
      if not running then
        playback_icon.status = 4
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

-- Should this be so randomly here? Shouldn't this be in init? Or at the top of the script? Why is it here in this place?
g = grid.connect()

g.key = function(x,y,z)
  if y == 8 then
    -- Global controls
    if z == 1 then
      -- key pressed
      tracks[1].controls[index_to_pages[x]] = true
    elseif z == 0 then
      -- key released
      if x == 1 then
        page = "pitch"
        subpage = "pitches"
      elseif x == 2 then
        page = "offset"
        subpage = "pitches"
      elseif x == 3 then
        page = "pitch"
        subpage = "triggers"
      end
      tracks[1].controls[index_to_pages[x]] = false
    end
  else
    -- Page controls
    if z == 1 then -- key pressed
      if tracks[1].controls[page] and subpage == "pitches" then
        -- Set loop start and end points when page button is pressed
        table.insert(grid_buttons_pressed, x)
        if #grid_buttons_pressed == 2 then
          -- When 2 buttons are pressed immediately set loop start and end point
          tracks[1][page].loop_start = (math.min(grid_buttons_pressed[1], grid_buttons_pressed[2]) * 6) - 5
          tracks[1][page].loop_end = math.max(grid_buttons_pressed[1], grid_buttons_pressed[2]) * 6
          tracks[1][page].new_loop_set = true
        end
      else
        -- Page button isn't pressed, set page specific properties (pitches, triggers, etc)
        if subpage == "pitches" then
          position = ((x - 1) * 6) + 1
          if tracks[1][page].triggers[position] and tracks[1][page].pitches[x] == y then
            -- Existing note pressed, turn off step
            tracks[1][page].triggers[position] = false
          else
            -- New note pressed
            tracks[1][page].pitches[x] = y
            tracks[1][page].triggers[position] = true
          end
        elseif subpage == "triggers" and y > 1 then
          -- Only trigger on row 2-7 because we only have 6 triggers per step
          position = ((x - 1) * 6) + (8 - y)
          if tracks[1][page].triggers[position] then
            -- Existing trigger pressed, turn off
            tracks[1][page].triggers[position] = false
          else
            -- New trigger pressed
            tracks[1][page].triggers[position] = true
          end
        end
      end
      TU.print(tracks[1][page].triggers)
    elseif z == 0 then -- key released
      if #grid_buttons_pressed == 1 then -- If there's still a single page key pressed
        if not tracks[1][page].new_loop_set then -- Check if new loop start and end points have been set
          -- If not, we've got a single keypress whilst the page button was pressed so create a single step loop
          tracks[1][page].loop_start = (grid_buttons_pressed[1] * 6) - 5
          tracks[1][page].loop_end = grid_buttons_pressed[1] * 6
        else
          -- New loop start and end points have been set before, since we've just released the remaining single button
          -- we can now set our "dirty" flag to false again
          tracks[1][page].new_loop_set = false
        end
      end
      table.remove(grid_buttons_pressed, TU.key(grid_buttons_pressed, x))
    end
  end
end

function grid_redraw()
  g:all(0)
  -- Draw pages
  for i=1,16 do
    local BRIGHTNESS_LOW = 4
    local BRIGHTNESS_MID = 8
    local BRIGHTNESS_HIGH = 15
    if i < math.ceil(tracks[1][page].loop_start / 6) or i > math.ceil(tracks[1][page].loop_end / 6) then
      BRIGHTNESS_MID = 4
    end
    if subpage == "pitches" then
      -- Check if there's at least one trigger enabled for this step
      -- Also check if this step's trigger itself is enabled
      click = false
      step = false
      for j=1,6 do
        if tracks[1][page].triggers[((i-1) * 6) + j] then
          if j == 1 then
            step = true
          end
          click = true
        end
      end
      -- Set brightness. If this step is currently playing it's high, if not and this step's trigger is enabled it's mid
      -- if not but any other trigger for this step is enabled it's low
      -- and if there is no trigger enabled for this step at all it's off but we show a moving cursor at the top row
      if step then
        g:led(i,tracks[1][page].pitches[i],i==math.ceil(tracks[1][page].position / 6) and BRIGHTNESS_HIGH or BRIGHTNESS_MID)
      elseif click then
        g:led(i,tracks[1][page].pitches[i],i==math.ceil(tracks[1][page].position / 6) and BRIGHTNESS_HIGH or BRIGHTNESS_LOW)
      else
        g:led(i,1,i==math.ceil(tracks[1][page].position / 6) and BRIGHTNESS_LOW or 0)
      end
    elseif subpage == "triggers" then
      for j=1,6 do -- 24ppqn = 6 ticks per 16th note
        if tracks[1][page].triggers[((i-1) * 6) + j] then
          g:led(i,8-j,j==(tracks[1][page].position - ((i-1) * 6)) and BRIGHTNESS_HIGH or BRIGHTNESS_MID)
        else
          g:led(i,8-j,j==(tracks[1][page].position - ((i-1) * 6)) and 3 or 0)
        end
      end
    end
  end
  -- Draw global controls
  for k, v in pairs(pages) do
    if k == page then
      g:led(pages[k],8,11)
    else
      g:led(pages[k],8,4)
    end
  end
  g:refresh()
end
