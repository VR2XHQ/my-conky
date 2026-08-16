# 後記
對於 cairo 及 cairo_xlib 模組的載入迷思，之前的理解有所謬誤。建立這倉庫後，在主系統 linux mint 21.3 上運行[這舊的腳本](scripts/main.lua-old)，一直相安無事。最近因為安裝 Budgie 及 Fedora，就中文輸入法的[RIME設定](https://github.com/VR2XHQ/my-rime-cj)，實驗跨 device/distro 方便的安裝體驗，於是也來測試一下 conky 在 Budgie 及 Fedora 的部署，結果遇上一些異常情況。因為困惑，所以反覆驗証，當然也向 AI 求解，過濾[不當的幻覺](docs/additional_notes/About_preset_howto.md)，最後得出今次補充。

2026年初至今，大半年過去了，AI 的進步是明顯的，現時的免費版已不過於陽春。提問的邏緝十分重要，選對了話語，讓它短時間內找到合適的解說。


## cairo 模組的合併與分離
當初誤信套件的 conky 是把 cairo_xlib 合併到 cairo 的，腳本加上 require('cairo_xlib') 便出鐠。[事實並非如此](docs/additional_notes/About_xlib_combined.md)，應是取決於 upstream 的差異。雖然升級到 mint 22.3，它提供的 conky-all 套件版本仍是較舊的 1.19。6，屬於模組合併，而 Budgie 及 Fedora 的版本為 1.22.2，模組分開。

對於 AppImage 版本，亦同樣被誤導，由於它的[表現如同模組合併方式](docs/additional_notes/ConkyAppImage与系统版区别.md)。其實它是取用了套件所安裝的 cairo 庫，若沒安裝套件，跟本無法操作。這點在現時的 [main.lua 版本](scripts/main.lua)上修正了。另外 jinli 的思路亦造成誤導原因，他以為 Fedora 的模組袛有 cairo_xlib，所以用那段 pcall 來解決不同 distro 間的差異，[其實不對](docs/additional_notes/Lua%20Cairo%20模組載入差異.md)。


## 腳本的微調及修正
應對不同的 linux distro 要有比較通用的方法。
- 改用函數獲取 CAPS 及 NUM [鍵的狀態](scripts/main.lua)
- 補回 cpu_cores 數量的[傳遞](scripts/conky_draw_lib.lua)
- 增補相關的 [symbols font](assets/fonts/)
- 改用 /etc/os-release 資訊，取代 [lsb-release](docs/additional_notes/LSB%20模組與發行版資訊區別.md) 獲取系統版本資訊
- conky 1.24 以上的版本，[語法有取締](scripts/conky_lua.lua)。
- 模仿版 beny-conky 做了[對應上述的部份改動](beny-conky/beny.lua), 但保留過去開發的痕蹟。


## 編繹最新的源碼
Conky 源碼採用 cairo/cairo_xlib 模組獨立生成，不會造成執行上的困難，祗要如現時腳本的處理，無論新舊的 conky 版本都能自動適配，當日一心要求腳本通用，才會[硬改源碼](https://github.com/VR2XHQ/conky/tree/one-libcairo-build?tab=readme-ov-file)來遷就，事實上有點多餘。不過，在過程中，確實讓人多了思考，作出對問題解決的不同取向。

後來 conky upstream 有多次更新，較早時做過同步拉取，看似沒有衝突，順利完成編繹。但最近再次同步拉取，已經無法兼容了。換言之，恰當的處理應該讓客製化的分支不去同步 upstream，停留在當時的狀態比較穩妥，就像 snapshot 般定格。回帶過去狀態不難，但要小心處理，[此文檔詳盡記錄了做法](docs/additional_notes/取消merge與查看commit.md)，供日後參考。

這是個人 conky fork 頁面上 [Tag 快照](https://github.com/VR2XHQ/conky/tags)，並且建立了 [Pre-release](https://github.com/VR2XHQ/conky/releases/tag/my-cairo-experiment)，收進自家版本的安裝包。

打包 binary 亦要點學問, 通過 AI 答問，完成了這個[實用的打包腳本](tools/package-uninstall.sh), 感覺很好用。

既然已經玩到地步，最新的 Upstream 也來[硬改實驗](https://github.com/VR2XHQ/conky/tree/new-test)，完成第二個 [Tag 快照](https://github.com/VR2XHQ/conky/tags)，當然也來個 [Pre-release](https://github.com/VR2XHQ/conky/releases/tag/my-cairo-experiment-20260808)。袛要掌握核心的原理，改法其實大同小異。


## 倉庫更新 - 注意之處
今次更新，沒有在 README.md 上作大量修改，而另引一個 SUPPLEMENT.md 來統一說明，並增補檔案及修改部份腳本。在本地倉庫先創建一個 DEV 分支，改動完後切回 main，直接做最後的推送工作。唯要留意小心，[這文檔概述了考量](docs/additional_notes/Git分支操作误区.md)，作為一個參考。


## 最後 。。。
暫時就到此為止，待日後有新問題出現時，觸發另一次探究。

## 2026-08-17
沒料到然後來得真快，原以為打包了就輕鬆在不同 distro 上安裝，事實仍要做點調整，主因是 conky 對系統庫的依賴。編繹是在特定的環境下進行，移到別 distro 使用時，總會有些地方要考慮，否則隨時出問題。這就是為何各系統都有自家 conky 發行版本，才能穩定地工作。現時試驗的可謂 workaround 版本，最理想還是各自在原生環境下編繹比較妥當。

包含依賴庫的做法[容易踏坑](docs/additional_notes/Conky共享庫缺失解決方案.md)，想當然的做法，竟然令系統掛掉，還好[能夠修復](docs/additional_notes/Fedora%20外置%20SSD%20啟動修復指南.md)。

暫時在以下系統安裝後可用，會否還出其他故障，還需長時間的使用才能發現，這是除錯的樂趣。
- Fedora Workstation
- Ubuntu Budgie
- Pop!_OS

今次修正，主要是針對打包腳本，另[定了新名](tools/package-conky.sh)以分別。當然又要另建[新的Tag及Pre-release](https://github.com/VR2XHQ/conky/releases/tag/conky-portable-20260815), 留個記錄。

至此真的要暫告一段，還有太多無聊研究等著開啟。