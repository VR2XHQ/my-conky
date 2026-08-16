## Q1 :
```bash
我的外置SSD上的Fedora workstation無法正常啟動，卡在zam0檢查上，似是是損壞了，要怎樣在另一台linux上作檢查？
```

## Ans1 :
Fedora Workstation（從 Fedora 33 開始）預設採用 **Btrfs** 檔案系統，並包含 FAT32（EFI 分區）與 ext4（`/boot` 分區）。卡在 `zram0` 通常有兩種原因：**硬體/檔案系統損壞導致載入掛載失敗**，或是**更新後 initramfs/核心映像檔損壞**。

請在另一台 Linux 電腦上執行以下步驟進行排查與修復：

---

## 第一步：確認外置硬碟的代號與分區

接上外置 SSD 後，開啟終端機，執行以下指令確認裝置代號（例如 `/dev/sdb` 或 `/dev/nvme1n1`）：

```bash
lsblk -f

```

找到你的外置 SSD，觀察各分區的檔案系統類型（FSTYPE），通常會看到：

* `vfat` (EFI 系統分區，如 `/dev/sdb1`)
* `ext4` (Boot 分區，如 `/dev/sdb2`)
* `btrfs` (Fedora 系統主分區，如 `/dev/sdb3`)

---

## 第二步：檢查 SSD 硬體健康狀況 (SMART)

在嘗試修復檔案系統前，先確認 SSD 硬體本身是否有壞軌或嚴重衰退：

```bash
# 安裝檢測工具（以 Ubuntu/Debian 為例；Fedora 請用 dnf）
sudo apt install smartmontools

# 檢查硬體健康狀態（將 /dev/sdX 替換為你的硬碟代號）
sudo smartctl -H /dev/sdX

```

* 如果顯示 **PASSED**：硬體正常，極可能是檔案系統或系統設定損壞。
* 如果顯示 **FAILED** 或有大量 Read/Write Error：硬體可能故障，建議先用 `ddrescue` 或 `dd` 備份整張硬碟的 Image 檔再做處理。

---

## 第三步：修復檔案系統

針對不同的分區進行修復：

### 1. 修復 Btrfs 主分區 (根目錄 `/` 與 `/home`)

> ⚠️ **重要警告**：Btrfs 的 `btrfs check --repair` 指令在某些極端情況下可能造成二次損壞。**切勿直接加入 `--repair` 參數！**

1. **先進行唯讀檢測：**
```bash
sudo btrfs check /dev/sdX3

```


2. **嘗試以唯讀/救援模式掛載備份資料：**
如果檢測回報錯誤，先建立掛載點嘗試救出重要檔案：
```bash
sudo mkdir -p /mnt/fedora
sudo mount -o ro,recovery /dev/sdX3 /mnt/fedora

```


若成功掛載，請立刻將重要資料複製到另一台電腦上。
3. **進行檔案系統修復（Scrub/Clear-Tree）：**
若能正常掛載（或以可讀寫模式掛載），執行洗刷修復（Scrub）：
```bash
sudo btrfs scrub start -B /mnt/fedora

```


若無法掛載且確認有損壞，可先嘗試修復樹狀結構區段：
```bash
sudo btrfs check --clear-space-cache v2 /dev/sdX3

```



### 2. 修復 Ext4 分區 (`/boot`)

```bash
sudo fsck.ext4 -f /dev/sdX2

```

### 3. 修復 FAT32 分區 (`/boot/efi`)

```bash
sudo fsck.vfat -a /dev/sdX1

```

---

## 第四步：若檔案系統無損，檢查 Boot/Initramfs

如果檔案系統完全正常，但引導時依然卡在 `zram0`，往往是因為最近一次更新未順利完成，導致 `initramfs` 損壞。你可以透過 **Chroot** 重新建置開機映像：

1. **掛載 Fedora 分區與系統虛擬目錄：**
```bash
sudo mount -o subvol=root /dev/sdX3 /mnt
sudo mount /dev/sdX2 /mnt/boot
sudo mount /dev/sdX1 /mnt/boot/efi

for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i /mnt$i; done

```


2. **進入 Chroot 環境並重新修復/產生 dracut：**
```bash
sudo chroot /mnt
dracut --regenerate-all --force
exit

```


3. **安全解除掛載並重試：**
```bash
sudo umount -R /mnt

```


## Q2 :
```bash
我使用ext4
```

## Ans2 :
既然你的 Fedora 系統使用的是 **ext4** 檔案系統（而不是預設的 Btrfs），處理和修復過程會相對簡單且標準許多！

以下是在另一台 Linux 電腦上檢查與修復 ext4 外置 SSD 的步驟：

---

## 第一步：確認外置 SSD 的分區代號

請將 SSD 接上另一台 Linux 電腦，開啟終端機並執行：

```bash
lsblk -f

```

找到你的外置 SSD（例如 `/dev/sdb` 或 `/dev/nvme1n1`），確認各分區的代號：

* **EFI 分區** (`vfat`)：例如 `/dev/sdb1`
* **Boot 分區** (`ext4`)：例如 `/dev/sdb2`
* **Fedora 根目錄分區** (`ext4` 或 `LVM`)：例如 `/dev/sdb3`

> 💡 **注意事項**：如果是使用了 Fedora 的預設 LVM 邏輯卷，分區名稱可能會顯示為 `/dev/mapper/fedora-root` 或類似名稱。

---

## 第二步：修復 ext4 檔案系統 (`fsck`)

**⚠️ 重要：執行檢查與修復前，請確保該分區「沒有」被掛載（Unmounted）。**

如果系統自動掛載了該硬碟，請先卸載：

```bash
sudo umount /dev/sdX*

```

### 1. 強制修復根目錄與 Boot 的 ext4 分區

使用 `fsck.ext4` 或 `e2fsck` 工具進行檢查與自動修復：

```bash
# -f : 強制檢查（即使系統標記為乾淨）
# -y : 自動對所有修復提示回答 yes
sudo fsck.ext4 -fy /dev/sdX3

```

*（請將 `/dev/sdX3` 替換為你的 ext4 根目錄分區代號；若有獨立的 `/boot` 分區 `/dev/sdX2`，也請執行一次）*

### 2. 檢查修復結果

* 如果最後顯示 **`FILE SYSTEM WAS MODIFIED`**：說明成功修復了損壞的區塊/inode。
* 如果提示 **`UNRECOVERABLE ERROR`** 或大量 I/O Error：可能代表 SSD 顆粒出現硬體物理損壞。

