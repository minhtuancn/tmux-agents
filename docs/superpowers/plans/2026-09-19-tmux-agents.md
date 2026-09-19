# tmux-agents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Đóng gói config tmux hiện tại thành repo `tmux-agents` với installer đa nền tảng, status bar mới (session/app đậm, path rút gọn, giờ GMT+7) và TUI `tls` "Table Pro" adaptive frame.

**Architecture:** Một repo git tại `/home/dev/tmux` chứa config master `tmux.conf`, bộ scripts `bin/` (t, tls, tmux-menu, vn-time.sh), `install.sh` idempotent copy ra `~/.tmux*` + `~/.local/bin` + ghi `.bashrc`, và plugins vendor (tpm/sensible/yank) để cài offline. Push lên GitHub `minhtuancn/tmux-agents`.

**Tech Stack:** bash, tmux 3.4+, Git, GitHub CLI (`gh` — MCP GitHub đang lỗi 401).

**Spec:** `docs/superpowers/specs/2026-09-19-tmux-agents-design.md`

## Global Constraints

- Config master phải giữ NGUYÊN toàn bộ binding/menu/theme hiện tại (prefix `C-a`, F1 menu, `C-a m`, `C-a M`, OSC 52, Tokyo Night).
- Không dùng dấu nháy đơn `'` bên trong `#(...)` của tmux format (dùng script file thay thế).
- `vn-time.sh` phải nằm CỐ ĐỊNH tại `~/.tmux/bin/vn-time.sh` (tmux.conf tham chiếu trực tiếp).
- tmux.conf chạy OK cả khi máy thiếu lệnh `manager` (guard menu).
- tls: không đổi logic tương tác hiện tại (n/d/r/f/R/q, số 1-9, `Up/Down/jk`, switch-client/attach), chỉ đổi render + helpers.
- Mọi script bash: `#!/usr/bin/env bash`, `chmod +x`.
- Alias trong .bashrc dùng `$HOME` literal (bash KHÔNG expand tilde trong alias).
- Remote cứng: `minhtuancn/tmux-agents`, branch `main`.

## Files

| File | Trạng thái | Trách nhiệm |
|------|-----------|-------------|
| `bin/vn-time.sh` | MỚI | xuất giờ GMT+7 |
| `bin/t` | MỚI | vào tmux: tạo main nếu chưa có session, ngược lại gọi tls |
| `bin/tls` | SỬA | TUI picker "Table Pro" adaptive (giữ logic, thay render) |
| `bin/tmux-menu` | COPY | giữ nguyên (file đang chạy) |
| `tmux.conf` | MỚI (repo) | config master: status bar mới + guard manager |
| `install.sh` | MỚI | installer idempotent đa nền tảng |
| `help.txt` | COPY | từ `~/.tmux/help.txt` |
| `plugins/{tpm,tmux-sensible,tmux-yank}` | COPY | vendor từ `~/.tmux/plugins/` |
| `README.md` | VIẾT LẠI | quickstart + tính năng |
| `LICENSE` | COPY | fetch từ repo GitHub hiện có (giữ nguyên) |

---

### Task 1: `bin/vn-time.sh`

**Files:**
- Create: `bin/vn-time.sh`

**Interfaces:**
- Produces: script tại `bin/vn-time.sh`; install.sh copy sang `~/.tmux/bin/vn-time.sh`; tmux.conf gọi `#(~/.tmux/bin/vn-time.sh)`.

- [ ] **Step 1: Tạo script**

```bash
#!/usr/bin/env bash
# vn-time.sh — in giờ GMT+7 (Asia/Ho_Chi_Minh), bất kể TZ server
TZ=Asia/Ho_Chi_Minh date '+%a %d %b %H:%M'
```

- [ ] **Step 2: Verify**

Run: `chmod +x bin/vn-time.sh && bash -n bin/vn-time.sh && bin/vn-time.sh`
Expected: không lỗi cú pháp; output khớp `^[A-Z][a-z]{2} [0-9]{2} [A-Z][a-z]{2} [0-9]{2}:[0-9]{2}$`

- [ ] **Step 3: Commit**

```bash
git add bin/vn-time.sh
git commit -m "feat(bin): vn-time.sh — giờ GMT+7 cố định"
```

---

### Task 2: `bin/t`

**Files:**
- Create: `bin/t`

**Interfaces:**
- Consumes: `tls` (thư mục cùng / PATH).
- Produces: script `bin/t`; install.sh copy sang `~/.local/bin/t`; alias `t='$HOME/.local/bin/t'`.

- [ ] **Step 1: Tạo script**

