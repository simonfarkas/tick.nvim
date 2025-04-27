if vim.fn.has('nvim-0.7.0') ~= 1 then
  vim.api.nvim_err_writeln('Tick.nvim requires Neovim 0.7.0 or higher')
  return
end

require('tick').setup()

vim.api.nvim_create_user_command('Tick', function()
  require('tick.ui').open_dashboard()
end, {})