---

## 第三步：修復 EFI 引導分區 (FAT32)

通常 `/boot/efi` 是 FAT32 格式，建議也順便檢查：

```bash
sudo fsck.vfat -a /dev/sdX1

```

---

## 第四步：若檔案系統無損，修復損壞的 initramfs (Chroot)

如果 `fsck` 顯示檔案系統完全正常，但開機依然卡在 `zram0`，通常是上次系統更新時 `dracut` 產生的開機映像（initramfs）毀損。你可以透過 Chroot 重新生成它：

1. **掛載外置 SSD 到救援系統：**
```bash
sudo mkdir -p /mnt/fedora
sudo mount /dev/sdX3 /mnt/fedora           # 根目錄
sudo mount /dev/sdX2 /mnt/fedora/boot      # 若有獨立 /boot
sudo mount /dev/sdX1 /mnt/fedora/boot/efi  # EFI 分區

# 綁定系統虛擬目錄
for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i /mnt/fedora$i; done

```


2. **切換進入 Fedora 系統並重新生成 initramfs：**
```bash
sudo chroot /mnt/fedora
dracut --regenerate-all --force
exit

```


3. **安全解除掛載：**
```bash
sudo umount -R /mnt/fedora

```



修復完成後，將 SSD 插回原本的電腦開機測試即可。


## Q3 :
```bash
eny@Klevv-R1:~$ sudo fsck.ext4 -fy /dev/sdc4
e2fsck 1.47.0 (5-Feb-2023)
Pass 1: Checking inodes, blocks, and sizes
Inode 9306321 extent tree (at level 1) could be narrower.  Optimize? yes

Inode 9306349 extent tree (at level 1) could be narrower.  Optimize? yes

Inode 9306351 extent tree (at level 1) could be narrower.  Optimize? yes

Inode 9306386 extent tree (at level 1) could be narrower.  Optimize? yes

Inode 9306407 extent tree (at level 1) could be narrower.  Optimize? yes

Inode 9308138 extent tree (at level 1) could be narrower.  Optimize? yes

Inode 9308163 extent tree (at level 1) could be narrower.  Optimize? yes

Inode 9308164 extent tree (at level 1) could be narrower.  Optimize? yes

Inode 9308233 extent tree (at level 1) could be narrower.  Optimize? yes

Pass 1E: Optimizing extent trees
Pass 2: Checking directory structure
Pass 3: Checking directory connectivity
Pass 4: Checking reference counts
Pass 5: Checking group summary information

fedora: ***** FILE SYSTEM WAS MODIFIED *****
fedora: 206749/13123584 files (0.5% non-contiguous), 6281642/52489984 blocks
```

## Ans3 :
這是一個非常好的結果！

日誌顯示：

1. **`FILE SYSTEM WAS MODIFIED`**：`fsck` 已經成功修復並優化了你的檔案系統結構（調整了 extent tree 的深度並修復了組摘要資訊）。
2. **沒有出現物理損壞**（沒有跳出 `Unrecoverable read error` 或大量壞軌警告）。

這代表你的 **ext4 檔案系統資料本身已經恢復健康** 了。

---

### 接下來該怎麼做？

既然檔案系統已經修復完成，現在你有兩個選擇：

#### 選擇 A：直接插回原電腦測試開機

有很大的機率只是因為檔案系統結構異常或未正常關機，導致上次開機載入 `zram0` 時卡死。你可以直接將 SSD 接回原本的電腦，看看能否正常進入 Fedora。

---

#### 選擇 B：如果依然卡在 `zram0`，進行 Chroot 修復

如果插回去開機**依然卡住**，這代表「檔案系統」雖然好了，但上次損壞時可能導致 **系統核心映像檔 (initramfs)** 毀損。請在目前的電腦上執行以下步驟重組開機檔：

1. **掛載外置 SSD（請根據你實際的分區調整，假設 `/dev/sdc4` 是根目錄）：**
```bash
sudo mkdir -p /mnt/fedora
sudo mount /dev/sdc4 /mnt/fedora

# 如果你有獨立的 /boot (/dev/sdc2 或 sdc3) 與 EFI (/dev/sdc1)，也需要掛載：
# sudo mount /dev/sdc2 /mnt/fedora/boot
# sudo mount /dev/sdc1 /mnt/fedora/boot/efi

# 綁定系統目錄
for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i /mnt/fedora$i; done

```


2. **進入切換環境並重新修復 Initramfs：**
```bash
sudo chroot /mnt/fedora
dracut --regenerate-all --force
exit

```


3. **安全卸載：**
```bash
sudo umount -R /mnt/fedora

```



修復完後就可以拔掉 SSD，拿去原電腦開機了！


## Q4 :
```bash
beny@Klevv-R1:~$ sudo fsck.ext4 -fy /dev/sdc3
e2fsck 1.47.0 (5-Feb-2023)
ext2fs_open2: Bad magic number in super-block
fsck.ext4: Superblock invalid, trying backup blocks...
fsck.ext4: Bad magic number in super-block while trying to open /dev/sdc3

The superblock could not be read or does not describe a valid ext2/ext3/ext4
filesystem.  If the device is valid and it really contains an ext2/ext3/ext4
filesystem (and not swap or ufs or something else), then the superblock
is corrupt, and you might try running e2fsck with an alternate superblock:
    e2fsck -b 8193 <device>
 or
    e2fsck -b 32768 <device>

/dev/sdc3 contains a swap file system labelled 'swap'
```

## Ans4 :
警告訊息的最下方揭曉了原因：

> **/dev/sdc3 contains a swap file system labelled 'swap'**

`/dev/sdc3` **不是 ext4 檔案系統，而是系統的 Swap（虛擬記憶體）分區**！這就是為什麼 `fsck.ext4` 會回報 `Bad magic number in super-block` ——因為它根本不是拿來放檔案的 ext4 分區。

---

## 為什麼上一步修復 `/dev/sdc4` 已經足夠？

在前面的步驟中，你對 `/dev/sdc4` 執行 `fsck.ext4` 時已經獲得了成功：

```text
fedora: ***** FILE SYSTEM WAS MODIFIED *****
fedora: 206749/13123584 files...

```

這代表：

