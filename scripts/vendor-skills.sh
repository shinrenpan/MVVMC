#!/bin/bash
# 把 MVVMC 的 skills 以「釘住的版本」複製進一個消費專案。
#
# 為什麼需要這支：`~/.claude/skills/mvvmc-*` 是指向這個 repo 的 symlink，
# 所有專案因此共用 HEAD——這裡改一行，你每個專案的規範當下就變了，而且無聲。
# 三個上架 App 的 MVVMC 版本各不相同，不是意外，是這個結構的必然結果。
#
# 用法：
#   scripts/vendor-skills.sh <專案目錄> [tag]     # 複製並釘住（預設用當前 HEAD 最近的 tag）
#   scripts/vendor-skills.sh --check <專案目錄>   # 檢查專案的複本有沒有被改過／落後
#
# 釘住之後，升版是明確動作：重跑一次這支指令。不會睡一覺就變了。

set -euo pipefail

MVVMC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 要 vendor 哪些。mvvmc-skip 刻意排除——它是凍結的未驗證筆記，不屬於規範。
SKILLS=(
  mvvmc-model mvvmc-viewmodel mvvmc-view mvvmc-hostcontroller
  mvvmc-structure mvvmc-navigation mvvmc-testing
  mvvmc-review mvvmc-deep-review
  swift-concurrency
)

STAMP_FILE=".claude/skills/MVVMC-VERSION"

die() { echo "error: $*" >&2; exit 1; }

# ---------- --check ----------
if [[ "${1:-}" == "--check" ]]; then
  TARGET="${2:-}"
  [[ -n "$TARGET" ]] || die "用法: $0 --check <專案目錄>"
  [[ -d "$TARGET" ]] || die "找不到目錄: $TARGET"
  [[ -f "$TARGET/$STAMP_FILE" ]] || die "${TARGET} 沒有 vendor 過（找不到 ${STAMP_FILE}）"

  PINNED=$(sed -n 's/^tag: //p' "$TARGET/$STAMP_FILE")
  echo "專案釘住的版本: $PINNED"

  git -C "$MVVMC_ROOT" rev-parse "$PINNED" >/dev/null 2>&1 \
    || die "MVVMC repo 裡沒有這個 tag: $PINNED"

  drift=0
  for s in "${SKILLS[@]}"; do
    [[ -d "$TARGET/.claude/skills/$s" ]] || { echo "  缺少: $s"; drift=1; continue; }
    tmp=$(mktemp -d)
    git -C "$MVVMC_ROOT" archive "$PINNED" ".claude/skills/$s" 2>/dev/null | tar -x -C "$tmp" || true
    if [[ -d "$tmp/.claude/skills/$s" ]] \
       && ! diff -rq "$tmp/.claude/skills/$s" "$TARGET/.claude/skills/$s" >/dev/null 2>&1; then
      echo "  已被就地修改: ${s}（vendor 的複本不該手改——改上游再重新 vendor）"
      drift=1
    fi
    rm -rf "$tmp"
  done

  LATEST=$(git -C "$MVVMC_ROOT" tag --sort=-v:refname | head -1)
  [[ "$PINNED" == "$LATEST" ]] || echo "  可升版: $PINNED → ${LATEST}（升版是你的決定，不是必須）"
  [[ $drift -eq 0 ]] && echo "  複本與 $PINNED 一致"
  exit 0
fi

# ---------- vendor ----------
TARGET="${1:-}"
[[ -n "$TARGET" ]] || die "用法: $0 <專案目錄> [tag]"
[[ -d "$TARGET" ]] || die "找不到目錄: $TARGET"

TAG="${2:-$(git -C "$MVVMC_ROOT" describe --tags --abbrev=0)}"
git -C "$MVVMC_ROOT" rev-parse "$TAG" >/dev/null 2>&1 || die "沒有這個 tag: $TAG"
SHA=$(git -C "$MVVMC_ROOT" rev-parse --short "$TAG")

mkdir -p "$TARGET/.claude/skills"
for s in "${SKILLS[@]}"; do
  rm -rf "${TARGET:?}/.claude/skills/$s"
  tmp=$(mktemp -d)
  git -C "$MVVMC_ROOT" archive "$TAG" ".claude/skills/$s" | tar -x -C "$tmp"
  mv "$tmp/.claude/skills/$s" "$TARGET/.claude/skills/$s"
  rm -rf "$tmp"
  echo "  vendored $s"
done

cat > "$TARGET/$STAMP_FILE" <<STAMP
tag: $TAG
commit: $SHA
vendored: $(date +%Y-%m-%d)
source: https://github.com/shinrenpan/MVVMC

這份是複製進來的快照，不是 symlink——所以上游改動不會自己流進來，這正是重點。
不要就地修改這底下的檔案：改動會在下次 vendor 時被覆蓋，而且 \`--check\` 會報出來。
規則要改就改上游的 MVVMC repo，發一個 tag，再重跑 vendor。

升版：  <MVVMC>/scripts/vendor-skills.sh $(cd "$TARGET" && pwd) <新 tag>
檢查：  <MVVMC>/scripts/vendor-skills.sh --check $(cd "$TARGET" && pwd)
STAMP

echo
echo "完成：$TARGET 釘在 $TAG ($SHA)"
echo "建議在該專案的 CLAUDE.md 加一行：MVVMC spec: ${TAG}（見 .claude/skills/MVVMC-VERSION）"
