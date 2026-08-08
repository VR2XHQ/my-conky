-- package.path = package.path .. ";" .. os.getenv("HOME") .. "/.config/conky/?.lua"
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.config/conky/scripts/?.lua"

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
require 'conky_lua'
local settings, cache = conky.beny, {}
local cr, width, height, updates
local Col = settings.colors
local icon_font = settings.icon_font
local icon_size = scale(30)
local icon_col = Col.LG
local dash_col = Col.GR


-- ==========================================
-- 1. 模組導入 (Require Modules)
-- ==========================================
local draw = require('conky_draw_lib')
local fetcher = require('data_fetcher')

-- ==========================================
-- 2. 靜態配置與全域/持久變數 (Config & Persistence)
-- ==========================================
local isIconFontAvailable = fetcher.font_exists(icon_font or 'Symbols Nerd Font')
-- 在腳本頂部定義一次即可
local cpu_cores = tonumber(io.popen("nproc"):read("*all")) or 1
local updateWidget
local updateClock
local updateSystem
local updateCpuMem
local updateSound
local updateNetwork
local updateDisks
local updateOther

local cache_ifaces = {}

-- 【重要】定義在函數外面，作為持久快取
local net_stats = { 
  today_rx="0 B", today_tx="0 B", today_total="0 B", 
  month_rx="0 B", month_tx="0 B", month_total="0 B" 
}

-- 定義在函數外部，數據會一直保留在記憶體中
local disk_cache = {
  root = { pct = 0, used = "0B", size = "0B" },
  home = { pct = 0, used = "0B", size = "0B" }
}

local weather_cache = {}
local last_weather_update = 0
local weather_interval = 600 -- 每 10 分鐘 (600秒) 更新一次
local is_updating = false -- 門戶鎖，防止重疊執行

-- local scroll_pos = 0 -- 滾動位置

