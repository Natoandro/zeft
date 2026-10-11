#!/usr/bin/env bash
set -euo pipefail

push_tag=false
bump_version=false
bump_level=patch
while [[ "$#" -gt 0 ]]; do
  option="$1"
  shift
  case "$option" in
    --push)
      if [[ "$push_tag" == true ]]; then
        echo "Option '--push' can only be specified once." >&2
        exit 2
      fi
      push_tag=true
      ;;
    --bump)
      if [[ "$bump_version" == true ]]; then
        echo "Option '--bump' can only be specified once." >&2
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
            echo "Bump level must be major, minor, or patch." >&2
            exit 2
            ;;
        esac
      fi
      ;;
    *)
      echo "Usage: scripts/tag-release.sh [--push] [--bump [major|minor|patch]]" >&2
      exit 2
      ;;
  esac
done

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Release tagging requires a clean working tree." >&2
  exit 1
fi
if [[ "$bump_version" == true ]]; then
  if ! git diff --cached --quiet; then
    echo "Version bump requires an empty Git index." >&2
    exit 1
  fi
  git var GIT_AUTHOR_IDENT >/dev/null
fi

version="$(sed -nE 's/^[[:space:]]*\.version = "([^"]+)"[,]?$/\1/p' build.zig.zon)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Could not read a valid package version from build.zig.zon." >&2
  exit 1
fi
if [[ "$bump_version" == true && ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Automatic version bumps require a stable major.minor.patch version." >&2
  exit 1
fi

tag="v$version"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  tag_commit="$(git rev-parse "$tag^{commit}")"
  head_commit="$(git rev-parse HEAD)"
  if [[ "$push_tag" != true || "$tag_commit" != "$head_commit" ]]; then
    echo "Tag '$tag' already exists." >&2
    exit 1
  fi
else
  git tag -a "$tag" -m "Release $tag"
fi

if [[ "$push_tag" == true ]]; then
  git push origin "$tag"
fi

if [[ "$bump_version" == true ]]; then
  next_version="$(scripts/bump-version.sh "$bump_level")"
  if ! git diff --cached --quiet; then
    echo "Refusing to create the version bump commit with staged files." >&2
    exit 1
  fi
  git add build.zig.zon
  staged_paths="$(git diff --cached --name-only)"
  if [[ "$staged_paths" != build.zig.zon ]]; then
    echo "Refusing to create the version bump commit with unrelated staged files." >&2
    exit 1
  fi
  git commit -m "chore(release): bump version to $next_version"
  printf 'Bumped package version to %s and committed it.\n' "$next_version"
fi

if [[ "$push_tag" == true ]]; then
  if [[ "$bump_version" == true ]]; then
    printf 'Pushed release tag %s. Push the version bump commit separately when ready.\n' \
      "$tag"
  else
    printf 'Pushed tag %s to origin.\n' "$tag"
  fi
else
  if [[ "$bump_version" == true ]]; then
    printf 'Push the release tag %s and the version bump commit when ready.\n' "$tag"
  else
    printf 'Created annotated tag %s. Push it with: git push origin %s\n' "$tag" "$tag"
  fi
fi
