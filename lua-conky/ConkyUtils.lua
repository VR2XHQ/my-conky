-- 更完整的工具函數集
local ConkyUtils = {}

-- 獲取數字（帶默認值）
function ConkyUtils.get_number(expr, default)
    default = default or 0
    local value = conky_parse("${" .. expr .. "}")
    return tonumber(value) or default
end

-- 獲取字符串
function ConkyUtils.get_string(expr, default)
    default = default or ""
    local value = conky_parse("${" .. expr .. "}")
    return value or default
end

-- 獲取並格式化為百分比
function ConkyUtils.get_percentage(expr)
    local value = ConkyUtils.get_number(expr, 0)
    return string.format("%.1f%%", value)
end

-- 使用示例
local cpu = ConkyUtils.get_number("cpu cpu0")
local time = ConkyUtils.get_string("time %H:%M:%S")
local mem_display = ConkyUtils.get_percentage("memperc")


function ConkyUtils.format_percentage(num)
  if not num then return "0%" end
  return string.format("%.1f%%", num)
end