-- ~/.config/conky/scripts/conky_draw_lib.lua
local M = {}

-- cr: context, x,y: 坐標, w,h: 尺寸, pct: 數值, color: 顏色, opt: 選項
function M.bar_with_text(cr, x, y, w, h, pct, color, opt)
  -- 1. 處理參數預設 (opt 若為 nil 則設為空表)
  local opt = opt or {}
  local font_size = scale(opt.size or 14)
  local font = opt.font or "DejaVu Sans Mono"
  -- 確保 nil 時為 true，false 時為 false
  local show_text = (opt.show == nil) and true or opt.show

  -- 2. 繪製背景條 (灰色)
  cairo_set_source_rgba(cr, 0.2, 0.2, 0.2, 0.5)
  cairo_rectangle(cr, x, y, w, h)
  cairo_fill(cr)
    
  -- 3. 繪製條形圖
  -- cairo_set_source_rgba(cr, color[1], color[2], color[3], color[4])
  cairo_set_source_rgba(cr, table.unpack(color))
  cairo_rectangle(cr, x, y, (pct / 100) * w, h)
  cairo_fill(cr)
  
  -- 4. 繪製文字 (在條形圖右側 10 像素處)
  if show_text then
    cairo_select_font_face(cr, font, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, font_size)
    cairo_move_to(cr, x + w + scale(10), y + h - scale(2)) -- y 軸稍微微調以對齊中線
    cairo_show_text(cr, string.format("%d%%", pct))
    cairo_stroke(cr)
  end
end
  
-- cr: context, x, y: 坐標, text: 內容, font: 字體名稱, size: 大小, color: {r,g,b,a}, bold: 布林值
function M.text(cr, x, y, text, font, size, color, bold)
  local weight = bold and CAIRO_FONT_WEIGHT_BOLD or CAIRO_FONT_WEIGHT_NORMAL
  cairo_select_font_face(cr, font or "DejaVu Sans Mono", CAIRO_FONT_SLANT_NORMAL, weight)
  cairo_set_font_size(cr, scale(size or 12))
  cairo_set_source_rgba(cr, color[1], color[2], color[3], color[4] or 1.0)
  cairo_move_to(cr, x, y)
  cairo_show_text(cr, text)
  cairo_stroke(cr)
end

-- 獲取文字在當前縮放下的實際寬度
function M.get_text_width(cr, text, font, size, bold)
  local weight = bold and CAIRO_FONT_WEIGHT_BOLD or CAIRO_FONT_WEIGHT_NORMAL
  cairo_save(cr)
  cairo_select_font_face(cr, font or "Monaco", CAIRO_FONT_SLANT_NORMAL, weight)
  cairo_set_font_size(cr, scale(size)) -- 確保測量的是縮放後的尺寸
  local extents = cairo_text_extents_t:create()
  cairo_text_extents(cr, text, extents)
  cairo_restore(cr)
  return extents.x_advance -- x_advance 比 width 更適合用於排版位移
end

-- cr, x, y, label: 標籤內容, value: 數值內容, x_tab: 預設偏移, font, size, color
function M.draw_pair_text(cr, x, y, label, value, x_tab, font, size, color, bold)
  local gap = scale(10) -- 標籤與數值間的最小安全間隙
    local weight = bold and CAIRO_FONT_WEIGHT_BOLD or CAIRO_FONT_WEIGHT_NORMAL

  -- 1. 先測量標籤的實際寬度
  cairo_save(cr)
  cairo_select_font_face(cr, font or "Noto Sans Mono CJK HK", CAIRO_FONT_SLANT_NORMAL, weight)
  cairo_set_font_size(cr, scale(size))
  local extents = cairo_text_extents_t:create()
  cairo_text_extents(cr, label, extents)
  local label_w = extents.x_advance
  cairo_restore(cr)

  -- 2. 防撞檢查：如果標籤寬度 + 間隙 > 預設偏移，則動態推開
  local final_value_x = x + x_tab
  if label_w + gap > x_tab then
    final_value_x = x + label_w + gap
  end

  -- 3. 繪製標籤
  M.text(cr, x, y, label, font, size, color, false)
  
  -- 4. 繪製數值 (對齊動態計算後的座標)
  -- 數值通常可以用不同的顏色突出
  M.text(cr, final_value_x, y, value, font, size, Col.LG, false)
end


-- 虛線分割線
-- cr: context, x: 起點x, y: 坐標y, w: 線條長度, color: 顏色
function M.stippled_hr(cr, x, y, w, color)
  cairo_save(cr) -- 儲存狀態，避免虛線樣式影響後續繪圖
    
  -- 設定顏色與線寬
  cairo_set_source_rgba(cr, color[1], color[2], color[3], color[4] or 1.0)
  -- cairo_set_source_rgba(cr, table.unpack(color))
  cairo_set_line_width(cr, 2.0)
    
  -- 設定點狀樣式：{點的長度, 間隔長度}
  -- {2, 2} 代表 2像素線段、2像素空白，模擬 stippled 效果
  local dash = {10.0, 5.0}
  cairo_set_dash(cr, dash, 2, 0)
    
  -- 畫線
  cairo_move_to(cr, x, y)
  cairo_line_to(cr, x + w, y)
  cairo_stroke(cr)
    
  cairo_restore(cr) -- 恢復狀態（關閉虛線模式）
