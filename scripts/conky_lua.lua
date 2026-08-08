-------------------------------------------------------------------------------
-- 1. 基礎工具區塊 (最先執行)
-------------------------------------------------------------------------------
-- 定義一個全域變數來存儲縮放率，方便各處存取
-- 如果之後想動態修改，只需更新這個值
_G.global_scaling = 1.1

-- 定義全域 scale 函數
function _G.scale(n)
    return math.floor(n * (_G.global_scaling or 1))
end

function mtime()
  return math.floor(os.time() * 1000) -- + socket.gettime() * 1000
end

-- 僅供參考，沒有使用到。
function os.capture(cmd)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  return s
end

function conky_parse_num(expr)
  local res = conky_parse("${" .. expr .. "}")
  if res == nil then return 0 end
  -- 使用 string.match 只提取數字部分，防止帶有單位（如 % 或 MiB）導致 tonumber 失敗
  return tonumber(res:match("[%d%.]+")) or 0
end

-- 工具函數：創建顏色，參數為 紅, 綠, 藍, 透明度 (範圍均為 0-1)
function rgba_to_r_g_b_a(color)
  return color[1], color[2], color[3], color[4]
end

-- function getOsIcon() -- this is only tested on fedora -- 抄自 jinli-conky
-- 	--local distro = os.capture('lsb_release -is'):lower():match('^%s*(.-)%s*$')
-- 	local osName = io.popen('lsb_release -is'):read('*l') or 'linux'
-- 	local distro = osName:lower():match('^%s*(.-)%s*$')
-- 	local icon_map = {
-- 		fedora = '\u{f30a}',
-- 		ubuntu = '\u{f0548}',
-- 		deepin = '\u{f321}',
-- 		archlinux = '\u{f303}',
-- 		manjaro = '\u{f312}',
-- 		debian = '\u{e77d}',
-- 		archcraft = '\u{f345}',
-- 		mint = '\u{f08ed}',
-- 		linuxmint = '\u{f08ed}',
-- 		nixos = '\u{f313}',
-- 		gentoo = '\u{f30d}',
-- 		elementary = '\u{f309}',
-- 		endeavour = '\u{f322}',
-- 		centos = '\u{f304}',
-- 		pop_os = '\u{f32a}',
-- 		suse = '\u{ef6d}',
-- 		kubuntu = '\u{f333}',
-- 		raspberry = '\u{f315}',
-- 	}
-- 	print("Distro detected: " .. distro)
-- 	local icon = icon_map[distro] or '\u{ebc6}' -- default linux icon
-- 	return icon
-- end

function getOsIcon()
  local osName = 'linux'

  local f = io.open('/etc/os-release', 'r')
  if f then
    for line in f:lines() do
      -- 匹配 ID=ubuntu 或 ID="ubuntu"，並排除 VERSION_ID, ID_LIKE 等
      local id = line:match('^ID="?([%w_%-]+)"?')
      if id then
        osName = id
        break
      end
    end
    f:close()
  end

  local distro = osName:lower()

  -- 清除任何潛在的空白或隱藏字元
  distro = distro:gsub('%s+', '')

  local icon_map = {
    fedora = '\u{f30a}',
    linuxmint = '\u{f30e}', -- Mint, also f08ed
    ubuntu = '\u{f320}', -- Budgie
    arch = '\u{f303}',
    debian = '\u{f306}',
    pop = '\u{f32a}', -- Pop!_OS
    linux = '\u{f31b}',
  }

  local icon = icon_map[distro] or icon_map['linux']
  print("Distro detected: [" .. distro .. "]")
  print("Icon selected: " .. icon)

  return icon
end

local width, height, dpi = scale(360), scale(800), 96

