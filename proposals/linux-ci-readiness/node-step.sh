set -euo pipefail
forge_node_dir=$(mktemp -d "$RUNNER_TEMP/forge-node.XXXXXX")
curl --fail --location --silent --show-error --output "$forge_node_dir/node.tar.xz" https://nodejs.org/dist/v24.3.0/node-v24.3.0-linux-x64.tar.xz
printf '%s  %s\n' 'a962afadaa8b94bae8bff87ddd6c11f7aae621032424ef05c0a4fe2537fa4de0' "$forge_node_dir/node.tar.xz" | sha256sum --check --strict
mkdir "$forge_node_dir/runtime"
tar -xJf "$forge_node_dir/node.tar.xz" -C "$forge_node_dir/runtime" --strip-components=1
printf '%s  %s\n' '11ee468e2ac16c11dde59c6897b341968442430439733fdce6ff6f4da8bca38f' "$forge_node_dir/runtime/bin/node" | sha256sum --check --strict
export PATH="$forge_node_dir/runtime/bin:$PATH"
printf '%s\n' "$forge_node_dir/runtime/bin" >> "$GITHUB_PATH"
test "$(npm --version)" = '11.4.2'
npm ci --ignore-scripts --no-audit --no-fund
.toolchain/ci-python/bin/python scripts/javascript_env.py
