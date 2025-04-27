local M = {}

M.config = {
  data_dir = vim.fn.stdpath("data") .. "/tick",
  default_billing_rate = 0,
  default_currency = "USD",
  currencies = {
    USD = { symbol = "$", rate = 1.0 },
    EUR = { symbol = "€", rate = 0.93 },
    GBP = { symbol = "£", rate = 0.80 },
    JPY = { symbol = "¥", rate = 154.50 },
  },
  save_on_exit = true,
  projects_file = "projects.json",
  ui = {
    border = "rounded",
    width = 60,
    height = 19,
  }
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  if vim.fn.isdirectory(M.config.data_dir) == 0 then
    vim.fn.mkdir(M.config.data_dir, "p")
  end
  
  require("tick.projects").load()
  
  M.create_commands()
end

function M.create_commands()
  vim.api.nvim_create_user_command("TickOpen", function()
    require("tick.ui").open_dashboard()
  end, {})
  
  vim.api.nvim_create_user_command("TickCreateProject", function(opts)
    require("tick.projects").create_project(opts.args)
  end, {nargs = 1})
  
  vim.api.nvim_create_user_command("TickSwitch", function(opts)
    require("tick.projects").switch_project(opts.args)
  end, {nargs = 1, complete = "custom,v:lua.require'tick.projects'.complete_projects"})
  
  vim.api.nvim_create_user_command("TickSetTask", function(opts)
    require("tick.tasks").set_current_task(opts.args)
  end, {nargs = 1})
  
  vim.api.nvim_create_user_command("TickSetRate", function(opts)
    require("tick.billing").set_rate(tonumber(opts.args))
  end, {nargs = 1})
  
  vim.api.nvim_create_user_command("TickStartTimer", function()
    require("tick.tasks").start_timer()
  end, {})
  
  vim.api.nvim_create_user_command("TickStopTimer", function()
    require("tick.tasks").stop_timer()
  end, {})
  
  vim.api.nvim_create_user_command("TickHistory", function()
    require("tick.ui").show_history()
  end, {})
  
  vim.api.nvim_create_user_command("TickTimeReport", function()
    require("tick.ui").show_time_report()
  end, {})
  
  vim.api.nvim_create_user_command("TickExportCSV", function(opts)
    require("tick.ui").export_time_report_csv(opts.args)
  end, {nargs = "?"})
  
  vim.api.nvim_create_user_command("TickDeleteProject", function(opts)
    require("tick.projects").delete_project(opts.args)
  end, {nargs = 1, complete = "custom,v:lua.require'tick.projects'.complete_projects"})
end

return M