1. **`/dev/sdc4` 才是你 Fedora 的根目錄（``/`）分區**。
2. 你的 **ext4 核心檔案系統已經順利修復完成**！
3. Swap 分區（`/dev/sdc3`）不需要也不用執行 `fsck`。

---

## 你的外置 SSD 分區結構解析

你可以執行 `lsblk -f /dev/sdc` 來確認，你的 SSD 分區佈局通常是這樣：

| 分區代號 | 檔案系統 | 用途 | 處理狀況 |
| --- | --- | --- | --- |
| `/dev/sdc1` | `vfat` | EFI 系統引導分區 | 可用 `fsck.vfat -a /dev/sdc1` 檢查 |
| `/dev/sdc2` | `ext4` | `/boot` 開機檔分區（若有） | 可用 `fsck.ext4 -fy /dev/sdc2` 檢查 |
| `/dev/sdc3` | `swap` | Swap 虛擬記憶體 | **無需檢查** |
| `/dev/sdc4` | `ext4` | Fedora 根目錄 (`/`) | **已完成修復！** |

---

## 接下來該做什麼？

現在主要的根目錄檔案系統（`/dev/sdc4`）已經修復好了，你可以：

1. **直接拔下 SSD，插回原本的電腦開機測試**。有很高的機率現在已經可以正常順暢進入 Fedora 了！
2. 如果插回去開機**依然卡死在 `zram0**`，這說明檔案系統雖然修好了，但引導映像檔（`initramfs`）毀損，需要進行 **Chroot 重建 initramfs**。


## Q5 :
```bash
beny@Klevv-R1:~$ for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i /mnt/fedora$i; done
beny@Klevv-R1:~$ sudo chroot /mnt/fedora
root@Klevv-R1:/# dracut --regenerate-all --force
zstd: symbol lookup error: zstd: undefined symbol: POOL_free
dracut[F]: Creation of /boot/initramfs-7.0.13-200.fc44.x86_64.img.tmp failed
zstd: symbol lookup error: zstd: undefined symbol: POOL_free
dracut[F]: Creation of /boot/initramfs-7.1.3-201.fc44.x86_64.img.tmp failed
zstd: symbol lookup error: zstd: undefined symbol: POOL_free
dracut[F]: Creation of /boot/initramfs-7.1.5-200.fc44.x86_64.img.tmp failed
```

## Ans5 :
這個錯誤非常關鍵！它直接揭露了為什麼會卡在 `zram0` 以及修復失敗的原因：

錯誤訊息：
`zstd: symbol lookup error: zstd: undefined symbol: POOL_free`

這代表你的 **Fedora 系統內的 `zstd` 壓縮工具（或是其依賴的 `libzstd` 動態連結庫）版本不匹配或已損壞**。由於 Fedora 預設使用 `zstd` 來壓縮 `initramfs` 開機映像檔與 zram 記憶體區段，當 `zstd` 崩潰時，`dracut` 就無法順利產生開機檔，開機時載入 zram 也會直接卡死！

請在目前的 **chroot (`root@Klevv-R1:/#`)** 環境下，按照以下步驟進行修復：

---

## 步驟一：修復損壞的 zstd 相關套件

在 chroot 中透過 `dnf` 重新安裝並修復 `zstd` 與 `libzstd`：

```bash
# 1. 補全網絡解析設定（確保 chroot 內能連網）
# 如果在 chroot 內提示網絡無法連線，可先 exit 出去執行：
# sudo cp /etc/resolv.conf /mnt/fedora/etc/resolv.conf
# 重新 sudo chroot /mnt/fedora 後再繼續

# 2. 強制重新安裝 libzstd 與 zstd
dnf reinstall -y zstd libzstd

```

如果 `dnf reinstall` 失敗或提示套件損壞，嘗試清除快取後修復：

```bash
dnf clean all
dnf upgrade -y zstd libzstd

```

---

## 步驟二：測試 `zstd` 是否恢復正常

安裝完成後，直接在 chroot 終端機測試 `zstd` 指令：

```bash
zstd --version

```

* 如果正常輸出版本號（沒有出現 `symbol lookup error`），代表動態庫修復成功！

---

## 步驟三：重新產生 initramfs 開機映像檔

`zstd` 恢復正常後，重新執行 `dracut`：

```bash
dracut --regenerate-all --force

```

這次應該就能順利完成，不會再跳出任何 `Creation failed` 的錯誤。

---

## 步驟四：安全退出並重啟

修復完成後，執行以下指令退出並解掛：

```bash
# 1. 退出 chroot
exit

# 2. 解除所有掛載
sudo umount -R /mnt/fedora

# 3. 拔下 SSD 插回原本電腦開機測試！

```


## Q6 :
```bash
root@Klevv-R1:/# dnf reinstall -y zstd libzstd
Updating and loading repositories:
 Fedora 44 - x86_64 - Updates                     100% | 608.0   B/s |   5.9 KiB |  00m10s
 RPM Fusion for Fedora 44 - Nonfree - Steam       100% |   1.6 KiB/s |  14.3 KiB |  00m09s
 RPM Fusion for Fedora 44 - Nonfree - NVIDIA Driv 100% |   1.7 KiB/s |  13.0 KiB |  00m08s
 google-chrome                                    100% | 220.0   B/s |   1.3 KiB |  00m06s
 Fedora 44 - x86_64                               100% | 842.0   B/s |   5.7 KiB |  00m07s
 Copr repo for PyCharm owned by phracek           100% | 355.0   B/s |   2.1 KiB |  00m06s
Repositories loaded.
Package                    Arch   Version                    Repository               Size
Reinstalling:
 libzstd                   x86_64 0:1.5.7-5.fc44             fedora              956.1 KiB
   replacing libzstd       x86_64 0:1.5.7-5.fc44             19278be6a81040f5b6c 956.1 KiB
 zstd                      x86_64 0:1.5.7-5.fc44             fedora              502.4 KiB
   replacing zstd          x86_64 0:1.5.7-5.fc44             19278be6a81040f5b6c 502.4 KiB

Transaction Summary:
 Reinstalling:       2 packages
 Replacing:          2 packages

Total size of inbound packages is 557 KiB. Need to download 557 KiB.
After this operation, 0 B extra will be used (install 1 MiB, remove 1 MiB).
[1/2] zstd-0:1.5.7-5.fc44.x86_64                  100% | 225.7 KiB/s | 192.5 KiB |  00m01s
[2/2] libzstd-0:1.5.7-5.fc44.x86_64               100% | 333.5 KiB/s | 364.2 KiB |  00m01s
------------------------------------------------------------------------------------------
[2/2] Total                                       100% | 508.4 KiB/s | 556.7 KiB |  00m01s
Running transaction
[1/6] Verify package files                        100% | 166.0   B/s |   2.0   B |  00m00s
[2/6] Prepare transaction                         100% |  11.0   B/s |   4.0   B |  00m00s
[3/6] Reinstalling libzstd-0:1.5.7-5.fc44.x86_64  100% |  39.0 MiB/s | 957.4 KiB |  00m00s
[4/6] Reinstalling zstd-0:1.5.7-5.fc44.x86_64     100% |  11.8 MiB/s | 506.0 KiB |  00m00s
[5/6] Removing zstd-0:1.5.7-5.fc44.x86_64         100% |   1.3 KiB/s |  25.0   B |  00m00s
[6/6] Removing libzstd-0:1.5.7-5.fc44.x86_64      100% |   3.0   B/s |   8.0   B |  00m02s
Complete!
root@Klevv-R1:/# zstd --version
zstd: symbol lookup error: zstd: undefined symbol: POOL_free
```