```bash
#!/usr/bin/env bash
# t — vào tmux: chưa có session nào → tạo/attach main; đã có → picker tls
set -uo pipefail

if ! tmux has-session 2>/dev/null; then
  exec tmux new-session -A -s main
fi
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/tls"
```
Lưu ý: resolve `tls` theo thư mục kế bên (hoạt động cả khi chạy từ repo lẫn sau install → cùng `~/.local/bin`).

- [ ] **Step 2: Verify**

Run: `chmod +x bin/t && bash -n bin/t`
Expected: không lỗi cú pháp. (Chạy thật chỉ khi user yêu cầu manual — nó tạo session `main` trên máy.)

- [ ] **Step 3: Commit**

```bash
git add bin/t
git commit -m "feat(bin): t — vào tmux nhanh (main hoặc picker)"
```

---

### Task 3: `bin/tls` — render "Table Pro" adaptive

**Files:**
- Modify: `bin/tls` (base = copy code hiện tại, thay HELPERS + RENDER)

**Interfaces:**
- Produces: script `bin/tls` giữ nguyên tên hàm `collect/build_filtered/read_key/do_switch/do_new/do_delete/do_rename/do_filter`; install.sh copy sang `~/.local/bin/tls`.

- [ ] **Step 1: Copy code hiện tại làm base**

```bash
cp ~/.local/bin/tls bin/tls
```

- [ ] **Step 2: Thay block HELPERS (từ `current_session()` đến hết `uptime_str()`) bằng code dưới**

```bash
# ── Display width (bỏ ANSI, đếm ký tự) ──
dwc() { local s; s=$(printf '%s' "$1" | sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g'); printf '%s' "${#s}"; }

# ── Detect unicode frame ──
UNICODE=0
detect_unicode() {
  case "${TLS_STYLE:-auto}" in
    ascii)   UNICODE=0 ;;
    unicode) UNICODE=1 ;;
    *)
      case "$(locale charmap 2>/dev/null)" in
        UTF-8|utf8) UNICODE=1 ;;
        *)          UNICODE=0 ;;
      esac ;;
  esac
}

# ── Bộ ký tự khung ──
C_TL=+; C_TR=+; C_BL=+; C_BR=+; C_H=-; C_V="|"; C_CUR=">"; C_AT="*"
init_chars() {
  if [ "$UNICODE" = 1 ]; then
    C_TL="╭"; C_TR="╮"; C_BL="╰"; C_BR="╯"
    C_H="─"; C_V="│"; C_CUR="❯"; C_AT="●"
  fi
}

current_session() {
  [ -n "${TMUX:-}" ] && tmux display-message -p '#{session_name}' 2>/dev/null || echo ""
}

collect() {
  S_NAME=(); S_CREATED=(); S_ACTIVITY=(); S_WINDOWS=()
  S_WINDOW=(); S_PATH=(); S_ATTACHED=()

  while IFS='|' read -r act name created wins win path attached; do
    [ -z "$name" ] && continue
    S_NAME+=("$name");      S_CREATED+=("$created")
    S_ACTIVITY+=("$act");   S_WINDOWS+=("$wins")
    S_WINDOW+=("$win");     S_PATH+=("$path")
    S_ATTACHED+=("$attached")
  done < <(tmux list-sessions \
    -F '#{session_activity}|#{session_name}|#{session_created}|#{session_windows}|#{window_name}|#{pane_current_path}|#{session_attached}' \
    2>/dev/null | sort -t'|' -k1 -rn)
}

build_filtered() {
  F_IDX=()
  local cur; cur=$(current_session)
  local n=${#S_NAME[@]}

  for ((i=0; i<n; i++)); do
    if [ -n "$filter" ]; then
      local ln="${S_NAME[$i],,}" lf="${filter,,}" lp="${S_PATH[$i],,}"
      [[ "$ln" == *"$lf"* || "$lp" == *"$lf"* ]] || continue
    fi
    F_IDX+=("$i")
  done

  local fc=${#F_IDX[@]}
  [ "$selected" -ge "$fc" ] && selected=$(( fc > 0 ? fc - 1 : 0 ))
}

uptime_str() {
  local c=$1 now diff d h m
  now=$(date +%s)
  diff=$((now - c))
  if   (( diff < 60 ));    then printf '%ds' "$diff"
  elif (( diff < 3600 ));  then printf '%dm' "$((diff / 60))"
  elif (( diff < 86400 )); then d=$((diff / 3600)); m=$(((diff % 3600) / 60)); printf '%dh%02dm' "$d" "$m"
  else                            d=$((diff / 86400)); h=$(((diff % 86400) / 3600)); printf '%dd%02dh' "$d" "$h"
  fi
}

short_path() {
  # ~-short + giữ đuôi tối đa 22 ký tự (thư mục cuối luôn lộ)
  local p="$1"
  [ -z "$p" ] && { echo "-"; return; }
  case "$p" in
    "$HOME"*) p="~${p#"$HOME"}" ;;
  esac
  [ "${#p}" -gt 22 ] && p="...${p: -19}"
  printf '%s' "$p"
}

pad_col() {  # $1=text $2=width $3=align(L|R)
  local t="$1" w="$2" a="${3:-L}" len pad
  len=$(dwc "$t")
  [ "$len" -ge "$w" ] && { printf '%s' "$t"; return; }
  pad=$((w - len))
  if [ "$a" = "R" ]; then printf '%'"$pad"'s%s' '' "$t"; else printf '%s%'"$pad"'s' "$t" ''; fi
}
```

