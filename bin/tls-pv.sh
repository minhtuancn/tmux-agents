#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════
#  tls-pv.sh — Preview session (chạy trong pane split dưới của tls)
#
#  Đọc tên session được chọn từ file ($1) do tls ghi → ATTACH TRỰC TIẾP
#  (live thật, tương tác được = tmux lồng). Khi tls chuyển chọn → tmux
#  switch-client chuyển CLIENT này sang session mới. Tắt preview → pane
#  được kill → client/tls-pv.sh kết thúc.
#
#  $2 = socket path server tmux (từ env TMUX của pane picker). BẮT BUỘC:
#  sau `unset TMUX` (để tạo client lồng) tmux không còn biết socket → phải
#  target rõ bằng `-S`, nếu không `attach` rơi vào server mặc định (sai).
# ═══════════════════════════════════════════════════════════════════════
file="${1:?usage: tls-pv.sh <sel-file> [server-socket]}"
sock="$2"

s=""
[ -f "$file" ] && IFS= read -r s < "$file"

unset TMUX   # cho phép attach nested client (tạo client preview riêng cho pane)
if [ -n "$s" ]; then
  if [ -n "$sock" ]; then tmux -S "$sock" attach-session -t "$s" 2>/dev/null
  else                     tmux       attach-session -t "$s" 2>/dev/null; fi
fi
exit 0