local utils = require("tick.utils")
local M = {}

M.timer_start = nil
M.current_task = "default"

function M.is_timer_running()
  return M.timer_start ~= nil
end

function M.start_timer()
  local projects = require("tick.projects")
  local current_project = projects.get_current_project()
  
  if not current_project then
    vim.notify("No active project. Create or switch to a project first.", vim.log.levels.ERROR)
    return
  end
  
  if M.is_timer_running() then
    vim.notify("Timer already running for task: " .. M.current_task, vim.log.levels.WARN)
    return
  end
  
  M.timer_start = os.time()
  
  if not current_project.tasks[M.current_task] then
    current_project.tasks[M.current_task] = {
      total_time = 0,
      sessions = {}
    }
  end
  
  vim.api.nvim_echo({{"", ""}}, false, {})
  vim.cmd("redraw")
  
  vim.notify("Started timer for task: " .. M.current_task, vim.log.levels.INFO)
  
  utils.update_statusline()
end


function M.stop_timer()
  local projects = require("tick.projects")
  local current_project = projects.get_current_project()
  
  if not current_project then
    vim.notify("No active project", vim.log.levels.ERROR)
    return
  end
  
  if not M.is_timer_running() then
    vim.notify("No timer running", vim.log.levels.WARN)
    return
  end
  
  local end_time = os.time()
  local elapsed = end_time - M.timer_start
  
  table.insert(current_project.tasks[M.current_task].sessions, {
    start_time = M.timer_start,
    end_time = end_time,
    duration = elapsed
  })
  
  current_project.tasks[M.current_task].total_time = 
    current_project.tasks[M.current_task].total_time + elapsed
  
  current_project.total_time = current_project.total_time + elapsed
  
  local formatted_time = utils.format_time(elapsed)
  
  vim.api.nvim_echo({{"", ""}}, false, {})
  vim.cmd("redraw")
  
  vim.notify(
    "Stopped timer for task: " .. M.current_task .. 
    "\nTime spent: " .. formatted_time,
    vim.log.levels.INFO
  )
  
  M.timer_start = nil
  
  projects.save()
  
  utils.update_statusline()
end

function M.set_current_task(task_name)
  if not task_name or task_name == "" then
    vim.notify("Task name cannot be empty", vim.log.levels.ERROR)
    return
  end
  
  local projects = require("tick.projects")
  if not projects.get_current_project() then
    vim.notify("No active project. Create or switch to a project first.", vim.log.levels.ERROR)
    return
  end
  
  if M.is_timer_running() then
    M.stop_timer()
  end
  
  M.current_task = task_name
  
  vim.api.nvim_echo({{"", ""}}, false, {})
  vim.cmd("redraw")
  
  vim.notify("Set current task: " .. task_name, vim.log.levels.INFO)
  
  utils.update_statusline()
end

function M.get_task_history()
  local projects = require("tick.projects")
  local current_project = projects.get_current_project()
  
  if not current_project then
    return {}
  end
  
  local history = {}
  for task_name, task_data in pairs(current_project.tasks) do
    for _, session in ipairs(task_data.sessions) do
      table.insert(history, {
        task = task_name,
        start_time = session.start_time,
        end_time = session.end_time,
        duration = session.duration
      })
    end
  end
  
  table.sort(history, function(a, b)
    return a.start_time > b.start_time
  end)
  
  return history
end

return M
