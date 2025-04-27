# tick.nvim

A time tracking and project management plugin for Neovim.

## Features

- Project management with archiving and tagging
- Time tracking with start/stop functionality
- Billing rate management with multiple currencies
- Detailed time reports and billing history
- CSV export for time reports
- Beautiful and intuitive UI

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'simonfarkas/tick.nvim',
  config = function()
    require('tick').setup()
  end
}
```

## Configuration

Default configuration:

```lua
require('tick').setup({
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
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:TickOpen` | Open the main dashboard |
| `:TickCreateProject <name>` | Create a new project |
| `:TickSwitch <name>` | Switch to a project |
| `:TickSetTask <name>` | Set current task |
| `:TickSetRate <rate>` | Set billing rate |
| `:TickStartTimer` | Start the timer |
| `:TickStopTimer` | Stop the timer |
| `:TickHistory` | Show task history |
| `:TickTimeReport` | Show time report |
| `:TickExportCSV [filename]` | Export time report to CSV |
| `:TickDeleteProject <name>` | Delete a project |

## Keybindings

When the dashboard is open:

| Key | Action |
|-----|--------|
| `q` or `Esc` | Close window |
| `n` | Create new project |
| `p` | Switch project |
| `t` | Set task |
| `r` | Set rate |
| `s` | Start timer |
| `S` | Stop timer |
| `h` | Show history |
| `b` | Show billing |
| `d` | Delete project |
| `T` | Show time report |
| `a` | Archive project |
| `A` | Unarchive project |
| `e` | Set project description |
| `+` | Add project tag |
| `-` | Remove project tag |

## Project Management

### Creating Projects

1. Press `n` in the dashboard
2. Enter project name
3. Project is created and automatically selected

### Switching Projects

1. Press `p` in the dashboard
2. Select project from the list
3. Project is switched and becomes active

### Archiving Projects

1. Press `a` in the dashboard
2. Select project to archive
3. Confirm archiving

### Unarchiving Projects

1. Press `A` in the dashboard
2. Select project to unarchive
3. Project is restored to active state

### Project Tags

- Add tags with `+` key
- Remove tags with `-` key
- Tags help organize and categorize projects

### Project Description

- Set project description with `e` key
- Description appears in project details

## Time Tracking

### Starting a Timer

1. Set current task with `t`
2. Press `s` to start timer
3. Timer runs in background

### Stopping a Timer

1. Press `S` to stop timer
2. Time entry is recorded
3. Added to task history

### Task History

1. Press `h` to view history
2. Shows recent time entries
3. Includes start/end times and duration

## Billing

### Setting Rates

1. Press `r` in the dashboard
2. Enter hourly rate
3. Select currency
4. Rate is applied to current project

### Billing Reports

1. Press `b` to view billing
2. Shows total time and amount
3. Includes task breakdown
4. Displays in selected currency

## Time Reports

### Viewing Reports

1. Press `T` to show time report
2. Enter date range (optional)
3. View daily and task breakdown

### Exporting Reports

1. Use `:TickExportCSV` command
2. Enter date range (optional)
3. Specify output filename
4. CSV file is generated with:
   - Date
   - Task
   - Start time
   - End time
   - Duration
   - Amount

## Data Storage

- Projects and time entries are stored in JSON format
- Data directory: `~/.local/share/nvim/tick/`
- Projects file: `projects.json`
- Data is automatically saved on changes

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License 