- [ ] **Step 3: Thay toàn bộ hàm `render()` bằng code dưới**

```bash
frame_w() {  # độ rộng nội dung (cols - viền 2), giới hạn để không vỡ
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  local w=$((cols - 4))
  [ "$w" -gt 84 ] && w=84
  [ "$w" -lt 40 ] && w=40
  printf '%s' "$w"
}

render() {
  local cur; cur=$(current_session)
  local fc=${#F_IDX[@]}
  local w; w=$(frame_w)
  local hdr="SESSION     UPTIME   WINS  RUNNING     PATH"

  line_top=$(printf '%s' "$C_TL"; printf '%*s' "$((w+2))" '' | tr ' ' "$C_H"; printf '%s' "$C_TR")
  line_mid=$(printf '%s' "$C_V"; printf '%*s' "$((w+2))" '' | tr ' ' "$C_H"; printf '%s' "$C_V")
  line_bot=$(printf '%s' "$C_BL"; printf '%*s' "$((w+2))" '' | tr ' ' "$C_H"; printf '%s' "$C_BR")

  clear
  echo ""
  printf "  %s\n" "$line_top"
  printf "  ${BLD}${CYN}  TMUX SESSIONS${RST}  %*s ${DIM}%d dang chay${RST}\n" "$((w-15))" "" "$fc"
  printf "  %s\n" "$line_mid"

  if [ "$fc" -eq 0 ]; then
    if [ -n "$filter" ]; then
      printf "  ${C_V}  ${DIM}No sessions match '%s'${RST}\n" "$filter"
    else
      printf "  ${C_V}  ${DIM}No tmux sessions found${RST}\n"
    fi
    printf "  ${C_V}  ${DIM}Press ${BLD}n${RST}${DIM} to create a new session${RST}\n"
  else
    printf "  ${C_V}  ${DIM}%s${RST}\n" "$hdr"
    printf "  %s\n" "$line_mid"

    local pos=0
    for i in "${F_IDX[@]}"; do
      local u; u=$(uptime_str "${S_CREATED[$i]}")
      local wl; wl="${S_WINDOWS[$i]}w"
      local r="${S_WINDOW[$i]}"
      local p; p=$(short_path "${S_PATH[$i]}")
      local name="${S_NAME[$i]}"
      [[ ${#name} -gt 12 ]] && name="${name:0:10}.."

      local sel="0"; [ "$pos" -eq "$selected" ] && sel="1"
      local mark=" "; [ "$name" = "$cur" ] && mark="$C_AT"

      if [ "$sel" = "1" ]; then
        printf "  ${BGRY}${C_V} ${CUR}%s %s%s %s%s %s %s%s${RST}\n" \
          "$mark" \
          "$(pad_col "$name" 18)" \
          "$(pad_col "$u" 10)" \
          "$(pad_col "$wl" 6)" \
          "$(pad_col "$r" 10)" \
          "$(pad_col "$p" 22)"
      else
        printf "  ${C_V}  %s %s %s %s %s %s${RST}\n" \
          "$mark" \
          "$(pad_col "$name" 18)" \
          "$(pad_col "$u" 10)" \
          "$(pad_col "$wl" 6)" \
          "$(pad_col "$r" 10)" \
          "$(pad_col "$p" 22)"
      fi
      pos=$((pos + 1))
    done
  fi

  echo ""
  printf "  %s\n" "$line_mid"
  if [ "$fc" -gt 0 ]; then
    printf "  ${C_V}  ${BLD}[1-%d]${RST} vao  ${BLD}Up/Down${RST} chon  ${BLD}Enter${RST} switch\n" "$fc"
    printf "  ${C_V}  ${BLD}n${RST} tao  ${BLD}d${RST} xoa  ${BLD}r${RST} doi ten  ${BLD}f${RST} loc  ${BLD}R${RST} refresh  ${BLD}q${RST} thoat\n"
  fi
  printf "  %s\n" "$line_bot"
  echo ""
}

# ── Khởi tạo 1 lần — thêm TRƯỚC vòng lặp main (trước `collect` đầu tiên) ──
detect_unicode
init_chars
```

