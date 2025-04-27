local utils = require("tick.utils")
local M = {}

M.buf = nil
M.win = nil

function M.create_float_win()
  local config = require("tick").config
  local width = config.ui.width
  local height = config.ui.height
  
  local ui_width = vim.api.nvim_get_option("columns")
  local ui_height = vim.api.nvim_get_option("lines")
  
  local col = math.floor((ui_width - width) / 2)
  local row = math.floor((ui_height - height) / 2)
  
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    M.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(M.buf, "bufhidden", "wipe")
  end
  
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = config.ui.border,
  }
  
  M.win = vim.api.nvim_open_win(M.buf, true, opts)
  
  vim.api.nvim_win_set_option(M.win, "winblend", 0)
  vim.api.nvim_win_set_option(M.win, "cursorline", true)
  
  vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
  vim.api.nvim_buf_set_option(M.buf, "filetype", "tick")
  
  M.set_keymaps()
  
  return M.buf, M.win
end

function M.set_keymaps()
  local function set_keymap(mode, key, action)
    vim.api.nvim_buf_set_keymap(M.buf, mode, key, action, {
      noremap = true,
      silent = true,
      nowait = true
    })
  end
  
  set_keymap("n", "q", "<cmd>lua require('tick.ui').close_window()<CR>")
  set_keymap("n", "<Esc>", "<cmd>lua require('tick.ui').close_window()<CR>")
  set_keymap("n", "p", "<cmd>lua require('tick.ui').prompt_switch_project()<CR>")
  set_keymap("n", "n", "<cmd>lua require('tick.ui').prompt_new_project()<CR>")
  set_keymap("n", "t", "<cmd>lua require('tick.ui').prompt_set_task()<CR>")
  set_keymap("n", "r", "<cmd>lua require('tick.ui').prompt_set_rate()<CR>")
  set_keymap("n", "s", "<cmd>lua require('tick.tasks').start_timer()<CR>")
  set_keymap("n", "S", "<cmd>lua require('tick.tasks').stop_timer()<CR>")
  set_keymap("n", "h", "<cmd>lua require('tick.ui').show_history()<CR>")
  set_keymap("n", "b", "<cmd>lua require('tick.ui').show_billing()<CR>")
  set_keymap("n", "d", "<cmd>lua require('tick.ui').prompt_delete_project()<CR>")
  set_keymap("n", "T", "<cmd>lua require('tick.ui').show_time_report()<CR>")
  set_keymap("n", "a", "<cmd>lua require('tick.ui').prompt_archive_project()<CR>")
  set_keymap("n", "A", "<cmd>lua require('tick.ui').prompt_unarchive_project()<CR>")
  set_keymap("n", "e", "<cmd>lua require('tick.ui').prompt_set_description()<CR>")
  set_keymap("n", "+", "<cmd>lua require('tick.ui').prompt_add_tag()<CR>")
  set_keymap("n", "-", "<cmd>lua require('tick.ui').prompt_remove_tag()<CR>")
end

function M.close_window()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
    M.win = nil
  end
end

