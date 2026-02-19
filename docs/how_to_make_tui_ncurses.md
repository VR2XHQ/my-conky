下面我給你一個「可以直接編譯執行」的 ncurses TUI 範本，包含：

- 主視窗佈局（上方標題列 + 左側選單 + 右側內容區）
- 鍵盤操作（上下選單、Enter 確認、q 離開）
- 事件迴圈（main loop）
- 清楚拆分成數個函式，方便你之後擴充

---

## 範本結構概覽

整體程式會長這樣：

- `main()`
  - 初始化 ncurses
  - 初始化顏色
  - 建立視窗（header / menu / content）
  - 進入事件迴圈 `main_loop(...)`
  - 結束 ncurses
- `draw_header()`
- `draw_menu()`
- `draw_content()`
- `handle_input()`：處理鍵盤輸入（上下鍵、Enter、q）
- `main_loop()`：事件迴圈

---

## 完整範例程式（單檔，可直接編譯）

檔名例如：`tui_template.c`

```c
#include <ncurses.h>
#include <string.h>

#define MENU_ITEMS 4

typedef struct AppState {
    int running;              // 程式是否繼續執行
    int selected_index;       // 目前選單選項索引
    const char *menu_items[MENU_ITEMS];
} AppState;

// 函式宣告
void init_app_state(AppState *state);
void draw_header(WINDOW *header_win);
void draw_menu(WINDOW *menu_win, AppState *state);
void draw_content(WINDOW *content_win, AppState *state);
void handle_input(AppState *state, int ch);
void main_loop(WINDOW *header_win, WINDOW *menu_win, WINDOW *content_win, AppState *state);
void init_colors(void);

int main() {
    // 1. 初始化 ncurses
    initscr();              // 開啟 ncurses 模式
    cbreak();               // 停用行緩衝，輸入立即送到程式
    noecho();               // 不自動顯示輸入字元
    keypad(stdscr, TRUE);   // 啟用功能鍵（方向鍵等）
    curs_set(0);            // 隱藏游標

    if (has_colors()) {
        start_color();
        init_colors();
    }

    // 2. 取得終端大小
    int rows, cols;
    getmaxyx(stdscr, rows, cols);

    // 3. 建立視窗
    int header_height = 3;
    int menu_width    = cols / 4;  // 左側 1/4 做選單
    int content_width = cols - menu_width;

    WINDOW *header_win  = newwin(header_height, cols, 0, 0);
    WINDOW *menu_win    = newwin(rows - header_height, menu_width, header_height, 0);
    WINDOW *content_win = newwin(rows - header_height, content_width, header_height, menu_width);

    // 4. 初始化應用狀態
    AppState state;
    init_app_state(&state);

    // 5. 首次繪製
    draw_header(header_win);
    draw_menu(menu_win, &state);
    draw_content(content_win, &state);

    // 6. 進入事件迴圈
    main_loop(header_win, menu_win, content_win, &state);

    // 7. 清理與結束
    delwin(header_win);
    delwin(menu_win);
    delwin(content_win);
    endwin(); // 結束 ncurses

    return 0;
}

// 初始化顏色配對
void init_colors(void) {
    // 前景色, 背景色
    init_pair(1, COLOR_BLACK, COLOR_CYAN);    // header
    init_pair(2, COLOR_YELLOW, COLOR_BLUE);   // 被選取的 menu
    init_pair(3, COLOR_WHITE, COLOR_BLACK);   // 一般文字
    init_pair(4, COLOR_GREEN, COLOR_BLACK);   // content 高亮文字
}

// 初始化應用狀態
void init_app_state(AppState *state) {
    state->running = 1;
    state->selected_index = 0;
    state->menu_items[0] = "總覽";
    state->menu_items[1] = "系統資訊";
    state->menu_items[2] = "設定";
    state->menu_items[3] = "關於";
}

// 繪製上方標題列
void draw_header(WINDOW *header_win) {
    int rows, cols;
    getmaxyx(header_win, rows, cols);

    werase(header_win);

    if (has_colors()) {
        wattron(header_win, COLOR_PAIR(1));
    }

    // 填滿背景顏色
    for (int i = 0; i < cols; i++) {
        mvwaddch(header_win, 0, i, ' ');
        mvwaddch(header_win, 1, i, ' ');
        mvwaddch(header_win, 2, i, ' ');
    }

    const char *title = " ncurses TUI 範本 ";
    mvwprintw(header_win, 1, (cols - (int)strlen(title)) / 2, "%s", title);

    if (has_colors()) {
        wattroff(header_win, COLOR_PAIR(1));
    }

    box(header_win, 0, 0);
    mvwprintw(header_win, 0, 2, "[ F1:Help  q:退出 ]");

    wrefresh(header_win);
}

// 繪製左側選單
void draw_menu(WINDOW *menu_win, AppState *state) {
    werase(menu_win);
    box(menu_win, 0, 0);
    mvwprintw(menu_win, 0, 2, "[ 選單 ]");

    for (int i = 0; i < MENU_ITEMS; i++) {
        int y = i + 2;
        if (i == state->selected_index) {
            if (has_colors()) wattron(menu_win, COLOR_PAIR(2));
            mvwprintw(menu_win, y, 2, "> %s", state->menu_items[i]);
            if (has_colors()) wattroff(menu_win, COLOR_PAIR(2));
        } else {
            mvwprintw(menu_win, y, 2, "  %s", state->menu_items[i]);
        }
    }

    wrefresh(menu_win);
}

// 根據選單狀態繪製右側內容區
void draw_content(WINDOW *content_win, AppState *state) {
    werase(content_win);
    box(content_win, 0, 0);
    mvwprintw(content_win, 0, 2, "[ 內容 ]");

    if (has_colors()) wattron(content_win, COLOR_PAIR(3));

    switch (state->selected_index) {
        case 0:
            mvwprintw(content_win, 2, 2, "這是「總覽」頁面。");
            mvwprintw(content_win, 3, 2, "可以在這裡顯示系統狀態摘要、快速資訊等。");
            break;
        case 1:
            mvwprintw(content_win, 2, 2, "這是「系統資訊」頁面。");
            mvwprintw(content_win, 3, 2, "你可以在這裡放 CPU / 記憶體 / 網路等監控。");
            break;
        case 2:
            mvwprintw(content_win, 2, 2, "這是「設定」頁面。");
            mvwprintw(content_win, 3, 2, "在這裡可以提供可調整的選項與表單。");
            break;
        case 3:
            mvwprintw(content_win, 2, 2, "這是「關於」頁面。");
            mvwprintw(content_win, 3, 2, "放版本資訊、作者、使用說明等。");
            break;
        default:
            mvwprintw(content_win, 2, 2, "未知選項。");
            break;
    }

    if (has_colors()) wattroff(content_win, COLOR_PAIR(3));

    if (has_colors()) wattron(content_win, COLOR_PAIR(4));
    mvwprintw(content_win, getmaxy(content_win) - 2, 2,
              "提示: 使用上下鍵移動選單, Enter 確認, q 離開。");
    if (has_colors()) wattroff(content_win, COLOR_PAIR(4));

    wrefresh(content_win);
}

// 處理鍵盤輸入，更新 AppState
void handle_input(AppState *state, int ch) {
    switch (ch) {
        case 'q':
        case 'Q':
            state->running = 0;
            break;
        case KEY_UP:
            state->selected_index--;
            if (state->selected_index < 0) {
                state->selected_index = MENU_ITEMS - 1;
            }
            break;
        case KEY_DOWN:
            state->selected_index++;
            if (state->selected_index >= MENU_ITEMS) {
                state->selected_index = 0;
            }
            break;
        case '\n':  // Enter
        case KEY_ENTER:
            // 在這裡可以加入「選取後執行動作」的邏輯
            // 例如根據 selected_index 觸發不同功能
            break;
        default:
            break;
    }
}

// 主事件迴圈
void main_loop(WINDOW *header_win, WINDOW *menu_win, WINDOW *content_win, AppState *state) {
    int ch;
    while (state->running) {
        ch = getch();               // 取得鍵盤輸入
        handle_input(state, ch);    // 依輸入更新狀態

        // 依狀態重新繪製畫面
        draw_header(header_win);
        draw_menu(menu_win, state);
        draw_content(content_win, state);
    }
}
```