- [ ] **Step 4: Xoá code render cũ** — bỏ `LINE`/`LINE2` và block `render()` ASCII cũ; đảm bảo `BGRY` (nền dim `48;5;236`) có trong block Colors (thêm `BGRY='\033[48;5;236m'` nếu thiếu).

- [ ] **Step 5: Verify**

```bash
bash -n bin/tls
tmux -f /dev/null -L tlscheck new-session -d -s a -c /tmp 2>/dev/null
tmux -f /dev/null -L tlscheck new-session -d -s b -c /tmp 2>/dev/null
printf 'q' | TLS_STYLE=ascii bin/tls
```
Expected: render thành công, thoát sạch (exit 0), không treo. Nếu `read` nhận EOF làm lặp vô hạn → thay bằng `printf 'q' |` (đã dùng). Dọn dẹp: `tmux -f /dev/null -L tlscheck kill-server`.
(TLS_STYLE quyết định frame — script dùng `tmux` server MẶC ĐỊNH khi gọi lệnh; nếu máy đang có server thật sẽ list đúng session — vẫn an toàn vì chỉ `switch` khi chọn.)

- [ ] **Step 6: Commit**

```bash
git add bin/tls
git commit -m "feat(bin): tls — render 'Table Pro' adaptive (UTF-8/ASCII fallback, căn cột theo ký tự)"
```

---

### Task 4: `tmux.conf` — config master (status bar mới + guard manager)

**Files:**
- Create: `tmux.conf` (bản master — nội dung DƯỚI ĐÂY là config cuối cùng, copy nguyên vẹn)

**Interfaces:**
- Consumes: `~/.tmux/bin/vn-time.sh` (Task 1) qua `#(...)`; guard `command -v manager`.
- Produces: file `tmux.conf`; install.sh copy sang `~/.tmux.conf`.

- [ ] **Step 1: Tạo file với nội dung sau (chuẩn master)**

