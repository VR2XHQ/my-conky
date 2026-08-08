package.path = package.path .. ";" .. os.getenv("HOME") .. "/.config/conky/beny-conky/?.lua"
-- 使用AppImage版本時要加上，因為要使用到系統的庫。
-- package.cpath = package.cpath .. ";/usr/lib/conky/lib?.so"

-- 修正：手動載入自編譯的 Imlib2 舊版符號
-- local imlib_path = "/home/beny/.local/lib/conky/libimlib2.so"
-- local load_imlib, err = package.loadlib(imlib_path, 'luaopen_imlib2_old')

-- if load_imlib then
--     load_imlib() -- 手動執行入口函數
--     package.loaded['imlib2'] = true -- 標記模組已載入，避免後面的 require 'imlib2' 報錯
-- else
--     print("Warning: Could not load imlib2_old: " .. (err or "unknown error"))
    -- 如果手動載入失敗，嘗試原本的載入方式
--     package.cpath = package.cpath .. ";/home/beny/.local/lib/conky/lib?.so"
-- end

-- 針對 Linux Mint 21.3 的符號修復
-- local imlib_path = "/home/beny/.local/lib/conky/libimlib2.so"
-- local load_imlib = package.loadlib(imlib_path, 'luaopen_imlib2_old')

-- if load_imlib then
--  load_imlib() 
-- package.loaded['imlib2'] = true -- 標記已載入，防止後續 require 'imlib2' 報錯
-- else
--  print("Imlib2 載入失敗")
-- end

-- require('cairo')
require('lib')
require('cairo-tools')
-- require('imlib2')
-- cairo works on Ubuntu, cairo_xlib works on Fedora
-- 自編繹版本，要這部份去載入cairo_xlib。
-- local ok, cairo = pcall(require, "cairo_xlib")
-- if not ok then
--     cairo = require("cairo")
-- end
-- make the cairo functions globally available if needed
-- _G.cairo = cairo

-- 自適配不同 Conky 版本 + 載入 Cairo
local function init_cairo()
    -- AppImage 路徑設定
    local appdir = os.getenv("APPDIR")
    if appdir then
        local f = io.open(appdir .. "/usr/lib/conky/libcairo.so", "r")
        if f then
            f:close()
            package.cpath = package.cpath .. ";" .. appdir .. "/usr/lib/conky/lib?.so"
        end
    end

    -- 載入 Cairo
    local status, cairo = pcall(require, 'cairo')
    if status then
        pcall(require, 'cairo_xlib')
    end

    return status, cairo
end

-- 主程式使用
local ok, cairo = init_cairo()
if not ok then
    -- 錯誤處理（可選）
    print("⚠️ Cairo 載入失敗，部分功能可能無法使用")
end

conky = {}
require 'beny-config'
local settings, cache = conky.beny, {}
local cr, width, height, updates
local isIconFontAvailable = font_exists(settings.icon_font or 'Symbols Nerd Font')

local mycloud_cooldown = 0  -- 在函數外定義，紀錄冷卻截止時間

local function draw_background_other(cr, w, h)
  local corner_radius = 20 -- 圓角弧度
  
  -- 開始繪製圓角路徑
  cairo_move_to(cr, corner_radius, 0)
  cairo_line_to(cr, w - corner_radius, 0)
  cairo_curve_to(cr, w, 0, w, 0, w, corner_radius)
  cairo_line_to(cr, w, h - corner_radius)
  cairo_curve_to(cr, w, h, w, h, w - corner_radius)
  cairo_line_to(cr, corner_radius, h)
  cairo_curve_to(cr, 0, h, 0, h, 0, h - corner_radius)
  cairo_line_to(cr, 0, corner_radius)
  cairo_curve_to(cr, 0, 0, 0, 0, corner_radius, 0)
  cairo_close_path(cr)

  -- 設定顏色：黑色半透明 (2026年流行的毛玻璃感建議 alpha 設在 0.3 ~ 0.5)
  cairo_set_source_rgba(cr, 0.05, 0.05, 0.1, 0.45) 
  cairo_fill(cr)
end

function conky_main()
  if conky_window == nil then return end
  -- 在 function conky_main() 內部起始處
  if settings == nil or settings.widgets == nil then 
    print("Warning: settings not loaded yet.")
    return 
  end
  local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
  cr = cairo_create(cs)
  
  width = conky_window.width
  height = conky_window.height
  
  draw_background_other(cr, width, height)

  updates=tonumber(conky_parse('${updates}'))
  
  local start = mtime()
  for widget,config in pairs(settings.widgets) do
    updateWidget(widget, config)
  end
  -- print(os.date('%c') .. ' updated in ' .. string.format('%.2f seconds', mtime() - start))
  
    -- 1. 先銷毀底層資源
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    -- 2. 斷開 Lua 引用 (這步最重要)
    cr = nil 
    -- 3. 執行輕量回收
    collectgarbage("step")
end

function updateWidget(widget, config)
  if config.hide ~= nil and config.hide == true then
    return
  end
  local start = mtime()
  if widget == 'clock'   then updateClock(config)   end
  if widget == 'system'  then updateSystem(config)  end
  if widget == 'cpu'     then updateCpu(config)     end
  if widget == 'memory'  then updateMemory(config)  end
  if widget == 'disks'   then updateDisks(config)   end
  if widget == 'network' then updateNetwork(config) end
  if widget == 'load'    then updateLoad(config)    end
  -- print(os.date('%c') .. ' updated ' .. widget .. ' in ' .. string.format('%.2f seconds', mtime() - start))
end

function scale(n)
  return math.floor(n * (settings.scaling or 1));
end