conky.config = {
    -- 基本設定
    background = false,
    update_interval = 1,
    double_buffer = true,
    no_buffers = true,
    use_xft = true,
    draw_borders = false,

    -- GNOME 專用視窗設定（穩定透明）
    own_window = true,
    own_window_type = 'normal',
    own_window_hints = 'undecorated,sticky,below,skip_taskbar,skip_pager',
    -- own_window_transparent = false,
    -- own_window_argb_visual = true,
    -- own_window_argb_value = 0,
    -- own_window_colour = '#0b0d18',
    -- own_window_colour = '#000000',
    -- 以上語法，在新版conky(1.24> ?)將不再使用。
    own_window_colour = '#10000040',
    -- own_window_colour = '#1E1E2E80',
    -- own_window_colour = '#2E344099',
    -- own_window_colour = '#00000000',

    -- 字體與顏色
    default_color = 'skyblue',

    -- 位置與大小
    alignment = 'top_right',
    gap_x = 20,
    gap_y = 10,
    border_inner_margin = 0,
	  border_outer_margin = 0,
    minimum_width = math.ceil(width / dpi * 96),
    minimum_height = math.ceil(height / dpi * 96),

    -- 載入 Lua 腳本
    lua_load = '/home/beny/.config/conky/scripts/main.lua',
    lua_draw_hook_pre = 'main', -- 可以不用寫做 conky_main

};

conky.text = [[
]];

conky.beny = {
	scaling = _G.global_scaling,
	icon_font = 'Symbols Nerd Font',
	widgets = {
		clock = {
			hide = false,
			pos = {x = scale(15), y = scale(30)},
			showDate = true,
			timeFormat = '%H:%M:%S',
			dateFormat = '%A, %e %B',
			osIcon = getOsIcon(),
		},
		system = {
			hide = false,
			pos = {x = scale(10), y = scale(90)},
		},
		cpumem = {
			hide = false,
			pos = {x = scale(10), y = scale(225)},
			gaugeLoc = 'right', -- left, right
			top = 7,
		},
		sound = {
			hide = false,
			pos = {x = scale(10), y = scale(335)},
			gaugeLoc = 'right', -- left, right
			top = 3,
		},
		network = {
			hide = false,
			pos = {x = scale(10), y = scale(440)},
			gaugeLoc = 'left', -- left, right
			network = 'auto', -- network name 'eth0'
			showIpv6 = false,
		},
		disks = {
			hide = false,
			pos = {x = scale(10), y = scale(605)},
			gaugeLoc = 'right', -- left, right
			-- disks = {Home = '/home', Root = '/'}
			disks = 'auto',
			exclude = {'/var/lib/docker', 'fast.workspace', '/boot/efi'},
			include = {MyCloud = '/media/mycloud/benyuenkc', public = '/media/mycloud/public'}
			-- sort = {NAS, Home, Root}
		},
    weather = {
      hide = false,
			pos = {x = scale(50), y = scale(665)},  
    },
		other = {
			hide = false,
			pos = {x = scale(50), y = scale(735)},
			--max = 2,
			--warn = 2,
			--crit = 4,
		},
	},
	fonts = {
		-- default = 'DejaVu Sans Mono',
		default = 'Noto Sans Mono CJK HK',
		-- default = 'JetBrains Mono',
		significant = 'JetBrains Mono',
		ckj = 'Noto Sans Mono CJK HK',
	},
	colors = {
		default = {1.0, 1.0, 0.8, 1.0},
		-- highlight = {1.0, 1.0, 0.0, 1.0},
		-- gaugeBg = {1.0, 1.0, 0.8, 1.0},
		-- gaugeBgAlpha = 0.1,
		-- gauge = {0.5, 0.5, 0.5, 1},
		-- gaugeAlpha = 0.8,
		-- gaugeInfo = {0.0, 1.0, 0.0, 1.0},
		-- gaugeWarn = {1.0, 1.0, 0.0, 1.0},
		-- gaugeCrit = {1.0, 0.0, 0.0, 1.0},
    R = {1.0, 0.0, 0.0, 1.0},
    Y = {1.0, 1.0, 0.0, 1.0},
    G = {0.0, 1.0, 0.0, 1.0},
    B = {0.0, 0.0, 1.0, 1.0},
    O = {1.0, 0.65, 0.0, 1.0},
    OW = {1.0, 1.0, 0.8, 1.0},
    LG = {0.6, 1, 0.6, 1},
    GR = {0.5, 0.5, 0.5, 1},
    SB = {0.53, 0.81, 0.92, 1.0}, -- SkyBlue
    DSB = {0.00, 0.75, 1.00, 1.0}, -- DeepSkyBlue
    MB = {0.45, 0.76, 0.98, 1.0}, -- Maya Blue
	},
}