---

## 編譯與執行

在 Linux 終端：

```bash
gcc tui_template.c -lncurses -o tui_template
./tui_template
```

如果你的系統把 ncurses 拆成 `ncursesw`（寬字元版本）：

```bash
gcc tui_template.c -lncursesw -o tui_template
```

---

## 程式架構與事件迴圈說明

### 1. 狀態集中管理：`AppState`

```c
typedef struct AppState {
    int running;
    int selected_index;
    const char *menu_items[MENU_ITEMS];
} AppState;
```

- `AppState` 就是你的「全域狀態容器」
- 所有 UI 的變化都應該來自 `AppState`
- 事件迴圈只負責：
  - 讀輸入 → 更新 `AppState` → 重畫畫面

這種寫法的好處是之後可以很自然地擴充：

- 新增頁面
- 加入子選單狀態
- 加入設定值（例如刷新頻率、顯示模式）

---

### 2. 初始化與結束

`main()` 裡的流程：

1. 初始化 ncurses：`initscr()`, `cbreak()`, `noecho()`, `keypad()`, `curs_set()`
2. 建立視窗：`header_win`, `menu_win`, `content_win`
3. 初始化 `AppState`
4. 首次繪製畫面
5. 進入 `main_loop(...)`
6. 離開時 `delwin()` + `endwin()`

