這是在 Linux Mint 21.3 (2026年環境) 中，自行編譯 Conky 並解決 Imlib2 模組失效的完整技術總結。

1. 問題核心原因
Linux Mint 21.3 提供的 libimlib2 版本 (1.7.4) 低於 Conky 預期的 1.10.0。
編譯行為：Conky 偵測到舊版庫，會調用 imlib2_old.pkg 進行編譯，生成入口函數名為 luaopen_imlib2_old 的共享庫。
執行錯誤：Lua 的 require 'imlib2' 指令僅會尋找標準名稱 luaopen_imlib2，導致報錯 undefined symbol: luaopen_imlib2 並使 conky_main 變為 nil。

2. 失敗的嘗試（避坑指南）
欺騙 CMake 版本：強行指定版本為 1.10+ 會導致編譯失敗，因為舊版系統庫缺少新版所需的 C API 函數（如 imlib_version）。
升級 Lua 版本：強行使用 Lua 5.4 雖符合 Conky 要求，但若不處理符號對映，依然會發生載入錯誤。

3. 最終正確解決方案（標準作業程序）

第一階段：正確編譯

確保安裝必要依賴，並讓 CMake 自動處理相容性：

安裝依賴

    sudo apt install liblua5.4-dev libimlib2-dev libtolua++-dev

清理並編譯 (讓其自動偵測版本並生成 _old 符號)

    rm -rf build && mkdir build && cd build

    cmake .. -DRELEASE=ON -DCMAKE_INSTALL_PREFIX=$HOME/local -DBUILD_IMLIB2=ON -DBUILD_LUA_IMLIB2=ON -DLUA_LIBRARY=/usr/lib/x86_64-linux-gnu/liblua5.4.so -DLUA_INCLUDE_DIR=/usr/include/lua5.4

    make -j$(nproc)

    make install


第二階段：修正 Lua 載入邏輯 (關鍵)

在您的 Lua 進入點檔案（如 jinli.lua）最頂端，手動對接舊版符號，繞過 require 的限制：

-- 針對 Linux Mint 21.3 的符號修復

    local imlib_path = "/home/beny/local/lib/conky/libimlib2.so"

    local load_imlib = package.loadlib(imlib_path, 'luaopen_imlib2_old')

    if load_imlib then
      
      load_imlib() 
      
      package.loaded['imlib2'] = true -- 標記已載入，防止後續 require 'imlib2' 報錯

    else
      
      print("Imlib2 載入失敗")

    end

-- 隨後再載入其他依賴

    require 'lib'

    require 'cairo-tools'


4. 驗證與維護

符號檢查：使用 nm -D ~/local/lib/conky/libimlib2.so | grep luaopen，若看到 T luaopen_imlib2_old 且 Lua 腳本已對應，即可正常運作。

路徑建議：啟動 Conky 時建議使用絕對路徑指定配置檔，確保 Lua 內部的 lua_load 路徑正確。

這套方法在不更動系統穩定性的前提下，完美解決了自編譯版與舊版系統庫的相容性問題。
