#!/bin/bash
# 把 ~/.claude/skills/ 的 mvvmc-* 釘在某個 tag，而不是跟著這個 repo 的工作區。
#
# 為什麼：`~/.claude/skills/mvvmc-*` 原本是指向本 repo 工作區的 symlink，所以
# 每個專案都在跟 HEAD——這裡改一行，你所有專案的規範當下就變，沒有版本也沒有通知。
# 三個上架 App 各在不同版本的 MVVMC 上，就是這樣來的。
#
# 為什麼不是「把 skills 複製進專案」：官方文件明定同名 skill 的優先順序是
# **Enterprise > Personal > Project**。只要 `~/.claude/skills/` 有同名的，專案層
# 那份永遠不會被載入。複製進專案是 no-op。
#   https://code.claude.com/docs/en/skills.md
#
# 用法：
#   scripts/pin-skills.sh <tag>     # 釘住某一版（升版就是重跑這行）
#   scripts/pin-skills.sh --status  # 現在釘在哪？有沒有新版？
#   scripts/pin-skills.sh --dev     # 改回跟著工作區（要改規範本身時用）

set -euo pipefail

MVVMC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKTREE="$HOME/.mvvmc-pinned"
SKILLS_DIR="$HOME/.claude/skills"

SKILLS=(
  mvvmc-model mvvmc-viewmodel mvvmc-view mvvmc-hostcontroller
  mvvmc-structure mvvmc-navigation mvvmc-testing
  mvvmc-review mvvmc-deep-review mvvmc-skip
  swift-concurrency
)

die() { echo "error: $*" >&2; exit 1; }

current_target() {
  local l="$SKILLS_DIR/mvvmc-view"
  [[ -L "$l" ]] && readlink "$l" || echo ""
}

# ---------- --status ----------
if [[ "${1:-}" == "--status" ]]; then
  t=$(current_target)
  [[ -n "$t" ]] || die "$SKILLS_DIR/mvvmc-view 不是 symlink（或不存在）"
  if [[ "$t" == "$WORKTREE"/* ]]; then
    pinned=$(git -C "$WORKTREE" describe --tags --exact-match 2>/dev/null || echo "（不在 tag 上）")
    echo "模式: 釘住   版本: $pinned"
    latest=$(git -C "$MVVMC_ROOT" tag --sort=-v:refname | head -1)
    [[ "$pinned" == "$latest" ]] \
      && echo "已是最新（${latest}）" \
      || echo "可升版: $pinned → ${latest}（升版是你的決定，不是必須）"
  else
    echo "模式: 開發   目標: $t"
    echo "⚠️ 跟著工作區走——這個 repo 一改，你所有專案的規範當下就變。"
    echo "   寫 App 之前請跑: $0 <tag>"
  fi
  exit 0
fi

# ---------- --dev ----------
if [[ "${1:-}" == "--dev" ]]; then
  for s in "${SKILLS[@]}"; do
    src="$MVVMC_ROOT/.claude/skills/$s"
    [[ -d "$src" ]] || continue
    rm -rf "${SKILLS_DIR:?}/$s"
    ln -s "$src" "$SKILLS_DIR/$s"
  done
  echo "已切回開發模式：symlink 指向工作區。寫 App 之前記得再釘回去。"
  exit 0
fi

# ---------- pin ----------
TAG="${1:-}"
[[ -n "$TAG" ]] || die "用法: $0 <tag> | --status | --dev"
git -C "$MVVMC_ROOT" rev-parse "$TAG" >/dev/null 2>&1 || die "沒有這個 tag: $TAG"

if [[ -d "$WORKTREE" ]]; then
  git -C "$WORKTREE" checkout -q --detach "$TAG"
else
  git -C "$MVVMC_ROOT" worktree add -q --detach "$WORKTREE" "$TAG"
fi

mkdir -p "$SKILLS_DIR"
for s in "${SKILLS[@]}"; do
  src="$WORKTREE/.claude/skills/$s"
  [[ -d "$src" ]] || { echo "  略過（該版本沒有）: $s"; continue; }
  rm -rf "${SKILLS_DIR:?}/$s"
  ln -s "$src" "$SKILLS_DIR/$s"
  echo "  $s → $TAG"
done

echo
echo "已釘在 ${TAG}。上游之後怎麼改都不會流進來，升版請重跑這行。"
echo "要改規範本身時：$0 --dev"
