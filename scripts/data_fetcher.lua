local M = {}

-- 封裝 CPU 溫度獲取
function M.get_cpu_temp()
    -- 這裡使用 io.open 雖然程式碼多幾行，但執行效能比 execi 快 10 倍
    local f = io.open("/sys/class/hwmon/hwmon1/temp1_input", "r")
    if not f then return "N/A" end
    -- local t = f:read("*all"):gsub("%s+", "")
    local t = f:read("*line")
    f:close()
    -- return string.format("%.1f°C", tonumber(t) / 1000)
    return string.format("%.0f°C", t / 1000)
end

-- 封裝音量獲取
function M.get_R_volume()
  -- 使用 pactl 獲取預設輸出端的音量百分比
  local handle = io.popen("pactl get-sink-volume @DEFAULT_SINK@ | grep -m 1 / | awk -F/ '{print $2}' | tr -d ' %'")
  local result = handle:read("*line")
  handle:close()
  return tonumber(result) or 0
end

function M.get_L_volume()
  -- 使用 pactl 獲取預設輸出端的音量百分比
  local handle = io.popen("pactl get-sink-volume @DEFAULT_SINK@ | grep -m 1 / | awk -F/ '{print $4}' | tr -d ' %'")
  local result = handle:read("*line")
  handle:close()
  return tonumber(result) or 0
end

-- 輔助函數：修剪前後空白與換行
local function trim(s)
  return s:match("^%s*(.-)%s*$") or s
end

-- 獲取目前的 Sink 描述
function M.get_sink_description()
  -- 直接利用 Conky 內建解析，穩定且支援中文
  -- return conky_parse('${pa_sink_description}')
  -- 獲取 Sink 描述 (使用你原有的 awk 邏輯)
  local cmd = [[pactl list sinks | awk -v SINK="$(pactl get-default-sink)" '$0 ~ "Name: " SINK {found=1} found && /Description:/ {sub(/^.*Description: /, "", $0); print $0; exit}']]
  local handle = io.popen(cmd)
  local result = handle:read("*all")
  handle:close()
  return trim(result)
end

-- 獲取目前的 Port 描述
function M.get_sink_port()
  -- 這就是你想要的那行顯示，由conky取音訊變量，容易造成 core dumped
  -- return conky_parse('${pa_sink_active_port_description}')
  -- return conky_parse('${pa_sink_active_port_name}')
  -- 獲取 Sink 描述 (使用你原有的 awk 邏輯)
  -- local cmd = [[pactl list sinks | awk -v SINK="$(pactl get-default-sink)" '$0 ~ "Name: " SINK {found=1} found && /Active Port:/ {sub(/^.*Active Port: /, "", $0); print $0; exit}']]
  local cmd = [[~/.config/conky/scripts/output_type.sh]]
  local handle = io.popen(cmd)
  local result = handle:read("*all")
  handle:close()
  return trim(result)
end

-- 獲取輸出 (Sink) 靜音狀態
function M.get_output_status()
  -- @DEFAULT_SINK@ 代表目前預設輸出
  local handle = io.popen("pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null")
  local result = handle:read("*all")
  handle:close()
  
  -- 比對是否包含 "yes"
  if result:match("yes") then
    return "muted"
  else
    return "unmuted"
  end
end

-- 獲取輸入 (Source/Mic) 靜音狀態
function M.get_input_status()
  local handle = io.popen("pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null")
  local result = handle:read("*all")
  handle:close()
  
  if result:match("yes") then
    return "muted"
  else
    return "unmuted"
  end
end

