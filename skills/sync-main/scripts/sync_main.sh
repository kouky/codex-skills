#!/usr/bin/env bash

set -euo pipefail

script_name="$(basename "$0")"

usage() {
  cat <<EOF
Usage:
  $script_name start "<commit message>"
  $script_name continue
  $script_name push
  $script_name status
EOF
}

git_path_dir_exists() {
  local path
  path="$(git rev-parse --git-path "$1")"
  [[ -d "$path" ]]
}

git_path_exists() {
  local path
  path="$(git rev-parse --git-path "$1")"
  [[ -e "$path" ]]
}

rebase_in_progress() {
  git_path_exists rebase-merge || git_path_exists rebase-apply
}

print_conflicts() {
  local conflicts
  conflicts="$(git diff --name-only --diff-filter=U)"
  if [[ -n "$conflicts" ]]; then
    printf 'Conflicted files:\n%s\n' "$conflicts" >&2
  fi
}

current_branch() {
  git branch --show-current
}

fetch_origin_main() {
  git fetch origin main:refs/remotes/origin/main
}

ensure_origin_main_exists() {
  if ! git rev-parse --verify --quiet origin/main >/dev/null; then
    printf 'Could not find origin/main after fetching.\n' >&2
    exit 1
  fi
}

ensure_non_main_source_is_clean_base() {
  local branch
  branch="$(current_branch)"

  if [[ "$branch" == "main" ]]; then
    return 0
  fi

  ensure_origin_main_exists

  if git merge-base --is-ancestor HEAD origin/main; then
    return 0
  fi

  if [[ -n "$branch" ]]; then
    printf 'Refusing to start from branch "%s" because it already has commits not on origin/main.\n' "$branch" >&2
  else
    printf 'Refusing to start from detached HEAD because it already has commits not on origin/main.\n' >&2
  fi

  if [[ -n "$(git log --oneline --decorate origin/main..HEAD)" ]]; then
    printf 'Commits ahead of origin/main:\n' >&2
    git log --oneline --decorate --max-count=10 origin/main..HEAD >&2
  fi

  printf 'Start from main, or from a task branch whose HEAD is still reachable from origin/main.\n' >&2
  exit 1
}

ensure_non_main_push_scope() {
  local ahead_count branch
  branch="$(current_branch)"

  if [[ "$branch" == "main" ]]; then
    return 0
  fi

  ensure_origin_main_exists

  if ! git merge-base --is-ancestor origin/main HEAD; then
    printf 'Cannot push from this non-main source because HEAD is not based on origin/main.\n' >&2
    printf 'Run "%s start" or "%s continue" to rebase before pushing.\n' "$script_name" "$script_name" >&2
    exit 1
  fi

  ahead_count="$(git rev-list --count origin/main..HEAD)"
  if [[ "$ahead_count" != "1" ]]; then
    if [[ -n "$branch" ]]; then
      printf 'Refusing to push branch "%s" to main because it is %s commits ahead of origin/main.\n' "$branch" "$ahead_count" >&2
    else
      printf 'Refusing to push detached HEAD to main because it is %s commits ahead of origin/main.\n' "$ahead_count" >&2
    fi

    if [[ "$ahead_count" != "0" ]]; then
      printf 'Commits ahead of origin/main:\n' >&2
      git log --oneline --decorate --max-count=10 origin/main..HEAD >&2
    fi

    printf 'Non-main sync sources must contain exactly the single sync commit before pushing.\n' >&2
    exit 1
  fi
}

ensure_no_other_git_operation() {
  if git_path_exists MERGE_HEAD; then
    printf 'A merge is already in progress. Finish or abort it before using %s.\n' "$script_name" >&2
    exit 1
  fi

  if git_path_exists CHERRY_PICK_HEAD; then
    printf 'A cherry-pick is already in progress. Finish or abort it before using %s.\n' "$script_name" >&2
    exit 1
  fi

  if git_path_exists REVERT_HEAD; then
    printf 'A revert is already in progress. Finish or abort it before using %s.\n' "$script_name" >&2
    exit 1
  fi

  if git_path_dir_exists sequencer; then
    printf 'Another git sequencer operation is already in progress. Finish or abort it before using %s.\n' "$script_name" >&2
    exit 1
  fi
}

sync_state_file() {
  git rev-parse --git-path sync-main-state
}

read_state_token() {
  local state_file
  state_file="$(sync_state_file)"
  if [[ -f "$state_file" ]]; then
    cat "$state_file"
  fi
}

write_state_token() {
  local token="$1"
  printf '%s\n' "$token" > "$(sync_state_file)"
}

clear_state_token() {
  rm -f "$(sync_state_file)"
}

stash_ref_for_token() {
  local token="$1"
  git stash list --format='%gd %gs' | awk -v token="$token" 'index($0, token) { print $1; exit }'
}

