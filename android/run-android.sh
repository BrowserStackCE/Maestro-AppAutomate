#!/usr/bin/env bash
# run-android.sh
# Reads device selection and capabilities from browserstack.yml and
# triggers an Android Maestro build on BrowserStack App Automate.
#
# Usage:
#   chmod +x run-android.sh
#   export BROWSERSTACK_USERNAME="your-username"
#   export BROWSERSTACK_ACCESS_KEY="your-access-key"
#   ./run-android.sh
#
# Optional -- upload fresh app/suite before running:
#   ./run-android.sh --upload

set -euo pipefail

CONFIG="browserstack.yml"

# -- Dependency check -----------------------------------------------------------
for cmd in curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: '$cmd' is required but not found."; exit 1; }
done

# -- Credentials ----------------------------------------------------------------
BS_USER="${BROWSERSTACK_USERNAME:-}"
BS_KEY="${BROWSERSTACK_ACCESS_KEY:-}"
if [[ -z "$BS_USER" || -z "$BS_KEY" ]]; then
  echo "ERROR: Set BROWSERSTACK_USERNAME and BROWSERSTACK_ACCESS_KEY before running."
  exit 1
fi

# -- Parse browserstack.yml with Python (no extra deps needed) -----------------
read_yml() {
  # Usage: read_yml <key>   -- returns the scalar value for a top-level key
  python3 - "$CONFIG" "$1" <<'EOF'
import sys, re

config_file = sys.argv[1]
key         = sys.argv[2]

with open(config_file) as f:
    content = f.read()

# Strip comment lines and inline comments
lines = []
for line in content.splitlines():
    stripped = line.strip()
    if stripped.startswith('#'):
        continue
    # Remove inline comments (but keep # inside quoted strings -- simple heuristic)
    line = re.sub(r'\s+#.*$', '', line)
    lines.append(line)

text = '\n'.join(lines)

# Extract scalar value for the key
m = re.search(rf'^{re.escape(key)}:\s*(.+)$', text, re.MULTILINE)
print(m.group(1).strip() if m else '')
EOF
}

read_yml_list() {
  # Usage: read_yml_list <key>  -- returns a JSON array string for a YAML list
  python3 - "$CONFIG" "$1" <<'EOF'
import sys, re, json

config_file = sys.argv[1]
key         = sys.argv[2]

with open(config_file) as f:
    lines = f.readlines()

# Find the key line, then collect indented "- value" lines that follow
collecting = False
items = []
key_pattern = re.compile(rf'^{re.escape(key)}:\s*$')

for line in lines:
    stripped = line.strip()
    if stripped.startswith('#'):
        continue
    if key_pattern.match(line):
        collecting = True
        continue
    if collecting:
        m = re.match(r'^\s+-\s+(.+)$', line)
        if m:
            items.append(m.group(1).strip().strip('"\''))
        elif line.strip() and not line.startswith(' '):
            break  # new top-level key -- stop

print(json.dumps(items))
EOF
}

read_yml_bool() {
  # Returns "true" or "false" (lowercase) for a boolean YAML key
  read_yml "$1" | tr '[:upper:]' '[:lower:]'
}

# -- Read values from browserstack.yml -----------------------------------------
APP=$(read_yml "app")
TEST_SUITE=$(read_yml "testSuite")
PROJECT=$(read_yml "project")
MAESTRO_VERSION=$(read_yml "maestroVersion")
DEVICES_JSON=$(read_yml_list "devices")

TEST_OBS=$(read_yml_bool "testObservability")
NETWORK_LOGS=$(read_yml_bool "networkLogs")
DEVICE_LOGS=$(read_yml_bool "deviceLogs")
APP_PROFILING=$(read_yml_bool "appProfiling")
RETRY=$(read_yml_bool "retryTestsOnFailure")
ACCESSIBILITY=$(read_yml_bool "accessibility")

# Accessibility sub-options
WCAG_VERSION=$(python3 - "$CONFIG" <<'EOF'
import sys, re
with open(sys.argv[1]) as f:
    text = f.read()
m = re.search(r'wcagVersion:\s*(\S+)', text)
print(m.group(1) if m else 'wcag22aa')
EOF
)

