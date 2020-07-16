-- Crowseq help
--
-- KEY2 = previous page
-- KEY3 = next page

local left_offset = 66
local page = 1


function draw_button(x, y)
  x = left_offset + ((x-1) * 4)
  y = 16 + ((y-1) * 4)
  screen.rect(x, y, 2, 2)
end

function draw_zoomed_button(x, y)
  x = left_offset + 4 + ((x-1) * 16)
  y = 24 + ((y-1) * 16)
  screen.rect(x, y, 8, 8)
end


overview = function()
  local top_offset = 0
  screen.clear()
  screen.level(4)
  screen.move(0, top_offset + 5)
  screen.text("The grid is")
  screen.move(0, top_offset + 13)
  screen.text("separated into")
  screen.move(0, top_offset + 21)
  screen.text("two sections:")
  screen.move(0, top_offset + 29)
  screen.text("row 2-8:")
  screen.move(0, top_offset + 37)
  screen.text("track/page")
  screen.move(0, top_offset + 45)
  screen.text("controls")
  screen.move(0, top_offset + 53)
  screen.text("row 1: global")
  screen.move(0, top_offset + 61)
  screen.text("controls")

  screen.level(2)
  screen.move(left_offset + 30, 5)
  screen.text_center("track/page")
  screen.move(left_offset + 30, 13)
  screen.text_center("controls")

  for i=1,16 do
    for j=1,8 do
      draw_button(i, j)
    end
  end
  screen.fill()

  screen.level(12)
  for i=1,16 do
    draw_button(i,8)
  end
  screen.fill()

  screen.move(left_offset + 30, 54)
  screen.text_center("global controls")
end

tracks = function()
  local top_offset = 0
  screen.clear()
  screen.level(4)
  screen.move(0, top_offset + 5)
  screen.text("The global")
  screen.move(0, top_offset + 13)
  screen.text("controls are")
  screen.move(0, top_offset + 21)
  screen.text("always visible.")
  screen.move(0, top_offset + 29)
  screen.text("They are")
  screen.move(0, top_offset + 37)
  screen.text("separated into")
  screen.move(0, top_offset + 45)
  screen.text("four tracks")

  screen.level(1)
  for i=1,16 do
    for j=1,8 do
      draw_button(i, j)
    end
  end
  screen.fill()

  for i=1,4 do
    if i % 2 == 0 then
      screen.level(4)
    else
      screen.level(16)
    end
    for j=(i*4 - 3), i*4 do
      draw_button(j,8)
    end
    screen.fill()
    screen.move(left_offset + 7 + 16 * (i -1), 54)
    screen.text_center("t"..i)
  end
end

track_pages = function()
  local top_offset = 0
  screen.clear()
  screen.level(4)
  screen.move(0, top_offset + 5)
  screen.text("Each track has")
  screen.move(0, top_offset + 13)
  screen.text("four pages")
  screen.move(0, top_offset + 29)
  screen.text("pi: pitches")
  screen.move(0, top_offset + 37)
  screen.text("tr: triggers")
  screen.move(0, top_offset + 45)
  screen.text("of: offsets")
  screen.move(0, top_offset + 53)
  screen.text("oc: octaves")

  screen.level(16)
  for i=1,4 do
    draw_zoomed_button(i, 1)
  end
  screen.fill()
  screen.move(left_offset + 5, 40)
  screen.text("pi")
  screen.move(left_offset + 20, 40)
  screen.text("tr")
  screen.move(left_offset + 36, 40)
  screen.text("of")
  screen.move(left_offset + 52, 40)
  screen.text("oc")
end

local pages = {
  overview,
  tracks,
  track_pages
}

function key(n,z)
  if n == 2 and z == 1 then
    -- Previous page
    page = math.max(page - 1, 1)
  elseif n == 3 and z == 1 then
    -- Next page
    page = math.min(page + 1, #pages)
  end
  redraw()
end

function redraw()
  pages[page]()
  screen.update()
end