```conf
set -g default-command "LC_ALL=en_US.UTF-8 ${SHELL}"
set -g default-shell "${SHELL}"
set -g default-terminal "tmux-256color"
set -as terminal-overrides ',*:Tc'
set -as terminal-features ',xterm*:clipboard'

# Clipboard: forward OSC 52 (OpenCode) to outer terminal
set -g set-clipboard on
set -g allow-passthrough all
set -as terminal-features ',tmux-256color:clipboard'
set -as terminal-features ',screen-256color:clipboard'

set -g prefix C-a
unbind C-b
bind C-a send-prefix

set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g history-limit 50000
set -g set-titles on
set -g set-titles-string "#S — #W"
set -g renumber-windows on
set -g detach-on-destroy off
set -g escape-time 10
set -g focus-events on
set -g display-time 3000

set -g status-interval 2
set -g status-position top
set -g status-style "bg=#1a1b26,fg=#c0caf5"
# ── Status bar: SESSION (đậm) + APP (đậm) + path (~-short, rút gọn giữ đuôi) ──
set -g status-left "#[bg=#7aa2f7,fg=#1a1b26,bold] #S #[bg=#7dcfff,fg=#16161e,bold] #W #[bg=#292e42,fg=#a9b1d6]  ~#{=<-24:#{s|#{HOME}|~|:pane_current_path}} "
set -g status-left-length 66
# ── Status bar: giờ GMT+7 cố định qua script + host ──
set -g status-right "#[bg=#292e42,fg=#a9b1d6] #(~/.tmux/bin/vn-time.sh) GMT+7 #[bg=#bb9af7,fg=#1a1b26,bold] #h "
set -g status-right-length 72

setw -g window-status-current-style "bg=#1a1b26,fg=#7dcfff,bold"
setw -g window-status-current-format " #I:#W "
setw -g window-status-style "bg=#1a1b26,fg=#565f89"
setw -g window-status-format " #I:#W "
setw -g window-status-separator ""

set -g message-style "bg=#1a1b26,fg=#c0caf5"
set -g message-command-style "bg=#1a1b26,fg=#c0caf5"
set -g mode-style "bg=#c0caf5,fg=#1a1b26"
set -g display-panes-time 3000

bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"

bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

bind -r Tab next-window
bind -r BTab previous-window

bind r source-file ~/.tmux.conf \; display "Config reloaded"

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'

if "test ! -f ~/.tmux/plugins/tpm/tpm" {
  run "git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm 2>/dev/null"
}

# ── F1: Quick Actions (menu nhanh hằng ngày) ──
bind -n F1 display-menu -T " #[fg=#7dcfff,bold]⌘ Quick Actions " -x C -y C \
  "" \
  "  New Window      " n "new-window -c '#{pane_current_path}'" \
  "  Split H         " - "split-window -h -c '#{pane_current_path}'" \
  "  Split V         " | "split-window -v -c '#{pane_current_path}'" \
  "" \
  "  Sessions        " s "choose-tree -Zs" \
  "  Detach          " d "detach-client" \
  "" \
  "  Status          " S "if-shell 'command -v manager' { run-shell 'tmux display-popup -w 80% -h 60% -E \"manager status 2>&1 | head -30\"' }" \
  "  Proxy: On       " O "if-shell 'command -v manager' { run-shell 'manager proxy:on > /dev/null 2>&1; tmux display-message \"9Router: ON\"' }" \
  "  Proxy: Off      " f "if-shell 'command -v manager' { run-shell 'manager proxy:off > /dev/null 2>&1; tmux display-message \"9Router: OFF\"' }" \
  "" \
  "  Help Guide      " "?" "display-popup -w 90% -h 80% -E 'cat ~/.tmux/help.txt | less -R'"

# ── Ctrl+a m: Tmux Menu (quản lý window/pane) ──
bind m display-menu -T " #[fg=#7aa2f7,bold]❖ Tmux Menu " -x C -y C \
  "  New Window        " n "new-window -c '#{pane_current_path}'" \
  "  Kill Window       " x "kill-window" \
  "  Next Window       " Tab "next-window" \
  "  Prev Window       " BTab "previous-window" \
  "" \
  "  Split H           " - "split-window -h -c '#{pane_current_path}'" \
  "  Split V           " | "split-window -v -c '#{pane_current_path}'" \
  "  Swap Pane         " "{" "swap-pane -D" \
  "" \
  "  Sessions          " s "choose-tree -Zs" \
  "  Rename Window     " r "command-prompt -I '#W' 'rename-window %%'" \
  "  Rename Session    " R "command-prompt -I '#S' 'rename-session %%'" \
  "" \
  "  Detach            " d "detach-client" \
  "  Reload Config     " D "source-file ~/.tmux.conf" \
  "  Help Guide        " ? "display-popup -w 90% -h 80% -E 'cat ~/.tmux/help.txt | less -R'"

# ── Ctrl+a M: Manager Menu — chỉ hiện khi có CLI `manager` ──
bind M if-shell "command -v manager" {
  display-menu -T " #[fg=#bb9af7,bold]⚙ Manager " -x C -y C \
    "" \
    "  Status          " S "run-shell 'tmux display-popup -w 80% -h 60% -E \"manager status 2>&1 | head -30\"'" \
    "" \
    "  Proxy: On       " O "run-shell 'manager proxy:on > /dev/null 2>&1; tmux display-message \"9Router: ON\"'" \
    "  Proxy: Off      " f "run-shell 'manager proxy:off > /dev/null 2>&1; tmux display-message \"9Router: OFF\"'" \
    "  Proxy: Test     " T "run-shell 'tmux display-popup -w 80% -h 50% -E \"manager 9router:test 2>&1\"'" \
    "  Proxy: Restart  " R "run-shell 'manager 9router:restart > /dev/null 2>&1; tmux display-message \"9Router restarted\"'" \
    "" \
    "  Docker          " D "run-shell 'tmux display-popup -w 80% -h 60% -E \"manager docker 2>&1\"'" \
    "  Stats           " t "run-shell 'tmux display-popup -w 60% -h 40% -E \"manager stats 2>&1\"'" \
    "  System Info     " I "run-shell 'tmux display-popup -w 80% -h 60% -E \"manager system 2>&1\"'" \
    "  Cleanup         " C "run-shell 'manager cleanup > /dev/null 2>&1; tmux display-message \"Cleaned up\"'" \
    "" \
    "  Full Manager    " M "run-shell 'manager menu'" \
    "  Help Guide      " ? "display-popup -w 90% -h 80% -E 'cat ~/.tmux/help.txt | less -R'"
}

if "test -f ~/.tmux/plugins/tpm/tpm" {
  run "~/.tmux/plugins/tpm/tpm"
}
```

- [ ] **Step 2: Verify cú pháp (bắt buộc)**