BEST_PRACTICE=$(python3 - "$CONFIG" <<'EOF'
import sys, re
with open(sys.argv[1]) as f:
    text = f.read()
m = re.search(r'bestPractice:\s*(\S+)', text)
print((m.group(1) if m else 'true').lower())
EOF
)

NEEDS_REVIEW=$(python3 - "$CONFIG" <<'EOF'
import sys, re
with open(sys.argv[1]) as f:
    text = f.read()
m = re.search(r'needsReview:\s*(\S+)', text)
print((m.group(1) if m else 'false').lower())
EOF
)

SCREEN_READER=$(python3 - "$CONFIG" <<'EOF'
import sys, re
with open(sys.argv[1]) as f:
    text = f.read()
m = re.search(r'screenReaderAutomationReport:\s*(\S+)', text)
print((m.group(1) if m else 'false').lower())
EOF
)

# -- Optional upload step -------------------------------------------------------
if [[ "${1:-}" == "--upload" ]]; then
  echo "==> Uploading app (custom_id: $APP)..."
  curl -s -u "$BS_USER:$BS_KEY" \
    -X POST "https://api-cloud.browserstack.com/app-automate/maestro/v2/app" \
    -F "file=@../app/WikipediaSample.apk" \
    -F "custom_id=${APP}" | python3 -c "import sys,json; d=json.load(sys.stdin); print('  app_url:', d.get('app_url','(see response)'))"

  echo "==> Zipping tests/ flows..."
  zip -r android_flows.zip tests >/dev/null

  echo "==> Uploading test suite (custom_id: AndroidFlows)..."
  SUITE_URL=$(curl -s -u "$BS_USER:$BS_KEY" \
    -X POST "https://api-cloud.browserstack.com/app-automate/maestro/v2/test-suite" \
    -F "file=@android_flows.zip" \
    -F "custom_id=AndroidFlows" | python3 -c "import sys,json; d=json.load(sys.stdin); url=d.get('test_suite_url',''); print(url)")
  echo "  test_suite_url: $SUITE_URL"
  # Use the direct bs:// URL for this build to avoid custom_id resolution issues
  TEST_SUITE="$SUITE_URL"
fi

# -- Build the JSON payload from config values ----------------------------------
export DEVICES_JSON CONFIG
PAYLOAD=$(python3 ../build_payload.py \
  "$APP" "$TEST_SUITE" "$PROJECT" "$MAESTRO_VERSION" \
  "$TEST_OBS" "$NETWORK_LOGS" "$DEVICE_LOGS" "$APP_PROFILING" "$RETRY" \
  "$ACCESSIBILITY" "$WCAG_VERSION" "$BEST_PRACTICE" "$NEEDS_REVIEW" "$SCREEN_READER")

# -- Trigger the build ----------------------------------------------------------
echo "==> Triggering Android build from $CONFIG ..."
echo "    Devices : $(echo "$DEVICES_JSON" | python3 -c 'import sys,json; print(", ".join(json.load(sys.stdin)))')"
echo "    App     : $APP"
echo "    Suite   : $TEST_SUITE"
echo ""

RESPONSE=$(curl -s -u "$BS_USER:$BS_KEY" \
  -X POST "https://api-cloud.browserstack.com/app-automate/maestro/v2/android/build" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo "$RESPONSE" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    if "build_id" in d:
        bid = d["build_id"]
        print("Build triggered!")
        print("  Build ID :", bid)
        print("  Dashboard: https://app-automate.browserstack.com/builds/" + str(bid))
    else:
        print("ERROR:", d.get("message", "Unknown error"))
        sys.exit(1)
except Exception as e:
    print("ERROR parsing response:", e)
    print(sys.stdin.read())
    sys.exit(1)
' || true

# -- Cleanup: remove the zip after the build is triggered ---------------------
if [[ -f "android_flows.zip" ]]; then
  rm -f android_flows.zip
  echo "==> Cleaned up android_flows.zip"
fi
