local M = {}

function M.set_rate(rate, currency)
  if not rate or type(rate) ~= "number" or rate < 0 then
    vim.notify("Invalid billing rate. Please provide a non-negative number.", vim.log.levels.ERROR)
    return
  end
  
  local projects = require("tick.projects")
  local current_project = projects.get_current_project()
  
  if not current_project then
    vim.notify("No active project. Create or switch to a project first.", vim.log.levels.ERROR)
    return
  end
  
  current_project.billing_rate = rate
  current_project.currency = currency or require("tick").config.default_currency
  
  vim.api.nvim_echo({{"", ""}}, false, {})
  vim.cmd("redraw")
  
  vim.notify(
    string.format("Set billing rate to %s%.2f %s for project: %s",
      M.get_currency_symbol(current_project.currency),
      rate,
      current_project.currency,
      projects.current_project
    ),
    vim.log.levels.INFO
  )
  
  projects.save()
end

function M.get_currency_symbol(currency)
  local config = require("tick").config
  return config.currencies[currency] and config.currencies[currency].symbol or "$"
end

function M.convert_amount(amount, from_currency, to_currency)
  local config = require("tick").config
  if from_currency == to_currency then
    return amount
  end
  
  local from_rate = config.currencies[from_currency] and config.currencies[from_currency].rate or 1.0
  local to_rate = config.currencies[to_currency] and config.currencies[to_currency].rate or 1.0
  
  return amount * (to_rate / from_rate)
end

function M.calculate_billing(project_name, target_currency)
  local projects = require("tick.projects")
  local project = project_name and projects.projects[project_name] or projects.get_current_project()
  
  if not project then
    return {
      hours = 0,
      rate = 0,
      total = 0,
      currency = require("tick").config.default_currency
    }
  end
  
  local hours = project.total_time / 3600 
  local rate = project.billing_rate
  local currency = project.currency or require("tick").config.default_currency
  local total = hours * rate
  
  if target_currency and target_currency ~= currency then
    total = M.convert_amount(total, currency, target_currency)
    rate = M.convert_amount(rate, currency, target_currency)
    currency = target_currency
  end
  
  return {
    hours = hours,
    rate = rate,
    total = total,
    currency = currency
  }
end

function M.generate_billing_report(project_name, target_currency)
  local projects = require("tick.projects")
  local utils = require("tick.utils")
  local project = project_name and projects.projects[project_name] or projects.get_current_project()
  
  if not project then
    vim.notify("No project selected for billing report", vim.log.levels.ERROR)
    return {}
  end
  
  local currency = target_currency or project.currency or require("tick").config.default_currency
  local bill = M.calculate_billing(project_name, currency)
  
  local report = {
    project_name = project_name or projects.current_project,
    billing_rate = bill.rate,
    currency = bill.currency,
    total_time = project.total_time,
    formatted_time = utils.format_time(project.total_time),
    hours = bill.hours,
    total_amount = bill.total,
    tasks = {}
  }
  
  for task_name, task_data in pairs(project.tasks) do
    local task_hours = task_data.total_time / 3600
    local task_amount = task_hours * project.billing_rate
    
    if target_currency and target_currency ~= currency then
      task_amount = M.convert_amount(task_amount, currency, target_currency)
    end
    
    table.insert(report.tasks, {
      name = task_name,
      total_time = task_data.total_time,
      formatted_time = utils.format_time(task_data.total_time),
      hours = task_hours,
      amount = task_amount
    })
  end
  
  table.sort(report.tasks, function(a, b)
    return a.total_time > b.total_time
  end)
  
  return report
end