```bash
tmux -f /dev/null -L cfgcheck new-session -d -s v 2>/dev/null
tmux -f /dev/null -L cfgcheck source-file tmux.conf
echo "exit=$?"
tmux -f /dev/null -L cfgcheck show -g status-left
tmux -f /dev/null -L cfgcheck show -g status-right
tmux -f /dev/null -L cfgcheck kill-server 2>/dev/null
```
Expected: `exit=0`; hai dòng status hiển thị đúng format mới. Nếu source-file báo lỗi dòng nào → sửa NGAY dòng đó (thường do lồng `\"` trong `if-shell`), không commit khi còn lỗi.

- [ ] **Step 3: Chú ý lỗi dễ mắc** — biến `${SHELL}` trong `set -g default-command` phải giữ nguyên chữ `{SHELL}` (tmux expand, NOT shell expand — vì toàn bộ file trong heredoc/double-quote? Trên máy dev đang hoạt động thì dùng `${SHELL}` literal đã đúng).

- [ ] **Step 4: Commit**

```bash
git add tmux.conf
git commit -m "feat: tmux.conf master — status bar session/app đậm, path rút gọn, giờ GMT+7, guard manager"
```

---

### Task 5: Vendor plugins + help.txt + tmux-menu + LICENSE

**Files:**
- Copy: `help.txt` ← `~/.tmux/help.txt`
- Copy: `bin/tmux-menu` ← `~/.local/bin/tmux-menu`
- Copy: `plugins/{tpm,tmux-sensible,tmux-yank}` ← `~/.tmux/plugins/`
- Copy: `LICENSE` ← fetch từ GitHub (giữ nguyên bản repo cũ)

- [ ] **Step 1: Copy help + tmux-menu + plugins**

```bash
cp ~/.tmux/help.txt help.txt
mkdir -p bin plugins
cp ~/.local/bin/tmux-menu bin/tmux-menu
cp -r ~/.tmux/plugins/tpm plugins/tpm
cp -r ~/.tmux/plugins/tmux-sensible plugins/tmux-sensible
cp -r ~/.tmux/plugins/tmux-yank plugins/tmux-yank
# bỏ .git bên trong plugin vendor (không commit submodule)
rm -rf plugins/tpm/.git plugins/tmux-sensible/.git plugins/tmux-yank/.git
chmod +x bin/tmux-menu
```

- [ ] **Step 2: Fetch LICENSE giữ nguyên**

```bash
gh api repos/minhtuancn/tmux-agents/contents/LICENSE --jq .content | base64 -d > LICENSE
wc -l LICENSE
```

- [ ] **Step 3: Verify**

```bash
ls -la plugins/ && find plugins -name '.git' | wc -l   # phải = 0
bash -n bin/tmux-menu
head -3 LICENSE
```

- [ ] **Step 4: Commit**

```bash
git add help.txt bin/tmux-menu plugins LICENSE
git commit -m "chore: vendor plugins (tpm/sensible/yank), help.txt, tmux-menu, LICENSE"
```

---

### Task 6: `install.sh` — installer đa nền tảng, idempotent

**Files:**
- Create: `install.sh`

**Interfaces:**
- Consumes: `tmux.conf`, `bin/*`, `help.txt`, `plugins/*` (đã commit ở task trước).
- Produces: cài vào `~/.tmux.conf`, `~/.tmux/help.txt`, `~/.tmux/bin/vn-time.sh`, `~/.tmux/plugins/*`, `~/.local/bin/{t,tls,tmux-menu}`, thêm alias vào `~/.bashrc`.

- [ ] **Step 1: Tạo script**

