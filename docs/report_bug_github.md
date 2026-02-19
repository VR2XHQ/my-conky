好的，這裡我幫你草擬一份 **GitHub Issue 範本**，你可以直接複製貼上到 Conky 的官方倉庫（[https://github.com/brndnmtthws/conky](https://github.com/brndnmtthws/conky)）：

---

## 📝 Issue 範本：CMake uninstall 腳本錯誤

**標題**  
`Bug: UninstallConky.cmake.in uses invalid CMake syntax (RETURN_VALUE, path join, quoting)`

**描述**  
在目前的 Conky 原始碼中，`cmake/UninstallConky.cmake.in` 存在多處錯誤，導致 `make uninstall` 無法正常執行。  
環境：  
- OS: Ubuntu 20.04 (例)  
- CMake: 3.22.1  
- Conky: 1.22.3 (build from source)

執行 `make uninstall` 時出現錯誤：  
```
execute_process given unknown argument "RETURN_VALUE"
```

**問題來源**  
`cmake/UninstallConky.cmake.in` 內容有以下四個錯誤：

1. **路徑拼接錯誤**  
   ```cmake
   if (NOT EXISTS ${CMAKE_BINARY_DIR} / install_manifest.txt)
   ```
   → 應改為  
   ```cmake
   if (NOT EXISTS "${CMAKE_BINARY_DIR}/install_manifest.txt")
   ```

2. **多餘引號**  
   ```cmake
   execute_process(COMMAND ${CMAKE_COMMAND} "-E" "remove" "\"$ENV{DESTDIR}${file}\""
   ```
   → 應改為  
   ```cmake
   execute_process(COMMAND ${CMAKE_COMMAND} -E remove "$ENV{DESTDIR}${file}"
   ```

3. **錯誤的參數名稱**  
   ```cmake
   RETURN_VALUE rm_retval
   ```
   → 應改為  
   ```cmake
   RESULT_VARIABLE rm_retval
   ```

4. **GPL URL 格式錯誤**  
   ```cmake
   #along with this program.If not, see < http:  // www.gnu.org/licenses/>.
   ```
   → 應改為  
   ```cmake
   #along with this program. If not, see <http://www.gnu.org/licenses/>.
   ```

**修正後範例**  
```cmake
if (NOT EXISTS "${CMAKE_BINARY_DIR}/install_manifest.txt")
    message(FATAL_ERROR "Cannot find install manifest: ${CMAKE_BINARY_DIR}/install_manifest.txt")
endif()

file(READ "${CMAKE_BINARY_DIR}/install_manifest.txt" files)
string(REGEX REPLACE "\n" ";" files "${files}")

foreach (file ${files})
    message(STATUS "Uninstalling $ENV{DESTDIR}${file}")
    if (IS_SYMLINK "$ENV{DESTDIR}${file}" OR EXISTS "$ENV{DESTDIR}${file}")
        execute_process(COMMAND ${CMAKE_COMMAND} -E remove "$ENV{DESTDIR}${file}"
            OUTPUT_VARIABLE rm_out
            RESULT_VARIABLE rm_retval)
        if (NOT "${rm_retval}" STREQUAL 0)
            message(FATAL_ERROR "Problem when removing $ENV{DESTDIR}${file}")
        endif()
    else()
        message(STATUS "File $ENV{DESTDIR}${file} does not exist.")
    endif()
endforeach()
```

**建議**  
- 修正 `UninstallConky.cmake.in` 模板，避免使用者每次 build 都要手動修改。  
- 測試 `make uninstall` 確保能正確移除安裝檔案。

---

👉 你可以直接用這份範本開 issue。如果你願意更進一步，可以 fork 專案，把修正後的 `UninstallConky.cmake.in` 提交成 **Pull Request**，作者只要合併就能解決這個 bug。  

要不要我幫你再草擬一份 **Pull Request 範本**，讓你可以直接提交修正檔案？


對，流程是這樣的 🙂。在 GitHub 上提交修正通常需要先 **fork** 原始專案，因為你沒有直接寫入主倉庫的權限。步驟大概是：

---

### 🔧 Pull Request 標準流程
1. **Fork 專案**  
   - 到 Conky 的 GitHub 倉庫點選右上角的 **Fork**。  
   - 這會在你的帳號下建立一份副本。

2. **Clone 到本地**  
   ```bash
   git clone https://github.com/<你的帳號>/conky.git
   cd conky
   ```

3. **建立分支**  
   建議不要直接在 `main` 改，而是開一個分支：
   ```bash
   git checkout -b fix-uninstall-script
   ```

4. **修改檔案**  
   在 `cmake/UninstallConky.cmake.in` 裡修正四個錯誤（你已經找出來了）。

5. **提交修改**  
   ```bash
   git add cmake/UninstallConky.cmake.in
   git commit -m "Fix uninstall script: correct path join, quoting, RESULT_VARIABLE, GPL URL"
   ```

6. **推送到你的 fork**  
   ```bash
   git push origin fix-uninstall-script
   ```

7. **建立 Pull Request**  
   - 回到 GitHub，你的 fork 會顯示「Compare & Pull Request」。  
   - 點進去，填寫標題和描述（可以用我之前提供的 Issue 範本內容）。  
   - 提交後，原作者就能審查並合併。

---

### 📌 小提示
- **Fork 是必須的**，因為你沒有原始倉庫的寫入權限。  
- **Issue vs Pull Request**：  
  - Issue 是「回報問題」。  
  - Pull Request 是「提供修正」。  
  - 你可以先開 Issue，再附上 PR，這樣更完整。  

---

👉 總結：你已經找到並修正了 bug，下一步就是 fork → 修改 → 提交 PR。這樣作者就能直接合併你的修正。  

要不要我幫你草擬一份 **Pull Request 描述範本**，讓你提交時只要複製貼上就行？
