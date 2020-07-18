-- Crowseq
--
-- PAGE1 = controls pitch
-- PAGE2 = controls triggers
-- PAGE3 = controls pitch offset
-- PAGE4 = controls octave
-- ENC1 = BPM
-- ENC2 = division
-- ENC3 = transpose
-- KEY2 = reset/stop
-- KEY3 = play/pause

-- TODO Add per track divisor/clock sync to allow tracks to move at different speeds (one very slow one very fast for example)
-- TODO Separate triggers from pitches/give them their own position and loop start/end points
--      If/when doing so remove the trigger page specific mid brightness handling based on the pitch page
-- TODO Add chance
-- TODO Add morph
-- TODO Add randomize
-- TODO Add some form of rythmic variation similar to offsets for pitches
-- TODO Add Euclidean sequencer, horizontal, 16 steps. ENC2 increases enabled steps, ENC3 rotates, track+start&end sets length and loop start&end

local musicutil = require "musicutil"
local TU = require "tabutil"
local UI = require "ui"

local running = false
local scale = nil
local divisor = 4
local grid_buttons_pressed = {}
local pages = {
  pitch = {
    index = 1,
    subpage = false,
    type = "steps",
    loop = true
  },
  triggers = {
    index = 2,
    subpage = true,
    type = "ticks",
    loop = false
  },
  offset = {
    index = 3,
    subpage = false,
    type = "steps",
    loop = true
  },
  octave = {
    index = 4,
    subpage = false,
    type = "steps",
    loop = true
  },
}
local index_to_pages = {"pitch", "triggers", "offset", "octave"}
local page = "pitch"
local track = 1

-- Tracks
local tracks = {}
for i = 1,4 do
  tracks[i] = {}
  tracks[i].pitch = {}
  tracks[i].pitch.pitches = {}
  tracks[i].pitch.position = 1
  tracks[i].pitch.loop_start = 1 -- or start_point and end_point?
  tracks[i].pitch.loop_end = 96
  tracks[i].pitch.new_loop_set = false
  tracks[i].triggers = {}
  tracks[i].offset = {}
  tracks[i].offset.pitches = {}
  tracks[i].offset.position = 1
  tracks[i].offset.loop_start = 1
  tracks[i].offset.loop_end = 96
  tracks[i].offset.new_loop_set = false
  tracks[i].octave = {}
  tracks[i].octave.octaves = {}
  tracks[i].octave.position = 1
  tracks[i].octave.loop_start = 1
  tracks[i].octave.loop_end = 96
  tracks[i].octave.new_loop_set = false
  tracks[i].controls = {pitch = false, triggers = false, offset = false, octave = false}
end

local task_id = nil
local playback_icon = UI.PlaybackIcon.new(121, 55)
playback_icon.status = 4


function build_scale()
  -- Need 14 notes because we have to cover the range of 7 pitches + 7 offsets
  scale = musicutil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 14)
  -- TU.print(scale)
end

function has_trigger(step)
  -- Check if there is a trigger enabled on any of the ticks of the given step
  -- Returns true for tick if any tick has a trigger enabled
  -- Returns true for step if the trigger for the first tick of a step is enabled
  local tick_trigger = false
  local step_trigger = false
  for i=1,6 do
    if tracks[track].triggers[((step - 1) * 6) + i] then
      if i == 1 then
        step_trigger = true
      end
      tick_trigger = true
    end
  end
  return step_trigger, tick_trigger
end

function tick_to_step(tick)
  -- Calculate the step for a given tick
  return math.ceil(tick / 6)
end

function step_to_tick(step)
  -- Calculate the tick for a given step
  return (step * 6) - 5
end

function get_offset_from_key(key_y)
  -- We're centered around row 4
  return 4 - key_y
end

function get_key_from_offset(offset)
  -- We're centered around row 4
  return 4 - offset
end

