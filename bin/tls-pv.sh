#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════
#  tls-pv.sh — Preview session (chạy trong display-popup của tls)
#
#  Đọc tên session được chọn từ file ($1) do tls ghi → ATTACH TRỰC TIẾP
#  (live thật, tương tác được). Khi thoát khỏi preview → popup tự đóng.
#  tls đổi session → đóng + mở lại popup với session mới.
# ═══════════════════════════════════════════════════════════════════════
file="${1:?usage: tls-pv.sh <sel-file>}"

s=""
[ -f "$file" ] && IFS= read -r s < "$file"

unset TMUX   # cho phép attach nested client trong popup (tạo client preview riêng)
[ -n "$s" ] && tmux attach-session -t "$s" 2>/dev/null
exit 0