```bash
#!/usr/bin/env bash
# install.sh — cài + cấu hình tmux-agents (idempotent, chạy lại không hỏng)
set -uo pipefail
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; RST='\033[0m'
say()  { printf "${GREEN}[install]${RST} %s\n" "$1"; }
warn() { printf "${YELLOW}[warn]${RST} %s\n" "$1"; }
fail() { printf "${RED}[error]${RST} %s\n" "$1"; exit 1; }

YES=0
[ "${1:-}" = "--yes" ] && YES=1
ask() { [ "$YES" = 1 ] && return 0; printf "${YELLOW}%s [y/N]${RST} " "$1"; read -r a; [[ "$a" =~ ^[Yy]$ ]]; }

# 1. Backup config cũ
if [ -f "$HOME/.tmux.conf" ]; then
  bak="$HOME/.tmux.conf.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$HOME/.tmux.conf" "$bak" && say "Backup cũ: $bak"
fi

# 2. Cài package nếu thiếu
has() { command -v "$1" >/dev/null 2>&1; }
OS="$(uname -s)"
if ! has tmux; then
  if [ "$OS" = "Darwin" ]; then
    has brew && { brew install tmux; say "tmux đã cài qua brew"; } || warn "Thiếu brew + tmux — cài thủ công rồi chạy lại"
  elif [ "$OS" = "Linux" ]; then
    if has sudo && ask "Cài tmux + xclip (apt-get)?"; then
      sudo apt-get update -qq && sudo apt-get install -y tmux xclip
      say "tmux + xclip đã cài"
    else
      warn "Chưa cài tmux — tiếp tục copy config, reload tmux sau khi cài"
    fi
  fi
else
  say "tmux: $(tmux -V)"
  ! has xclip && has apt-get && has sudo && { sudo apt-get install -y xclip >/dev/null 2>&1 && say "xclip đã cài"; }
fi

# 3. Copy config
cp tmux.conf "$HOME/.tmux.conf" && say "~/.tmux.conf đã cập nhật"

# 4. Scripts
mkdir -p "$HOME/.local/bin" "$HOME/.tmux/bin"
cp bin/tls bin/t bin/tmux-menu "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/t" "$HOME/.local/bin/tls" "$HOME/.local/bin/tmux-menu"
cp bin/vn-time.sh "$HOME/.tmux/bin/vn-time.sh"
chmod +x "$HOME/.tmux/bin/vn-time.sh"
say "Scripts → ~/.local/bin + ~/.tmux/bin"

# 5. Help
mkdir -p "$HOME/.tmux"
cp help.txt "$HOME/.tmux/help.txt"

# 6. Plugins (không đè cấu hình sẵn có)
mkdir -p "$HOME/.tmux/plugins"
cp -rn plugins/tpm plugins/tmux-sensible plugins/tmux-yank "$HOME/.tmux/plugins/" 2>/dev/null || true
say "Plugins vendor sẵn → ~/.tmux/plugins"

# 7. Alias trong .bashrc (chỉ thêm nếu chưa có)
BASH_RC="$HOME/.bashrc"
TMUX_BLOCK="# tmux-agents: t (vào tmux), tls (list & select)"
if [ -f "$BASH_RC" ] && ! grep -qF "alias tls=" "$BASH_RC"; then
  {
    echo ""
    echo "$TMUX_BLOCK"
    echo "alias t=\"\$HOME/.local/bin/t\""
    echo "alias tls=\"\$HOME/.local/bin/tls\""
  } >> "$BASH_RC"
  say "Đã thêm alias t, tls vào ~/.bashrc (mở shell mới để dùng)"
elif [ -f "$BASH_RC" ]; then
  say "~/.bashrc đã có alias t/tls — bỏ qua"
fi

# 8. Verify
tmux -f /dev/null -L installcheck new-session -d -s v 2>/dev/null
if tmux -f /dev/null -L installcheck source-file "$HOME/.tmux.conf"; then
  say "Config load OK"
else
  warn "Config load LỖI — xem chi tiết ở trên"
fi
tmux -f /dev/null -L installcheck kill-server 2>/dev/null

echo ""
printf "${GREEN}✔ Hoàn tất.${RST} Gõ ${CYAN}source ~/.bashrc${RST} rồi ${CYAN}t${RST} để vào tmux.\n"
```

- [ ] **Step 2: Verify với HOME giả (không đụng máy thật)**

