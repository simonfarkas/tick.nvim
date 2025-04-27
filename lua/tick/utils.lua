local M = {}

function M.format_time(seconds)
  if not seconds or seconds <= 0 then
    return "0:00:00"
  end
  
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = seconds % 60
  
  return string.format("%d:%02d:%02d", hours, minutes, secs)
end

function M.read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  
  local content = file:read("*all")
  file:close()
  
  return content
end

function M.write_file(path, content)
  local file = io.open(path, "w")
  if not file then
    vim.notify("Failed to write to file: " .. path, vim.log.levels.ERROR)
    return false
  end
  
  file:write(content)
  file:close()
  
  return true
end

function M.update_statusline()
  local projects = require("tick.projects")
  local tasks = require("tick.tasks")
  
  local current_project = projects.get_current_project()
  if not current_project then
    vim.g.tick_status = nil
    return
  end
  
  local status = projects.current_project
  
  if tasks.current_task then
    status = status .. " | " .. tasks.current_task
  end
  
  if tasks.is_timer_running() then
    local elapsed = os.time() - tasks.timer_start
    status = status .. " | " .. M.format_time(elapsed) .. " ⏱️"
  end
  
  vim.g.tick_status = status
end

function M.get_current_elapsed()
  local tasks = require("tick.tasks")
  
  if tasks.is_timer_running() then
    return os.time() - tasks.timer_start
  end
  
  return 0
end

function M.setup_autosave()
  local config = require("tick").config
  
  if config.save_on_exit then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        local tasks = require("tick.tasks")
        
        if tasks.is_timer_running() then
          tasks.stop_timer()
        end
      end
    })
  end
end

function M.setup_statusline()
  return function()
    return vim.g.tick_status or ""
  end
end

return M