function updateClock(config)
  local pos = config.pos or {x = 0, y = 0}
  -- time
  write(cr, os.date(config.timeFormat or '%H:%M'), {
    pos = {x = pos.x, y = pos.y - scale(5)},
    font = {settings.fonts.significant, scale(40), 1},
    color = settings.colors.color_Y,
    align = {'left', 'top'},
  })
  -- date
  if config.showDate == nil or config.showDate then
    write(cr, os.date(config.dateFormat or '%A, %b %e'), {
      pos = {x = pos.x, y = pos.y + scale(35)},
      font = {settings.fonts.significant, scale(16), 1},
      color = settings.colors.color_O,
      align = {'left', 'top'},
    })
  end
  -- icon for distro
  write(cr, config.osIcon, {
    pos = {x = width - scale(20), y = pos.y - scale(5)},
    font = {'Symbols Nerd Font', scale(50)},
    color = settings.colors.color_G,
    align = {'right', 'top'},
  })
end

function updateSystem(config)
  local pos = config.pos or {x = 0, y = scale(70)}
  local leftTextX = pos.x
  local rightTextX = pos.x + scale(100)
  local y = pos.y + scale(2)
  local y_space = scale(18)
  local C = settings.colors.color_OW
  local F = {settings.fonts.default, scale(14)}
  local A = {'left', 'top'}

  -- os
  local os = conky_parse('${exec lsb_release -irs}')
  -- 取得 OS 資訊並立即清理換行
  os = os:gsub('\n', ' '):gsub('^%s*(.-)%s*$', '%1')
  write(cr, 'OS', {
    pos = {x = leftTextX, y = y},
  font  = F, color = C, align = A,
  })
  write(cr, os, {
    pos = {x = rightTextX, y = y},
  font  = F, color = C, align = A,
  })
  y = y + y_space

  -- hostname
  local hostname = conky_parse('${nodename}')
  write(cr, 'Hostname', {
    pos = {x = leftTextX, y = y},
    font  = F, color = C, align = A,
  })
  write(cr, hostname, {
    pos = {x = rightTextX, y = y},
    font  = F, color = C, align = A,
  })
  y = y + y_space

  -- kernel
  local kernel = conky_parse('${kernel}')
  write(cr, 'Kernel', {
    pos = {x = leftTextX, y = y},
    font  = F, color = C, align = A,
  })
  write(cr, kernel, {
    pos = {x = rightTextX, y = y},
    font  = F, color = C, align = A,
  })
  y = y + y_space

  -- uptime
  local uptime = conky_parse('${uptime}')
  write(cr, 'Uptime', {
    pos = {x = leftTextX, y = y},
    font  = F, color = C, align = A,
  })
  write(cr, uptime, {
    pos = {x = rightTextX, y = y},
    font  = F, color = C, align = A,
  })
  y = y + y_space

  -- cpu
  local cpu = conky_parse('${execi 10000 cat /proc/cpuinfo | grep \'model name\' | sed -e \'s/model name.*: //\'| uniq}')
  write(cr, 'CPU', {
    pos = {x = leftTextX, y = y},
    font  = F, color = C, align = A,
  })
  write(cr, cpu, {
    pos = {x = rightTextX - 60, y = y},
    font  = {}, color = C, align = A,
  })
  y = y + y_space

  -- gpu
  local gpu = conky_parse('${execi 10000 lspci | grep \' VGA \' | cut -d "[" -f2 | cut -d "]" -f1}')
  write(cr, 'GPU', {
    pos = {x = leftTextX, y = y},
    font  = F, color = C, align = A,
  })
  write(cr, gpu, {
    pos = {x = rightTextX, y = y},
    font  = F, color = C, align = A,
  })
  y = y + y_space

  -- processes
  local processes = conky_parse('${processes}')
  local running_processes = conky_parse('${running_processes}')
  write(cr, 'Processes', {
    pos = {x = leftTextX, y = y},
    font  = F, color = C, align = A,
  })
  write(cr, running_processes .. ' / ' .. processes, {
    pos = {x = rightTextX, y = y},
    font  = F, color = C, align = A,
  })
  y = y + y_space

  -- threads
  local threads = conky_parse('${threads}')
  local running_threads = conky_parse('${running_threads}')
  write(cr, 'Threads', {
    pos = {x = leftTextX, y = y},
    font  = F, color = C, align = A,
  })
  write(cr, running_threads .. ' / ' .. threads, {
    pos = {x = rightTextX, y = y},
    font  = F, color = C, align = A,
  })
  y = y + y_space

  -- load average
  local load1 = conky_parse('${loadavg 1}')
  local load5 = conky_parse('${loadavg 2}')
  local load15 = conky_parse('${loadavg 3}')
  write(cr, 'Load Average', {
    pos = {x = leftTextX, y = y},
    font  = F, color = C, align = A,
  })
  write(cr, load1 .. ' | ' .. load5 .. ' | ' .. load15, {
    pos = {x = rightTextX + 20, y = y},
    font  = F, color = C, align = A,
  })
  y = y + y_space
end
  
