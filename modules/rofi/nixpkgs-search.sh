set -euo pipefail

query="$*"

if [[ -z "$query" ]]; then
  read -r -p "Search nixpkgs: " query
fi

[[ -n "$query" ]] || exit 0

auth='aWVSALXpZv:X8gPHnzL52wFEekuxsfQ9cSh'
index=""

for generation in 46 45 44 43; do
  candidate="latest-$generation-nixos-unstable"
  count="$(${CURL:-curl} --silent --show-error --user "$auth" \
    --header 'Content-Type: application/json' \
    --data '{"query":{"match_all":{}}}' \
    "https://search.nixos.org/backend/$candidate/_count" \
    | ${JQ:-jq} -r '.count // empty')"
  if [[ "$count" =~ ^[1-9][0-9]*$ ]]; then
    index="$candidate"
    break
  fi
done

if [[ -z "$index" ]]; then
  printf '%s\n' 'Unable to find the current nixos-unstable search index.' >&2
  exit 1
fi

# shellcheck disable=SC2016 # jq expands its $query variable, not the shell.
payload="$(${JQ:-jq} -cn --arg query "$query" '{
  size: 100,
  query: {
    bool: {
      must: [{term: {type: "package"}}],
      should: [
        {match: {package_pname: {query: $query, boost: 3}}},
        {match: {package_attr_name: {query: $query, boost: 2}}},
        {match: {package_description: $query}}
      ],
      minimum_should_match: 1
    }
  }
}')"

results="$(mktemp)"
trap 'rm -f "$results"' EXIT

${CURL:-curl} --fail --silent --show-error --user "$auth" \
  --header 'Content-Type: application/json' \
  --data "$payload" \
  "https://search.nixos.org/backend/$index/_search" \
  | ${JQ:-jq} -r '
      .hits.hits[]?
      | ._source
      | [
          (.package_attr_name // .package_pname),
          (.package_pversion // "unknown"),
          (.package_description // "")
        ]
      | @tsv
    ' > "$results"

if [[ ! -s "$results" ]]; then
  printf 'No nixpkgs packages found matching %q.\n' "$query" >&2
  exit 1
fi

tv --source-command "cat ${results@Q}" --no-preview