has_unstaged_or_untracked_changes() {
  if ! git diff --quiet --ignore-submodules --; then
    return 0
  fi

  [[ -n "$(git ls-files --others --exclude-standard)" ]]
}

preserve_unrelated_changes() {
  local token ref

  clear_state_token

  if ! has_unstaged_or_untracked_changes; then
    return 0
  fi

  token="sync-main-preserve-$(date +%s)-$$"
  git stash push --include-untracked -m "$token" >/dev/null
  ref="$(stash_ref_for_token "$token")"

  if [[ -z "$ref" ]]; then
    printf 'Saved unrelated changes, but could not find the preservation stash.\n' >&2
    exit 1
  fi

  write_state_token "$token"
  printf 'Preserved unrelated tracked and untracked changes in %s.\n' "$ref"
}

restore_preserved_changes() {
  local token ref

  token="$(read_state_token)"
  if [[ -z "$token" ]]; then
    return 0
  fi

  ref="$(stash_ref_for_token "$token")"
  if [[ -z "$ref" ]]; then
    printf 'Could not find the preserved-change stash for token %s.\n' "$token" >&2
    exit 1
  fi

  if git stash pop "$ref"; then
    clear_state_token
    printf 'Restored preserved changes from %s.\n' "$ref"
  else
    local status=$?
    printf 'Restoring preserved changes caused conflicts.\n' >&2
    print_conflicts
    printf 'The preservation stash %s was kept. Resolve the conflicts and drop it manually after verifying the result.\n' "$ref" >&2
    exit "$status"
  fi
}

show_preservation_state() {
  local token ref

  token="$(read_state_token)"
  if [[ -z "$token" ]]; then
    return 0
  fi

  ref="$(stash_ref_for_token "$token")"
  if [[ -n "$ref" ]]; then
    printf 'Preserved-change stash pending: %s.\n' "$ref"
  else
    printf 'Preserved-change stash token is recorded, but the stash entry was not found.\n'
  fi
}

ensure_no_pending_preserved_changes() {
  local token ref

  token="$(read_state_token)"
  if [[ -z "$token" ]]; then
    return 0
  fi

  ref="$(stash_ref_for_token "$token")"
  if [[ -n "$ref" ]]; then
    printf 'Cannot push while preserved unrelated changes are still pending in %s.\n' "$ref" >&2
  else
    printf 'Cannot push while preserved unrelated changes are still marked as pending.\n' >&2
  fi
  printf 'Resolve or clear the preserved-change restore state before pushing.\n' >&2
  exit 1
}

start_rebase() {
  local message="${1:-}"

  if [[ -z "$message" ]]; then
    printf 'Commit message required.\n' >&2
    usage
    exit 1
  fi

  ensure_no_other_git_operation

  if rebase_in_progress; then
    printf 'A rebase is already in progress. Resolve it and run "%s continue".\n' "$script_name" >&2
    exit 1
  fi

  if git diff --cached --quiet; then
    printf 'No staged changes to commit.\n' >&2
    exit 1
  fi

  fetch_origin_main
  ensure_non_main_source_is_clean_base
  git commit -m "$message"
  preserve_unrelated_changes

  if git rebase origin/main; then
    restore_preserved_changes
    printf 'Rebase complete. Run "%s push" to publish main.\n' "$script_name"
  else
    local status=$?
    printf 'Rebase stopped for conflict resolution.\n' >&2
    print_conflicts
    exit "$status"
  fi
}

continue_rebase() {
  ensure_no_other_git_operation

  if ! rebase_in_progress; then
    printf 'No rebase is in progress.\n' >&2
    exit 1
  fi

  if git rebase --continue; then
    if rebase_in_progress; then
      printf 'Rebase still in progress. Continue after the next stop.\n'
    else
      restore_preserved_changes
      printf 'Rebase complete. Run "%s push" to publish main.\n' "$script_name"
    fi
  else
    local status=$?
    printf 'Rebase still needs attention.\n' >&2
    print_conflicts
    exit "$status"
  fi
}

push_main() {
  local branch

  branch="$(current_branch)"

  if rebase_in_progress; then
    printf 'Cannot push while a rebase is still in progress.\n' >&2
    exit 1
  fi

  ensure_no_other_git_operation
  ensure_no_pending_preserved_changes
  fetch_origin_main
  ensure_non_main_push_scope

  if [[ "$branch" == "main" ]]; then
    git push origin main
  else
    git push origin HEAD:refs/heads/main
  fi
}

show_status() {
  git status --short --branch
  if rebase_in_progress; then
    printf 'Rebase in progress.\n'
    print_conflicts
  else
    printf 'No rebase in progress.\n'
  fi
  show_preservation_state
}

case "${1:-}" in
  start)
    start_rebase "${2:-}"
    ;;
  continue)
    continue_rebase
    ;;
  push)
    push_main
    ;;
  status)
    show_status
    ;;
  *)
    usage
    exit 1
    ;;
esac