-- ==========================================
-- 3. 內部工具函數 (Internal Local Functions)
-- ==========================================
-- 動態讀取 Caps Lock 與 Num Lock 狀態（相容 Wayland / X11 及跨機器）
local function get_led_state(led_name)
    -- 利用 grep 檢查所有 matching 檔案中是否有任意一個值為 1
    local handle = io.popen("grep -h '1' /sys/class/leds/input*::" .. led_name .. "/brightness 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    -- 如果有拿到 '1'，代表該鎖定鍵為開啟狀態
    return (result and result:find("1")) and "On" or "Off"
end


-- ==========================================
-- 4. Conky 主接口 (Main Entry Point)
-- ==========================================
function conky_main()
  if conky_window == nil then return end
  -- 在 function conky_main() 內部起始處
  if settings == nil or settings.colors == nil then 
    print("Warning: settings not loaded yet.")
    return 
  end

  local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
  local cr = cairo_create(cs)
  
  -- 【關鍵步驟】獲取目前的視窗寬高並繪製背景
  draw.background(cr, conky_window.width, conky_window.height)
  
   -- local start = mtime()
  for widget, config in pairs(settings.widgets) do
    updateWidget(cr, widget, config)
  end

  -- 清理
  cairo_destroy(cr)
  cairo_surface_destroy(cs)
  collectgarbage("step") -- 執行一小步垃圾回收，比 "collect" 更省 CPU
end


updateWidget = function(cr, widget, config)
  if config.hide ~= nil and config.hide == true then
    return
  end
  local start = mtime()
  if widget == 'clock'   then updateClock(cr, config)   end
  if widget == 'system'  then updateSystem(cr, config)  end
  if widget == 'cpumem'  then updateCpuMem(cr, config)  end
  if widget == 'sound'   then updateSound(cr, config)   end
  if widget == 'network' then updateNetwork(cr, config) end
  if widget == 'disks'   then updateDisks(cr, config)   end
  if widget == 'weather' then updateWeather(cr, config) end
  if widget == 'other'   then updateOther(cr, config)   end
  -- print(os.date('%c') .. ' updated ' .. widget .. ' in ' .. string.format('%.2f seconds', mtime() - start))
end

updateClock = function(cr, config)
  local pos = config.pos or {x = 0, y = 0}
  local x, y = pos.x, pos.y
  local text = {f = settings.fonts.default, s = scale(16), c = Col.OW}
  local icon = {x = conky_window.width - scale(60), y = y + scale(20), f = settings.icon_font, s = scale(50), c = Col.LG}
  local line_h = scale(10)
  
  local time = os.date(config.timeFormat or '%H:%M') --conky_parse('${time %H:%M:%S}')
  local date = os.date(config.dateFormat or '%A, %b %e') --conky_parse('${time %Y-%m-%d}')
  --local caps_lock = conky_parse('${key_caps_lock}')
  --local num_lock = conky_parse('${key_num_lock}')
  local caps_lock = get_led_state("capslock")
  local num_lock  = get_led_state("numlock")
  
  if isIconFontAvailable then
    draw.text(cr, icon.x, icon.y, config.osIcon, icon.f, icon.s, icon.c)
  else
    draw.text(cr, icon.x, icon.y, "OS", text.f, text.s + scale(26), icon.c)
  end
  
  draw.text(cr, x, y, time, font, text.s + scale(12), text.c, true)
  if config.showDate == nil or config.showDate then
    draw.text(cr, x, y + line_h*2, date, text.f, text.s - scale(2), text.c, true)
  end
  
  local x_tab = x + scale(185)
  local caps_col = (caps_lock == "Off") and Col.GR or Col.O
  local num_col = (num_lock == "Off") and Col.GR or Col.O
  draw.text(cr, x_tab, y, "Caps Lock", text.f, text.s, caps_col, true)
  draw.text(cr, x_tab, y + line_h*2, "Num Lock", text.f, text.s, num_col, true)
  
  draw.line(cr, y + line_h*3, dash_col)
end

updateSystem = function(cr, config)
  local pos = config.pos or {x = 0, y = 0}
  local x, y = pos.x, pos.y
  local text = {f = settings.fonts.default, s = scale(14), c = Col.SB}
  local icon = {x = x + scale(5), y = y + scale(5), f = settings.icon_font, s = scale(40), c = Col.LG}
  local x_tab = x + scale(80)
  local line_h = scale(20)

  local nodename = conky_parse('${nodename}')
  local kernel = conky_parse('${kernel}')
  local uptime = conky_parse('${uptime}')
  local loadavg = conky_parse('${loadavg}')
  local processes = conky_parse('${processes}')
  local running_processes = conky_parse('${running_processes}')
  --local id = conky_parse('${execi 3600 lsb_release -irs}')
  --id = id:gsub('\n', ' '):gsub('^%s*(.-)%s*$', '%1') -- 取得 OS 資訊並立即清理換行
  -- 替代方案（更快 ，不需執行外部指令）
  local id = conky_parse("${execi 3600 grep '^PRETTY_NAME=' /etc/os-release | cut -d'\"' -f2}")
  
  draw.text(cr, icon.x, icon.y, "\u{f0aab}", icon.f, icon.s, icon.c, true)
  draw.text(cr, x_tab, y, id, text.f, text.s + scale(4), Col.OW, true)
  draw.text(cr, x, y + line_h*1, "Hostname:", text.f, text.s, text.c)
  draw.text(cr, x_tab, y + line_h*1, nodename, text.f, text.s, text.c)
  draw.text(cr, x, y + line_h*2, "Kernel:", text.f, text.s, text.c)
  draw.text(cr, x_tab, y + line_h*2, kernel, text.f, text.s, text.c)
  draw.text(cr, x, y + line_h*3, "Uptime:", text.f, text.s, text.c)
  draw.text(cr, x_tab, y + line_h*3, uptime, text.f, text.s, text.c)
  draw.text(cr, x, y + line_h*4, "Load Avg:", text.f, text.s, text.c)
  draw.text(cr, x_tab, y + line_h*4, loadavg, text.f, text.s, text.c)
  
  local run_status = string.format("Running/Processes: %2d / %3d", running_processes, processes)
  draw.text(cr, x, y + line_h*5, run_status, text.f, text.s, text.c)

  -- 1. 解析三個負載數值
  local l1, l5, l15 = loadavg:match("([^%s]+)%s+([^%s]+)%s+([^%s]+)")
  -- 使用真實的核心數（例如 8 或 16）
  local n_cores = cpu_cores or 8
  
  -- 2. 設定弧形的位置 (放在 widget 右側空白處)
  local arc_x = x + scale(300) 
  local arc_y = y + scale(50)
  
  -- 3. 繪製三層弧形 (1min, 5min, 15min)
  -- 假設負載 4.0 對於 8 核 CPU 是 50%
  local p1 = (tonumber(l1) or 0) / n_cores * 100
  local p5 = (tonumber(l5) or 0) / n_cores * 100
  local p15 = (tonumber(l15) or 0) / n_cores * 100
  
  -- 從內到外畫三圈
  draw.draw_arc_gauge(cr, arc_x, arc_y, scale(22), p15, Col.G, scale(4)) -- 15min: 綠
  draw.draw_arc_gauge(cr, arc_x, arc_y, scale(30), p5,  Col.Y, scale(4)) -- 5min: 黃
  draw.draw_arc_gauge(cr, arc_x, arc_y, scale(38), p1,  Col.R, scale(4)) -- 1min: 紅
  
  -- 4. 在中心標註 "Load" 文字
  draw.text(cr, arc_x - scale(15), arc_y + scale(5), "LOAD", text.f, text.s - scale(0), Col.OW, true)
  
  draw.line(cr, y + line_h*6 - scale(10), dash_col)
end
  
updateCpuMem = function(cr, config)
  local pos = config.pos or {x = 0, y = 0}
  local x, y = pos.x, pos.y
  local text = {f = settings.fonts.default, s = scale(14), c = Col.OW}
  local icon = {x = x + scale(5), y = y + scale(25), f = settings.icon_font, s = scale(35), c = Col.LG}
  local x_tab = scale(60)
  local line_h = scale(20)
  local grid = {x=70, y=20}

  local acpitemp = conky_parse('${acpitemp}')
  local cpu_temp = fetcher.get_cpu_temp()
  
  draw.text(cr, icon.x, icon.y, "\u{f4bc}", icon.f, icon.s, icon.c, false)
  draw.cpu_grid(cr, x + x_tab, y + line_h, grid, settings.colors, text.f, cpu_cores)
  
  -- 定義標籤寬度（例如固定佔 14 個字元）
  -- %-14s 代表靠左對齊，佔 14 格
  local label_acpi    = string.format("%-14s: %s°C", "ACPI Temp", acpitemp)
  local label_package = string.format("%-14s: %s", "Package Temp", cpu_temp)
  draw.text(cr, x, y + line_h*3, label_acpi, text.f, text.s, text.c)
  draw.text(cr, x, y + line_h*4, label_package, text.f, text.s, text.c)
  
  draw.line(cr, y + line_h*5 - scale(10), dash_col)
end

updateSound = function(cr, config)
  local pos = config.pos or {x = 0, y = 0}
  local x, y = pos.x, pos.y
  local text = {f = settings.fonts.default, s = scale(12), c = Col.OW}
  local icon = {x = x + scale(5), y = y + scale(15), f = settings.icon_font, s = scale(35), c = Col.LG}
  local line_h = scale(20)
  local tab1 = x + scale(60)
  local tab2 = x + scale(130)
  local updates = conky_parse_num('updates') or 0

  if updates % 5 == 0 then
    sink_desc = fetcher.get_sink_description() or "N/A"
    sink_port = fetcher.get_sink_port() or "N/A"
  end
  if updates % 2 == 0 then
    current_R_vol = fetcher.get_R_volume()
    current_L_vol = fetcher.get_L_volume()
    out_status = fetcher.get_output_status()
    in_status = fetcher.get_input_status()
  end
  
  local out_icon = (out_status == "muted") and "\u{f057f}" or "\u{f057e}"
  local in_icon  = (in_status == "muted")  and "\u{f036d}" or "\u{f036c}"

  
  draw.text(cr, icon.x, icon.y, "\u{e638}", icon.f, icon.s, icon.c, false)
  draw.text(cr, icon.x, icon.y + scale(40), out_icon, icon.f, scale(20), Col.SB)
  draw.text(cr, icon.x + scale(25), icon.y + scale(40), in_icon, icon.f, scale(20), Col.SB)
  draw.text(cr, tab1, y, sink_desc, text.f, text.s, text.c)
  draw.text(cr, tab1, y + line_h*1, "Port: " .. sink_port, text.f, text.s, text.c)
  draw.text(cr, tab1, y + line_h*2, "Volume R", text.f, text.s + scale(2), text.c)
  draw.text(cr, tab1, y + line_h*3, "Volume L", text.f, text.s + scale(2), text.c)
  
  local vol_color_R = (current_R_vol > 66) and Col.R or (current_R_vol > 33) and Col.Y or Col.G
  draw.bar_with_text(cr, tab2, y + line_h*1 + scale(10), scale(150), scale(12), current_R_vol, vol_color_R, {size=text.s, font=text.f})
  
  local vol_color_L = (current_L_vol > 66) and Col.R or (current_R_vol > 33) and Col.Y or Col.G
  draw.bar_with_text(cr, tab2, y + line_h*2 + scale(10), scale(150), scale(12), current_L_vol, vol_color_L, {size=text.s, font=text.f})
  
  draw.line(cr, y + line_h*4 - scale(10), dash_col)
end

updateNetwork = function(cr, config)
  local pos = config.pos or {x = 10, y = 450}
  local x, y = pos.x, pos.y
  local text = {f = settings.fonts.default, s = scale(16), c = Col.OW}
  local icon = {x = x + scale(5), y = y, f = settings.icon_font, s = scale(30), c = Col.LG}
  local speed = {f = settings.fonts.default, s = scale(12), c = Col.DSB}
  local line_h_t = scale(40)
  local tab1 = x + scale(50)
  local tab2 = x + scale(160)
  local tab3 = x + scale(270)
  local updates = conky_parse_num('updates') or 0
  
  if updates % 10 == 0 or #cache_ifaces == 0 then
    cache_ifaces = fetcher.get_all_active_interfaces()
  end
  
  -- 如果完全沒有活動介面
  if #cache_ifaces == 0 then
    draw.text(cr, icon.x, icon.y, "Network: Disconnected", text.f, scale(18), Col.R)
    return
  end
  
  -- 遍歷所有活動介面並繪製
  for i, iface in ipairs(cache_ifaces) do
    local y_offset = (i - 1) * line_h_t
    local Icon = (iface.type == "wifi") and "\u{f16bb}" or "\u{f0c54}"
    
    -- 如果沒有 IP (代表介面未連線)，顯示為灰色
    local color = (iface.ip == "No Address" or iface.ip == "") and Col.GR or Col.OW
    
    -- 繪製圖標與名稱
    draw.text(cr, icon.x, icon.y + y_offset, Icon, icon.f, icon.s, icon.c)
    draw.text(cr, tab1, icon.y + y_offset, iface.name, text.f, text.s, color)
    
    -- 繪製 IP 地址
    draw.text(cr, tab2, icon.y + y_offset, iface.ip, text.f, text.s, color)
    
    -- 繪製該介面的瞬時流量 (選配)
    local down, up = fetcher.get_net_speed(iface.name)
    draw.text(cr, tab3, icon.y + y_offset-scale(12), "D: " .. down, speed.f, speed.s, speed.c)
    draw.text(cr, tab3, icon.y + y_offset, "U: " .. down, speed.f, speed.s, speed.c)
  end
  
  -- 每 60 秒更新一次，其餘時間會保留上一次的結果  
  if updates % 60 == 0 or updates <= 1 then
    local new_data = fetcher.get_vnstat_data()
    -- 確保抓到資料才覆蓋快取
    if new_data and new_data.today_rx ~= "N/A" then
      net_stats = new_data
    end
  end
  
  local x = x + scale(10)
  local y = y + scale(70)
  local tab4 = x + scale(120)
  local line_h = scale(20)
  local text = {f = settings.fonts.default, s = scale(12), c = Col.SB}

  -- 今日數據
  draw.text(cr, x, y, "Today RX/TX:", text.f, text.s, text.c)
  draw.text(cr, tab4, y, net_stats.today_rx .. " / " .. net_stats.today_tx, text.f, text.s, text.c)
  draw.text(cr, x, y + line_h*1, "Today Total:", text.f, text.s, text.c)
  draw.text(cr, tab4, y + line_h*1, net_stats.today_total, text.f, text.s, text.c)
  -- 本月數據
  draw.text(cr, x, y + line_h*2, "Month RX/TX:", text.f, text.s, text.c)
  draw.text(cr, tab4, y + line_h*2, net_stats.month_rx .. " / " .. net_stats.month_tx, text.f, text.s, text.c)
  draw.text(cr, x, y + line_h*3, "Month Total:", text.f, text.s, text.c)
  draw.text(cr, tab4, y + line_h*3, net_stats.month_total, text.f, text.s, text.c)
  
  draw.line(cr, y + line_h*4 - scale(10), dash_col)
end

updateDisks = function(cr, config)
  local pos = config.pos or {x = 10, y = 450}
  local x, y = pos.x, pos.y
  local text = {f = settings.fonts.default, s = scale(16), c = Col.OW}
  local icon = {x = x + scale(5), y = y + scale(15), f = settings.icon_font, s = scale(35), c = Col.LG}
  local line_h = scale(20)
  local tab1 = x + scale(50)
  local tab2 = x+ scale(280)
  local bar = {offset = scale(15), w = scale(60), h = scale(15)}
  local updates = conky_parse_num('updates') or 0
  
  local function draw_disk_cached_block(cr, x, y, data, label)
    -- 1. 繪製文字標籤與數值 (例如: Root: 20G / 100G)
    local disk_text = string.format("%s: %s / %s", label, data.used, data.size)
    draw.text(cr, tab1, y, disk_text, text.f, text.s, text.c)
    
    -- 2. 繪製進度條 (位於文字下方 8 像素)
    -- 超過 90% 自動變紅色
    local bar_color = (data.pct > 80) and Col.R or (data.pct > 40) and Col.Y or Col.G
    draw.bar_with_text(cr, tab2, y - bar.offset, bar.w, bar.h, data.pct, bar_color,{show=false})
  end

  draw.text(cr, icon.x, icon.y, "\u{f02ca}", icon.f, icon.s, icon.c, false)

 -- Show disk info
  -- 每 10 秒才去抓一次資料
  if updates % 10 == 0 or updates <= 1 then
    disk_cache.root = fetcher.get_disk_info("/")
    disk_cache.home = fetcher.get_disk_info("/home")
  end
  -- 繪製時，直接讀取快取中的內容 (每一秒都會執行繪圖，但讀取的是舊資料)
  draw_disk_cached_block(cr, x, y+line_h*0, disk_cache.root, "Root")
  draw_disk_cached_block(cr, x, y+line_h*1, disk_cache.home, "Home")
  
  draw.line(cr, y + line_h*2 - scale(10), dash_col)
end

updateWeather = function(cr, config)
  local pos = config.pos or {x = 50, y = 750}
  local x, y = pos.x, pos.y
  local font = settings.fonts.default
  local updates = conky_parse_num('updates') or 0

  -- 2026 優化版更新邏輯
  -- 1. 只有當 updates > 5 (避開啟動瞬間的閃爍)
  -- 2. 且距離上次更新超過間隔
  -- 3. 且目前不在更新中
  if updates > 5 and (os.time() - last_weather_update) > weather_interval then
    if not is_updating then
      is_updating = true
      weather_cache = fetcher.get_hko_weather()
      last_weather_update = os.time()
      is_updating = false
    end
  end
  
  -- 針對啟動時還沒拿到數據的情況，預設顯示
  if #weather_cache == 0 and updates <= 5 then
    weather_cache = {"天氣數據載入中..."}
  end
  
  draw.text(cr, x, y, "Weather (香港天文台)", font, scale(22), Col.LG, true)
  
  -- 繪製天氣 (逐行)
  for i, line in ipairs(weather_cache) do
    draw.text(cr, x, y + scale(35) + (i-1)*22, line, font, scale(18), Col.LG)
  end
  
  draw.line(cr, y + scale(45), dash_col)
end

updateOther = function(cr, config)
  local pos = config.pos or {x = 50, y = 750}
  local x, y = pos.x, pos.y  
  local font = settings.fonts.default

  -- 3. 平滑滾動：Conky 版本資訊
  -- local version_text = "Conky Version : " .. conky_version
  -- local x_limit = 250 -- 滾動區域寬度
  -- local x_start = 50
  -- local y_pos = voffset+100

  -- 計算位移 (每幀移動 1 像素，數值越大滾越快)
  -- scroll_pos = scroll_pos + 20
  
  -- 使用 Cairo 的 Clip 功能限制顯示區域
  -- cairo_save(cr)
  -- cairo_rectangle(cr, x_start, y_pos - 15, x_limit, 25) -- 定義顯示窗口
  -- cairo_clip(cr)
  
  -- 繪製文字，X 座標會隨時間減少
  -- 當文字完全移出左側後，重置到右側
  -- local text_width = 250 -- 預估寬度
  -- local x_draw = x_start + x_limit - (scroll_pos % (x_limit + text_width))
  
  -- 這是平滑滾動的核心公式
  -- x_draw = 區域起始點 + 區域寬度 - (目前更新次數 * 速度 % (區域寬度 + 文字預估寬度))
  -- local scroll_speed = 50 -- 每秒移動 2 像素
  -- local x_draw = x_start + x_limit - ((updates * scroll_speed) % 550) 

  -- draw.text(cr, x_draw, y_pos, version_text, "DejaVu Sans Mono", 16, Col.Y)
  -- cairo_restore(cr)
  

  -- 平滑滾動設定
  local scroll_area_x = x     -- 滾動區域的起始 X
  local scroll_area_y = y     -- 滾動區域的 Y 座標
  local scroll_area_w = scale(280)     -- 滾動區域的寬度 (文字只在這個寬度內顯示)
  local scroll_speed = scale(10)      -- 滾動速度 (像素/幀)

  local version_text = "Conky Version : " .. conky_version
  local text_w = scale(200)            -- 預估文字寬度 (可微調)

  -- 1. 儲存目前繪圖狀態
  cairo_save(cr)

  -- 2. 定義「裁切框」：文字只會出現在這個矩形內
  cairo_rectangle(cr, scroll_area_x, scroll_area_y - scale(20), scroll_area_w, scale(30))
  cairo_clip(cr) -- 執行裁切，之後的繪圖若超出此框會被隱藏

  -- 3. 計算動態 X 座標
  -- 使用 os.clock() 配合速度，能讓滾動不受 Conky update_interval 的跳動影響，更平滑
  local t = os.clock()
  local total_dist = scroll_area_w + text_w
  local offset = (t * scale(50) * scroll_speed) % total_dist
  local x_draw = scroll_area_x + scroll_area_w - offset

  -- 4. 繪製文字
  draw.text(cr, x_draw, scroll_area_y, version_text, font, scale(16), Col.SB)

  -- 5. 恢復繪圖狀態 (解除裁切框，以免影響後續繪圖)
  cairo_restore(cr)

  -- for debug
  -- local current_time = os.time()
  local current_time = os.clock()
  conky_set_update_interval(0.5)
  draw.text(cr, x + scale(50), y + scale(25), "Updated = " .. current_time, font, scale(16), Col.Y)
  draw.text(cr, x + scale(50), y + scale(45), "Update_interval = " .. conky_info.update_interval, font, scale(16), Col.Y)
  draw.text(cr, x + scale(0), y + scale(65), conky_build_info, font, scale(10), Col.Y)

end