function init()
  local scale_names = {}
  for i = 1, #musicutil.SCALES do
    table.insert(scale_names, string.lower(musicutil.SCALES[i].name))
  end

  -- Add parameters
  params:add({type = "option", id = "scale_mode", name = "scale mode",
    options = scale_names, default = 1,
    action = function() build_scale() end})
  params:add({type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = 60, formatter = function(param) return musicutil.note_num_to_name(param:get(), true) end,
    action = function() build_scale() end})
  params:default()

  for i = 1,#tracks do
    for j = 1,16 do
      table.insert(tracks[i].pitch.pitches, 7)
      table.insert(tracks[i].offset.pitches, 0)
      table.insert(tracks[i].octave.octaves, 0)
    end
    for j = 1,96 do
      if j % 6 == 1 then
        table.insert(tracks[i].triggers, true)
      else
        table.insert(tracks[i].triggers, false)
      end
    end
    -- TU.print(tracks[i].triggers)
    -- print(tracks[i].triggers[1])
    crow.output[i].action = "pulse(0.01, 8, 1)"
  end
  grid_redraw()

  local task_id = clock.run(tick)

  -- Screen refresh
  clock.run(function()
    while true do
      clock.sleep(1/30)
      redraw()
    end
  end)

  -- Grid refresh
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
        for i = 1,#tracks do
          -- print(tracks[track].pitch.position)
          -- print(tracks[track].triggers[tracks[track].pitch.position])
          if tracks[i].triggers[tracks[i].pitch.position] then
            local note_num = 8 - tracks[i].pitch.pitches[tick_to_step(tracks[i].pitch.position)]
            if tracks[i].offset.pitches[tick_to_step(tracks[i].offset.position)] ~= 0 then
              note_num = note_num + (8 - tracks[i].offset.pitches[tick_to_step(tracks[i].offset.position)])
            end
            -- Subtract 36 (=3V/octaves) from the note_num so C3/note 60 ends up at 2V
            -- This is to allow transposing octaves up as well as down for modules that only take positive voltage as pitch input
            crow.ii.crow.output(i, ((scale[note_num] - 36)/12 + tracks[i].octave.octaves[tick_to_step(tracks[i].octave.position)]))
            crow.output[i].execute()
          end

          -- Increment tracks[i].pitch.position. Wrap tracks[track].pitch.loop_start in case the current tracks[track].pitch.position is at tracks[track].pitch.loop_end
          tracks[i].pitch.position = math.max((tracks[i].pitch.position % tracks[i].pitch.loop_end) + 1, tracks[i].pitch.loop_start)
          tracks[i].offset.position = math.max((tracks[i].offset.position % tracks[i].offset.loop_end) + 1, tracks[i].offset.loop_start)
          tracks[i].octave.position = math.max((tracks[i].octave.position % tracks[i].octave.loop_end) + 1, tracks[i].octave.loop_start)
        end
      end
    -- end
  end
end

function key(n,z)
  if n == 2 and z == 1 then
    -- Reset to start
    tracks[track].pitch.position = 1
    tracks[track].offset.position = 1
    tracks[track].octave.position = 1
    if not running then
      playback_icon.status = 4
    end
  elseif n == 3 and z == 1 then
    -- Play/pause
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
  elseif n == 3 then
    -- Transpose
    -- This is wrong/upside down. Not sure what the best way to "flip" the grid is
    -- TU.print(tracks[track].octave.octaves)
    for step, pitch in pairs(tracks[track].pitch.pitches) do
      local new_pitch = pitch - d
      if new_pitch < 1 then
        tracks[track].pitch.pitches[step] = 7
        tracks[track].octave.octaves[step] = util.clamp(tracks[track].octave.octaves[step] + 1, -3, 3)
      elseif new_pitch > 7 then
        tracks[track].pitch.pitches[step] = 1
        tracks[track].octave.octaves[step] = util.clamp(tracks[track].octave.octaves[step] - 1, -3, 3)
      else
        tracks[track].pitch.pitches[step] = new_pitch
      end
      -- print(step, pitch, new_pitch, tracks[track].octave.octaves[step])
      -- TU.print(tracks[track].octave.octaves)
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
  screen.move(0, 22)
  screen.text("track: "..track)
  screen.move(0, 30)
  screen.text("page: "..page)
  playback_icon:redraw()
  screen.update()
end

g = grid.connect()

g.key = function(x,y,z)
  if y == 8 then
    -- Global controls
    if z == 1 then -- Key pressed
      track = math.ceil(x/4)
      page = index_to_pages[x - ((track -1) * 4)]
      tracks[track].controls[page] = true
    elseif z == 0 then -- Key released
      tracks[track].controls[page] = false
    end
  else
    -- Page controls
    if z == 1 then -- key pressed
      if tracks[track].controls[page] and pages[page]["loop"] then
        -- Set loop start and end points when page button is pressed
        table.insert(grid_buttons_pressed, x)
        if #grid_buttons_pressed == 2 then
          -- When 2 buttons are pressed immediately set loop start and end point
          tracks[track][page].loop_start = step_to_tick(math.min(grid_buttons_pressed[1], grid_buttons_pressed[2]))
          tracks[track][page].loop_end = step_to_tick(math.max(grid_buttons_pressed[1], grid_buttons_pressed[2])) + 5
          tracks[track][page].new_loop_set = true
        end
      else
        -- Page button isn't pressed, set page specific properties (pitches, triggers, etc)
        if page == "pitch" then
          local step_trigger, tick_trigger = has_trigger(x)
          local tick_position = step_to_tick(x)
          if tick_trigger then
            -- Step with one or more triggers enabled
            if tracks[track][page].pitches[x] == y then
              -- Existing pitch pressed, turn off all triggers for this step
              for i=tick_position,(tick_position + 5) do
                tracks[track].triggers[i] = false
              end
            else
              -- New pitch pressed, only change pitch, keep triggers as is
              tracks[track][page].pitches[x] = y
            end
          else
            -- Step with no triggers pressed, set pitch and enable trigger on tick 1 of the step
            tracks[track][page].pitches[x] = y
            tracks[track].triggers[tick_position] = true
          end
        elseif page == "triggers" then
          -- Only trigger on row 2-7 because we only have 6 triggers per step
          if y ~= 1 then
            local position = ((x - 1) * 6) + (8 - y)
            if tracks[track].triggers[position] then
              -- Existing trigger pressed, turn off
              tracks[track].triggers[position] = false
            else
              -- New trigger pressed
              tracks[track].triggers[position] = true
            end
          end
        elseif page == "offset" then
          if tracks[track][page].pitches[x] == y then
            -- Existing offset pressed, turn off
            tracks[track][page].pitches[x] = 0
          else
            -- New offset pressed, set it
            tracks[track][page].pitches[x] = y
          end
        elseif page == "octave" then
          tracks[track][page].octaves[x] = get_offset_from_key(y)
        end
      end
      -- TU.print(tracks[track][page])
    elseif z == 0 then -- key released
      if #grid_buttons_pressed == 1 then -- If there's still a single page key pressed
        if not tracks[track][page].new_loop_set then -- Check if new loop start and end points have been set
          -- If not, we've got a single keypress whilst the page button was pressed so create a single step loop
          tracks[track][page].loop_start = step_to_tick(grid_buttons_pressed[1])
          tracks[track][page].loop_end = step_to_tick(grid_buttons_pressed[1]) + 5
        else
          -- New loop start and end points have been set before, since we've just released the remaining single button
          -- we can now set our "dirty" flag to false again
          tracks[track][page].new_loop_set = false
        end
      end
      table.remove(grid_buttons_pressed, TU.key(grid_buttons_pressed, x))
    end
  end