function updateCpu(config)
  local pos = config.pos or {x = 0, y = 0}
  local freq = conky_parse('${freq_g 1}')
  local hwmon = config.hwmon or getCoreHwmon()
  local tempSensor = config.tempSensor or 1
  local temperature = conky_parse('${hwmon ' .. hwmon .. ' temp '  .. tempSensor .. '}')
  local avgCpu = conky_parse('${cpu}')
  local cpuCount = getCpuCount()
  local warnTemp, critTemp, maxTemp = 60, 80, 110
  if (cache.cpu == nil or cache.cpu.idleTemperatureCount < 1000) and (tonumber(freq) < 1 or tonumber(avgCpu) < 10) then
    if cache.cpu == nil then cache.cpu = {} end
    cache.cpu.idleTemperatureSum = (cache.cpu.idleTemperatureSum or 0) + tonumber(temperature)
    cache.cpu.idleTemperatureCount = (cache.cpu.idleTemperatureCount or 0) + 1
  end
  if cache.cpu ~= nil and cache.cpu.idleTemperatureSum ~= nil and cache.cpu.idleTemperatureCount ~= nil then
    warnTemp = cache.cpu.idleTemperatureSum / cache.cpu.idleTemperatureCount * 1.5
    critTemp = warnTemp * 1.3
  end

  local y = pos.y + scale(5) -- start of text
  local gauge_center = {x = scale(110), y = pos.y + scale(120)}
  local leftTextX = gauge_center.x + scale(7)
  local rightTextX = width
  if config.gaugeLoc == 'right' then
    gauge_center.x = width - scale(110)
    leftTextX = pos.x
    rightTextX = gauge_center.x - scale(7)
  end

  local gauge_from = 180
  local gauge_to = 360
  if config.gaugeLoc == 'right' then
    gauge_from = 0
    gauge_to = 180
  end

  -- temperature
  write(cr, 'CPU Temperature', {
    pos = {x = leftTextX, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'left', 'top'},
  })
  write(cr, temperature .. '°C', {
    pos = {x = rightTextX, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'right', 'top'},
  })
  gauge(cr, tonumber(temperature), {
    pos = gauge_center,
    radius = scale(108), thickness = scale(6),
    from = gauge_from, to = gauge_to,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = maxTemp,
    warn = {from = warnTemp, color = settings.colors.gaugeWarn},
    crit = {from = critTemp, color = settings.colors.gaugeCrit},
  })

  -- average cpu
  y = y+scale(12)
  write(cr, 'Average CPU usage ', {
    pos = {x = leftTextX, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'left', 'top'},
  })
  write(cr, avgCpu:pad(3, ' ', 'STR_PAD_LEFT') .. '%', {
    pos = {x = rightTextX, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'right', 'top'},
  })
  gauge(cr, tonumber(avgCpu), {
    pos = gauge_center,
    radius = scale(98), thickness = scale(11),
    from = gauge_from + scale(2), to = gauge_to - scale(2),
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    warn = {from = 100/cpuCount, color = settings.colors.gaugeInfo},
    crit = {from = 90, color = settings.colors.gaugeWarn},
  })

  -- cpu cores
  y = y+scale(13)
  if cpuCount > 1 then
    local r = scale(89)
    local perRow = math.ceil(cpuCount/4)
    local minCoresPerRow = config.minCoresPerRow or 2
    if perRow < minCoresPerRow then
        perRow = minCoresPerRow
    end
    local s = ''
    for i=1,cpuCount,1 do
      s = s .. '${cpu cpu' .. i .. '},'
    end
    local cpuUsage = conky_parse(s):split(',')
    for i=1,cpuCount,perRow do
      local usages = {}
      local sum = 0
      local j
      for j=i,i+perRow-1,1 do
        if j > cpuCount then
          break
        end
        table.insert(usages, tonumber(cpuUsage[j]))
        sum = sum + cpuUsage[j]
      end

      local avg = round(sum/perRow,1)

      local leftText, rightText
      if perRow == 1 then
        leftText = 'Core ' .. i
        rightText = avg .. '%'
      else
        leftText = 'Cores ' .. (i .. '-' .. i+perRow-1):pad(5, ' ', 'STR_PAD_LEFT')
        rightText = avg .. '%'
      end

      -- cpu cores text
      write(
        cr,
        leftText,
        {
          pos = {x = leftTextX, y = y},
          font = {settings.fonts.default, scale(12)},
          color = settings.colors.default,
          align = {'left', 'top'},
        }
      )
      write(
        cr,
        rightText,
        {
          pos = {x = rightTextX, y = y},
          font = {settings.fonts.default, scale(12)},
          color = settings.colors.default,
          align = {'right', 'top'},
        }
      )

      -- cpu cores gauges
      local thickness = math.floor(scale(12) / perRow)                   -- 4 = 3 / 6 = 2 / 8 = 1   / 12 = 1 / 16 = 0
      local rDec = thickness + (scale(12) - thickness * perRow) / perRow -- 4 = 3 / 6 = 2 / 8 = 1.5 / 12 = 0 / 16 = 0.75
      if thickness == 0 then
        thickness = 1
      elseif thickness > 2 then
        rDec = thickness
        thickness = math.ceil(thickness / 2 )
      end
      local usage
      for j,usage in ipairs(usages) do
        gauge(cr, usage, {
          pos = gauge_center,
          radius = r - rDec * (j-1), thickness = thickness,
          from = gauge_from, to = gauge_to,
          background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
          color = settings.colors.gauge,
          alpha = settings.colors.gaugeAlpha,
          warn = {from = 50, color = settings.colors.gaugeInfo},
        })
      end

      y = y + scale(12)
      r = r - scale(12)
    end
  end

  -- average cpu graph
  y = y + scale(55)
  local graph_x = gauge_center.x + scale(30)
  local graph_width = width - graph_x
  local graph_direction = 'right'
  if config.gaugeLoc == 'right' then
    graph_x = gauge_center.x - scale(30)
    graph_width = graph_x
    graph_direction = 'left'
  end
  graph(cr, 'cpu', tonumber(avgCpu), {
    pos = {x = graph_x, y = y - scale(20)},
    direction = graph_direction, amplitude = 'up',
    color = settings.colors.gauge,
    alpha = 0.9, width = graph_width, height = scale(40),
  })
  y = y + scale(1)
  local text_align = 'left'
  if config.gaugeLoc == 'right' then
    text_align = 'right'
  end
  write(cr, freq .. ' GHz', {
    pos = {x = graph_x, y = y - scale(20)},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {text_align, 'top'},
  })

  -- top
  y = y + scale(12)
  if config.top and config.top > 0 then
    if cache.top == nil or updates % 4 == 0 then
      -- local topCpu = os.capture('LC_ALL=C ps -eo comm,%cpu --sort=-%cpu --no-headers|head -4'):split('\n')
      local topCpu = os.capture(
        'LC_ALL=C top -w 512 -bn 1 -d 1 -o %CPU|grep -A40 "PID USER"|tail -40|' ..
        'tr -s " "|cut -d " " -f10,13-'
      ):split('\n')
      topCpu = table.map(topCpu, function (row)
        local cpu, cmd = row:match('^([%d.]+) +(.-)$')
        if cmd == nil then return {cmd = '', cpu = 0} end
        return {
          cmd = string.sub(cmd, 1, 20),
          cpu = cpu,
        }
      end)
      topCpu = table.group(
        topCpu,
        function (row) return row.cmd end,
        {
          sum = function (sum, row)
            if sum == nil then
              return tonumber(row.cpu)
            end
            return sum + tonumber(row.cpu)
          end,
        }
      )

      topCpu = table.values(table.filter(topCpu, function (row)
        return row.sum
      end))
      table.sort(topCpu, function (row1, row2)
        return row1.sum > row2.sum
      end)

      cache.top = {}
      table.move(topCpu, 1, config.top, 1, cache.top)
    end

    local firstRow = y;
    for _, data in pairs(cache.top) do
      -- Process name, left aligned
      write(cr, data.key:pad(20), {
        pos = { x = leftTextX, y = y },
        font = {settings.fonts.default, scale(12)},
        color = settings.colors.default,
        align = {'left', 'top'},
      })
      -- CPU percentage, right aligned
      write(cr, tostring(round(data.sum/cpuCount, 1)):pad(7, ' ', 'STR_PAD_LEFT') .. '%', {
        pos = { x = rightTextX, y = y }, -- adjust 140 to your desired right margin
        font = {settings.fonts.default, scale(12)},
        color = settings.colors.default,
        align = {'right', 'top'},
      })
      y = y + scale(12)
    end
    y = firstRow + scale(12) * config.top
  end

  -- icon for CPU
  -- if font is not found, fall back to text 'CPU'
  local text = '\u{f4bc}' -- nf-fa-microchip
  local font = {settings.icon_font, scale(40)}
  local icon_x = gauge_center.x - scale(20)
  local icon_y = gauge_center.y - scale(20)
  if config.gaugeLoc == 'right' then
    icon_x = gauge_center.x + scale(20)
  end
  if not isIconFontAvailable then
    text = 'CPU'
    font = {settings.fonts.significant, scale(20), 1}
    icon_y = gauge_center.y - scale(17)
  end
  write(cr, text, {
    pos = {x = gauge_center.x - scale(20), y = icon_y},
    font = font,
    color = settings.colors.default,
    align = {'left', 'top'},
  })
