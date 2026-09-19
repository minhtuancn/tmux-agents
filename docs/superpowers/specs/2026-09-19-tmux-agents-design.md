# tmux-agents — Design Spec

Ngày: 2026-09-19
Trạng thái: Approved (user duyệt design)

## 1. Mục tiêu

Đóng gói cấu hình + công cụ tmux hiện đang chạy trên máy dev thành một **bản cài đặt tự động** có thể deploy lên máy khác (Linux Debian/Ubuntu, Linux generic không sudo, macOS), đặt trong repo GitHub `minhtuancn/tmux-agents` (hiện gần như trống: LICENSE + README.md 56B).

Giữ nguyên trải nghiệm hiện tại:
- `t` → vào tmux (session chính `main`)
- `tls` → TUI list & select session (script bash đang chạy tại `~/.local/bin/tls`, v3, ASCII, chọn bằng số/phím)
- Trong tmux: `F1` → menu nhanh, `F1`→`s` → danh sách session (choose-tree)
- Theme Tokyo Night, status bar phía trên

Nâng cấp giao diện status bar theo yêu cầu:
1. Tên session **đậm**
2. Tên ứng dụng đang chạy (window name) nằm ngang với session, **đậm**
3. Hiển thị tên thư mục có đường dẫn; đường dẫn quá dài → rút gọn giữ đuôi (luôn hiện đúng thư mục cuối)
4. Thời gian quy đổi cố định **GMT+7** bất kể TZ của server

## 2. Layout repo

```
/home/dev/tmux/  (= repo tmux-agents)
├── README.md            # quickstart 1 lệnh, screenshot, giới thiệu tính năng
├── LICENSE              # MIT (giữ nguyên từ repo hiện có)
├── install.sh           # installer đa nền tảng, idempotent
├── tmux.conf            # config master (status bar mới + giữ bindings/menus)
├── help.txt             # sao chép nguyên trạng từ ~/.tmux/help.txt
├── bin/
│   ├── tls              # GIỮ code picker hiện tại (tinh chỉnh path truncate)
│   ├── t                # MỚI: wrapper t/tls
│   ├── tmux-menu        # giữ nguyên (manager menu phụ)
│   └── vn-time.sh       # MỚI: xuất giờ GMT+7
├── plugins/             # vendor sẵn: tpm, tmux-sensible, tmux-yank (cài offline được)
└── docs/superpowers/specs/2026-09-19-tmux-agents-design.md
```

## 3. Status bar (tmux.conf)

### 3.1 Cấu trúc top bar (Tokyo Night)

```
[ SESSION ] [ APP ] [📁 path]   ⋯ tabs ⋯   [📍 Thứ DD T gg:pp GMT+7] [ HOST ]
```

- `status-position top`, `status-interval 2`
- **status-left** — 3 chip:
  1. `#[bg=#7aa2f7,fg=#1a1b26,bold] #S ` — session name, **bold**
  2. `#[bg=#7dcfff,fg=#16161e,bold] #W ` — tên ứng dụng đang chạy (window name, auto-rename), **bold**, ngay cạnh session
  3. `#[bg=#292e42,fg=#a9b1d6] 📁 {cwd} ` — thư mục làm việc
- **cwd** format (pure format, không phụ thuộc shell):
  - base: `#{s|#{HOME}|~|:pane_current_path}` (home → `~`, nested expand)
  - truncate: `#{=<-24:...}` giữ 24 ký tự **cuối** (luôn lộ thư mục cuối khi path dài)
- **status-right**:
  - `#[bg=#292e42,fg=#a9b1d6] #(~/.tmux/bin/vn-time.sh) GMT+7 `
  - `#[bg=#bb9af7,fg=#1a1b26,bold] #h ` — hostname chip tím, bold (giữ style cũ)
- **window-status** (tabs): giữ màu Tokyo Night; active tab thêm **bold**

### 3.2 vn-time.sh

```bash
#!/usr/bin/env bash
TZ=Asia/Ho_Chi_Minh date '+%a %d %b %H:%M'
```

