-- data_manager.lua
local DataManager = {}
DataManager.__index = DataManager

-- 在 data_manager.lua 內部或外部定義
DataManager.utils = {}

-- 預設定義（作為模板，可為空）
DataManager.default_schema = {}

--- 創建新的數據管理器
-- @param update_interval 更新頻率 (秒)
-- @param schema 該實例負責的 Conky 變數定義表
function DataManager:new(update_interval, schema)
    local obj = setmetatable({}, self)
    
    obj.update_interval = update_interval or 1
    obj.data_schema = schema or DataManager.default_schema
    obj.cache = {}
    obj.last_update = 0
    
    -- 正確初始化：根據傳入的 schema 設定初始緩存值
    for key, def in pairs(obj.data_schema) do
        -- def[2] 是你在 schema 中定義的默認值 (如 0 或 "00:00:00")
        obj.cache[key] = def[2]
    end
    
    return obj
end

--- 核心更新函數
function DataManager:update_all()
    local now = os.time()
    
    -- 檢查時間間隔
    if now - self.last_update < self.update_interval then
        return self.cache
    end
    
    for key, def in pairs(self.data_schema) do
        local conky_var = def[1]
        local default_val = def[2]
        
        -- 獲取 Conky 原始數據
        local raw_value = conky_parse("${" .. conky_var .. "}")
        
        if raw_value == nil or raw_value == "" then
            self.cache[key] = default_val
        else
            -- 嘗試轉數字，若失敗（帶單位字串）則保留原樣
            local num = tonumber(raw_value)
            self.cache[key] = num or raw_value
        end
    end
    
    self.last_update = now
    return self.cache
end

--- 獲取緩存數據
function DataManager:get(key)
    return self.cache[key]
end

-- 手動設置某個數據（用於測試或自定義數據）
function DataManager:set(key, value)
  self.cache[key] = value
end

-- 強化後的格式化函數：支援處理可能是字串的情況
function DataManager.utils.format_bytes(val, decimals)
    local num = tonumber(val)
    -- 如果是字串 (如 Conky 已格式化的 "4.05GiB")，直接回傳
    if not num then return val or "0B" end 
    
    decimals = decimals or 1
    local units = {"B", "KB", "MB", "GB", "TB"}
    
    -- 自動計算單位等級：1=B, 2=KB, 3=MB, 4=GB, 5=TB
    local unit_idx = 1
    local temp_num = num
    
    while temp_num >= 1024 and unit_idx < #units do
        temp_num = temp_num / 1024
        unit_idx = unit_idx + 1
    end
    
    -- units[unit_idx] 才是正確的陣列存取方式
    return string.format("%." .. decimals .. "f %s", temp_num, units[unit_idx])
end


return DataManager