## Ans6 :
這說明 **RPM 系統內的 `libzstd` 雖然重新安裝了，但系統環境中存在「另一個」權重更高、且版本損壞或過舊的 `libzstd.so**`（通常位於 `/usr/local/lib` 或 `/usr/local/lib64`）。

當你執行 `zstd` 時，動態連結器（ld.so）優先載入了這個損壞的舊版 `.so` 檔，而不是 dnf 剛剛安裝到 `/usr/lib64/` 的正版庫，導致依然出現 `POOL_free` 符號找不到的錯誤。

請在 **chroot (`root@Klevv-R1:/#`)** 環境下執行以下步驟排查並解決：

---

### 第一步：找出是哪個 `libzstd.so` 搞鬼

執行 `ldd` 檢查 `zstd` 到底引用了哪裡的共享庫：

```bash
ldd $(which zstd) | grep zstd

```

你可能會看到類似這樣的輸出：
`libzstd.so.1 => /usr/local/lib/libzstd.so.1 (0x...)`

正常 Fedora 的套件應該要指向 **`/usr/lib64/libzstd.so.1`**。如果指向了 `/usr/local/lib/` 或其他地方，就是問題所在！

---

### 第二步：搜尋並處理干擾的庫檔案

搜尋系統中所有的 `libzstd.so` 檔案：

```bash
find / -name "libzstd.so*" 2>/dev/null

```

#### 解決方案：

1. 如果在 `/usr/local/lib/` 或 `/usr/local/lib64/` 找到了 `libzstd.so*`，這些通常是以前手動編譯或某些第三方軟體放入的。將它們改名排除：
```bash
# 移走 /usr/local 裡面的干擾檔
mv /usr/local/lib/libzstd.so* /tmp/ 2>/dev/null
mv /usr/local/lib64/libzstd.so* /tmp/ 2>/dev/null

```


2. 重新更新動態連結快取：
```bash
ldconfig

```



---

### 第三步：再次測試 `zstd`

再次檢查版本與符號：

```bash
zstd --version

```

如果成功印出版本號（如 `*** zstd command line interface 64-bits v1.5.7 ... ***`），代表干擾已排除！

---

### 第四步：重新產生開機檔 `initramfs`

`zstd` 正常後，直接執行 dracut：

```bash
dracut --regenerate-all --force

```

無報錯完成後即可 `exit`，解掛載並回原電腦開機！


## Q7 :
```bash
root@Klevv-R1:/# ldd $(which zstd) | grep zstd
    libzstd.so.1 => /usr/local/lib/conky/libzstd.so.1 (0x00007fe551321000)
```

## Ans7 :
案情終於水落石出了！

可以看到這行關鍵輸出：
`libzstd.so.1 => /usr/local/lib/conky/libzstd.so.1`

系統在啟動 `zstd` 時，居然去載入了 **Conky（桌面小工具）** 自帶的 `libzstd.so.1`！這個庫缺乏 `POOL_free` 符號，直接把 Fedora 系統的核心工具給搞崩了。

這通常是因為以前安裝 Conky 或其模組時，把 `/usr/local/lib/conky` 寫入了系統的全域動態庫搜尋路徑（`/etc/ld.so.conf` 或 `/etc/ld.so.conf.d/`）中。

請在 **chroot (`root@Klevv-R1:/#`)** 環境下執行以下步驟清理：

---

### 第一步：找出是哪個設定檔把 Conky 路徑加進去的

在 `/etc/ld.so.conf.d/` 裡面搜尋包含 `conky` 的設定檔：

```bash
grep -rnw '/etc/ld.so.conf' '/etc/ld.so.conf.d/' -e 'conky'

```

你應該會看到類似 `/etc/ld.so.conf.d/conky.conf` 或其他的 `.conf` 檔案包含 `/usr/local/lib/conky`。

---

### 第二步：移除該設定檔並更新動態庫連結

1. **刪除或移走該 `.conf` 設定檔：**
```bash
# 假設找到的檔名是 /etc/ld.so.conf.d/conky.conf （請依實際檔名調整）
rm -f /etc/ld.so.conf.d/conky*.conf

```


2. **重新整理動態庫快取（非常重要）：**
```bash
ldconfig

```



---

### 第三步：驗證 `zstd` 是否恢復正常

再次檢查 `zstd` 載入的庫與版本：

```bash
# 1. 確認路徑已經變回 /usr/lib64
ldd $(which zstd) | grep zstd

# 2. 測試 zstd 能否正常執行
zstd --version

```

**預期結果：**
`ldd` 應該會顯示 `libzstd.so.1 => /usr/lib64/libzstd.so.1`，且 `zstd --version` 能夠順利輸出版本號！

---

### 第四步：重新產生 `initramfs` 開機檔

`zstd` 恢復正常後，立刻重新建置開機檔：

```bash
dracut --regenerate-all --force

```

這一步成功完成後，你的 Fedora 就修復完畢了！

---

### 第五步：安全退出並開機

```bash
# 1. 退出 chroot
exit

# 2. 解除所有掛載
sudo umount -R /mnt/fedora

```

現在可以拔下 SSD，插回原本的電腦開機，系統就能順利進入 Fedora 了！