Output ví dụ: `Thu 19 Sep 00:44`. Nhãn `GMT+7` đặt tĩnh ở status-right liền sau.

Lưu ý kỹ thuật (đã verify trong môi trường dev):
- `#()` trong tmux 3.4 cache kết quả, refresh ≥1s/lần — phù hợp status-interval 2
- Trong `display -p` (headless) `#()` chưa kịp chạy → hiện placeholder rỗng; **status bar render bình thường khi có client gắn vào** (theo man page tmux). Không thể preview headless trong env này → verify live sau khi cài.
- Không dùng quote bên trong `#(...)` → tách cmd ra script file.

### 3.3 Giữ nguyên từ config hiện tại

- Prefix `C-a`, bindings split/pane/resize/tab, `r` reload
- F1 menu (Quick Actions), `C-a m` (Tmux Menu), `C-a M` (Manager Menu)
- OSC 52 clipboard (`set-clipboard on`, terminal-features, allow-passthrough)
- Theme Tokyo Night, mouse, base-index 1, renumber-windows, history 50000
- Plugins tpm/sensible/yank; auto-clone tpm nếu thiếu

**Thay đổi duy nhất**: bọc các mục menu gọi lệnh `manager` bằng
`if-shell "command -v manager"` — máy không có `manager` không lỗi menu.
(fix sẵn lỗi quote dòng Cleanup đã sửa trong phiên trước)

## 4. bin/t và bin/tls

### 4.1 bin/tls — redesign "Table Pro" (adaptive frame)

Giữ toàn bộ logic hiện có (list → select → switch/attach, n/d/r/f/R/q, quick number, filter, new session tạo + attach), **redesign phần render**:

**Mockup mục tiêu (kiểu UTF-8):**
```
  ╭─ TMUX SESSIONS ──────────────────────── 3 đang chạy ─╮
  │                                                        │
  │    #  SESSION    RUNNING   UPTIME    WIN   PATH        │
  │  ───────────────────────────────────────────────────── │
  │  ● 1 main      ▸ bash      2d03h     2w    ~/tmux      │
  │  ❯ 2 dev-api   ▸ nvim      5h12m     3w    ~/dev/api   │
  │    3 deploy    ▸ bash      12m       1w    /srv/deploy │
  │                                                        │
  │  [1-9] vào · ↑↓/jk chọn · n tạo · d xoá · r đổi tên · │
  │  f lọc · R refresh · q thoát                          │
  ╰────────────────────────────────────────────────────────╯
```

**Cơ chế chống vỡ khung (bắt buộc):**
1. **Auto-detect UTF-8**: `locale charmap` hoặc `$LANG`/`$LC_ALL` chứa `UTF-8` → khung unicode; ngược lại → khung ASCII:
   ```
   +-- TMUX SESSIONS -----------------------------+
   |  #  SESSION  RUNNING  UPTIME  WIN  PATH      |
   +----------------------------------------------+  (đỉnh/gạch dưới)
   |  ...                                         |
   +----------------------------------------------+
   ```
2. **Env override**: `TLS_STYLE=ascii|unicode` (mặc định auto).
3. **Căn chỉnh theo display width** (đếm ký tự, không đếm byte — dùng `wc -m` hoặc `${#}` với locale UTF-8) → tên session chứa dấu tiếng Việt/unicode không làm lệch cột.
4. PATH cột: `~`-short + giữ đuôi tối đa 22 ký tự (nhất quán status bar).

**Màu (Tokyo Night, đồng bộ tmux.conf):**
- Viền/title: cyan `#7dcfff` (ANSI 36/1), header dim
- Dòng chọn: **nền dim `#292e42` (ANSI 48;5;236) + chữ đậm cyan**, marker `❯` (unicode) / `>` (ascii)
- Dòng thường: dim nhạt; marker `●` (unicode) / `*` (ascii) cho session hiện tại
- Footer phím tắt: dim, tách bằng `·`
- Số thứ tự: vàng (giữ style hiện tại)

**Vẫn giữ**: current-session marker, sort theo activity (mới nhất trên), trong-tmux → `switch-client`, ngoài → `attach-session`, filter, new/delete(confirm)/rename, empty state có gợi ý `n`.