function M.render_dashboard()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end

  vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
  
  local projects = require("tick.projects")
  local tasks = require("tick.tasks")
  local billing = require("tick.billing")
  local utils = require("tick.utils")
  
  local lines = {}
  table.insert(lines, "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
  table.insert(lines, "┃                       TICK.NVIM                       ┃")
  table.insert(lines, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
  table.insert(lines, "")
  
  local current_project = projects.get_current_project()
  if not current_project then
    table.insert(lines, "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
    table.insert(lines, "┃                    NO ACTIVE PROJECT                   ┃")
    table.insert(lines, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
    table.insert(lines, "")
    table.insert(lines, "  Press 'n' to create a new project")
    table.insert(lines, "  Press 'p' to switch to an existing project")
    table.insert(lines, "")
  else
    table.insert(lines, "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
    table.insert(lines, "┃                    PROJECT DETAILS                     ┃")
    table.insert(lines, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
    table.insert(lines, "")
    table.insert(lines, "  Project: " .. projects.current_project)
    table.insert(lines, "  Created: " .. os.date("%Y-%m-%d", current_project.created_at))
    table.insert(lines, "  Total time: " .. utils.format_time(current_project.total_time))
    
    if current_project.billing_rate and current_project.billing_rate > 0 then
      local bill = billing.calculate_billing()
      table.insert(lines, string.format("  Billing rate: %s%.2f %s",
        billing.get_currency_symbol(bill.currency),
        bill.rate,
        bill.currency
      ))
      table.insert(lines, string.format("  Total amount: %s%.2f %s",
        billing.get_currency_symbol(bill.currency),
        bill.total,
        bill.currency
      ))
    else
      table.insert(lines, "  Billing rate: Not set")
      table.insert(lines, "  Total amount: Not set")
    end
    
    table.insert(lines, "")
    
    table.insert(lines, "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
    table.insert(lines, "┃                     CURRENT TASK                      ┃")
    table.insert(lines, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
    table.insert(lines, "")
    table.insert(lines, "  Task: " .. tasks.current_task)
    
    if tasks.is_timer_running() then
      local elapsed = os.time() - tasks.timer_start
      table.insert(lines, "  Timer: " .. utils.format_time(elapsed) .. " (running)")
    else
      table.insert(lines, "  Timer: Stopped")
    end
    
    table.insert(lines, "")
    
    table.insert(lines, "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
    table.insert(lines, "┃                    RECENT ACTIVITY                    ┃")
    table.insert(lines, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
    table.insert(lines, "")
    
    local history = tasks.get_task_history()
    if #history > 0 then
      for i = 1, math.min(3, #history) do
        local entry = history[i]
        local start_time = os.date("%Y-%m-%d %H:%M", entry.start_time)
        local end_time = os.date("%H:%M", entry.end_time)
        local duration = utils.format_time(entry.duration)
        
        table.insert(lines, string.format(
          "  %s - %s [%s] %s",
          start_time, end_time, duration, entry.task
        ))
      end
      if #history > 3 then
        table.insert(lines, "  ... (more entries available)")
      end
    else
      table.insert(lines, "  No recent activity")
    end
    
    table.insert(lines, "")
    
    table.insert(lines, "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
    table.insert(lines, "┃                    TASK BREAKDOWN                     ┃")
    table.insert(lines, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
    table.insert(lines, "")
    
    local task_count = 0
    for task_name, task_data in pairs(current_project.tasks) do
      local task_hours = task_data.total_time / 3600
      local task_amount = task_hours * (current_project.billing_rate or 0)
      
      if current_project.billing_rate and current_project.billing_rate > 0 then
        table.insert(lines, string.format(
          "  %s: %s (%.2f hrs, %s%.2f %s)",
          task_name,
          utils.format_time(task_data.total_time),
          task_hours,
          billing.get_currency_symbol(current_project.currency or "USD"),
          task_amount,
          current_project.currency or "USD"
        ))
      else
        table.insert(lines, string.format(
          "  %s: %s (%.2f hrs)",
          task_name,
          utils.format_time(task_data.total_time),
          task_hours
        ))
      end
      task_count = task_count + 1
    end
    
    if task_count == 0 then
      table.insert(lines, "  No tasks recorded yet")
    end
  end
  
  table.insert(lines, "")
  table.insert(lines, "┏━━━━━━━━━━━━━━━━━━━━━━ COMMANDS ━━━━━━━━━━━━━━━━━━━━━━━━━┓")
  table.insert(lines, "┃ n: New project   p: Switch project   t: Set task        ┃")
  table.insert(lines, "┃ r: Set rate      s: Start timer      S: Stop timer      ┃")
  table.insert(lines, "┃ h: History       b: Billing          d: Delete project  ┃")
  table.insert(lines, "┃ T: Time report   q/Esc: Close window                    ┃")
  table.insert(lines, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
  
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
end

function M.open_dashboard()
  M.create_float_win()
  M.render_dashboard()
end

function M.show_history()
  local tasks = require("tick.tasks")
  local history = tasks.get_task_history()
  
  M.create_float_win()
  
  local lines = {}
  table.insert(lines, "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
  table.insert(lines, "┃                     TASK HISTORY                      ┃")
  table.insert(lines, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
  table.insert(lines, "")
  
  if #history == 0 then
    table.insert(lines, "No task history found")
  else
    for i, entry in ipairs(history) do
      local start_time = os.date("%Y-%m-%d %H:%M", entry.start_time)
      local end_time = os.date("%H:%M", entry.end_time)
      local duration = utils.format_time(entry.duration)
      
      table.insert(lines, string.format(
        "%s - %s [%s] Task: %s",
        start_time, end_time, duration, entry.task
      ))
      
      if i >= 15 then
        table.insert(lines, "... (more entries not shown)")
        break
      end
    end
  end
  
  table.insert(lines, "")
  
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
end

function M.show_billing()
  local billing = require("tick.billing")
  local report = billing.generate_billing_report()
  
  M.create_float_win()
  
  local lines = {}
  table.insert(lines, "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
  table.insert(lines, "┃                     BILLING HISTORY                   ┃")
  table.insert(lines, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
  table.insert(lines, "")
  
  if not report.project_name then
    table.insert(lines, "No project selected")
  else
    table.insert(lines, "Project: " .. report.project_name)
    table.insert(lines, string.format("Billing rate: %s%.2f %s", 
      billing.get_currency_symbol(report.currency),
      report.billing_rate,
      report.currency
    ))
    table.insert(lines, "Total time: " .. report.formatted_time)
    table.insert(lines, string.format("Hours: %.2f", report.hours))
    table.insert(lines, string.format("Total amount: %s%.2f %s",
      billing.get_currency_symbol(report.currency),
      report.total_amount,
      report.currency
    ))
    table.insert(lines, "")
    table.insert(lines, "Task breakdown:")
    
    if #report.tasks == 0 then
      table.insert(lines, "  No tasks recorded yet")
    else
      for _, task in ipairs(report.tasks) do
        table.insert(lines, string.format(
          "  - %s: %s (%.2f hrs, %s%.2f %s)",
          task.name,
          task.formatted_time,
          task.hours,
          billing.get_currency_symbol(report.currency),
          task.amount,
          report.currency
        ))
      end
    end
  end
  
  table.insert(lines, "")
  
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
end

function M.show_time_report()
  local billing = require("tick.billing")
  local utils = require("tick.utils")
  
  vim.ui.input({
    prompt = "Enter start date (YYYY-MM-DD) or leave empty for all time: "
  }, function(start_date)
    vim.cmd("redraw")
    
    local start_timestamp = 0
    if start_date and start_date ~= "" then
      local year, month, day = start_date:match("(%d+)-(%d+)-(%d+)")
      if year and month and day then
        start_timestamp = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day)})
      else
        vim.notify("Invalid date format. Use YYYY-MM-DD", vim.log.levels.ERROR)
        return
      end
    end
    
    vim.ui.input({
      prompt = "Enter end date (YYYY-MM-DD) or leave empty for today: "
    }, function(end_date)
      vim.cmd("redraw")
      
      local end_timestamp = os.time()
      if end_date and end_date ~= "" then
        local year, month, day = end_date:match("(%d+)-(%d+)-(%d+)")
        if year and month and day then
          end_timestamp = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day)})
        else
          vim.notify("Invalid date format. Use YYYY-MM-DD", vim.log.levels.ERROR)
          return
        end
      end
      
      local report = billing.generate_time_report(nil, start_timestamp, end_timestamp)
      
      M.create_float_win()
      
      local lines = {}
      table.insert(lines, "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
      table.insert(lines, "┃                     TIME REPORT                      ┃")
      table.insert(lines, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
      table.insert(lines, "")
      
      if not report.project_name then
        table.insert(lines, "No project selected")
      else
        table.insert(lines, "Project: " .. report.project_name)
        table.insert(lines, string.format("Date range: %s to %s",
          os.date("%Y-%m-%d", report.start_date),
          os.date("%Y-%m-%d", report.end_date)
        ))
        table.insert(lines, "Total time: " .. utils.format_time(report.total_time))
        table.insert(lines, "")
        
        table.insert(lines, "Daily breakdown:")
        if #report.daily_breakdown == 0 then
          table.insert(lines, "  No time recorded in this period")
        else
          for _, day in ipairs(report.daily_breakdown) do
            table.insert(lines, string.format(
              "  - %s: %s",
              day.date,
              utils.format_time(day.total_time)
            ))
          end
        end
        
        table.insert(lines, "")
        table.insert(lines, "Task breakdown:")
        if #report.tasks == 0 then
          table.insert(lines, "  No tasks recorded in this period")
        else
          for _, task in ipairs(report.tasks) do
            table.insert(lines, string.format(
              "  - %s: %s",
              task.name,
              utils.format_time(task.total_time)
            ))
          end
        end
      end
      
      table.insert(lines, "")
      
      vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
    end)
  end)
end

function M.prompt_new_project()
  vim.ui.input({
    prompt = "Enter project name: "
  }, function(input)
    vim.cmd("redraw")
    
    if input and input ~= "" then
      require("tick.projects").create_project(input)
      
      vim.defer_fn(function()
        if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
          vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
          M.render_dashboard()
        end
      end, 100)
    end
  end)
end

function M.prompt_switch_project()
  local projects = require("tick.projects")
  local active_projects = projects.get_active_projects()
  local project_names = {}
  
  for _, project in ipairs(active_projects) do
    table.insert(project_names, project.name)
  end
  
  if #project_names == 0 then
    vim.notify("No active projects found. Create a project first.", vim.log.levels.INFO)
    return
  end
  
  vim.ui.select(project_names, {
    prompt = "Select project:"
  }, function(choice)
    vim.cmd("redraw")
    
    if choice then
      projects.switch_project(choice)
      
      vim.defer_fn(function()
        if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
          vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
          M.render_dashboard()
        end
      end, 100)
    end
  end)
end

function M.prompt_set_task()
  vim.ui.input({
    prompt = "Enter task name: "
  }, function(input)
    vim.cmd("redraw")
    
    if input and input ~= "" then
      require("tick.tasks").set_current_task(input)
      
      vim.defer_fn(function()
        if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
          vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
          M.render_dashboard()
        end
      end, 100)
    end
  end)
end

function M.prompt_set_rate()
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()
  
  vim.ui.input({
    prompt = "Enter hourly rate: "
  }, function(input)
    vim.cmd("redraw")
    
    if input and input ~= "" then
      local rate = tonumber(input)
      if rate and rate >= 0 then
        local config = require("tick").config
        local currencies = {}
        for code, _ in pairs(config.currencies) do
          table.insert(currencies, code)
        end
        
        vim.ui.select(currencies, {
          prompt = "Select currency:"
        }, function(choice)
          vim.cmd("redraw")
          
          if choice then
            require("tick.billing").set_rate(rate, choice)
            
            vim.defer_fn(function()
              if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
                vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
                M.render_dashboard()
              end
            end, 100)
          end
        end)
      else
        vim.notify("Invalid rate. Please enter a non-negative number.", vim.log.levels.ERROR)
      end
    end
  end)
end

function M.prompt_delete_project()
  local projects = require("tick.projects")
  local project_names = {}
  
  for name, _ in pairs(projects.projects) do
    table.insert(project_names, name)
  end
  
  if #project_names == 0 then
    vim.notify("No projects found to delete.", vim.log.levels.INFO)
    return
  end
  
  vim.ui.select(project_names, {
    prompt = "Select project to delete:"
  }, function(choice)
    vim.cmd("redraw")
    
    if choice then
      vim.ui.input({
        prompt = string.format("Are you sure you want to delete project '%s'? (y/N): ", choice)
      }, function(input)
        vim.cmd("redraw")
        
        if input and input:lower() == "y" then
          projects.delete_project(choice)
          
          vim.defer_fn(function()
            if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
              vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
              M.render_dashboard()
            end
          end, 100)
        end
      end)
    end
  end)
end

function M.export_time_report_csv(output_file)
  local billing = require("tick.billing")
  
  vim.ui.input({
    prompt = "Enter start date (YYYY-MM-DD) or leave empty for all time: "
  }, function(start_date)
    vim.cmd("redraw")
    
    local start_timestamp = 0
    if start_date and start_date ~= "" then
      local year, month, day = start_date:match("(%d+)-(%d+)-(%d+)")
      if year and month and day then
        start_timestamp = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day)})
      else
        vim.notify("Invalid date format. Use YYYY-MM-DD", vim.log.levels.ERROR)
        return
      end
    end
    
    vim.ui.input({
      prompt = "Enter end date (YYYY-MM-DD) or leave empty for today: "
    }, function(end_date)
      vim.cmd("redraw")
      
      local end_timestamp = os.time()
      if end_date and end_date ~= "" then
        local year, month, day = end_date:match("(%d+)-(%d+)-(%d+)")
        if year and month and day then
          end_timestamp = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day)})
        else
          vim.notify("Invalid date format. Use YYYY-MM-DD", vim.log.levels.ERROR)
          return
        end
      end
      
      if not output_file or output_file == "" then
        local default_name = string.format("time_report_%s_to_%s.csv",
          os.date("%Y%m%d", start_timestamp),
          os.date("%Y%m%d", end_timestamp)
        )
        
        vim.ui.input({
          prompt = string.format("Enter output file name [%s]: ", default_name)
        }, function(filename)
          vim.cmd("redraw")
          
          filename = filename and filename ~= "" and filename or default_name
          M.save_csv_report(filename, start_timestamp, end_timestamp)
        end)
      else
        M.save_csv_report(output_file, start_timestamp, end_timestamp)
      end
    end)
  end)
end

function M.save_csv_report(filename, start_timestamp, end_timestamp)
  local billing = require("tick.billing")
  local csv_data = billing.generate_time_report_csv(nil, start_timestamp, end_timestamp)
  
  if not filename:match("^/") then
    filename = vim.fn.getcwd() .. "/" .. filename
  end
  
  local dir = vim.fn.fnamemodify(filename, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  
  local file = io.open(filename, "w")
  if file then
    file:write(csv_data)
    file:close()
    vim.notify(string.format("Time report exported to %s", filename), vim.log.levels.INFO)
  else
    vim.notify(string.format("Failed to write to file %s", filename), vim.log.levels.ERROR)
  end
end

function M.prompt_archive_project()
  local projects = require("tick.projects")
  local active_projects = projects.get_active_projects()
  local project_names = {}
  
  for _, project in ipairs(active_projects) do
    table.insert(project_names, project.name)
  end
  
  if #project_names == 0 then
    vim.notify("No active projects found to archive.", vim.log.levels.INFO)
    return
  end
  
  vim.ui.select(project_names, {
    prompt = "Select project to archive:"
  }, function(choice)
    vim.cmd("redraw")
    
    if choice then
      vim.ui.input({
        prompt = string.format("Are you sure you want to archive project '%s'? (y/N): ", choice)
      }, function(input)
        vim.cmd("redraw")
        
        if input and input:lower() == "y" then
          projects.archive_project(choice)
          
          vim.defer_fn(function()
            if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
              vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
              M.render_dashboard()
            end
          end, 100)
        end
      end)
    end
  end)
end

function M.prompt_unarchive_project()
  local projects = require("tick.projects")
  local archived_projects = projects.get_archived_projects()
  local project_names = {}
  
  for _, project in ipairs(archived_projects) do
    table.insert(project_names, project.name)
  end
  
  if #project_names == 0 then
    vim.notify("No archived projects found.", vim.log.levels.INFO)
    return
  end
  
  vim.ui.select(project_names, {
    prompt = "Select project to unarchive:"
  }, function(choice)
    vim.cmd("redraw")
    
    if choice then
      projects.unarchive_project(choice)
      
      vim.defer_fn(function()
        if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
          vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
          M.render_dashboard()
        end
      end, 100)
    end
  end)
end

function M.prompt_set_description()
  local projects = require("tick.projects")
  local current_project = projects.get_current_project()
  
  if not current_project then
    vim.notify("No active project", vim.log.levels.ERROR)
    return
  end
  
  vim.ui.input({
    prompt = string.format("Enter description for project '%s': ", current_project.name),
    default = current_project.description or ""
  }, function(input)
    vim.cmd("redraw")
    
    if input then
      projects.set_project_description(current_project.name, input)
      
      vim.defer_fn(function()
        if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
          vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
          M.render_dashboard()
        end
      end, 100)
    end
  end)
end

function M.prompt_add_tag()
  local projects = require("tick.projects")
  local current_project = projects.get_current_project()
  
  if not current_project then
    vim.notify("No active project", vim.log.levels.ERROR)
    return
  end
  
  vim.ui.input({
    prompt = string.format("Enter tag for project '%s': ", current_project.name)
  }, function(input)
    vim.cmd("redraw")
    
    if input and input ~= "" then
      projects.add_project_tag(current_project.name, input)
      
      vim.defer_fn(function()
        if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
          vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
          M.render_dashboard()
        end
      end, 100)
    end
  end)
end

function M.prompt_remove_tag()
  local projects = require("tick.projects")
  local current_project = projects.get_current_project()
  
  if not current_project then
    vim.notify("No active project", vim.log.levels.ERROR)
    return
  end
  
  if not current_project.tags or #current_project.tags == 0 then
    vim.notify("No tags to remove", vim.log.levels.INFO)
    return
  end
  
  vim.ui.select(current_project.tags, {
    prompt = string.format("Select tag to remove from project '%s': ", current_project.name)
  }, function(choice)
    vim.cmd("redraw")
    
    if choice then
      projects.remove_project_tag(current_project.name, choice)
      
      vim.defer_fn(function()
        if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
          vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
          M.render_dashboard()
        end
      end, 100)
    end
  end)
end

return M