## Q8 :
```bash
root@Klevv-R1:/# grep -rnw '/etc/ld.so.conf' '/etc/ld.so.conf.d/' -e 'conky'
/etc/ld.so.conf.d/conky.conf:1:/usr/local/lib/conky
```

## Ans8 :
完全命中！正是 `/etc/ld.so.conf.d/conky.conf` 這個檔案將 `/usr/local/lib/conky` 強行加入到了系統全域的動態庫搜尋路徑中。

請在 **chroot (`root@Klevv-R1:/#`)** 環境下執行以下命令完成最後的清理與修復：

---

### 第一步：刪除設定檔並更新連結庫快取

```bash
# 1. 刪除干擾全域庫搜尋的 conky 設定檔
rm -f /etc/ld.so.conf.d/conky.conf

# 2. 重新整理系統動態庫快取（至關重要！）
ldconfig

```

---

### 第二步：驗證 `zstd`

執行以下命令驗證：

```bash
# 1. 確認 libzstd 已正確指向 /usr/lib64/libzstd.so.1
ldd $(which zstd) | grep zstd

# 2. 測試 zstd 執行狀況
zstd --version

```

*預期結果：`ldd` 顯示指向 `/usr/lib64/libzstd.so.1`，且 `zstd --version` 順利輸出版本訊息，不再出現 `symbol lookup error`！*

---

### 第三步：重新產生 `initramfs` 開機檔

`zstd` 恢復正常後，重新生成開機映像：

```bash
dracut --regenerate-all --force

```

這次將會順利完成（不會再出現任何 `failed` 警告）。

---

### 第四步：安全退出並開機測試

```bash
# 1. 退出 chroot
exit

# 2. 解除所有掛載
sudo umount -R /mnt/fedora

```

恭喜！拔掉 SSD 插回原本的電腦，現在可以正常開機進入 Fedora 了！


## Q9 :
```bash
root@Klevv-R1:/# rm -f /etc/ld.so.conf.d/conky.conf
root@Klevv-R1:/# ldconfig
root@Klevv-R1:/# ldd $(which zstd) | grep zstd
    libzstd.so.1 => /lib64/libzstd.so.1 (0x0000786758dcb000)
root@Klevv-R1:/# zstd --version
*** Zstandard CLI (64-bit) v1.5.7, by Yann Collet ***
root@Klevv-R1:/# dracut --regenerate-all --force
似乎成功了。
```

## Ans9 :
太棒了！🎉

從日誌可以看到：

1. `libzstd.so.1` 已經成功回歸到官方系統路徑 `/lib64/libzstd.so.1`。
2. `zstd --version` 順利印出了 `v1.5.7` 的版本訊息，代表**全域動態庫污染已經完全排除**。
3. `dracut --regenerate-all --force` 完美執行完畢，代表全新的開機映像檔（initramfs）已經重新打包成功。

這代表你的 **Fedora 系統開機元件與檔案系統已經全部修復完成**！

---

### 最後收尾步驟

請在目前的終端機中執行最後的清理，安全退出並卸載硬碟：

```bash
# 1. 退出 chroot 環境
exit

# 2. 卸載所有掛載的分區（請確保不在 /mnt/fedora 目錄下）
sudo umount -R /mnt/fedora

```

現在可以安心拔下外置 SSD，插回原本的電腦，重新開機。祝開機順利！


## Q10 :
```bash
Fedora重啟成功。這出錯是我搞conky時弄倒的，同樣Budgie也搞壞了。是否照樣修正？
```

## Ans10 :
太棒了！高興看到你的外置 SSD 成功順利開機！🎉

這整個經過非常有教育意義——當時為了讓 Conky 載入特定的動態庫，將 `/usr/local/lib/conky` 寫進了 `/etc/ld.so.conf.d/` 的全域設定檔中，結果這就像是把「專屬零件」丟進了「全域工具箱」，導致全系統的工具（如 `zstd`，甚至可能包括 Budgie 的桌面元件）在尋找標準庫時，全部被 Conky 自帶的舊版/非標準 `.so` 檔蓋過去了。

---

## Budgie 桌面壞掉是同一個原因嗎？

**是的，極高機率是同一個原因！**

Budgie 桌面環境（特別是其面板元件、Gtk 模組、外掛與圖形渲染硬體加速）極度依賴系統的標準動態庫（如 `libglib`、`libcairo`、`libgdk`、`libzstd` 等）。

當 Conky 的庫強行覆蓋全域搜尋路徑時，Budgie 啟動時也會像之前的 `zstd` 一樣，載入到錯誤的庫，引發 `symbol lookup error` 或直接崩潰 Segfault，導致無法載入桌面。

---

## 現在需要做什麼修正？

既然你剛才已經執行了：

1. **刪除 `/etc/ld.so.conf.d/conky.conf**`
2. **執行 `ldconfig` 重置全域動態庫連結**

**全域的動態庫污染其實已經被你修好了！**

你現在可以直接在 Fedora 中嘗試登入 Budgie 桌面。

---

## 如果 Budgie 依然無法正常載入，請按以下步驟排查：

### 1. 檢查是否還有其他 Conky 的全域庫設定

在 Fedora 終端機執行：

```bash
grep -rnw '/etc/ld.so.conf' '/etc/ld.so.conf.d/' -e 'conky'

```

*如果沒有輸出任何內容，代表全域設定已經完全乾淨。*

### 2. 重置 Budgie 的使用者設定檔（最常見的 Budgie 崩潰原因）

有時候在折騰 Conky 或桌面小工具時，可能寫壞了 Budgie 的個人組態檔或快取。可以在終端機重置 Budgie 的 Dconf 設定：

```bash
# 重置 Budgie 桌面組態到預設值
dconf reset -f /org/buddiesofbudgie/budgie-desktop/
# 或舊版路徑
dconf reset -f /com/solus-project/

# 清除使用者層級的圖形快取
rm -rf ~/.cache/budgie-desktop

```

### 3. 重新安裝 Budgie 套件（確保組件完整）

如果在全域污染期間有某些套件更新未完成，可以 reinstall Budgie：

```bash
sudo dnf reinstall -y budgie-desktop budgie-desktop-view

```

---

### 💡 經驗總結：未來如何安全地為 Conky 使用專屬動態庫？

千萬**不要**將專屬軟體的庫路徑加到 `/etc/ld.so.conf.d/` 這種全域設定中。如果你未來還想手動編譯或指定 Conky 的庫，請改用以下兩種安全方式：