end

function updateMemory(config)
  local pos = config.pos or {x = width-scale(205), y = scale(150)}
  local free = os.capture('LC_ALL=C free -m'):split('\n')
  local memTotal, memUsed, memFree, memShared, memBuffers, memAvailable =
    free[2]:match('(%d+) +(%d+) +(%d+) +(%d+) +(%d+) +(%d+)')
  local swapTotal, swapUsed, swapFree = free[3]:match('(%d+) +(%d+) +(%d+)')

  local gauge_from = 180
  local gauge_to = 400
  local gauge_center = {x = pos.x + scale(68), y = pos.y + scale(68)}
  local leftTextX = gauge_center.x + scale(47)
  local rightTextX = width
  if config.gaugeLoc == 'right' then
    gauge_from = -40
    gauge_to = 180
    gauge_center.x = pos.x + width - scale(68)
    leftTextX = pos.x
    rightTextX = gauge_center.x - scale(47)
  end

  -- memory
  local used = humanReadableBytes(memUsed + memShared, 'MiB'):pad(7, ' ', 'STR_PAD_LEFT')
  local total = humanReadableBytes(memTotal + 0, 'MiB'):pad(7, ' ', 'STR_PAD_LEFT')
  gauge(cr, memUsed + memShared, {
    pos = gauge_center,
    radius = scale(60), thickness = scale(15),
    from = gauge_from + scale(4), to = gauge_to - scale(4),
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = memTotal,
    warn = {from = memTotal * 0.5, color = settings.colors.gaugeInfo},
    crit = {from = memTotal * 0.95, color = settings.colors.gaugeCrit},
    level2 = {
      color = settings.colors.gauge,
      alpha = 0.2,
      value = memUsed + memShared + memBuffers
    }
  })

  local y = pos.y + scale(10)
  write(cr, 'RAM', {
    pos = {x = leftTextX, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'left', 'top'},
  })
  write(cr, used .. '/' .. total, {
    pos = {x = rightTextX, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'right', 'top'},
  })
  y = y + scale(12)

  -- caches
  local buffer = humanReadableBytes(memBuffers + 0, 'MiB'):pad(7, ' ', 'STR_PAD_LEFT')
  write(cr, 'Cache', {
    pos = {x = leftTextX, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'left', 'top'},
  })
  write(cr, buffer, {
    pos = {x = rightTextX, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'right', 'top'},
  })
  y = y + scale(12)

  -- swap
  local used = humanReadableBytes(swapUsed + 0, 'MiB'):pad(7, ' ', 'STR_PAD_LEFT')
  local total = humanReadableBytes(swapTotal + 0, 'MiB'):pad(7, ' ', 'STR_PAD_LEFT')
  if config.gaugeLoc == 'right' then
    rightTextX = rightTextX + scale(10)
  else
    leftTextX = leftTextX - scale(10)
  end
  write(cr, 'Swap', {
    pos = {x = leftTextX, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'left', 'top'},
  })
  write(cr, used .. '/' .. total, {
    pos = {x = rightTextX, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'right', 'top'},
  })
  gauge(cr, tonumber(swapUsed), {
    pos = gauge_center,
    radius = scale(43), thickness = scale(11),
    from = gauge_from + scale(2), to = gauge_to - scale(2),
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = swapTotal,
    warn = {from = swapTotal * 0.1, color = settings.colors.gaugeWarn},
    crit = {from = swapTotal * 0.2, color = settings.colors.gaugeCrit},
  })

  -- graph
  y = y + scale(50)
  local graph_x = leftTextX
  local graph_width = width - graph_x
  local graph_direction = 'right'
  if config.gaugeLoc == 'right' then
    graph_x = rightTextX
    graph_width = graph_x
    graph_direction = 'left'
  end
  graph(cr, 'mem', tonumber(memUsed) + tonumber(memShared), {
    pos = {x = graph_x, y = y},
    direction = graph_direction, amplitude = 'up',
    color = settings.colors.gauge,
    alpha = 0.9, width = graph_width, height = scale(30),
    max = tonumber(memTotal),
  })

  -- top
  y = y + scale(15)
  if config.top and config.top > 0 then
    if cache.topMem == nil or updates % 4 == 0 then
      local topMem = os.capture('LC_ALL=C ps -eo comm,%mem --sort=-%mem --no-headers|head -40'):split('\n')
      topMem = table.map(topMem, function (row)
        local cmd, mem = row:match('^(.-) +([%d.]+)$')
        return {
          cmd = cmd,
          mem = tonumber(mem),
        }
      end)
      topMem = table.group(
        topMem,
        function (row) return row.cmd end,
        {
          sum = function (sum, row)
            if sum == nil then
              return row.mem
            end
            return sum + row.mem
          end,
        }
      )
      topMem = table.values(topMem)

      table.sort(topMem, function (row1, row2)
        return tonumber(row1.sum) > tonumber(row2.sum)
      end)
      cache.topMem = {}
      table.move(topMem, 1, config.top, 1, cache.topMem)
    end

    leftTextX = gauge_center.x + scale(10)
    rightTextX = width
    if config.gaugeLoc == 'right' then
      leftTextX = pos.x
      rightTextX = gauge_center.x - scale(10)
    end
    for _, data in pairs(cache.topMem) do
      write(cr, data.key:pad(20, ' '), {
        pos = { x = leftTextX, y = y },
        font = {settings.fonts.default, scale(12)},
        color = settings.colors.default,
        align = {'left', 'top'},
      });
      write(cr, tostring(data.sum):pad(6, ' ', 'STR_PAD_LEFT') .. '%', {
        pos = { x = rightTextX, y = y },
        font = {settings.fonts.default, scale(12)},
        color = settings.colors.default,
        align = {'right', 'top'},
      });
      y = y + scale(12)
    end
  end

  -- icon for RAM
  -- if font is not found, fall back to text 'RAM'
  local text = '\u{efc5}' -- nf-fa-memory
  local font = {settings.icon_font, scale(40)}
  local icon_x = gauge_center.x - scale(20)
  local icon_y = gauge_center.y - scale(20)
  if not isIconFontAvailable then
    text = 'RAM'
    font = {settings.fonts.significant, scale(20), 1}
    icon_y = gauge_center.y - scale(17)
  end
  write(cr, text, {
    pos = {x = icon_x, y = icon_y},
    font = font,
    color = settings.colors.default,
    align = {'left', 'top'},
  })
