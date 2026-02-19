conky.config = {
    background = false,
    update_interval = 1,
    double_buffer = true,
    -- no_buffers = true,
    use_xft = true,

    own_window = true,
    own_window_type = 'normal',
    own_window_hints = 'undecorated,sticky,below,skip_taskbar,skip_pager',
    own_window_transparent = false,
    own_window_argb_visual = true,
    own_window_argb_value = 0,
    
    gap_x = 5,
    gap_y = 5,
    
    alignment = 'top_right',
    minimum_width = 400,
    minimum_height = 900,

    font = 'Noto Sans Mono CJK HK :size=16',
    default_color = 'skyblue',
    short_units = yes,
    
    -- 載入主Lua文件
    lua_load = '/home/beny/.config/conky/lua-conky/main.lua',
    lua_draw_hook_pre = 'conky_main'
};

conky.text = [[
#可以留空，或混合使用傳統文本
#${color white}${time %H:%M:%S}$color
]];

