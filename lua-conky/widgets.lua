-- widgets.lua
-- 基於DataManager的繪圖部件

require 'cairo'


local DataManager = require("data_manager")
local Config = require("setting")

local Widgets = {}

-- 建立兩個實例，擁有各自的緩存和計時器
-- 移除 local，直接賦值給 Widgets 的成員
Widgets.fast_mgr = DataManager:new(1, Config.fast_schema)   -- 1秒更新一次
Widgets.slow_mgr = DataManager:new(60, Config.slow_schema)  -- 60秒更新一次


-- 繪製帶標籤的圓環儀表
function Widgets.draw_gauge(cr, x, y, radius, value, max_value, label, unit)
    local line_width = radius * 0.15
    local bg_color = {0.1, 0.1, 0.1, 0.7}
    local fg_color = {0.0, 0.7, 0.0, 1.0}
    
    -- 根據值調整顏色（從綠到紅）
    local ratio = value / max_value
    if ratio > 0.7 then
        fg_color = {1.0, 0.5, 0.0, 1.0} -- 橙色
    elseif ratio > 0.9 then
        fg_color = {1.0, 0.0, 0.0, 1.0} -- 紅色
    end
    
    -- 繪製背景環
    cairo_set_line_width(cr, line_width)
    cairo_arc(cr, x, y, radius, 0, 2 * math.pi)
    cairo_set_source_rgba(cr, table.unpack(bg_color))
    cairo_stroke(cr)
    
    -- 繪製前景環
    local angle = ratio * 2 * math.pi
    cairo_arc(cr, x, y, radius, -0.5 * math.pi, -0.5 * math.pi + angle)
    cairo_set_source_rgba(cr, table.unpack(fg_color))
    cairo_stroke(cr)
    
    -- 繪製標籤和數值
    cairo_select_font_face(cr, "Noto Sans Mono CJK HK", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, radius * 0.5)
    cairo_set_source_rgba(cr, 0, 1, 1, 1)
    
    -- 數值
    local value_text = string.format("%.1f%s", value, unit or "")
    local extents = cairo_text_extents_t:create()
    cairo_text_extents(cr, value_text, extents)
    cairo_move_to(cr, x - extents.width/2, y + extents.height/2)
    cairo_show_text(cr, value_text)
    
    -- 標籤（較小字體）
    cairo_set_font_size(cr, radius * 0.3)
    cairo_move_to(cr, x - radius*0.9, y + radius*1.4)
    cairo_show_text(cr, label)
end

-- 繪製水平條形圖（用於網路速度等）
function Widgets.draw_bar_horizontal(cr, x, y, width, height, value, max_value, label)
    local bg_color = {0.2, 0.2, 0.2, 0.5}
    local fg_color = {0.2, 0.5, 1.0, 1.0}
    
    local fill_width = (value / max_value) * width
    
    -- 背景
    cairo_rectangle(cr, x, y, width, height)
    cairo_set_source_rgba(cr, table.unpack(bg_color))
    cairo_fill(cr)
    
    -- 前景
    cairo_rectangle(cr, x, y, fill_width, height)
    cairo_set_source_rgba(cr, table.unpack(fg_color))
    cairo_fill(cr)
    
    -- 標籤和數值
    cairo_select_font_face(cr, "Noto Sans Mono CJK HK", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, height * 1.2)
    cairo_set_source_rgba(cr, 1, 1, 0, 1)
    
    local text = string.format("%s: %d%%", label, value)
    cairo_move_to(cr, x + width + 10, y + height * 0.8)
    cairo_show_text(cr, text)
end

-- 繪製文本面板（用於系統資訊摘要）
function Widgets.draw_info_panel(cr, x, y)
    
    local lines = {
        string.format("CPU: %.1f%%", fast_data.cpu_usage),
        string.format("記憶體: %s / %s", fast_data.mem_used, fast_data.mem_max),
        string.format("下載: %s/s", fast_data.net_down),
        string.format("上傳: %s/s", fast_data.net_up),
        string.format("根目錄: %s / %s", slow_data.disk_root_used, slow_data.disk_root_size),
        string.format("家目錄: %s / %s", slow_data.disk_home_used, slow_data.disk_home_size),
        string.format("溫度: %.0f°C", fast_data.temp_cpu),
        string.format("日期: %s", slow_data.date),
        string.format("時間: %s", fast_data.time),
        string.format("運行: %s", slow_data.uptime),
    }
    
    cairo_select_font_face(cr, "Noto Sans Mono CJK HK", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, 20)
    cairo_set_source_rgba(cr, 1, 1, 0, 1)
    
    for i, line in ipairs(lines) do
        cairo_move_to(cr, x, y + (i * 30))
        cairo_show_text(cr, line)
    end
end

return Widgets