function M.generate_time_report(project_name, start_date, end_date)
  local projects = require("tick.projects")
  local project = project_name and projects.projects[project_name] or projects.get_current_project()
  
  if not project then
    vim.notify("No project selected for time report", vim.log.levels.ERROR)
    return {
      project_name = project_name or "No Project",
      start_date = start_date or 0,
      end_date = end_date or os.time(),
      total_time = 0,
      tasks = {},
      daily_breakdown = {}
    }
  end
  
  local report = {
    project_name = project_name or projects.current_project,
    start_date = start_date or 0,
    end_date = end_date or os.time(),
    total_time = 0,
    tasks = {},
    daily_breakdown = {}
  }
  
  for task_name, task_data in pairs(project.tasks) do
    local task_time = 0
    local task_sessions = {}
    
    for _, session in ipairs(task_data.sessions) do
      if session.start_time >= report.start_date and session.end_time <= report.end_date then
        task_time = task_time + session.duration
        table.insert(task_sessions, session)
      end
    end
    
    if task_time > 0 then
      table.insert(report.tasks, {
        name = task_name,
        total_time = task_time,
        sessions = task_sessions
      })
      report.total_time = report.total_time + task_time
    end
  end
  
  local current_date = report.start_date
  while current_date <= report.end_date do
    local next_date = current_date + 86400 
    local daily_time = 0
    
    for _, task in ipairs(report.tasks) do
      for _, session in ipairs(task.sessions) do
        if session.start_time >= current_date and session.end_time < next_date then
          daily_time = daily_time + session.duration
        end
      end
    end
    
    if daily_time > 0 then
      table.insert(report.daily_breakdown, {
        date = os.date("%Y-%m-%d", current_date),
        total_time = daily_time
      })
    end
    
    current_date = next_date
  end
  
  return report
end

function M.generate_time_report_csv(project_name, start_date, end_date)
  local report = M.generate_time_report(project_name, start_date, end_date)
  local projects = require("tick.projects")
  local project = projects.get_current_project()
  local csv_lines = {}
  
  local function escape_csv_field(field)
    if field == nil then
      return ""
    end
    field = tostring(field)
    if field:find('[,"\r\n]') then
      return '"' .. field:gsub('"', '""') .. '"'
    else
      return field
    end
  end
  
  table.insert(csv_lines, "Date,Task,Start Time,End Time,Duration (hours),Amount")
  
  if report.tasks and #report.tasks > 0 then
    for _, task in ipairs(report.tasks) do
      if task.sessions then
        for _, session in ipairs(task.sessions) do
          local date = os.date("%Y-%m-%d", session.start_time)
          local start_time = os.date("%H:%M", session.start_time)
          local end_time = os.date("%H:%M", session.end_time)
          local duration = session.duration / 3600 
          local amount = duration * (project and project.billing_rate or 0)
          
          table.insert(csv_lines, string.format(
            "%s,%s,%s,%s,%s,%s",
            escape_csv_field(date),
            escape_csv_field(task.name),
            escape_csv_field(start_time),
            escape_csv_field(end_time),
            escape_csv_field(string.format("%.2f", duration)),
            escape_csv_field(string.format("%.2f", amount))
          ))
        end
      end
    end
  else
    table.insert(csv_lines, "No time entries found in the selected period")
  end
  
  table.insert(csv_lines, "")
  table.insert(csv_lines, "Summary")
  table.insert(csv_lines, "Total Hours,Total Amount")
  
  local total_hours = report.total_time / 3600
  local total_amount = total_hours * (project and project.billing_rate or 0)
  local currency = project and project.currency or "USD"
  local currency_symbol = M.get_currency_symbol(currency)
  
  table.insert(csv_lines, string.format(
    "%s,%s",
    escape_csv_field(string.format("%.2f", total_hours)),
    escape_csv_field(string.format("%s%.2f %s", currency_symbol, total_amount, currency))
  ))
  
  table.insert(csv_lines, "")
  table.insert(csv_lines, "Final Billing")
  table.insert(csv_lines, escape_csv_field(string.format("%s%.2f %s", currency_symbol, total_amount, currency)))
  
  return table.concat(csv_lines, "\r\n")
end

return M
