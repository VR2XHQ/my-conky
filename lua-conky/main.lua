-- main.lua
-- 主入口文件

-- 自動將當前腳本目錄加入 Lua 的搜尋路徑
local script_path = debug.getinfo(1).source:match("@(.*/)")
package.path = script_path .. "?.lua;" .. package.path

require 'cairo'
-- require 'cairo_xlib'

local Widgets = require 'widgets'

function conky_main()
    if conky_window == nil then return end
    
    local cs = cairo_xlib_surface_create(
        conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height
    )
    local cr = cairo_create(cs)
        
    -- 每次循環都呼叫更新，但 DataManager 內部會根據 interval 決定是否真的抓取
    fast_data = Widgets.fast_mgr:update_all()
    slow_data = Widgets.slow_mgr:update_all()
    
    
    -- 繪製各種部件
    Widgets.draw_gauge(cr, 100, 100, 80, fast_data.cpu_usage, 100, "CPU", "%")
    Widgets.draw_gauge(cr, 300, 100, 60, fast_data.mem_perc, 100, "記憶體", "%")

    Widgets.draw_bar_horizontal(cr, 50, 300, 200, 20, slow_data.disk_root_perc, 100, "Root")
    
    Widgets.draw_bar_horizontal(cr, 50, 330, 200, 20, slow_data.disk_home_perc, 100, "Home")

    Widgets.draw_info_panel(cr, 100, 400)
    
    -- 清理
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end