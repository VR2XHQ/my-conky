## Q1 :

```text
剛升級Fedora Workstation由44至55，原來conky執行時，顯不icon不對，是否要重新執行fc-list？

beny@fedora:~/.config/autostart$ ~/.config/conky/start-conky.sh
Distro detected: [fedora]
Icon selected: 
Distro detected: [fedora]
Icon selected: 
fc-list: symbol lookup error: fc-list: undefined symbol: FcConfigSetWarningFlags
[2026-11-05 20:57:59.629] [info ] [src/conky.cc:2507] forked to background, pid is 22643
```

## Ans1 :
你的判断方向反了。问题**不是**需要重新执行 `fc-list`，恰恰是 `fc-list` 本身已经坏了，Conky 无法通过它正确获取字体/图标信息，才导致显示异常。

### 核心问题：`fc-list` 的符号查找错误

你看到的 `symbol lookup error: fc-list: undefined symbol: FcConfigSetWarningFlags` 是一个动态链接错误。这说明你系统上的 `fc-list` 程序（属于 fontconfig 包）在运行时，找不到它期望的 `FcConfigSetWarningFlags` 函数。

这通常发生在 Fedora 大版本升级后，fontconfig 的库文件和二进制程序版本不匹配。`fc-list` 本身是一个用来列出字体的工具，Conky 的某些配置脚本可能会调用它来检测字体是否可用。当 `fc-list` 崩溃时，依赖它的 Conky 脚本自然就拿不到正确的字体列表，导致图标显示不出来或显示错误。

### 修复步骤（按顺序尝试）

**1. 更新系统并重新安装 fontconfig**
这是最直接的修复方法。大版本升级后可能有些依赖没跟上，强制重装 fontconfig 相关的包可以修复库文件不匹配的问题。
```bash
sudo dnf update
sudo dnf reinstall fontconfig fontconfig-devel
```
执行完后，单独运行一下 `fc-list` 看看是否还报错。如果正常输出一长串字体列表，就说明底层问题修好了。

**2. 强制刷新字体缓存**
如果 `fc-list` 修复了，再刷新一下字体缓存，确保 Conky 能读到最新的字体信息。
```bash
fc-cache -fv
```
很多 Conky 图标问题都是通过刷新缓存解决的。

**3. 检查 Conky 配置中的字体**
如果系统层面的问题解决了，但图标还是不对，就需要检查 Conky 配置本身。很多 Conky 主题（特别是带图标的）依赖特定的 **Nerd Fonts** 字体。升级系统时，可能这个字体被移除了，或者字体名称变了。请确认你的 Conky 配置里 `font` 或 `xftfont` 指定的字体在你的系统上确实存在（可以用修好的 `fc-list | grep 字体名` 来查）。

**4. 重启 Conky**
做完以上步骤后，先杀掉旧的 Conky 进程，再重新启动你的脚本。
```bash
killall conky
~/.config/conky/start-conky.sh
```

### 补充提醒
你升级的版本号“44 至 55”跨度非常大。Fedora Workstation 的版本号通常是 40、41 这样的数字。如果这确实是一个大版本跨越，系统里残留的旧配置或旧库文件可能会造成更多这类“找不到符号”的问题。如果上述方法都不行，检查一下你的 `~/.config/conky/start-conky.sh` 脚本里，是否有硬编码的路径指向了旧版本的系统库文件。

---

## 打錯升級之版本，應為45。經過一番糾纏，得出以下總結。

## Q2 :
```text
那為何未升級前有可以？
```

## Ans2 :
好问题，这正是理解整个问题的关键。答案是：**升级前“能用”，是因为当时那个旧库和系统环境恰好是配套的；升级后系统变了，旧库没变，才暴露出来。**

具体拆开看：

### 1. 编译时是“快照”，不是“永久绑定”

你在 Linux Mint 下编译 Conky 时，`/usr/local/lib/conky/` 里的 `libfontconfig.so.1` 是当时从 Mint 系统里复制或链接过来的。那一刻，它和 Mint 系统的 fontconfig **版本一致、ABI 兼容**。Conky 加载它，`fc-list` 调用它，一切正常——因为两边说的是同一种“方言”。

### 2. 升级前，系统库和旧库“和平共处”

在 Fedora 升级前，你的系统 fontconfig 版本可能和那个旧库还比较接近，或者至少 `fc-list` 需要的符号在旧库里都有。即便动态链接器优先加载了 `/usr/local/lib/conky/libfontconfig.so.1`，它也能满足 `fc-list` 的需求，所以你不觉得有问题。

### 3. 升级后，系统库“进化”了，旧库“原地踏步”