1. **僅在啟動 Conky 時傳入環境變數：**
```bash
LD_LIBRARY_PATH=/usr/local/lib/conky conky

```


*這樣只有 Conky 自己會看到這些庫，完全不會影響到系統的 `zstd`、`dracut` 或 Budgie。*
2. **寫成啟動 Shell 腳本 (`conky-start.sh`)：**
```bash
#!/bin/bash
export LD_LIBRARY_PATH="/usr/local/lib/conky:$LD_LIBRARY_PATH"
exec conky "$@"

```


## Q11 :
```bash
令你誤會了，我是在另一個Ubuntu Budgie系統。
```

## Ans11 :
原來如此！是我會錯意了，以為是在同一台外置 Fedora 上的 Budgie 桌面。

也就是說：**那台作為救援機的 Ubuntu Budgie 電腦，先前因為搞 Conky 寫了 `/etc/ld.so.conf.d/conky.conf`，結果連帶把自身的 Ubuntu Budgie 系統環境也給弄壞了！**

---

## 修正方案

是的！完全不需要猶豫，**Ubuntu Budgie 也是照樣用一樣的方法修正**。

這個問題的根源不在於 Linux 發行版是 Fedora 還是 Ubuntu，而是在 Linux 的動態連結器（ld.so）機制上。當你在 Ubuntu 上寫了全域的 `/etc/ld.so.conf.d/conky.conf`，Ubuntu 系統內的所有桌面組件（包含 Budgie Desktop、Gnome/GTK 庫、Wayland/X11 繪圖模組等）在啟動時，都會被優先拉去讀取 `/usr/local/lib/conky` 裡的舊版/非標準庫，直接導致 Budgie 崩潰或卡死。

---

## 請在你的 Ubuntu Budgie 本機上執行以下步驟：

### 第一步：清理全域動態庫設定

開啟 Ubuntu 的終端機，執行以下指令：

```bash
# 1. 搜尋並刪除 Conky 的全域 ld 配置文件
sudo rm -f /etc/ld.so.conf.d/conky*.conf

# 2. 重新整理 Ubuntu 的動態庫快取（至關重要！）
sudo ldconfig

```

### 第二步：驗證 Ubuntu 系統基礎庫已恢復正常

檢查系統關鍵工具（如 `zstd` 或 `glib`）是否已經擺脫 Conky 庫的污染：

```bash
ldd $(which zstd) | grep zstd

```

*正常應該會指向 `/lib/x86_64-linux-gnu/libzstd.so.1` 或 `/usr/lib/...`，而**不能**出現 `/usr/local/lib/conky`。*

---

### 第三步：修復/重置 Ubuntu Budgie 桌面

當全域動態庫連結恢復正常後，如果 Budgie 桌面還是有點異常（例如圖形快取損壞或組態殘留），可以執行以下命令重置 Budgie：

```bash
# 1. 清除 Budgie 的使用者快取
rm -rf ~/.cache/budgie-desktop ~/.cache/budgie-panel

# 2. 重置 Budgie 桌面面板與設定到原廠預設
dconf reset -f /org/buddiesofbudgie/budgie-desktop/
dconf reset -f /com/solus-project/

# 3. 如果之前有套件在更新時損壞，執行套件修復
sudo apt update
sudo apt install --reinstall budgie-desktop budgie-desktop-environment

```

修復完成後，建議**重啟 Ubuntu 電腦**，你的 Ubuntu Budgie 就能完全恢復正常了！

---

### 💡 補充提醒 (Ubuntu 安全使用 Conky)

以後在 Ubuntu 上如果要測試第三方/自編譯的 Conky 動態庫，千萬別再放進 `/etc/ld.so.conf.d/` 裡了。

最安全的做法是建立一個 Conky 專用的啟動腳本（例如 `run-conky.sh`）：

```bash
#!/bin/bash
export LD_LIBRARY_PATH="/usr/local/lib/conky:$LD_LIBRARY_PATH"
conky &

```

這樣設定只會作用在 Conky 產生的進程內，完全不會影響到 Ubuntu Budgie 桌面的穩定度！


## Q12 :
```bash
你的指示，也是先進chroot去執行？
```

## Ans12 :
**不用進入 chroot！直接在 Ubuntu 系統內執行即可。**

因為這台 **Ubuntu Budgie 是你目前正在操作、已經成功開機進入系統的電腦**（救援主機），你擁有這台電腦完整的 `sudo` 管理員權限，所以可以直接在 Ubuntu 的終端機裡面修復它自身。

---

### 直接在 Ubuntu 終端機執行的 3 個步驟：

請直接開啟 Ubuntu 的終端機（Terminal），依序輸入：

#### 1. 刪除 Conky 全域設定檔並更新動態庫連結

```bash
sudo rm -f /etc/ld.so.conf.d/conky*.conf
sudo ldconfig

```

#### 2. 驗證是否清理成功

```bash
ldd $(which zstd) | grep zstd

```

*正常情況下，路徑會變回 Ubuntu 的標準系統路徑（如 `/lib/x86_64-linux-gnu/libzstd.so.1`），不會再出現 `/usr/local/lib/conky`。*

#### 3. 重啟 Ubuntu 電腦

```bash
sudo reboot

```

---

### 💡 為什麼之前 Fedora 需要 chroot，而 Ubuntu 不用？

* **Fedora 外置硬碟：** 因為它是**外接的硬碟**，系統根本還沒跑起來（卡在開機畫面），我們必須透過 `chroot` 「偽裝」進入外置硬碟的環境去修復它的開機檔。
* **Ubuntu 本機：** 它是你**目前正在運行的電腦**，所有的命令直接作用在目前系統上，所以完全不需要 `chroot`。


## Q13 :
```bash
不，它一樣是在外置SSD上。
```

## Ans13 :
明白！原來這台 **Ubuntu Budgie 也是裝在另一個外置 SSD 上**。

既然它也是外置系統，處理邏輯就跟剛才修復 Fedora 完全一樣 —— 需要**透過一台能正常開機的 Linux 主機，掛載該外置 SSD 並進入 `chroot**` 來修復它。

---

### 修復 Ubuntu Budgie 外置 SSD 的步驟：

請把裝有 **Ubuntu Budgie 的外置 SSD** 接上能用的 Linux 電腦，開啟終端機：

#### 第一步：確認 Ubuntu 的分區代號

