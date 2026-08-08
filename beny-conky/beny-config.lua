local scaling = 1.1

function scale(n)
  return math.floor(n * scaling)
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

local width, height, dpi = scale(280), scale(1000), 96
local default, primary, warn, crit = 0xffffff, 0x00bfa5, 0xfbc02d, 0xdd2c00

conky.config = {
	-- 基本設定
  background = false,
  update_interval = 1,
  double_buffer = true,
  no_buffers = true,
  use_xft = true,
	text_buffer_size = 2048,
	
	temperature_unit = 'celsius',
	cpu_avg_samples = 2,
	net_avg_samples = 2,
	
	override_utf8_locale = true,
	
  -- GNOME 專用視窗設定（穩定透明）
  own_window = true,
  own_window_type = 'normal',
  own_window_hints = 'undecorated,sticky,below,skip_taskbar,skip_pager',
  own_window_transparent = false,
  own_window_argb_visual = true,
  own_window_argb_value = 0,
  -- own_window_colour = '#0b0d18',
  -- own_window_colour = '#000000',

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
  lua_load = '/home/beny/.config/conky/beny-conky/beny.lua',
  lua_draw_hook_pre = 'conky_main',
};

conky.text = [[]];

conky.beny = {
	scaling = scaling,
	icon_font = 'Symbols Nerd Font',
	widgets = {
		clock = {
			hide = false,
			pos = {x = 0, y = 0},
			showDate = true,
			timeFormat = '%H:%M:%S',
			dateFormat = '%A, %e. %B',
			osIcon = getOsIcon(),
		},
		system = {
			hide = false,
			pos = {x = 0, y = scale(60)},
		},
		cpu = {
			hide = false,
			pos = {x = 0, y = scale(230)},
			gaugeLoc = 'right', -- left, right
			top = 7,
			-- hwmon = 0,
			-- tempSensor = 1,
			-- minCoresPerRow = 2,
		},
		memory = {
			hide = false,
			pos = {x = 0, y = scale(460)},
			gaugeLoc = 'right', -- left, right
			top = 3,
		},
		network = {
			hide = false,
			pos = {x = 0, y = scale(610)},
			gaugeLoc = 'left', -- left, right
			network = 'auto', -- network name 'eth0'
			showIpv6 = false,
		},
		disks = {
			hide = false,
			pos = {x = 0, y = scale(730)},
			gaugeLoc = 'right', -- left, right
			-- disks = {Home = '/home', Root = '/'},
			disks = 'auto',
			exclude = {'/var/lib/docker', 'fast.workspace', '/boot/efi', '/run/timeshift/.*/backup'},
			include = {MyCloud = '/media/mycloud/benyuenkc'},
      -- sort = {'Root', 'Home', 'MyCloud'},
      sort = 'size',
		},
		load = {
			hide = false,
			pos = {x = 0, y = scale(830)},
			--max = 2,
			--warn = 2,
			--crit = 4,
		},
	},
	fonts = {
		-- default = 'Monaco', -- suggestion: use a mono spaced font
		-- significant = 'GE Inspira',
    default = 'Noto Sans Mono CJK HK',
		ckj = 'Noto Sans Mono CJK HK',
	},
	colors = {
		default = 0xffffd0,
		highlight = primary,
		gaugeBg = default,
		gaugeBgAlpha = 0.1,
		gauge = 0x8080ff,
		gaugeAlpha = 0.8,
		gaugeInfo = primary,
		gaugeWarn = warn,
		gaugeCrit = crit,
		color_R = 0xff0000,
		color_Y = 0xfafaa0,
		color_G = 0x00ff00,
		color_B = 0x0000ff,
		color_O = 0xffa000,
		color_OW = 0xffffd0,
		color_LG = 0xa0ffa0,
		color_SB = 0x8080ff,
		color_GR = 0x808080,
	},
}

