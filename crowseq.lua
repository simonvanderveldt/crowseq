-- Crowseq
--
-- PAGE1 = controls pitch
-- PAGE2 = controls triggers
-- PAGE3 = controls pitch offset
-- PAGE4 = controls transpose
-- ENC1 = BPM
-- ENC2 = division
-- ENC3 = transpose
-- KEY2 = reset/stop
-- KEY3 = play/pause

-- TODO Make scale configurable
-- TODO Add per track divisor/clock sync to allow tracks to move at different speeds (one very slow one very fast for example)
-- TODO Questions about transpose feature/page
--      Does this somehow depend on the scale/mode? We can only show 7 pitches per page, so transpose would be transpose by one page height (i.e. 7 pitches)?
--      What about "normal"/per octave transpose? Is the fact that tranposing a full page is exactly an octave just a coincidence? Because of the chosen scale (scale = music.generate_scale_of_length(8, "major", 14))?
--      Should it simply be called octave and always just transpose by a full octave like on Ansible/Kria?
--      Should it be loopable like pitch and offset?
-- TODO Separate triggers from pitches? I.e. give them their own position
--      Not entirely sure how to make sure they can stay in sync
-- TODO How to blink grid key when looping single key/position?
-- TODO Use absolute value per step or grid based value (1-8) together with separate transpose function/table?
-- TODO Add morph
-- TODO Add randomize
-- TODO Add some form of rythmic variation similar to offsets for pitches
-- TODO Add Euclidean sequencer, horizontal, 16 steps. ENC2 increases enabled steps, ENC3 rotates, track+start&end sets length and loop start&end

local music = require "musicutil"
local TU = require "tabutil"
local UI = require "ui"

local running = false
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
  transpose = {
    index = 4,
    subpage = false,
    type = "steps",
    loop = false
  },
}
local index_to_pages = {"pitch", "triggers", "offset", "transpose"}
local page = "pitch"
local track = 1

-- Tracks
tracks = {}
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
  tracks[i].transpose = {}
  tracks[i].controls = {pitch = false, triggers = false, offset = false, transpose = false}
end

-- Need 14 notes because we have to cover the range of 7 pitch + 7 offset
scale = music.generate_scale_of_length(36, "major", 14)
-- TU.print(scale)

local task_id = nil
local playback_icon = UI.PlaybackIcon.new(121, 55)


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
  for i = 1,#tracks do
    for j = 1,16 do
      -- table.insert(tracks[track].pitch.pitches, math.random(7))
      table.insert(tracks[i].pitch.pitches, 7)
      table.insert(tracks[i].offset.pitches, 0)
      table.insert(tracks[i].transpose, 0)
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
        for i = 1,#tracks do
          -- print(tracks[track].pitch.position)
          -- print(tracks[track].triggers[tracks[track].pitch.position])
          if tracks[i].triggers[tracks[i].pitch.position] then
            local note_num = 8 - tracks[i].pitch.pitches[tick_to_step(tracks[i].pitch.position)]
            if tracks[i].offset.pitches[tick_to_step(tracks[i].offset.position)] ~= 0 then
              note_num = note_num + (8 - tracks[i].offset.pitches[tick_to_step(tracks[i].offset.position)])
            end
            crow.ii.crow.output(i, (scale[note_num]/12 + tracks[i].transpose[tick_to_step(tracks[i].pitch.position)]))
            crow.output[i].execute()
          end

          -- Increment tracks[i].pitch.position. Wrap tracks[track].pitch.loop_start in case the current tracks[track].pitch.position is at tracks[track].pitch.loop_end
          tracks[i].pitch.position = math.max((tracks[i].pitch.position % tracks[i].pitch.loop_end) + 1, tracks[i].pitch.loop_start)
          tracks[i].offset.position = math.max((tracks[i].offset.position % tracks[i].offset.loop_end) + 1, tracks[i].offset.loop_start)
        end
      end
    -- end
  end
end

function key(n,z)
  if n == 2 and z == 1 then
      tracks[track].pitch.position = 1
      tracks[track].offset.position = 1
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
  elseif n == 3 then
    -- Transpose
    -- This is wrong/upside down. Not sure what the best way to "flip" the grid is
    -- TU.print(tracks[track].transpose)
    for step, pitch in pairs(tracks[track].pitch.pitches) do
      local new_pitch = pitch - d
      if new_pitch < 1 then
        tracks[track].pitch.pitches[step] = 7
        tracks[track].transpose[step] = util.clamp(tracks[track].transpose[step] + 1, -3, 3)
      elseif new_pitch > 7 then
        tracks[track].pitch.pitches[step] = 1
        tracks[track].transpose[step] = util.clamp(tracks[track].transpose[step] - 1, -3, 3)
      else
        tracks[track].pitch.pitches[step] = new_pitch
      end
      -- print(step, pitch, new_pitch, tracks[track].transpose[step])
      -- TU.print(tracks[track].transpose)
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

-- Should this be so randomly here? Shouldn't this be in init? Or at the top of the script? Why is it here in this place?
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
            position = ((x - 1) * 6) + (8 - y)
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
        elseif page == "transpose" then
          tracks[track][page][x] = get_offset_from_key(y)
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
    elseif page == "transpose" then
      -- Show per step transpose
      -- Transpose is centered around the 4th row from the top, positive upward and negative downward
      local key_y = get_key_from_offset(tracks[track][page][i])
      if key_y ~= 4 then
        g:led(i, 4, BRIGHTNESS_LOW)
      end
      g:led(i, key_y, i==tick_to_step(tracks[track].pitch.position) and BRIGHTNESS_HIGH or BRIGHTNESS_MID)
    end
  end
  -- Draw global controls

  for i = 1,#tracks do
    for k, v in pairs(pages) do
      if i == track and k == page then
        g:led(((i - 1) * 4) + pages[k]["index"], 8, BRIGHTNESS_HIGH)
      else
        g:led(((i - 1) * 4) + pages[k]["index"], 8, BRIGHTNESS_LOW)
      end
    end
  end
  g:refresh()
end