```bash
lsblk -f

```

假設找到 Ubuntu 根目錄分區是 `/dev/sdX1`（請替換為實際代號，例如 `/dev/sdb1` 或 `/dev/sdc2`）。

#### 第二步：掛載分區並進入 Chroot

```bash
# 1. 建立掛載點並掛載 Ubuntu 根目錄
sudo mkdir -p /mnt/ubuntu
sudo mount /dev/sdX1 /mnt/ubuntu

# 2. 綁定系統虛擬目錄
for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i /mnt/ubuntu$i; done

# 3. 進入 chroot 環境
sudo chroot /mnt/ubuntu

```

#### 第三步：在 Chroot 內清除 Conky 全域動態庫污染

進入 `root@...:/#` 後，執行：

```bash
# 1. 刪除罪魁禍首的設定檔
rm -f /etc/ld.so.conf.d/conky*.conf

# 2. 重新整理動態庫快取
ldconfig

# 3. 驗證是否已恢復正常（路徑應指向 /lib/x86_64-linux-gnu/ 或 /usr/lib/）
ldd $(which zstd) | grep zstd

```

#### 第四步：重新產生 Ubuntu 開機映像 (initramfs)

為了確保 Ubuntu 開機時載入的 `initrd` 不會帶有舊的錯誤庫：

```bash
# 更新 Ubuntu 的所有 initramfs
update-initramfs -u -k all

```

#### 第五步：安全退出並卸載

```bash
# 1. 退出 chroot
exit

# 2. 解除所有掛載
sudo umount -R /mnt/ubuntu

```

完成後拔下 SSD 插回原本的電腦開機，Ubuntu Budgie 就會恢復正常了！


## Q14 :
```bash
beny@Klevv-R1:~$ sudo mkdir -p /mnt/budgie
[sudo] password for beny:     
beny@Klevv-R1:~$ sudo mount /dev/sdc2 /mnt/budgie
beny@Klevv-R1:~$ for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i /mnt/budgie$i; done
beny@Klevv-R1:~$ sudo chroot /mnt/budgie
root@Klevv-R1:/# rm -f /etc/ld.so.conf.d/conky.conf
root@Klevv-R1:/# ldconfig
root@Klevv-R1:/# ldd $(which zstd) | grep zstd
root@Klevv-R1:/# update-intramfs -u -k all
Command 'update-intramfs' not found, did you mean:
  command 'update-initramfs' from deb dracut (110-11)
  command 'update-initramfs' from deb initramfs-tools (0.151ubuntu1)
  command 'update-initramfs' from deb live-tools (1:20240525build1)
Try: apt install <deb name>
root@Klevv-R1:/# update-initramfs -u -k all
update-initramfs: Generating /boot/initrd.img-7.0.0-29-generic
update-initramfs: Generating /boot/initrd.img-7.0.0-28-generic
原來它沒有使用zstd，是桌面出錯，無法login。
```

## Ans14 :
這兩行日誌非常有價值，直接幫我們還原了 Ubuntu Budgie 的現狀：

1. **指令拼字問題**：剛才提示 `update-intramfs` 打錯字（少了 `i`），後來修正為 `update-initramfs -u -k all` 已經**成功更新了 boot 映像檔**！
2. **`zstd` 沒輸出**：Ubuntu 預設的 `initramfs-tools` 使用 `gzip` 或 `lz4` 作為壓縮格式，且 `zstd` 在 Ubuntu 上可能並未被全域動態連結，所以 `ldd` 才沒有輸出。
3. **已排除全域污染**：執行 `rm -f /etc/ld.so.conf.d/conky.conf` 與 `ldconfig` 後，**動態庫污染問題已經徹底解決**！

---

## 為什麼現在還是「桌面出錯，無法 Login」？

當 Conky 損壞全域動態庫時，當前使用者的桌面組態（Dconf/GSettings 快取）或 Xorg/Wayland Session 的狀態檔可能在崩潰當下寫入了**損壞的無效設定**。

即便動態庫現在修好了，Budgie 登入時讀取到那些損壞的桌面快取，依然會**載入失敗並自動退回登入畫面（Loop Login）**。

---

## 請在目前的 chroot (`root@Klevv-R1:/#`) 下執行修復：

請直接在眼前的 chroot 終端機進行 **Budgie 桌面組態重置** 與 **權限修復**：

### 1. 重置所有使用者的 Budgie 桌面與 GSettings 快取

由於是在 chroot 裡面，我們可以直接把使用者的 Budgie 與 GTK 快取目錄清空（重啟後系統會自動重建預設值，**不會遺失個人文件**）：

```bash
# 清理家目錄下所有使用者的 Budgie 與 Dconf 快取
rm -rf /home/*/.cache/budgie-*
rm -rf /home/*/.cache/dconf
rm -rf /home/*/.config/budgie-desktop

```

### 2. 修復使用者家目錄的檔案權限 (Xauthority)

有時候登入卡住是因為 `~/.Xauthority` 或 `~/.ICEauthority` 的擁有者被誤改成了 `root`：

```bash
# 修正 home 目錄權限（將 username 替換為你在 Ubuntu 的實際帳號名稱，例如 beny）
chown -R beny:beny /home/beny

```

### 3. 確保 LightDM / Budgie 套件檔完整

重新修復一次 Budgie 桌面與登入管理器（LightDM）：

```bash
apt update
apt install --reinstall -y budgie-desktop lightdm

```

---

## 完成修復與退出

執行完上述指令後即可退出：

```bash
# 1. 退出 chroot
exit

# 2. 解除所有掛載
sudo umount -R /mnt/budgie

```

現在可以把 Ubuntu Budgie 的外置 SSD 插回原電腦開機，現在應該就能順利輸入密碼並進入 Budgie 桌面了！


## Q15 :
```bash
登入管理器和先前不同，可能不是LightDM。
```

## Ans15 :
Ubuntu Budgie **預設確實是使用 LightDM**，但如果以前改過，或是安裝了 Gnome/KDE 等其他桌面，登入管理器（Display Manager）有可能被切換成了 **SDDM**、**GDM3** 或 **GDM**。

你可以直接在目前的 **chroot (`root@Klevv-R1:/#`)** 環境下，用以下方法確認、重置並修復登入管理器：

---

### 第一步：檢查目前系統正在使用哪一個 Display Manager

執行以下命令，查看 `/etc/systemd/system/display-manager.service` 指向誰：