end
  
function M.line(cr, y, color)
  local w = conky_window.width - scale(20)
  M.stippled_hr(cr, scale(10), y, w, color)
end

-- Add utils

-- 畫背景圓角矩形 (放在 conky_main 的最前面)
function M.background(cr, w, h)
  local aspect = 1.0
  local corner_radius = 15
  local radius = corner_radius / aspect
  
  cairo_new_sub_path(cr)
  cairo_arc(cr, w - radius, radius, radius, -90 * math.pi/180, 0 * math.pi/180)
  cairo_arc(cr, w - radius, h - radius, radius, 0 * math.pi/180, 90 * math.pi/180)
  cairo_arc(cr, radius, h - radius, radius, 90 * math.pi/180, 180 * math.pi/180)
  cairo_arc(cr, radius, radius, radius, 180 * math.pi/180, 270 * math.pi/180)
  cairo_close_path(cr)

  -- 設定顏色：黑色半透明 (2026年流行的毛玻璃感建議 alpha 設在 0.3 ~ 0.5)
  cairo_set_source_rgba(cr, 0.05, 0.05, 0.1, 0.3) 
  cairo_fill(cr)
  -- 在 cairo_fill(cr) 之後加入
  cairo_set_source_rgba(cr, 1, 1, 1, 0.1) -- 極淡的白色邊框
  cairo_set_line_width(cr, 1)
  cairo_stroke(cr)
end

function M.cpu_grid(cr, x_start, y_start, grid, color, font)
  local columns = 4
  -- 預先計算 scale，避免在迴圈中反覆呼叫函數
  local x_spacing = scale(grid.x or 70) -- 每個數據之間的水平間距
  local y_spacing = scale(grid.y or 20) -- 兩行之間的垂直間距
  local font_size_label = scale(14)
  local font_size_bar = scale(18)
  -- 如果沒傳顏色進來，這裡設一個保底，避免報錯
  local c = color or { R = {1,0,0,1}, Y = {1,1,0,1}, G = {0,1,0,1} }

  -- 1. 獲取 8 核平均使用率 (cpu0)
  local cpu_avg = conky_parse_num('cpu cpu0') or 0
  
  -- 2. 決定平均值的顏色 (用於 Bar)
  local avg_color = (cpu_avg > 80) and c.R or (cpu_avg > 40) and c.Y or c.G

  -- 3. 【優化】將 Bar 移出迴圈，只畫一次
  -- 顯示 8 核平均用量
  M.bar_with_text(cr, x_start, y_start - scale(35), scale(250), scale(15), cpu_avg, avg_color, {
    size = font_size_bar,
    font = font,
    show = true
  })

  -- 4. 繪製各個核心數據
  for cpu_num = 1, 8 do  -- 通常用戶習慣看到 C1-C8，而非 C0-C7
    local val_str = conky_parse("${cpu cpu" .. cpu_num .. "}")
    local val_num = tonumber(val_str) or 0
  
    -- 計算網格坐標 (索引從 0 開始計算位置)
    local i = cpu_num - 1
    local row = math.floor(i / columns)
    local col = i % columns
    local x = x_start + (col * x_spacing)
    local y = y_start + (row * y_spacing)

    -- 核心顏色邏輯
    local core_color = (val_num > 80) and c.R or (val_num > 40) and c.Y or c.G

    -- 繪製文字
    M.text(cr, x, y, string.format("C%d:%3d%%", cpu_num, val_num), font, font_size_label, core_color, false)
  end
end

-- cr: context, x,y: 中心坐標, r: 半徑, start_angle, end_angle: 角度(0-360)
-- pct: 百分比, color: 顏色, line_width: 粗細
function M.draw_arc_gauge(cr, x, y, r, pct, color, line_width)
  -- 1. 強制檢查百分比，範圍限制在 0 ~ 100 之間，且確保不是 nil
  local pct = tonumber(pct) or 0
  if pct < 0 then pct = 0 end
  if pct > 100 then pct = 100 end
  
  local start_angle = 135 -- 起始角度（左下）
  local end_angle = 405   -- 結束角度（右下，形成 270 度的弧）
  
  -- 2. 計算結束角度
  local current_angle = start_angle + (pct / 100) * (end_angle - start_angle)
  
  -- 3. 確保 a_end 永遠大於或等於 a_start
  local a_start = start_angle * math.pi / 180
  local a_end = current_angle * math.pi / 180 -- 這裡是繪製進度條的終點

  -- 4. 繪製背景
  cairo_set_source_rgba(cr, 0.2, 0.2, 0.2, 0.3)
  cairo_set_line_width(cr, line_width)
  -- 背景弧：135度 到 405度 (固定)
  cairo_arc(cr, x, y, r, a_start, 405 * math.pi / 180)
  cairo_stroke(cr)

  -- 5. 繪製進度 (加上條件判斷，避免起始與結束相等時的異常)
  if a_end > a_start then
    cairo_set_source_rgba(cr, table.unpack(color))
    cairo_arc(cr, x, y, r, a_start, a_end)
    cairo_stroke(cr)
  end
end


  
return M
  