-- 獲取網路流量統計 (使用 vnstat --oneline)
-- 格式通常為: 1;介面;本日RX;本日TX;本日總計;本日平均;本月RX;本月TX;本月總計...
function M.get_vnstat_data()
  local handle = io.popen("vnstat --oneline")
  local result = handle:read("*all")
  handle:close()
  
  if not result or result == "" then 
      return { today_rx="N/A", today_tx="N/A", today_total="N/A", month_rx="N/A", month_tx="N/A", month_total="N/A" }
  end

  local d = {}
  -- 使用循環匹配分號之間的內容，並存入 d
  for val in result:gmatch("([^;]+)") do
    d[#d + 1] = val:gsub("[\r\n]", "") -- 這是 Lua 中最安全的插入末尾方式
  end
  
  -- 根據你提供的輸出結果 (1;enp2s0;日期;RX;TX;Total...) 進行映射
  local stats = {
    today_rx    = d[4]  or "0 B",
    today_tx    = d[5]  or "0 B",
    today_total = d[6]  or "0 B",
    month_rx    = d[9]  or "0 B",
    month_tx    = d[10] or "0 B",
    month_total = d[11] or "0 B"
  }
  -- print("Field 4:", d[4]) -- for debug
  return stats
end

-- 獲取特定介面的下載/上傳速度
function M.get_net_speed(iface)
  -- 使用 conky_parse 獲取原生格式化字串 (如 1.2 KiB)
  local down = conky_parse("${downspeed " .. iface .. "}")
  local up = conky_parse("${upspeed " .. iface .. "}")
  return down, up
end

-- 獲取 IP 地址
function M.get_addr(iface)
  return conky_parse("${addr " .. iface .. "}")
end

-- 傳入掛載點 (如 "/" 或 "/home")，一次回傳所有數據
function M.get_disk_info(mount_point)
  return {
    pct  = tonumber(conky_parse("${fs_used_perc " .. mount_point .. "}")) or 0,
    used = conky_parse("${fs_used " .. mount_point .. "}"),
    size = conky_parse("${fs_size " .. mount_point .. "}")
  }
end

function M.get_hko_weather()
  -- 執行你的 shell 腳本並讀取結果
  local handle = io.popen("~/.config/conky/scripts/hko_weather.sh")
  local result = handle:read("*a")
  handle:close()
  -- print(result) --for debug
  
  -- 清理並按行分割，方便 Lua 逐行繪製
  local lines = {}
  for line in result:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  return lines
end

function M.font_exists(font_name)
  local handle = io.popen("fc-list | grep -i '" .. font_name .. "'")
  local result = handle:read("*a")
  handle:close()
  return result ~= ""
end

-- 獲取所有活動介面的詳細資訊列表
function M.get_all_active_interfaces()
  local handle = io.popen("ls /sys/class/net")
  local interfaces = handle:read("*a")
  handle:close()

  local active_list = {}
  
  for iface in interfaces:gmatch("%S+") do
    -- 排除本地回環介面
    if iface ~= "lo" then
      -- 檢查介面是否處於 UP 狀態 (Carrier Detected)
      local f = io.open("/sys/class/net/" .. iface .. "/operstate", "r")
      if f then
        local state = f:read("*l")
        f:close()
        
        -- 獲取 IP 地址，進一步確認是否有實際連線
        local ip = conky_parse("${addr " .. iface .. "}")
        
        if state == "up" then -- and ip ~= "No Address" and ip ~= "" then
          -- 判斷介面類型 (用於顯示圖標)
          local is_wifi = io.open("/sys/class/net/" .. iface .. "/wireless", "r") ~= nil
          table.insert(active_list, {
            name = iface,
            ip = ip,
            type = is_wifi and "wifi" or "ethernet"
          })
        end
      end
    end
  end
  return active_list
end

function M.get_iface_type(iface)
  -- 檢查是否存在 wireless 目錄
  local f = io.open("/sys/class/net/" .. iface .. "/wireless", "r")
  if f then
    f:close()
    return "wifi" --   
  else
    return "ethernet" --   
  end
end

-- 修正後的單一檢測函數
function M.get_addr_auto()
  local handle = io.popen("ls /sys/class/net")
  local interfaces = handle:read("*a")
  handle:close()

  for iface in interfaces:gmatch("%S+") do
    if iface ~= "lo" then
      local f = io.open("/sys/class/net/" .. iface .. "/operstate", "r")
      if f then
        local state = f:read("*l")
        f:close()
        if state == "up" then
          local ip = conky_parse("${addr " .. iface .. "}")
          if ip ~= "No Address" then
            return ip, iface -- 回傳兩個值
          end
        end
      end
    end
  end
  -- 【關鍵】如果都沒找到，回傳預設字串而不是 nil
  return "Disconnected", "none" 
end




return M