```bash
chmod +x install.sh && bash -n install.sh
FAKE=/tmp/opencode/tmux-home-test
rm -rf "$FAKE" && mkdir -p "$FAKE"
HOME="$FAKE" bash install.sh --yes
echo "--- kết quả cài lên HOME giả ---"
ls -la "$FAKE"/.tmux* "$FAKE"/.local/bin/ 2>/dev/null
tail -5 "$FAKE/.bashrc"
HOME="$FAKE" bash install.sh --yes   # lần 2 → phải idempotent, không lỗi
```
Expected: lần 1 tạo đủ ~/.tmux.conf, ~/.local/bin/{t,tls,tmux-menu}, ~/.tmux/{help.txt,bin,plugins}; bashrc có 2 alias; lần 2 chạy êm, không nhân đôi alias (đếm `grep -c "alias tls=" "$FAKE/.bashrc"` = 1).

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "feat: install.sh — installer idempotent đa nền tảng (Linux/macOS)"
```

---

### Task 7: `README.md`

**Files:**
- Create: `README.md` (VIẾT LẠI — thay bản 56B trên GitHub)

- [ ] **Step 1: Tạo README**

````markdown
# tmux-agents

Install và cấu hình tmux cho agent coding — status bar Tokyo Night, menu nhanh F1, TUI session picker `tls`.

## Cài đặt nhanh (máy mới)

```bash
git clone https://github.com/minhtuancn/tmux-agents.git && cd tmux-agents
bash install.sh          # tự cài package + config + scripts + alias
```

`install.sh` idempotent: backup config cũ, chạy lại bao nhiêu lần cũng OK.

## Sau khi cài

| Lệnh | Tác dụng |
|------|----------|
| `t`   | vào tmux: chưa có session → tạo `main`; đã có → picker `tls` |
| `tls` | TUI list & select session: số 1-9 / `↑↓jk` / Enter, `n` tạo, `d` xoá, `r` đổi tên, `f` lọc, `q` thoát |
| `F1`  | menu nhanh (window/split/sessions/detach) |
| `C-a` | prefix: `m` Tmux Menu, `M` Manager Menu, `[` copy mode, `r` reload config |

## Status bar

- Session name + tên ứng dụng đang chạy — **đậm**, cạnh nhau
- Thư mục làm việc: rút gọn `~`, nếu dài giữ đuôi (đúng thư mục cuối)
- Giờ cố định **GMT+7** (`~/.tmux/bin/vn-time.sh`) bất kể TZ server
- Yêu cầu tmux ≥ 3.4, Linux (xclip) hoặc macOS (pbcopy)

## Tuỳ biến tls

- `TLS_STYLE=ascii` hoặc `TLS_STYLE=unicode` — ép kiểu khung (mặc định: auto theo locale UTF-8)

## Screenshot

(Ảnh GIF demo sẽ thêm sau khi verify live trên máy thật)
````

- [ ] **Step 2: Verify** — `head -20 README.md` hiển thị đúng; không chứa secret.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: README — quickstart, keybindings, tuỳ biến TLS_STYLE"
```

---

### Task 8: Push lên GitHub `minhtuancn/tmux-agents`

**Files:**
- (không có — git op)

- [ ] **Step 1: Kiểm tra trạng thái + add remote**

```bash
git -C /home/dev/tmux status --short
git -C /home/dev/tmux log --oneline
git -C /home/dev/tmux remote -v
```
Expected: working tree sạch (hoặc chỉ còn plan file chưa commit — commit nó trước: `git add docs/ && git commit -m "docs: implementation plan"`).

Nếu chưa có remote: `git remote add origin https://github.com/minhtuancn/tmux-agents.git`

- [ ] **Step 2: Push (repo đích gần như trống — user đã duyệt khởi tạo)**

```bash
git pull --rebase origin main 2>/dev/null || true   # nhỡ có commit mới trên remote
git push -u origin main --force-with-lease
```
Dùng `--force-with-lease` (không phải `-f` trần): bảo vệ nếu ai khác vô tình push. Giải thích: remote hiện chỉ có LICENSE+README (56B), local là lịch sử mới nên buộc phải force; LICENSE được Task 5 fetch giữ nguyên.

- [ ] **Step 3: Verify trên GitHub**

```bash
gh repo view minhtuancn/tmux-agents
gh api repos/minhtuancn/tmux-agents/contents/ --jq '.[].name'
```
Expected: repo view có mô tả "Install and config tmux for agent coding"; contents liệt kê `install.sh`, `tmux.conf`, `bin/`, `plugins/`, `docs/`, `README.md`, `LICENSE`, `help.txt`.

- [ ] **Step 4: Báo user** — kèm URL repo + lệnh cài trên máy khác.

---

## Self-Review (chạy trước khi bàn giao)

| Yêu cầu spec | Task |
|--------------|------|
| §3 status bar mới (session/app đậm, path rút gọn, GMT+7) | Task 4 |
| §3.2 vn-time.sh cố định `~/.tmux/bin/` | Task 1 + Task 4 + Task 6 |
| §4.1 tls "Table Pro" adaptive (UTF-8/ASCII fallback, căn cột ký tự) | Task 3 |
| §4.2 bin/t | Task 2 |
| §4.3 tmux-menu giữ nguyên | Task 5 |
| §5 install.sh idempotent (backup, apt/brew, bashrc, verify) | Task 6 |
| §6 push GitHub | Task 8 |
| §7 verification | Task 3/4/6 bước Verify |
| Fix quote Cleanup + guard manager trên máy không có manager | Task 4 |
| README | Task 7 |
| LICENSE giữ nguyên | Task 5 |

Không có placeholder; interface nhất quán: script `t` chạy `$DIR/tls` (Task 2) — `tls` tồn tại ở cùng thư mục cả repo lẫn `~/.local/bin` (Task 6).