這是「標準 TUI 程式骨架」，之後你只要在中間插入自己邏輯即可。

---

### 3. 分區視窗：header + menu + content

視窗區塊拆分：

- header：顯示標題與快捷提示
- menu：顯示目前可選的功能項目
- content：根據選單做不同內容顯示

這樣的分區方式跟你平常拆「status bar / sidebar / main panel」的概念類似，之後也可以：

- 加底部 status bar
- 在 content 中再切子視窗（例如上下分割 log 與 detail）

---

### 4. 事件迴圈：`main_loop()`

```c
while (state->running) {
    ch = getch();
    handle_input(state, ch);
    draw_header(...);
    draw_menu(...);
    draw_content(...);
}
```

這就是 TUI 的「心臟」：

- `getch()` 是阻塞呼叫（等待輸入）
- 每次輸入 → 更新狀態 → 重畫畫面  
如果你想做「定期刷新」（例如每秒更新系統監控），可考慮：

- 改用 `nodelay(stdscr, TRUE)` + `usleep()`
- 或是 `timeout(ms)` 讓 `getch()` 最多等待一段時間

---

### 5. 輸入處理：`handle_input()`

這裡只做一件事：「解讀鍵盤 → 更新 AppState」。

- `KEY_UP / KEY_DOWN`：改變選單索引
- `'q'`：設定 `running = 0`
- `Enter`：之後可以加上「執行選單動作」

你之後可以在這裡延伸：

- 加 `KEY_LEFT / KEY_RIGHT` 做頁面切換
- 加 `F1 / F2 / F5` 等快捷鍵
- 加狀態 flag，例如 `editing_mode`, `help_visible`

---

## 下一步可以怎麼學、怎麼改？

如果你想「用做中學」，可以依序玩這幾個改動：

1. 把「系統資訊」頁面改成顯示實際資料，例如：
   - `/proc/loadavg`、`/proc/meminfo` 的解析後文字
2. 在「設定」頁面加一個可以切換的選項，例如：
   - 顯示模式：簡潔 / 詳細
   - 用空白鍵切換，狀態存進 `AppState`
3. 加一個底部 status bar：
   - 新增一個 `status_win`
   - 顯示目前選單名稱、時間、提示訊息

如果你願意，我可以幫你把這個範本進一步改成：

-「簡易系統監控 TUI」（讀 `/proc`）  
- 或「設定精靈」（有可編輯欄位與確認步驟）

你想先從哪一種擴充開始？我可以直接在這個範本上幫你做下一版。
