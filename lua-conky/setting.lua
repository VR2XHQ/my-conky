-- config.lua
local Config = {}

-- --- 自動偵測網卡邏輯 ---
local function get_default_interface()
    -- 尋找預設路由的網卡 (2026年 Linux 通用做法)
    local f = io.popen("ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \\K\\S+'")
    local interface = f:read("*all"):gsub("%s+", "")
    f:close()
    -- 如果偵測失敗，回退到預設值
    return (interface ~= "" and interface) or "enp2s0"
end

local active_iface = get_default_interface()

-- 高頻更新設定 (1秒)
Config.fast_schema = {
    cpu_usage = {"cpu cpu0", 0},
    mem_perc  = {"memperc", 0},
    mem_used  = {"mem", "0B"},
    mem_max   = {"memmax", "0B"},
    -- 動態注入網卡名稱
    net_down  = {"downspeed " .. active_iface, 0},
    net_up    = {"upspeed " .. active_iface, 0},
    time      = {"time %H:%M:%S", "00:00:00"},
    temp_cpu  = {"hwmon 0 temp 1", 0},
}

-- 低頻更新設定 (60秒)
Config.slow_schema = {
    disk_root_used = {"fs_used /", "0B"},
    disk_root_size = {"fs_size /", "0B"},
    disk_root_free = {"fs_free /", "0B"},
    disk_root_perc = {"fs_used_perc /", 0},
    disk_home_used = {"fs_used /home", "0B"},
    disk_home_size = {"fs_size /home", "0B"},
    disk_home_free = {"fs_free /home", "0B"},
    disk_home_perc = {"fs_used_perc /home", 0},
    uptime         = {"uptime_short", "0d 0h"},
    date           = {"time %Y-%m-%d", "2020-01-01"},
}

-- 介面外觀設定 (方便統一修改顏色和字體)
Config.colors = {
    bg = {0.1, 0.1, 0.1, 0.7},
    fg = {0.0, 0.7, 0.0, 1.0},
    warn = {1.0, 0.5, 0.0, 1.0},
    crit = {1.0, 0.0, 0.0, 1.0}
}

return Config

