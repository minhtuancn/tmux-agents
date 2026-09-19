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