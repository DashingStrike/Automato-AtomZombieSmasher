--
-- Repeatedly click a single location, avoid shift-click, stop if pixel changes
--

dofile("common.inc");

askText = singleLine([[
  Choose window
]]);

function findImage(img)
  local tol = 5000;
  if img == "2.select" then
    tol = 10000;
  end
  return srFindImage(img .. ".png", tol);
end

function findAndClick(img, step)
  local pos = findImage(img);
  if (not pos) then
    return false;
  else
    local offset = step.offset;
    if not offset then
      offset = { 5, 2 };
    end
    srClickMouse(pos[0]+offset[1], pos[1]+offset[2], false, 50, 100, 50);
    return true;
  end
end

function moveMouse()
  local pos = srGetWindowSize();
  srSetMousePos(pos[0] / 2 + math.random(-50, 50), pos[1] / 2 + math.random(-50, 50));
end

local auto = false;
local back_pos;

function doStep(name, step)
  local ret = true;
  local count = 1;
  while findImage("quit") or findImage("back") do
    if not back_pos then
      back_pos = findImage("back");
    end
    if back_pos then
      srClickMouse(back_pos[0], back_pos[1], false, 50, 100, 50);
      moveMouse();
      sleepWithStatus(500, "Dismissed back button (" .. count .. ")", 0xFFFFFFff, true);
    else
      sleepWithStatus(500, "Saw quit, but not back (" .. count .. ")", 0xFFFFFFff, true);
    end
    count = count + 1;
    srReadScreen();
  end
  if step.click then
    local pos = srGetWindowSize();
    pos[0] = pos[0] * step.click[1];
    pos[1] = pos[1] * step.click[2];
    srClickMouse(pos[0], pos[1], false, 50, 100, 50);
    return true;
  end
  if step.sleep then
    sleepWithStatus(step.sleep, name .. ": Sleeping...", 0xFFFFFFff);
    ret = true;
  end
  if step.find_to_click then
    ret = findAndClick(step.find_to_click, step);
    if ret then
      moveMouse();
    end
  end
  return ret;
end

local prev_step = false;
local cur_step = false;
local jump_to_step = false;
local last_name = false;

function step(name, step)
  local key;
  if last_name then
    key = last_name .. name;
    if cur_step then
      prev_step = cur_step;
    end
    cur_step = key;
  end
  last_name = name;
  if jump_to_step then
    if key == jump_to_step then
      -- good!
      jump_to_step = false;
    else
      -- continue;
      sleepWithStatus(1, "Seeking step " .. jump_to_step .. ", cur=" .. key, 0xFFFFFFff, true);
      return;
    end
  end
  local step_failed = false;
  local did_step = false;
  local start_time = lsGetTimer();
  while 1 do
    srReadScreen();
    lsShowScreengrab(0x808080ff);
    y = 100;
    lsPrint(10, y, 1, 1, 1, 0xFFFFFFff, "Current step = " .. name);
    y = y + 32;
    if prev_step then
      --lsPrint(10, y, 1, 1, 1, 0xFFFFFFff, "Prev step = " .. prev_step);
      --y = y + 32;
    end
    if auto then
      if lsButtonText(10, y, 1, 150, 0xFFFFFFff, "Disable auto") then
        auto = false;
      end
      y = y + 32;
    end
    if auto and not did_step then
      y = y + 32;
      if doStep(name, step) then
        did_step = lsGetTimer();
      else
        step_failed = true;
        if step.skip_if_no then
          if findImage(step.skip_if_no) then
            start_time = lsGetTimer();
          else
            if lsGetTimer() - start_time > step.timeout then
              sleepWithStatus(10, "Skipping...", 0xFFFFFFff, true);
              return;
            end
          end
        end
      end
    end

    if not auto then
      if lsButtonText(10, y, 1, 150, 0xFFFFFFff, "Enable auto") then
        auto = true;
      end
      y = y + 32;
      if lsButtonText(10, y, 1, 200, 0xFFFFFFff, "Do step (alt+ctrl)") or (lsAltHeld() and lsControlHeld()) then
        while lsAltHeld() or lsControlHeld() do
          sleepWithStatus(100, "Release Ctrl and Alt")
        end
        if doStep(name, step) then
          did_step = lsGetTimer();
        else
          step_failed = true;
        end
      end
      y = y + 32;
    end
    if lsButtonText(10, y, 1, 150, 0xFFFFFFff, "Next step") then
      sleepWithStatus(10, "Skipping...", 0xFFFFFFff, true);
      return;
    end
    y = y + 32;
    if prev_step then
      if lsButtonText(10, y, 1, 150, 0xFFFFFFff, "Prev step") then
        jump_to_step = prev_step;
        sleepWithStatus(10, "Skipping...", 0xFFFFFFff, true);
        return;
      end
    end
    y = y + 32;
    y = y + 32;
    if step_failed then
      lsPrint(10, y, 1, 1, 1, 0xFF7777ff, "Step failed");
    end
    y = y + 32;

    message = "";
    if did_step then
      if step.done then
        -- check done condition
        local is_done = false;
        if step.inv_done then
          is_done = true;
          if findImage(step.done) then
            is_done = false;
          end
        else
          if findImage(step.done) then
            is_done = true;
          end
        end

        if is_done then
          sleepWithStatus(100, "Step complete (found image)", 0xFFFFFFff, true);
          return;
        else
          message = "Could not find done image ";
          -- timeout
          local timeout = 15000;
          if step.timeout then
            timeout = step.timeout;
          end
          if lsGetTimer() - did_step > timeout then
            did_step = false;
            message = "Timed out";
            if step.skip_if_no then
              if not findImage(step.skip_if_no) then
                sleepWithStatus(10, "Skipping...", 0xFFFFFFff, true);
                return;
              end
            end
          end
        end
      else
        sleepWithStatus(100, "Step complete", 0xFFFFFFff, true);
        return;
      end
    end

    sleepWithStatus(10, message, 0xFFFFFFff, true);
  end
end

function doit()
  local mousePos = askForWindow(askText);
  local index = 1;

  while 1 do
    step("continue", { find_to_click = "1.continue", done = "1.continue", inv_done = true });
    step("sleep", { sleep = 2000 });
    step("select zone", { find_to_click = "2.select", done = "4.done", offset = { 5, 10 }, timeout = 4000 });
    step("click heli", { find_to_click = "3.heli", done = "heli-done", timeout = 2000, skip_if_no = "3.heli" });
    step("place heli", { click = { 0.5; 0.5 }, done = "3.heli", timeout = 2000, skip_if_no = "heli-done"});
    step("done placing troops", { find_to_click = "4.done", done = "4.done", inv_done = true });
    step("win map", { sleep = 1000, done = "1.continue" });
    step("move mouse", { click = { 0.5; 0.5 }});
    step("continue", { find_to_click = "1.continue" });
    step("wait for XP", { sleep = 1000, done = "left" });
    step("dismiss victory", { click = { 0.5; 0.5 }, done = "ok"});
    step("click ok", { find_to_click = "ok", done = "ok", inv_done = true });
    step("wait for victory points", { sleep = 2000, done = "left" });
    step("dismiss victory", { click = { 0.5; 0.5 }});
  end
end