end

function updateNetwork(config)
  local pos = config.pos or {x = width - scale(210), y = scale(315)}
  local network = config.network or getCurrentNetwork()
  if network == 'auto' then
    network = getCurrentNetwork()
  end

  local downspeed = tonumber(conky_parse('${downspeedf ' .. network .. '}'))
  local upspeed = tonumber(conky_parse('${upspeedf ' .. network .. '}'))
  if cache.maxDown == nil or cache.maxDown < downspeed then cache.maxDown = downspeed end
  if cache.maxUp == nil or cache.maxUp < upspeed then cache.maxUp = upspeed end
  if cache.maxDown == 0 or cache.maxUp == 0 then return end

  local gauge_center = {x = pos.x+scale(60), y = pos.y+scale(50)}
  local gauge_from = 180
  local gauge_to = 400
  if config.gaugeLoc == 'right' then
    gauge_center.x = pos.x + width - scale(60)
    gauge_from = -40
    gauge_to = 180
  end

  -- download gauge
  gauge(cr, downspeed, {
    pos = gauge_center,
    radius = scale(55), thickness = scale(10),
    from = gauge_from, to = gauge_to - scale(2),
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = cache.maxDown,
    warn = {from = cache.maxDown * .50, color = settings.colors.gaugeInfo},
  })
  -- upload gauge
  gauge(cr, upspeed, {
    pos = gauge_center,
    radius = scale(45), thickness = scale(7),
    from = gauge_from - scale(2), to = gauge_to - scale(1),
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = cache.maxUp,
    warn = {from = cache.maxUp * .50, color = settings.colors.gaugeInfo},
  })

  -- info
  local leftTextX = gauge_center.x + scale(40)
  local rightTextX = width
  if config.gaugeLoc == 'right' then
    leftTextX = pos.x
    rightTextX = gauge_center.x - scale(40)
  end
  local y = pos.y
  if config.hideInfo == nil or config.hideInfo == false then
    local localIp = conky_parse('${addr ' .. network .. '}')
    write(cr, 'LAN v4', {
      pos = {x = leftTextX, y = y},
      font = {settings.fonts.default, scale(12)},
      color = settings.colors.default,
      align = {'left', 'top'},
    })
    write(cr, localIp:pad(15, ' ', 'STR_PAD_LEFT'), {
      pos = {x = rightTextX, y = y},
      font = {settings.fonts.default, scale(12)},
      color = settings.colors.default,
      align = {'right', 'top'},
    })
    y = y + scale(12)
    local publicIp = conky_parse('${execi 3600 wget -q -O - checkip.dyndns.org | sed -e \'s/[^[:digit:]\\|.]//g\'}')
    write(cr, 'WAN v4', {
      pos = {x = leftTextX, y = y},
      font = {settings.fonts.default, scale(12)},
      color = settings.colors.default,
      align = {'left', 'top'},
    })
    write(cr, publicIp:pad(15, ' ', 'STR_PAD_LEFT'), {
      pos = {x = rightTextX, y = y},
      font = {settings.fonts.default, scale(12)},
      color = settings.colors.default,
      align = {'right', 'top'},
    })
  end

  y = y + scale(35)
  local graph_x = leftTextX
  local graph_width = width - graph_x
  local graph_direction = 'right'
  if config.gaugeLoc == 'right' then
    graph_x = rightTextX
    graph_width = graph_x
    graph_direction = 'left'
  end
  local gauge_height = scale(12)
  if config.showIpv6 == false then
    gauge_height = scale(18)
    y = y + scale(6)
  end
  -- upload
  graph(cr, 'upload', upspeed, {
    pos = {x = graph_x, y = y},
    direction = graph_direction, amplitude = 'up',
    color = settings.colors.gauge,
    alpha = 0.9, max = 'auto',
    width = graph_width, height = gauge_height,
  })
  -- download
  y = y + scale(3)
  graph(cr, 'download', downspeed, {
    pos = {x = graph_x, y = y},
    direction = graph_direction, amplitude = 'down',
    color = settings.colors.gauge,
    alpha = 0.9, max = 'auto',
    width = graph_width, height = gauge_height,
  })

  local x = gauge_center.x + scale(20)
  if config.showIpv6 == true then
    y = y + scale(34)
    local publicIpv6 = conky_parse('${execi 3600 wget -q -O - https://ifconfig.co/ip}')
    if config.gaugeLoc == 'right' then
      write(cr, publicIpv6:pad(15, ' ', 'STR_PAD_LEFT'), {
        pos = {x = pos.x, y = y},
        font = {settings.fonts.default, scale(12)},
        color = settings.colors.default,
        align = {'left'},
      })
    else
      write(cr, publicIpv6:pad(15, ' ', 'STR_PAD_LEFT'), {
        pos = {x = rightTextX, y = y},
        font = {settings.fonts.default, scale(12)},
        color = settings.colors.default,
        align = {'right'},
      })
    end
    y = y + scale(2)
  else
    y = y + scale(30)
  end
  -- current speeds / full speeds / total
  y = y + scale(12)
  local upDownTextX = width
  if config.gaugeLoc == 'right' then
    x = pos.x + scale(10)
    upDownTextX = gauge_center.x - scale(10)
  end
  path(cr, {
    pos = {x = x, y = y-scale(7)},
    points = {
        { x = x + scale(5), y = y},
        { x = x - scale(5), y = y},
    },
    fill = { color = upspeed > 0.1 and settings.colors.highlight or settings.colors.default },
  })
  local totalUp = conky_parse('${totalup ' .. network .. '}'):pad(7, ' ', 'STR_PAD_LEFT')
  local up = humanReadableBytes(upspeed, 'KiB'):pad(7, ' ', 'STR_PAD_LEFT')
  local upMax = humanReadableBytes(cache.maxUp, 'KiB'):pad(7, ' ', 'STR_PAD_LEFT')
  write(cr, up .. ' / ' .. upMax .. ' ' .. totalUp, {
    pos = {x = upDownTextX, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'right'},
  })
  y = y + scale(12)
  path(cr, {
    pos = {x = x, y = y},
    points = {
        { x = x + scale(5), y = y-scale(7)},
        { x = x - scale(5), y = y-scale(7)},
    },
    fill = { color = downspeed > 0.1 and settings.colors.highlight or settings.colors.default },
  })
  local totalDown = conky_parse('${totaldown ' .. network .. '}'):pad(7, ' ', 'STR_PAD_LEFT')
  local down = humanReadableBytes(downspeed, 'KiB'):pad(7, ' ', 'STR_PAD_LEFT')
  local downMax = humanReadableBytes(cache.maxDown, 'KiB'):pad(7, ' ', 'STR_PAD_LEFT')
  write(cr, down .. ' / ' .. downMax .. ' ' .. totalDown, {
    pos = {x = upDownTextX, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'right'},
  })

  -- icon for network f059f or ef09
  -- if font is not found, fall back to text 'NET'
  local text = '\u{ef09}'
  local font = {settings.icon_font, scale(40)}
  local icon_x = gauge_center.x - scale(22)
  local icon_y = gauge_center.y - scale(20)
  if not isIconFontAvailable then
    text = 'NET'
    font = {settings.fonts.significant, scale(20), 1}
    icon_y = gauge_center.y - scale(15)
  end
  if config.gaugeLoc == 'right' then
    icon_x = gauge_center.x - scale(22)
  end
  write(cr, text, {
    pos = {x = icon_x, y = icon_y},
    font = font,
    color = settings.colors.default,
    align = {'left', 'top'},
  })