end

function grid_redraw()
  local BRIGHTNESS_LOW = 4
  local BRIGHTNESS_MID = 8
  local BRIGHTNESS_HIGH = 11
  g:all(0)
  -- Draw pages
  for i=1,16 do
    BRIGHTNESS_MID = 8
    if pages[page]["loop"] then
      if i < tick_to_step(tracks[track][page].loop_start) or i > tick_to_step(tracks[track][page].loop_end) then
        BRIGHTNESS_MID = 4
      end
    end
    if page == "pitch" then
      -- Check if there is/are trigger(s) enabled for this step
      local step_trigger, tick_trigger = has_trigger(i)
      -- Set brightness. If this step is currently playing it's high, if not and this step's trigger is enabled it's mid
      -- if not but any other trigger for this step is enabled it's low
      -- and if there is no trigger enabled for this step at all it's off but we show a moving cursor at the top row
      if step_trigger then
        g:led(i, tracks[track][page].pitches[i], i==tick_to_step(tracks[track][page].position) and BRIGHTNESS_HIGH or BRIGHTNESS_MID)
      elseif tick_trigger then
        g:led(i, tracks[track][page].pitches[i], i==tick_to_step(tracks[track][page].position) and BRIGHTNESS_HIGH or BRIGHTNESS_LOW)
      else
        g:led(i,1,i==tick_to_step(tracks[track][page].position) and BRIGHTNESS_LOW or 0)
      end
    elseif page == "triggers" then
      if i < tick_to_step(tracks[track]["pitch"].loop_start) or i > tick_to_step(tracks[track]["pitch"].loop_end) then
        BRIGHTNESS_MID = 4
      end
      for j=1,6 do -- 24ppqn = 6 ticks per 16th note
        if tracks[track][page][((i-1) * 6) + j] then
          g:led(i,8-j,j==(tracks[track].pitch.position - ((i-1) * 6)) and BRIGHTNESS_HIGH or BRIGHTNESS_MID)
        else
          g:led(i,8-j,j==(tracks[track].pitch.position - ((i-1) * 6)) and 3 or 0)
        end
      end
    elseif page == "offset" then
      -- Set brightness. If this step has an offset and is currently playing it's high, if not and this step has an offset it's mid
      -- if there is no offset enabled for this step it's off but we show a moving cursor at the top row
      if tracks[track][page].pitches[i] ~= 0 then
        g:led(i, tracks[track][page].pitches[i], i==tick_to_step(tracks[track][page].position) and BRIGHTNESS_HIGH or BRIGHTNESS_MID)
      else
        g:led(i,1,i==tick_to_step(tracks[track][page].position) and BRIGHTNESS_LOW or 0)
      end
    elseif page == "octave" then
      -- Show per step octave
      -- Octave is centered around the 4th row from the top, positive upward and negative downward
      local key_y = get_key_from_offset(tracks[track][page].octaves[i])
      if key_y ~= 4 then
        g:led(i, 4, BRIGHTNESS_LOW)
      end
      g:led(i, key_y, i==tick_to_step(tracks[track].octave.position) and BRIGHTNESS_HIGH or BRIGHTNESS_MID)
    end
  end

  -- Draw global controls
  for i = 1,#tracks do
    for k, v in pairs(pages) do
      if i == track and k == page then
        g:led(((i - 1) * 4) + pages[k]["index"], 8, BRIGHTNESS_HIGH)
      else
        g:led(((i - 1) * 4) + pages[k]["index"], 8, k=="pitch" and BRIGHTNESS_MID or BRIGHTNESS_LOW)
      end
    end
  end
  g:refresh()
end
