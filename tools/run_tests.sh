#!/usr/bin/env bash
# Chạy toàn bộ test headless (song song). Dùng: tools/run_tests.sh [số tiến trình, mặc định = số lõi] [lọc tên]
# In mỗi suite một dòng "== tên: PASS=n FAIL=n SCRIPTERR=n" (sắp xếp theo tên), cuối cùng tổng hợp.
# Thoát với mã 1 nếu có FAIL hoặc SCRIPTERR.
cd "$(dirname "$0")/.."
JOBS="${1:-$(nproc)}"
FILTER="${2:-test_}"
OUT="$(mktemp -d)"
run_one() {
  f="$1"; out_dir="$2"; n=$(basename "$f" .gd)
  out=$(timeout 300 godot --headless --path . -s "$f" 2>&1)
  p=$(echo "$out" | grep -c '  PASS'); fl=$(echo "$out" | grep -c '  FAIL'); se=$(echo "$out" | grep -c 'SCRIPT ERROR')
  echo "== $n: PASS=$p FAIL=$fl SCRIPTERR=$se" > "$out_dir/$n.txt"
}
export -f run_one
ls tools/tests/${FILTER}*.gd | xargs -P "$JOBS" -I{} bash -c 'run_one {} '"$OUT"
cat "$OUT"/*.txt | sort
bad=$(cat "$OUT"/*.txt | grep -cE "FAIL=[1-9]|SCRIPTERR=[1-9]")
total=$(cat "$OUT"/*.txt | sed 's/.*PASS=\([0-9]*\).*/\1/' | paste -sd+ | bc)
echo "TỔNG: $(ls "$OUT"/*.txt | wc -l) suite, $total kiểm tra qua, $bad suite lỗi"
rm -rf "$OUT"
[ "$bad" -eq 0 ]