```bash
ls -l /etc/systemd/system/display-manager.service

```

你通常會看到以下其中一種輸出：

* `... -> /lib/systemd/system/lightdm.service` （LightDM）
* `... -> /lib/systemd/system/gdm3.service` （GDM3 / GNOME 預設）
* `... -> /lib/systemd/system/sddm.service` （SDDM / KDE 預設）

---

### 第二步：切換或重新設定 Display Manager

如果你想**重新切換回 Budgie 最相容的 LightDM**（或重新設定目前這個）：

```bash
# 重新配置預設的 Display Manager
dpkg-reconfigure lightdm

```

*(執行後畫面上會出現選單，選擇 `lightdm` 並按下 Enter 即可)*

如果系統提示 `lightdm` 未安裝或找不到，也可以改為重新配置 GDM3：

```bash
dpkg-reconfigure gdm3

```

---

### 第三步：重新安裝並修復當前的 Display Manager

確定是哪一個 Display Manager 後，直接重新安裝它以確保其組態檔完整：

```bash
# 如果是 LightDM
apt install --reinstall -y lightdm lightdm-gtk-greeter budgie-desktop-environment

# 如果是 GDM3
# apt install --reinstall -y gdm3

```

---

### 第四步：清除登入管理器本身的快取 (非常重要)

有時候登入畫面的暫存檔（Greeter cache）毀損也會導致輸入密碼後閃退：

```bash
# 清除 LightDM 快取
rm -rf /var/lib/lightdm/.cache/
rm -rf /var/log/lightdm/*

# 清除 GDM3 快取（若使用 GDM3）
rm -rf /var/lib/gdm3/.cache/

```

---

### 第五步：安全退出並重啟測試

修復完成後，即可退出並卸載：

```bash
# 1. 退出 chroot
exit

# 2. 卸載分區
sudo umount -R /mnt/budgie

```

拔下 SSD 插回原本的電腦開機，登入畫面與登入流程應該就能恢復正常了！


## Q16 :
```bash
不，我已進入budgie系統。
```

## Ans16 :
了解！太好了，這代表你的 **Ubuntu Budgie 已經能順利開機並進入系統了**！

如果現在是在 Ubuntu Budgie 系統裡面出現「某些 Conky 設定或桌面顯示不正常 / 無法 Login 到桌面環境」，請直接在 **Ubuntu Budgie 的 Terminal（終端機）** 執行以下修復即可：

---

### 第一步：清理全域環境（確保不再殘留 Conky 的動態庫設定）

直接開啟 Ubuntu Budgie 內部的終端機（Ctrl + Alt + T）：

```bash
# 1. 刪除全域 Conky ld 設定檔（若還存在）
sudo rm -f /etc/ld.so.conf.d/conky*.conf

# 2. 重置動態庫快取
sudo ldconfig

```

---

### 第二步：重置 Budgie 桌面的組態與快取

如果桌面面板（Panel）或圖形元件顯示異常、或者登入後有些元件載入不出來，執行以下指令清除快取：

```bash
# 1. 清除使用者層級的 Budgie 快取
rm -rf ~/.cache/budgie-desktop ~/.cache/budgie-panel ~/.cache/dconf

# 2. 重置 Budgie 桌面設定到官方預設狀態
dconf reset -f /org/buddiesofbudgie/budgie-desktop/
dconf reset -f /com/solus-project/

# 3. 重啟 Budgie 面板（無需重新開機）
budgie-panel --replace &

```

---

### 第三步：未來如何在 Ubuntu Budgie 上安全使用 Conky

為了避免再次因為 Conky 蓋掉系統庫導致桌面或 `zstd` 崩潰，未來請**完全避免**修改 `/etc/ld.so.conf.d/`。

如果你有自編譯或特製版的 Conky 庫（例如在 `/usr/local/lib/conky`），請改用 **獨立啟動指令** 來執行它：

在終端機或你的開機自啟腳本中寫入：

```bash
LD_LIBRARY_PATH=/usr/local/lib/conky conky

```

這樣這套庫就**只會被 Conky 本身調用**，絕對不會再影響到 Ubuntu Budgie 桌面或其他的系統元件了！


## Q17 :
```bash
相信我之前是用SDDM。
```

## Ans17 :
太好了！這就完全對得上了。

SDDM（Simple Desktop Display Manager）預設是 KDE Plasma 或 LXQt 使用的登入管理器，但在 Ubuntu 上完全可以自訂選用 SDDM 來作為 Budgie 的登入畫面。

當先前 `/etc/ld.so.conf.d/conky.conf` 造成全域動態庫污染時，**SDDM 和 Qt/GTK 的底層渲染庫（如 `libzstd`、`libglib` 等）也一併被弄崩了**，這就是為什麼之前會卡在登入畫面迴圈（Loop Login）或無法順利進入桌面的根本原因。

---

### 現在既已進入 Ubuntu Budgie 系統，請做最後的「收尾與預防」：

為了確保 SDDM 與 Budgie 桌面之後重啟不會再遇到殘留問題，請在 **Ubuntu Budgie 的終端機** 執行以下三行命令：

#### 1. 確保 SDDM 快取乾淨

```bash
# 清除 SDDM 的歷史暫存與日誌快取
sudo rm -rf /var/lib/sddm/.cache/

```

#### 2. 重新將 SDDM 設為預設 Display Manager（確保系統服務鏈結正常）

```bash
# 執行後選擇 sddm 即可
sudo dpkg-reconfigure sddm

```

#### 3. 重新建立系統動態庫與 initramfs 快取

```bash
# 雙重確認動態庫與開機映像檔乾淨無污染
sudo ldconfig
sudo update-initramfs -u

```

---

### 恭喜！兩台外置 SSD（Fedora & Ubuntu Budgie）已全數修復完畢 👏

這次的故障排除過程非常經典：

1. **Fedora 外置 SSD**：因為 `conky.conf` 導致 `zstd` 崩潰，無法生成 `initramfs`，開機卡死在 `zram0`；經由 ext4 `fsck` + chroot 清除污染 + `dracut` 重建修復成功。
2. **Ubuntu Budgie 外置 SSD**：同樣因 `conky.conf` 造成 SDDM/Budgie 圖形庫載入失敗卡在登入頁；經由 chroot 清除污染 + 重建 `update-initramfs` 修復成功。

兩台系統現在都已恢復最佳狀態！
