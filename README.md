# 基於 Conky 的研究


<p align="left">
  <img src="assets/Screenshot at 2026-02-11 17-01-53.png" alt="classic_version" width="20%" style="margin-right: 50px;">
  <img src="assets/Screenshot at 2026-02-11 17-05-45.png" alt="lua_version" width="22%" style="margin-right: 50px;">
  <img src="assets/Screenshot at 2026-02-11 16-58-53.png" alt="lua_version" width="15%">
</p>


<p align="left">
  <img src="https://img.shields.io/github/license/VR2XHQ/my-conky" />
  <img src="https://img.shields.io/github/last-commit/VR2XHQ/my-conky" />
  <img src="https://img.shields.io/github/v/release/VR2XHQ/my-conky" />
</p>


## 為何建立這個倉庫
記錄倉庫計劃中的[最後一個](https://github.com/VR2XHQ/myclock_stm32cube)定稿之後，已經來到2025年末。閒來無事，遇上桌面 Launcher [出了點狀況](docs/MATE%20mintMenu%20事件追查與修正撮要.md)，經常彈出 warning message，十分擾人。排查結果是某 .desktop 檔的設定不妥當造成，由此認識了icon與apps的關聯性，問題也解決了。在過程中，加深了對Linux下套件的認知，依靠 AI 的幫助，製作了幾個方便實用的腳本。

|檔名|用途|
|--|--|
|[pkginfo.sh](tools/pkginfo.sh)|取得安裝套件來源的資訊|
|[find-desktop.sh](tools/find-desktop.sh)|查找現有的 .desktop 位置|
|[manage-appimage.sh](tools/manage-appimage.sh)|處理 AppImage 相關事宜|
| | |

Launcher 有一個 Conky icon，當啓動它時，桌面左上方[顯示一個方框](assets/Screenshot%20at%202026-02-14%2000-34-43.png)，內裏有些系統資訊，但沒功能設定，方框呆在那裏亦無法移動。記得之前裝過 MX Linux，預設[桌面顯示時鐘](assets/Screenshot_2026-02-19_19-23-40.png)及一些系統資訊，十分簡潔討好，可以更改到不同位置上顯示。那時袛知與 Conky 相關，而且有對應的應用，可選不同的顯示組合。為何如今看到的，跟那些有這麼大的落差？出於好奇，網上搜尋 Conky 相關資料，於是開始了這次研究之旅。

過往靠自己四處查找及過濾資料，隨時吃掉大量時間，進展緩慢。現時改問 AI，確實方便快捷許多。不過，回覆難免錯漏，唯有自行判斷及驗証，做好把關。把玩了兩個多月，覺得應該將這些記錄下來。


## 倉庫的目錄結構
```text
./
├── assets/             圖片展示
├── docs/               參考資料
├── tools/              工具檔案
├── beny-conky/         抄來的版本
├── scripts/            移植原稿的版本
├── lua-conky/          實驗中 Lua script 
├── conky_classic.conf  純粹的版本
└── README.md           本說明文件
```


## 引子
Conky 好玩之處在於客製化的顯示，袛要你想得出的，大部份能夠實現。看過一些炫酷的示例，心動下著手嘗試打造[自己的版本](assets/Screenshot%20at%202026-02-11%2017-05-45.png)。基礎設定都在 .conkyrc 或者 conky.conf 定義，然後執行 conky，無需任何參數，資訊就顯示於桌面上。修改其內容，袛要語法無誤，即時見到效果。這是我喜歡的模式，正如把玩單片機，十分實在，可觸摸的東西，易於掌握。


## 工具
[Conky](https://github.com/VR2XHQ/conky?tab=readme-ov-file) 是系統監控工具，主要在 Linux 環境下使用，直觀地於桌面上展演，既實用，亦帶點好玩的味道。

執行檔的安裝有多種方法，大部份 Distro 都已經包含了它，但版本相對較舊。要貼近最新版本，可以採用官方的 AppImage 或 Nix Package。後者沒有試過，前者某程度上方便，但需安裝額外的 runtime libraries。

想要更好玩，就直接編繹源碼。[官方 GitHub](https://github.com/brndnmtthws/conky/wiki/Installation) 給了簡明的步驟，相當友善，並不因難。源碼採用 [Cmake](https://cmake.org/cmake/help/latest/manual/cmake.1.html#introduction-to-cmake-buildsystems) 來引導編繹的自動化，是很好的學習場境，因為並不複雜，按步就班地照做，就會生成執行檔，滿有成就感。當然 [Cmake](https://cmake.org/cmake/help/latest/index.html) 實在強大，要精通還得下苦功,

初時直接加上參數來做設定，後來安裝了 ccmake (tui) 及 cmake-gui，參數的初始化更加便利了。

~~~bash
# 下載 repo
git clone https://github.com/brndnmtthws/conky.git
cd ./conky
mkdir -p ./build
cd ./build
# 直接加載參數
cmake .. -DCMAKE_INSTALL_PREFIX=/home/beny/.local -DBUILD_LUA_CAIRO=ON -DBUILD_LUA_CAIRO_XLIB=ON -DBUILD_LUA_RSVG=ON -DBUILD_LUA_IMLIB2=ON -DBUILD_PULSEAUDIO=ON
make clean
make -j$(nproc)
make install
make uninstall  # 若要刪除已安裝的

# 安裝 ccmake
sudo apt install cmake-curses-gui
# 安裝 cmake-gui
sudo apt install cmake-qt-gui
~~~

在修練過程中，遇上兩個值得[記錄的事情](docs/how_to_make_conky_binary.md)。

- 在熟習流程的練習中，make uninstall 執行失敗。當時讓 AI 排查原因，它卻給了替代方案，建立了[這樣的腳本](tools/uninstall_from_manifest.sh)，及後問另一款 AI，它給了[改進的版本](tools/uninstall-f-m.sh)，兩者原理相近，語法運用稍不同，都記下來作為學習的記錄。這些腳本解決到問題，但對源碼竟然存在這樣的缺失，總有點不爽。深究下發現 [UninstallConky.cmake.in](https://github.com/brndnmtthws/conky/pull/2321/changes) 的語法存在問題，[稍為修正](docs/report_bug_github.md)就沒事了。作為 git [操作的練習](docs/how_to_git_stash.md)，而問題直觀無疑，於是做 push request，[被接納了](https://github.com/brndnmtthws/conky/pull/2321)。尋源的結果顯示，早於 uninstall 引進源碼時是正確的，可能在多年來的自動化維謢下，某次修改時反而弄錯了。事實上 uninstall 功能屬於小事，理所當然地一直被忽畧。但對於我這類小白，由於好奇心驅使，也許說白點是不甘心，它才被發掘出來。

- 在製作要顯示的資訊內容時，每種 Conky 版本都嘗試執行，確保沒出錯。問題來了，有些於使用自編繹的 binary 時出錯。其中 [require('cairo') 及 require('cairo_xlib')](scripts/main.lua-old) 的運用，困擾了許久。原來源碼預設兩者是分離的，即是各有各的 .so，若不明示 require 它們，就無法調用。套件及 AppImage Conky 把 cairo_xlib 合包於 cairo 模組，導致如果加上 require('cairo_xlib') 反而報錯找不到獨立的 .so。為了要統一，唯有[硬改源碼](https://github.com/VR2XHQ/conky/tree/one-libcairo-build?tab=readme-ov-file)，讓編繹時把兩者合包。這也讓我認識到，git branch 的妙用，既保持 fork 來的倉庫同步到 upstream，與自定所需的 branch 互不干擾。[（2026-08-08 補充）](SUPPLEMENT.md)


## 實作
獲取系統數據並顯示於桌面上，就是 Conky 基本的用途，配合自帶的一系列 [Vars](https://conky.cc/variables)，依照語法編寫到設定檔內的 conky.txt[[...]]，就輕易設計出所需的元素，例如[修改預設的範本](assets/Screenshot%20at%202026-02-17%2023-41-21.png)，令它移到右上方，並且改變顏色。

按這基本功，再參考別人的示範，開始構思自己想要的東西，湊合起來有了初形，最後[定稿](./conky_classic.conf)成為[這個模樣](assets/Screenshot%20at%202026-02-11%2017-01-53.png)。這是純粹運用內建的功能，但在獲取數據上，有時必需更好地利用[外掛腳本](scripts/output_type.sh)，例如[音訊方面](docs/how_to_awk_sink.md)，[本地天氣](scripts/hko_weather.sh)。

Conky 引進 Lua 的應用，始於 Conky 1.7.0（約 2009 年），主要目的是讓使用者能透過 Lua 腳本和 Cairo 圖形庫打造更靈活的桌面監控與美化效果。網絡上的範例多如繁星，看到這個 [jinli-conky](https://blog.jinli.io/p/linux%E7%8A%B6%E6%80%81%E7%9B%91%E6%8E%A7%E8%BD%AF%E4%BB%B6conky%E7%9A%84%E4%BD%BF%E7%94%A8/) 的介紹，覺得不錯。它是依據這個 [mircale-conky](https://github.com/tflori/miracle-conky) 而來的，首先仿照它們的做法，即以呼叫來劃分各段區塊的顯示，而內容則接近先前的排版，[另加上圖符外觀](assets/Screenshot%20at%202026-02-11%2017-05-45.png)。以 Lua/Cairo 來實現，其效果確實明顯較佳，而且比較容易維護。

這是 [jinli-conky 源碼](https://github.com/jin-li/jinli-conky)，按它的設計做了小修小改，完成了[自家的版本](assets/Screenshot%20at%202026-02-11%2016-58-53.png)，過程中遇到兩個困惑。
- 它用上 require('imlib2') 模組，套件及AppImage Conky 都順利執行。因為 Linux Mint 21.3 的 imlib2 版本太舊，又未能隨意升級，在此限制底下，編繹出來的 Conky 執行出錯，最後要啓用[撓過它的方案](docs/how_to_conky_imlib2_workaround.md)。及後才發現，其實並沒用上 imlib2，註解掉亦可以。奇怪原作者為何加進，目的也許預留日後擴充吧。
- 它的 updateDisks() 利用內建的 fs_ 及 diskio，當掛載的 NAS 在斷網時，因為 Conky 採用 statfs 來取得數據，立刻[變成阻塞真兇](docs/how_to_avoid_statfs.md)。理所當然而被忽畧的，總是一再發生。解決之道是[完全棄用](beny-conky/beny.lua)，以較穩定的外掛腳本取得 [fs_](beny-conky/get_fs.sh) 與及 [diskio](beny-conky/get_diskio.sh) 來迴避卡頓情況。

[Lua](https://www.lua.org/) 之前稍幑接觸過，但不懂得它可以做些什麼實事，現在才用心一點去了解它的語法。它給予較大的自由度，讓人集中構思於設計上，不用顧慮太多結構上的瑣碎細節，天馬行空般去創造所需，難怪 Lua 在遊戲開發中受歡迎。它「小而快、易嵌入、可擴展、支援協程與熱更新」，能在效能與靈活性之間取得最佳平衡。


## 總結
這趟 Conky + Lua + Cairo 的學習之旅，到此可告一段落。現時打造的，足夠日常使用了。最重要能夠藉著解決問題，長了多方面的認知，探索了比如 [一些限制](docs/how_to_gnome_conky.md)，[系統的音效](docs/what_HP_alsa_completed_guide.md), [TUI的淺嘗](docs/how_to_make_tui_ncurses.md), [PPA的方法](docs/how_to_PPA.md)，等等。這些都是依賴 AI 輔助，才得以在較短時間內完成。當然壞處是有的，比如它的準確性，真的不能照搬如儀。它給出的建議不一定對或者適合，唯慎用才是正道。