end

function updateDisks(config)
  local pos = config.pos or {x = 0, y = scale(250)}
  local disks = {}

  -- 如果是 auto，先放一個 Root 作為基底
  if config.disks == 'auto' then
    disks = { Root = '/' }
  else
    -- 如果是手動指定，直接複製過來
    for k, v in pairs(config.disks) do disks[k] = v end
  end
  
  -- 如果是 auto，才執行後續的 /dev/ 自動掃描
  if config.disks == 'auto' then
    local mounts = os.capture('mount |grep -E \'^/dev/\''):split("\n")
    for _,mount in pairs(mounts) do
      mount = mount:match('on (/[a-zA-Z0-9 ./_-]*) type')
      if mount ~= nil and mount ~= '/' then
        local excluded = false
        for _,exclude in pairs(config.exclude) do
          if mount:match(exclude) then
            excluded = true
            break
          end
        end
        if not excluded then
          disks[mount:gsub('(.*/)(.*)', '%2'):gsub('[./_-]', ' '):titlecase()] = mount
        end
      end
    end
  end
  
  -- 【關鍵】將 include 移出 if auto 之外，讓它永遠執行
  if config.include ~= nil then
    for name, mount in pairs(config.include) do
      -- 1. 檢查掛載清單（初步過濾）
      local is_mounted = os.capture('mount | grep \'' .. mount .. '\''):len() > 0
      
      -- 2. 使用 stat 進行物理探測（核心保護）
      local check_reachable = string.format('timeout 0.2s stat -t "%s" >/dev/null 2>&1', mount)
      
      local res = os.execute(check_reachable)
      -- print(res) --debug
      local is_reachable = (res == 0 or res == true)
      -- print(is_reachable) --debug

      if is_mounted and is_reachable then
        -- if is_reachable then
        disks[name] = mount
      end
    end
  end

  local sort, i = {}, 0
  if not config.sort or config.sort == 'size' then
    local sizes, j = {}, 0
    for name,mount in pairs(disks) do
      j = j + 1
      local cmd = "timeout 0.5s df -P " .. mount .. " | tail -1 | awk '{print $2}' 2>/dev/null"
      local res = os.capture(cmd)
      
      -- 確保即便 timeout 了，也能拿到 0 而不是 nil
      local size_val = tonumber(res) or 0
      sizes[j] = {size_val, name}
    end
    table.sort(sizes, function (a, b) return a[1] > b[1]; end)
    for _,size in pairs(sizes) do
      i = i + 1
      sort[i] = size[2]
    end
  elseif type(config.sort) == "table" then
    -- 除錯用：印出所有實際抓到的磁碟名稱
    -- for k, v in pairs(disks) do print("Found disk Key: [" .. k .. "] for path: " .. v) end
    
    -- 修正：只保留「目前確實存在」的掛載點
    local j = 0
    for _, name in ipairs(config.sort) do
      if disks[name] then
        j = j + 1
        sort[j] = name
      end
    end
  end
  

  -- 原來代碼的應用，取conky格式化的單位
  local function parseDiskioValue(val)
    local num, unit = val:match('([%d%.]+)%s*(%a+)')
    num = tonumber(num) or 0
    if unit == 'B' then
      return num
    elseif unit == 'KiB' then
      return num * 1024
    elseif unit == 'MiB' then
      return num * 1024 * 1024
    elseif unit == 'GiB' then
      return num * 1024 * 1024 * 1024
    else
      return num
    end
  end
  
  -- 將 Byte 自動轉換成適合的單位字串
  local function formatBytes(bytes)
    bytes = tonumber(bytes) or 0
    if bytes > 1024*1024*1024 then
      return string.format("%.1f GiB", bytes / (1024*1024*1024))
    elseif bytes > 1024*1024 then
      return string.format("%.1f MiB", bytes / (1024*1024))
    elseif bytes > 1024 then
      return string.format("%.1f KiB", bytes / 1024)
    else
      return string.format("%d B", bytes)
    end
  end

  -- 安全解析磁碟使用量
  local function safeParseFS(mount)
    -- 組合命令，呼叫外掛腳本
    local cmd = string.format("${execpi 5 ~/.config/conky/beny-conky/get_fs.sh %s}", mount)
    local result = conky_parse(cmd) or ""
    
    -- 嘗試解析輸出格式 used|total|perc
    local fs_used, fs_total, fs_perc = string.match(result, "([^|]+)|([^|]+)|([^|]+)")
    
    -- 防呆：如果解析失敗，給預設值
    if not fs_used or not fs_total or not fs_perc then
      fs_used, fs_total, fs_perc = "0", "0", "0"
    end
    
    return tonumber(fs_used) or 0, tonumber(fs_total) or 0, tonumber(fs_perc) or 0
  end

  -- 安全解析磁碟使讀寫量
  local function safeParseDiskIO()
    local cmd = conky_parse("${execpi 1 ~/.config/conky/beny-conky/get_diskio.sh}")
    local result = conky_parse(cmd) or ""
    local read_b, write_b = string.match(result, "([^|]+)|([^|]+)")
    if not read_b or not write_b then
      read_b, write_b = "0", "0"
    end
    return tonumber(read_b) or 0, tonumber(write_b) or 0
  end


  -- text for disks usage
  local radius, y, i = scale(56.5), pos.y + scale(8), 0
  local gauge_center = {x = pos.x + radius + 3.5, y = pos.y + radius + 3.5}
  local leftTextX = pos.x + radius + scale(13.5)
  local rightTextX = pos.x + width
  local gauge_from = 180
  local gauge_to = 360
  if config.gaugeLoc == 'right' then
    gauge_center.x = width - radius - 3.5
    gauge_from = 0
    gauge_to = 180
    leftTextX = pos.x
    rightTextX = pos.x + width - radius - scale(10)
  end
  
  -- 讀取sort後的各磁碟資料作顯示
  for _, name in pairs(sort) do
    local mount = disks[name]

    i = i + 1 --限制最多3項顯示
    if i > 4 then break end

    -- 解析輸出格式 used|total|perc
    local fs_used, fs_total, fs_perc = safeParseFS(mount)
    -- print("looping : " .. name .. " used=" .. fs_used .. " total=" .. fs_total .. " perc=" .. fs_perc) --debug
    write(cr, name, {
      pos = {x = leftTextX, y = y},
      font = {settings.fonts.default, scale(12)},
      color = settings.colors.default,
      align = {'left'},
    })
    write(cr, formatBytes(fs_used) .. " / " .. formatBytes(fs_total), {
      pos = {x = rightTextX, y = y},
      font = {settings.fonts.default, scale(12)},
      color = settings.colors.default,
      align = {'right'},
    })
    gauge(cr, tonumber(fs_perc), {
      pos = gauge_center,
      radius = radius, thickness = scale(7),
      from = gauge_from, to = gauge_to,
      background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
      color = settings.colors.gauge,
      alpha = settings.colors.gaugeAlpha,
      warn = {from = 85, color = settings.colors.gaugeInfo},
      crit = {from = 98, color = settings.colors.gaugeCrit},
    })
    radius = radius - scale(12)
    y = y + scale(12)
  end

  -- graph for disk activity (read + write)
  local graph_x = gauge_center.x + scale(50)
  local graph_width = width - graph_x
  local graph_direction = 'right'
  local rw_text_x = graph_x
  if config.gaugeLoc == 'right' then
    graph_x = gauge_center.x - scale(50)
    graph_width = graph_x
    graph_direction = 'left'
    rw_text_x = pos.x
  end

  local read_b, write_b = safeParseDiskIO()
  y = y + scale(4)
  write(cr, 'Read:' .. formatBytes(read_b) .. '/s', {
    pos = {x = rw_text_x, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'left'},
  })
  y = y + scale(18)
  graph(cr, 'disk', read_b, {
    pos = {x = graph_x, y = y},
    direction = graph_direction, amplitude = 'up',
    color = settings.colors.gauge,
    alpha = 0.9, width = graph_width, height = scale(15),
    max = 'auto',
  })
  y = y + scale(3)
  graph(cr, 'disk_write', write_b, {
    pos = {x = graph_x, y = y},
    direction = graph_direction, amplitude = 'down',
    color = settings.colors.gauge,
    alpha = 0.9, width = graph_width, height = scale(15),
    max = 'auto',
  })
  y = y + scale(18) + scale(12)
  write(cr, 'Write:' .. formatBytes(write_b) .. '/s', {
    pos = {x = rw_text_x, y = y},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'left'},
  })

  -- icon for hard disk
  local icon_x = gauge_center.x + scale(10)
  if config.gaugeLoc == 'right' then
    icon_x = gauge_center.x - scale(40)
  end
  -- if font is not found, fall back to text 'DISK'
  local text = '\u{f02ca}'
  local font = {settings.icon_font, scale(40)}
  local icon_y = gauge_center.y
  if not isIconFontAvailable then
    text = 'DISK'
    font = {settings.fonts.significant, scale(15), 1}
    icon_y = gauge_center.y + scale(10)
  end
  write(cr, text, {
    pos = {x = icon_x, y = icon_y},
    font = font,
    color = settings.colors.default,
    align = {'left', 'top'},
  })

  -- 舊代碼用conky變量，保留作參考
  -- local used = conky_parse('${fs_used ' .. mount .. '}'):pad(7, ' ', 'STR_PAD_LEFT')
  -- local total = conky_parse('${fs_size ' .. mount .. '}'):pad(7, ' ', 'STR_PAD_LEFT')
  -- write(cr, fs_used .. ' / ' .. fs_total, {
  -- gauge(cr, tonumber(conky_parse('${fs_used_perc ' .. mount .. '}')), {
  -- local read_str = conky_parse('${diskio_read}')
  -- local disk_read = parseDiskioValue(read_str)
  -- write(cr, 'Read:' .. disk_read, {
  -- local write_str = conky_parse('${diskio_write}')
  -- local disk_write = parseDiskioValue(write_str)
  -- write(cr, 'Write:' .. disk_write, {

end

function updateLoad(config)
  local pos = config.pos or {x = 0, y = scale(340)}

  local load1m = conky_parse('${loadavg 1}')
  local load5m = conky_parse('${loadavg 2}')
  local load15m = conky_parse('${loadavg 3}')
  local cpuCount = getCpuCount()
  local max = config.max or (cpuCount * 2)
  local warn = config.warn or cpuCount
  local crit = config.crit or (cpuCount * 1.1)

  -- gauges
  gauge(cr, tonumber(load1m), {
    pos = {x = pos.x+scale(8), y = pos.y+scale(500)},
    radius = scale(484), thickness = scale(16),
    from = 0.4, to = 35,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = max,
    warn = {from = warn, color = settings.colors.gaugeWarn},
    crit = {from = crit, color = settings.colors.gaugeCrit},
  })
  gauge(cr, tonumber(load5m), {
    pos = {x = pos.x+scale(8), y = pos.y+scale(500)},
    radius = scale(470), thickness = scale(8),
    from = 0.1, to = 33,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = max,
    warn = {from = warn, color = settings.colors.gaugeWarn},
    crit = {from = crit, color = settings.colors.gaugeCrit},
  })
  gauge(cr, tonumber(load15m), {
    pos = {x = pos.x+scale(8), y = pos.y+scale(500)},
    radius = scale(462), thickness = scale(4),
    from = 0, to = 31,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = max,
    warn = {from = warn, color = settings.colors.gaugeWarn},
    crit = {from = crit, color = settings.colors.gaugeCrit},
  })

  -- label
  write(cr, 'Load average', {
    pos = {x = pos.x+scale(2), y = pos.y+scale(58)},
    font = {settings.fonts.significant, scale(18), 0},
    color = settings.colors.highlight,
    align = {'left', 'top'},
  })

  -- text
  -- load1m = load1m:pad(5, ' ')
  -- load5m = load5m:pad(5, ' ')
  -- load15m = load15m:pad(5, ' ')
  write(cr, '1m ' .. load1m .. ' | 5m ' .. load5m .. ' | 15m ' .. load15m, {
    pos = {x = pos.x+scale(2), y = pos.y + scale(94)},
    font = {settings.fonts.default, scale(12)},
    color = settings.colors.default,
    align = {'left', 'top'},
  })
end