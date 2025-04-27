local utils = require("tick.utils")
local M = {}

M.projects = {}
M.current_project = nil

function M.load()
  local config = require("tick").config
  local projects_file = config.data_dir .. "/" .. config.projects_file
  
  if vim.fn.filereadable(projects_file) == 1 then
    local content = utils.read_file(projects_file)
    if content then
      local data = vim.json.decode(content) or {}
      M.projects = data.projects or {}
      M.current_project = data.current_project
      
      if M.current_project and M.projects[M.current_project] then
        M.projects[M.current_project].is_active = true
      end
    end
  end
end

function M.save()
  local config = require("tick").config
  local projects_file = config.data_dir .. "/" .. config.projects_file
  
  local data = {
    projects = M.projects,
    current_project = M.current_project
  }
  
  utils.write_file(projects_file, vim.json.encode(data))
end

function M.create_project(name)
  if not name or name == "" then
    vim.notify("Project name cannot be empty", vim.log.levels.ERROR)
    return
  end
  
  if M.projects[name] then
    vim.notify("Project already exists: " .. name, vim.log.levels.WARN)
    return
  end
  
  M.projects[name] = {
    name = name,
    created_at = os.time(),
    last_modified = os.time(),
    tasks = {},
    billing_rate = require("tick").config.default_billing_rate,
    total_time = 0,
    is_active = false,
    is_archived = false,
    description = "",
    tags = {}
  }
  
  vim.api.nvim_echo({{"", ""}}, false, {})
  vim.cmd("redraw")
  
  vim.notify("Created project: " .. name, vim.log.levels.INFO)
  M.save()
  
  M.switch_project(name)
end

function M.switch_project(name)
  if not M.projects[name] then
    vim.notify("Project does not exist: " .. name, vim.log.levels.ERROR)
    return
  end
  
  if M.current_project and M.projects[M.current_project] then
    M.projects[M.current_project].is_active = false
  end
  
  M.current_project = name
  M.projects[name].is_active = true
  M.projects[name].last_modified = os.time()
  
  vim.api.nvim_echo({{"", ""}}, false, {})
  vim.cmd("redraw")
  
  vim.notify("Switched to project: " .. name, vim.log.levels.INFO)
  M.save()
  
  utils.update_statusline()
end

function M.delete_project(name)
  if not M.projects[name] then
    vim.notify("Project does not exist: " .. name, vim.log.levels.ERROR)
    return
  end
  
  if M.current_project == name then
    M.close_project()
  end
  
  M.projects[name] = nil
  vim.notify("Deleted project: " .. name, vim.log.levels.INFO)
  M.save()
end

function M.archive_project(name)
  if not M.projects[name] then
    vim.notify("Project does not exist: " .. name, vim.log.levels.ERROR)
    return
  end
  
  M.projects[name].is_archived = true
  M.projects[name].last_modified = os.time()
  
  if M.current_project == name then
    M.close_project()
  end
  
  vim.notify("Archived project: " .. name, vim.log.levels.INFO)
  M.save()
end

function M.unarchive_project(name)
  if not M.projects[name] then
    vim.notify("Project does not exist: " .. name, vim.log.levels.ERROR)
    return
  end
  
  M.projects[name].is_archived = false
  M.projects[name].last_modified = os.time()
  
  vim.notify("Unarchived project: " .. name, vim.log.levels.INFO)
  M.save()
end

function M.set_project_description(name, description)
  if not M.projects[name] then
    vim.notify("Project does not exist: " .. name, vim.log.levels.ERROR)
    return
  end
  
  M.projects[name].description = description
  M.projects[name].last_modified = os.time()
  
  vim.notify("Updated project description", vim.log.levels.INFO)
  M.save()
end

function M.add_project_tag(name, tag)
  if not M.projects[name] then
    vim.notify("Project does not exist: " .. name, vim.log.levels.ERROR)
    return
  end
  
  if not M.projects[name].tags then
    M.projects[name].tags = {}
  end
  
  table.insert(M.projects[name].tags, tag)
  M.projects[name].last_modified = os.time()
  
  vim.notify("Added tag '" .. tag .. "' to project", vim.log.levels.INFO)
  M.save()
end

function M.remove_project_tag(name, tag)
  if not M.projects[name] then
    vim.notify("Project does not exist: " .. name, vim.log.levels.ERROR)
    return
  end
  
  if not M.projects[name].tags then
    return
  end
  
  for i, t in ipairs(M.projects[name].tags) do
    if t == tag then
      table.remove(M.projects[name].tags, i)
      M.projects[name].last_modified = os.time()
      vim.notify("Removed tag '" .. tag .. "' from project", vim.log.levels.INFO)
      M.save()
      return
    end
  end
end

function M.get_current_project()
  if M.current_project and M.projects[M.current_project] then
    return M.projects[M.current_project]
  end
  return nil
end

function M.get_active_projects()
  local active = {}
  for name, project in pairs(M.projects) do
    if not project.is_archived then
      table.insert(active, project)
    end
  end
  return active
end

function M.get_archived_projects()
  local archived = {}
  for name, project in pairs(M.projects) do
    if project.is_archived then
      table.insert(archived, project)
    end
  end
  return archived
end

function M.sort_projects_by(field, reverse)
  local projects = M.get_active_projects()
  table.sort(projects, function(a, b)
    if field == "name" then
      return reverse and a.name > b.name or a.name < b.name
    elseif field == "created_at" then
      return reverse and a.created_at < b.created_at or a.created_at > b.created_at
    elseif field == "last_modified" then
      return reverse and a.last_modified < b.last_modified or a.last_modified > b.last_modified
    elseif field == "total_time" then
      return reverse and a.total_time < b.total_time or a.total_time > b.total_time
    end
    return false
  end)
  return projects
end

function M.close_project()
  if M.current_project and M.projects[M.current_project] then
    M.projects[M.current_project].is_active = false
  end
  M.current_project = nil
  vim.notify("Closed current project", vim.log.levels.INFO)
  M.save()
  utils.update_statusline()
end

return M