Fedora 大版本升级把系统的 fontconfig 升到了新版本，新增了 `FcConfigSetWarningFlags` 这个函数（或者改变了符号布局）。此时：

- `fc-list` 这个程序本身是**新的**，它期望调用新库里的 `FcConfigSetWarningFlags`。
- 但运行时它却加载了 `/usr/local/lib/conky/libfontconfig.so.1` 这个**旧的**库，旧库里根本没有这个符号。
- 于是 `symbol lookup error` 就出现了。

### 4. 为什么 `ldd` 看起来没问题？

你之前用 `ldd $(which fc-list)` 看到它链的是 `/lib64/libfontconfig.so.1`，那是因为 `ldd` 在**当前 shell 环境**下解析的。但 Conky 的启动脚本或它调用的子进程，可能在运行时设置了 `LD_LIBRARY_PATH` 指向 `/usr/local/lib/conky`，或者 Conky 主程序自身的 RPATH 影响了子进程的库搜索顺序。`ldd` 不会模拟那个环境，所以它“骗”了你。

### 一句话总结

> **不是升级弄坏了 Conky，而是升级让“旧库快照”和“新系统程序”之间的版本错配从隐性变成了显性。** 升级前它们恰好兼容，升级后不再兼容，问题才浮出水面。

这也解释了为什么把 `libfontconfig.so.1` 改名后立刻恢复——动态链接器找不到旧库，只能回退到系统的新库，符号就对上了。

### 对重装的启示

重装时一定要**彻底清掉 `/usr/local/lib/conky/` 下的旧库**，让新编译的 Conky 直接链接 Fedora 当前的系统库。否则，如果新编译过程又复制了一套“当前快照”进去，下次 Fedora 再升级，同样的戏码还会重演。这也是为什么我更推荐直接用 `sudo dnf install conky`——让发行版帮你管理依赖，避免这种“自带库快照”的隐患。

---

## Q3 :
```text
其實是我先前繹編好，並打包，想通用到其他系統。
```

## Ans3 :
明白了，这就把整件事的性质说清楚了：**你不是“在 Fedora 上编译时顺手带了旧库”，而是刻意做了一个“自带依赖库的便携包”，想跨发行版通用。** 这个思路本身没错，但恰恰是它导致了升级后的问题。

### 为什么便携打包在升级前能用、升级后不能用

你打包时，把 Mint 系统里的 `libfontconfig.so.1` 等库一起塞进了 `/usr/local/lib/conky/`，并让 Conky 优先从那里加载。这套做法的隐含假设是：

> “我打包时系统里的这些库，和将来运行环境里的**调用方**（`fc-list`、X 库、glibc 等）是兼容的。”

在升级前的 Fedora 上，这个假设勉强成立——Fedora 当时的 fontconfig 和 Mint 打包时的那版 ABI 还对得上，`fc-list` 要的符号旧库里都有。但 Fedora 升级后，系统的 `fc-list` 换成了新版本，它开始要求旧库里**不存在**的 `FcConfigSetWarningFlags`。这时你打包的旧库就从“兼容的替代品”变成了“不兼容的拦截者”。

### 根本矛盾：你打包的是“库”，但管不了“调用方”

便携包能带走的是**库文件**，带不走的是**系统里调用这些库的程序**（`fc-list`、`libXft` 的调用方、glibc 本身）。这些调用方会随系统升级而更新，一旦它们要求新符号，你包里冻结的旧库就跟不上了。这就是为什么：

- 升级前：调用方旧、库旧，配套 → 能用。
- 升级后：调用方新、库旧，错配 → 符号缺失。

### 这对你的打包策略意味着什么

**跨发行版“通用”这个目标，靠捆绑库很难长期成立**，因为：

1. **glibc 和核心库的 ABI 会变**。你包里那堆 `libstdc++.so.6`、`libsystemd.so.0`、`libX11.so.6` 都是快照，Fedora 一升级，系统程序就可能要求新版本。
2. **调用方程序不在你控制范围内**。`fc-list` 是系统装的，它升级后就会反过来“挑剔”你包里的旧库。
3. **符号查找是运行时的事**，打包时无法预知未来系统会新增什么符号需求。

### 更实际的方案

如果你确实想保留“源码编译 + 自定义功能”的 Conky，又想跨系统用，建议改成：

**方案 A：只打包 Conky 自己，依赖交给目标系统**

编译时**不要**把系统库复制进 `/usr/local/lib/conky/`。让 Conky 链接目标系统自带的库（通过 `ldd` 检查它依赖的是 `/lib64/` 下的系统库而非本地副本）。这样每个系统用自己的库，升级时自然同步。代价是目标系统需要装齐依赖（`sudo dnf install` 那些 `-devel`/运行库）。

