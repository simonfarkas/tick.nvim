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

	vim.api.nvim_echo({ { "", "" } }, false, {})
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

function M.generate_time_report_html(project_name, start_date, end_date)
	local csv_content = M.generate_time_report_csv(project_name, start_date, end_date)

	local report = M.generate_time_report(project_name, start_date, end_date)
	local projects = require("tick.projects")
	local project = project_name and projects.projects[project_name] or projects.get_current_project()

	if not project then
		vim.notify("No project selected for time report", vim.log.levels.ERROR)
		return nil
	end

	local start_date_fmt = os.date("%B %d, %Y", report.start_date)
	local end_date_fmt = os.date("%B %d, %Y", report.end_date)
	local date_range = start_date_fmt .. " - " .. end_date_fmt

	local total_hours = report.total_time / 3600
	local total_amount = total_hours * (project and project.billing_rate or 0)
	local currency = project and project.currency or "USD"
	local currency_symbol = M.get_currency_symbol(currency)

	local html = [[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Time Report - ]] .. report.project_name .. [[</title>

<style>
  body {
    font-family: 'Arial', sans-serif;
    color: black;
    background: white;
    margin: 0;
    padding: 0;
  }

  .container {
    max-width: 900px;
    margin: 20px auto;
    padding: 20px;
    border-radius: 8px;
  }

  .header h1 {
    font-size: 2rem;
    font-weight: bold;
    margin: 0;
  }

  .header p {
    font-size: 1rem;
    color: #333;
    margin: 5px 0;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 20px;
  }

  th, td {
    padding: 12px;
    text-align: left;
    font-size: 0.9rem;
    border-bottom: 1px solid #ddd;
  }

  th {
    font-weight: bold;
    background-color: #f7f7f7;
    text-transform: uppercase;
  }

  tr:nth-child(even) {
    background-color: #fafafa;
  }

  .summary {
    margin-top: 30px;
    font-size: 1rem;
    text-align: right;
  }

  .final-billing {
    font-weight: bold;
    font-size: 1.25rem;
    margin-top: 2rem;
  }

  .footer {
    text-align: center;
    font-size: 0.8rem;
    margin-top: 40px;
  }

  button {
    margin-top: 20px;
    padding: 10px 20px;
    font-size: 1rem;
    font-weight: bold;
    border: 2px solid black;
    background-color: white;
    color: black;
    border-radius: 6px;
    cursor: pointer;
  }

  button:hover {
    background-color: #f0f0f0;
  }

  button:active {
    background-color: #e0e0e0;
  }

  @media print {
    .footer {
      display: none;
    }

    button {
      display: none;
    }

    .container {
      max-width: 100%;
      padding: 10px;
    }
  }
</style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Time Report</h1>
      <div class="project-name">]] .. report.project_name .. [[</div>
      <div class="date-range">]] .. date_range .. [[</div>
    </div>

    <div class="content">
]]

	if report.tasks and #report.tasks > 0 then
		html = html .. [[
      <table>
        <thead>
          <tr>
            <th>Date</th>
            <th>Task</th>
            <th>Start Time</th>
            <th>End Time</th>
            <th>Duration (hours)</th>
            <th>Amount</th>
          </tr>
        </thead>
        <tbody>
]]

		for _, task in ipairs(report.tasks) do
			if task.sessions then
				for _, session in ipairs(task.sessions) do
					local date = os.date("%Y-%m-%d", session.start_time)
					local start_time = os.date("%H:%M", session.start_time)
					local end_time = os.date("%H:%M", session.end_time)
					local duration = session.duration / 3600
					local amount = duration * (project and project.billing_rate or 0)

					html = html .. string.format([[
          <tr>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%.2f</td>
            <td>%s%.2f</td>
          </tr>
          ]],
						date,
						task.name,
						start_time,
						end_time,
						duration,
						currency_symbol,
						amount)
				end
			end
		end

		html = html .. [[
        </tbody>
      </table>
]]
	else
		html = html .. [[
      <div class="no-entries">
        <p>No time entries found in the selected period</p>
      </div>
]]
	end

	html = html .. [[
      <div class="summary">
        <h2>Summary</h2>
        <table class="summary-table">
          <tr>
            <th>Total Hours</th>
            <th>Total Amount</th>
          </tr>
          <tr>
            <td>]] .. string.format("%.2f", total_hours) .. [[</td>
            <td>]] .. string.format("%s%.2f %s", currency_symbol, total_amount, currency) .. [[</td>
          </tr>
        </table>
        <div class="final-billing">
          Final Billing: ]] .. string.format("%s%.2f %s", currency_symbol, total_amount, currency) .. [[
        </div>
      </div>
    </div>
  </div>
</body>
</html>
]]

	return html
end

return M
