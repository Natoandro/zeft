#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[tag-release] %s\n' "$*" >&2
}

trap 'status=$?; printf "[tag-release] ERROR: command failed (exit %s, line %s): %s\n" \
  "$status" "$LINENO" "$BASH_COMMAND" >&2; exit "$status"' ERR

log "Parsing release options."
push_tag=false
bump_version=false
bump_level=patch
while [[ "$#" -gt 0 ]]; do
  option="$1"
  shift
  case "$option" in
    --push)
      if [[ "$push_tag" == true ]]; then
        log "ERROR: option '--push' can only be specified once."
        exit 2
      fi
      push_tag=true
      ;;
    --bump)
      if [[ "$bump_version" == true ]]; then
        log "ERROR: option '--bump' can only be specified once."
        exit 2
      fi
      bump_version=true
      if [[ "$#" -gt 0 && "$1" != --* ]]; then
        case "$1" in
          major|minor|patch)
            bump_level="$1"
            shift
            ;;
          *)
            log "ERROR: bump level must be major, minor, or patch."
            exit 2
            ;;
        esac
      fi
      ;;
    *)
      log "ERROR: usage: scripts/tag-release.sh [--push] [--bump [major|minor|patch]]"
      exit 2
      ;;
  esac
done
log "Options: push=$push_tag, bump=$bump_version, bump_level=$bump_level."

log "Locating repository root."
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
log "Repository root: $repo_root"

log "Checking working tree is clean."
working_tree_status="$(git status --porcelain)"
if [[ -n "$working_tree_status" ]]; then
  log "ERROR: release tagging requires a clean working tree."
  exit 1
fi
log "Working tree is clean."
if [[ "$bump_version" == true ]]; then
  log "Checking the Git index before version bump."
  if ! git diff --cached --quiet; then
    log "ERROR: version bump requires an empty Git index."
    exit 1
  fi
  log "Checking Git author identity."
  git var GIT_AUTHOR_IDENT >/dev/null
fi

log "Reading package version from build.zig.zon."
version="$(sed -nE 's/^[[:space:]]*\.version = "([^"]+)"[,]?$/\1/p' build.zig.zon)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  log "ERROR: could not read a valid package version from build.zig.zon."
  exit 1
fi
log "Package version: $version"
if [[ "$bump_version" == true && ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  log "ERROR: automatic version bumps require a stable major.minor.patch version."
  exit 1
fi

tag="v$version"
log "Checking whether tag $tag already exists."
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  tag_commit="$(git rev-parse "$tag^{commit}")"
  head_commit="$(git rev-parse HEAD)"
  if [[ "$push_tag" != true || "$tag_commit" != "$head_commit" ]]; then
    log "ERROR: tag '$tag' already exists and cannot be reused in this state."
    exit 1
  fi
  log "Reusing existing tag $tag at HEAD."
else
  log "Creating annotated tag $tag."
  git tag -a "$tag" -m "Release $tag"
  log "Created annotated tag $tag."
fi

if [[ "$push_tag" == true ]]; then
  log "Pushing tag $tag to origin."
  git push origin "$tag"
  log "Pushed tag $tag to origin."
fi

if [[ "$bump_version" == true ]]; then
  log "Bumping package version at level $bump_level."
  next_version="$(scripts/bump-version.sh "$bump_level")"
  log "Next package version: $next_version"
  log "Checking the Git index before staging the version file."
  if ! git diff --cached --quiet; then
    log "ERROR: refusing to create the version bump commit with staged files."
    exit 1
  fi
  log "Staging build.zig.zon."
  git add build.zig.zon
  staged_paths="$(git diff --cached --name-only)"
  if [[ "$staged_paths" != build.zig.zon ]]; then
    log "ERROR: refusing to create the version bump commit with unrelated staged files."
    exit 1
  fi
  log "Creating Conventional Commit for version $next_version."
  git commit -m "chore(release): bump version to $next_version"
  log "Committed version bump to $next_version."
fi

if [[ "$push_tag" == true ]]; then
  if [[ "$bump_version" == true ]]; then
    log "Pushed release tag $tag. Push the version bump commit separately when ready."
  else
    log "Pushed tag $tag to origin."
  fi
else
  if [[ "$bump_version" == true ]]; then
    log "Push the release tag $tag and the version bump commit when ready."
  else
    log "Created annotated tag $tag. Push it with: git push origin $tag"
  fi
fi
log "Release tagging finished."