Nếu khung vẫn không đẹp trên terminal đặc thù (font/emulator phá glyph dù đã UTF-8) → phương án dự phòng "Icon-rich" (emoji cột, bỏ hẳn khung viền) như đã bàn — quyết định khi verify live.

### 4.2 bin/t (mới)
```bash
#!/usr/bin/env bash
# t — vào tmux: picker nếu đã có session, tạo main nếu chưa
if ! tmux has-session 2>/dev/null; then
  exec tmux new-session -A -s main   # chưa có session nào → tạo/attach main
fi
exec tls  # có session → cùng picker tls (tự switch/attach)
```
(đơn giản, minh bạch — không lồng alias phức tạp)

### 4.3 bin/tmux-menu (giữ nguyên)
Không đổi.

## 5. install.sh

Idempotent, chạy `bash install.sh`:

1. **Backup**: `~/.tmux.conf` tồn tại → copy sang `~/.tmux.conf.bak-<YYYYmmdd-HHMMSS>` (không xoá)
2. **Package** (chỉ khi thiếu lệnh): 
   - Debian/Ubuntu + sudo: `apt-get install -y tmux xclip`
   - Debian/Ubuntu không sudo: cảnh báo, tiếp tục config
   - macOS + brew: `brew install tmux` (pbcopy có sẵn)
   - Detect OS qua `uname` + `/etc/os-release`
3. **Copy config**: `tmux.conf` → `~/.tmux.conf` (overwrite; backup đã có ở bước 1)
4. **Scripts**: `bin/*` → `~/.local/bin/` + `chmod +x`
5. **Help**: `help.txt` → `~/.tmux/help.txt`
6. **vn-time**: `bin/vn-time.sh` → `~/.tmux/bin/vn-time.sh` (ĐỊNH VỊ CỐ ĐỊNH — tmux.conf tham chiếu `#(~/.tmux/bin/vn-time.sh)`, không được đổi nơi khác) + chmod +x.
7. **Plugins**: copy `plugins/*` → `~/.tmux/plugins/` (không đè nếu tồn tại; dùng rsync/cp -n)
8. **.bashrc**: thêm nếu chưa có:
   ```bash
   alias t='/home/<user>/.local/bin/t'     # dùng $HOME
   alias tls='/home/<user>/.local/bin/tls'
   ```
   (dùng literal `$HOME` — viết `alias t="${HOME}/.local/bin/t"` khi generate, hoặc alias t='~/.local/bin/t' — bash expand tilde trong alias? KHÔNG. → dùng `eval` không; chốt: alias t="$HOME/.local/bin/t")
9. **Verify**: `tmux source-file ~/.tmux.conf -L <tạm>` → in "OK"; báo kết quả từng bước
10. Nếu header não tương tác (CI): `--yes` skip prompts

Output in màu, đánh số bước, exit code 0/1.

## 6. Git & push

- Repo local tại `/home/dev/tmux` (đã `git init -b main`)
- Commit theo từng giai đoạn (spec → scripts → config/install → README → push)
- Push lên `minhtuancn/tmux-agents` (main) bằng `gh` CLI (MCP GitHub đang 401)
- Giữ LICENSE MIT từ repo hiện có (fetch qua gh, giữ nguyên)

## 7. Verification

| Mục | Cách kiểm |
|-----|----------|
| Config không lỗi | `tmux -f /dev/null source-file tmux.conf` |
| tls hoạt động | chạy thử `bash bin/tls` (ngoài & trong tmux) |
| Bin executables | `bash -n` mỗi script |
| Status bar visual | live check bằng mắt sau khi user chạy `t` (không preview headless được) |
| Install idempotent | chạy `install.sh` 2 lần trên máy test → không đổi state |

## 8. Không nằm trong scope

- Sửa `tmux-menu` / F1 menu nội dung (giữ nguyên)
- Banner login `/etc/profile.d/99-dev-hint.sh` (máy-specific, không đóng gói)
- Plugins mới, theme mới