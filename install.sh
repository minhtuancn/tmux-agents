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