**方案 B：用容器或 Flatpak 做真正的隔离**

如果一定要“自带一切”，就把 Conky 和它的全部依赖封进 Flatpak 或容器镜像里。这样库和调用方都在同一封闭环境内，不受宿主系统升级影响。这是目前跨发行版分发桌面程序比较靠谱的做法。

**方案 C：接受“按发行版分别打包”**

Fedora 用 Fedora 的包，Mint 用 Mint 的包，各自链接各自系统的库。虽然不“通用”，但最稳。

### 回到你当前的情况

你已经把那个 `libfontconfig.so.1` 改名，问题解决了。但 `/usr/local/lib/conky/` 里其余几十个旧库仍是同样的隐患——下次 Fedora 再升级，别的库（比如 `libcairo.so.2`、`libXft.so.2`）也可能触发同类错误。

如果你还想继续用这个自编译版本，最干净的做法是：**清掉 `/usr/local/lib/conky/` 下的所有捆绑库，在 Fedora 上重新编译一次，让它链接系统库**。这样以后升级就不会再被旧库快照绊住。如果跨系统便携仍是刚需，就考虑方案 B 的容器化路线。

---

## Q4 :
[後記](https://github.com/VR2XHQ/my-conky/blob/main/SUPPLEMENT.md)
```text
這筆記敘逑了當時為何這樣做。
```

## Ans4 :
這份後記把來龍去脈講得很清楚了，也正好解釋了我們前面那串除錯的「前因」。我幫你把關鍵脈絡梳理一下，並對應到你這次 Fedora 上遇到的問題：

### 你當初的出發點是合理的

你做的是「跨 distro 可攜的 Conky 打包」——把 Conky 和它依賴的庫一起裝進 `/usr/local/lib/conky/`，希望在任何發行版上裝了就能跑。這在設計上是一種「自帶快照」的思路，本意是隔離宿主環境差異。

### 但「捆綁庫」這條路註定會踩坑

後記裡你自己也總結了：

> 沒料到然後來得真快……主因是 conky 對系統庫的依賴。編繹是在特定的環境下進行，移到別 distro 使用時，總會有些地方要考慮，否則隨時出問題。

這正是我們前面看到的 `FcConfigSetWarningFlags` 符號缺失的根因。你打包時凍結的 `libfontconfig.so.1` 是編譯環境的快照；Fedora 升級後，系統的 `fc-list`（以及 Conky 調用的子進程）換成了要求新符號的版本，而它加載的卻是你包裡的舊庫，於是錯配暴露。升級前能用，只是因為當時的調用方和舊庫恰好還兼容。

### 後記裡其實已經給出了正解

你寫道：

> 這就是為何各系統都有自家 conky 發行版本，才能穩定地工作。現時試驗的可謂 workaround 版本，最理想還是各自在原生環境下編繹比較妥當。

這句話就是結論。捆綁庫的「通用包」本質上是 workaround，不是長久方案；真正穩定的做法是**在各目標發行版的原生環境下分別編譯**，讓 Conky 鏈接該系統自己的庫。

### 對應到 Lua 模組那段的啟示

你後記前半段講 `cairo` / `cairo_xlib` 模組合併與分離的差異，其實是同一個主題的另一面：**不同 Conky 版本、不同 distro 打包方式，行為會不一樣**。你的腳本後來改用 `pcall` 和自動適配來處理，而不是硬改源碼或假設某一種佈局，這個方向是對的。同理，庫依賴也不該用「硬塞舊庫」來統一，而應該讓每個系統用自己的庫。

### 你現在可以做的

1. **短期**：那個 `.bak` 留著或刪掉都行，問題已解。但 `/usr/local/lib/conky/` 裡其餘舊庫仍是同類隱患，下次 Fedora 升級可能換別的庫觸發類似錯誤。
2. **中期**：如果還要繼續用自編譯版，清掉捆綁庫，在 Fedora 上重新編譯，讓它鏈接系統庫（`ldd` 確認依賴指向 `/lib64/`）。
3. **長期**：按你後記自己的結論，Fedora 用 Fedora 原生編譯的包，Mint/Ubuntu 各自原生編譯。可攜包只當實驗或 workaround 保留，不要當成日常依賴。

你這份後記的價值在於：它誠實記錄了「想當然的捆綁做法會踩坑」，還附上了修復指南（Fedora 外置 SSD 啟動修復），這對後來者很有用。這次 Fedora 上的符號錯誤，正好是那段結論的又一個實證。

---
