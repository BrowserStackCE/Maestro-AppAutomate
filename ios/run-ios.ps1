# run-ios.ps1
# Reads device selection and capabilities from browserstack.yml and
# triggers an iOS Maestro build on BrowserStack App Automate.
#
# Usage:
#   $env:BROWSERSTACK_USERNAME = "your-username"
#   $env:BROWSERSTACK_ACCESS_KEY = "your-access-key"
#   cd ios
#   .\run-ios.ps1
#
# Optional -- upload fresh app/suite before running:
#   .\run-ios.ps1 -Upload

param(
    [switch]$Upload
)

$ErrorActionPreference = "Stop"
$CONFIG = "browserstack.yml"

# -- Credentials check ----------------------------------------------------------
if (-not $env:BROWSERSTACK_USERNAME -or -not $env:BROWSERSTACK_ACCESS_KEY) {
    Write-Error "ERROR: Set BROWSERSTACK_USERNAME and BROWSERSTACK_ACCESS_KEY before running."
    exit 1
}
$BS_USER = $env:BROWSERSTACK_USERNAME
$BS_KEY  = $env:BROWSERSTACK_ACCESS_KEY

# -- Read scalar values from browserstack.yml via Python ------------------------
function Read-YmlScalar($key) {
    python3 -c "import re,sys; t=open('$CONFIG').read(); lines=[l for l in t.splitlines() if not l.strip().startswith('#')]; t='\n'.join(lines); m=re.search(r'^' + r'$key' + r':\s*(.+)$', t, re.M); print(m.group(1).strip()) if m else print('')"
}

$APP        = Read-YmlScalar "app"
$TEST_SUITE = Read-YmlScalar "testSuite"
$PROJECT    = Read-YmlScalar "project"

# -- Optional upload step -------------------------------------------------------
if ($Upload) {
    Write-Host "==> Uploading app (custom_id: $APP)..."
    curl.exe -s -u "${BS_USER}:${BS_KEY}" `
        -X POST "https://api-cloud.browserstack.com/app-automate/maestro/v2/app" `
        -F "file=@..\app\Wikipedia.ipa" `
        -F "custom_id=$APP"

    Write-Host "==> Zipping tests/ flows..."
    if (Test-Path ios_flows.zip) { Remove-Item ios_flows.zip }
    Push-Location tests
    try { Compress-Archive -Path * -DestinationPath ..\ios_flows.zip }
    finally { Pop-Location }

    Write-Host "==> Uploading test suite (custom_id: iOSFlows)..."
    $suiteResponse = curl.exe -s -u "${BS_USER}:${BS_KEY}" `
        -X POST "https://api-cloud.browserstack.com/app-automate/maestro/v2/test-suite" `
        -F "file=@ios_flows.zip" `
        -F "custom_id=iOSFlows"
    $SUITE_URL = python3 -c "import sys,json; d=json.loads('$suiteResponse'); print(d.get('test_suite_url',''))"
    Write-Host "  test_suite_url: $SUITE_URL"
    # Use the direct bs:// URL to avoid custom_id resolution issues
    $TEST_SUITE = $SUITE_URL
}

# -- Build JSON payload via build_payload.py ------------------------------------
$env:CONFIG       = $CONFIG
$env:DEVICES_JSON = python3 -c "import re,json; t=open('$CONFIG').read(); lines=t.splitlines(); collecting=False; items=[]; [items.append(re.match(r'^\s+-\s+(.+)$',l).group(1).strip().strip(chr(39)+chr(34))) for l in lines if not l.strip().startswith('#') and collecting and re.match(r'^\s+-\s+',l)]; [setattr(__builtins__,'_c',True) for l in lines if re.match(r'^devices:\s*$',l)]; exec('collecting=True') if re.search(r'^devices:\s*$',t,re.M) else None; exec(open('$CONFIG').read() if False else ''); print(json.dumps([l.strip().strip(chr(39)+chr(34)) for l in t.splitlines() if not l.strip().startswith(chr(35)) and re.match(r'^\s+-\s+',l) and collecting] if False else json.dumps([])))"

# Simpler device list extraction
$env:DEVICES_JSON = python3 -c "
import re, json
with open('$CONFIG') as f:
    lines = f.readlines()
collecting = False
items = []
for line in lines:
    s = line.strip()
    if s.startswith('#'): continue
    if re.match(r'^devices:\s*$', line):
        collecting = True
        continue
    if collecting:
        m = re.match(r'^\s+-\s+(.+)$', line)
        if m: items.append(m.group(1).strip().strip(chr(39)+chr(34)))
        elif s and not line.startswith(' '): break
print(json.dumps(items))
"

$TEST_OBS      = python3 -c "import re; t=open('$CONFIG').read(); m=re.search(r'testObservability:\s*(\S+)',t); print(m.group(1).lower()) if m else print('false')"
$NETWORK_LOGS  = python3 -c "import re; t=open('$CONFIG').read(); m=re.search(r'networkLogs:\s*(\S+)',t); print(m.group(1).lower()) if m else print('false')"
$DEVICE_LOGS   = python3 -c "import re; t=open('$CONFIG').read(); m=re.search(r'deviceLogs:\s*(\S+)',t); print(m.group(1).lower()) if m else print('true')"
$APP_PROFILING = python3 -c "import re; t=open('$CONFIG').read(); m=re.search(r'appProfiling:\s*(\S+)',t); print(m.group(1).lower()) if m else print('true')"
$RETRY         = python3 -c "import re; t=open('$CONFIG').read(); m=re.search(r'retryTestsOnFailure:\s*(\S+)',t); print(m.group(1).lower()) if m else print('false')"
$ACCESSIBILITY = python3 -c "import re; t=open('$CONFIG').read(); m=re.search(r'^accessibility:\s*(\S+)',t,re.M); print(m.group(1).lower()) if m else print('false')"
$WCAG_VERSION  = python3 -c "import re; t=open('$CONFIG').read(); m=re.search(r'wcagVersion:\s*(\S+)',t); print(m.group(1)) if m else print('wcag22aa')"
$BEST_PRACTICE = python3 -c "import re; t=open('$CONFIG').read(); m=re.search(r'bestPractice:\s*(\S+)',t); print(m.group(1).lower()) if m else print('true')"
$NEEDS_REVIEW  = python3 -c "import re; t=open('$CONFIG').read(); m=re.search(r'needsReview:\s*(\S+)',t); print(m.group(1).lower()) if m else print('false')"
$SCREEN_READER = python3 -c "import re; t=open('$CONFIG').read(); m=re.search(r'screenReaderAutomationReport:\s*(\S+)',t); print(m.group(1).lower()) if m else print('false')"
$MAESTRO_VER   = python3 -c "import re; t=open('$CONFIG').read(); lines=[l for l in t.splitlines() if not l.strip().startswith('#')]; t='\n'.join(lines); m=re.search(r'maestroVersion:\s*(\S+)',t); print(m.group(1)) if m else print('')"

$PAYLOAD = python3 ..\build_payload.py $APP $TEST_SUITE $PROJECT $MAESTRO_VER `
    $TEST_OBS $NETWORK_LOGS $DEVICE_LOGS $APP_PROFILING $RETRY `
    $ACCESSIBILITY $WCAG_VERSION $BEST_PRACTICE $NEEDS_REVIEW $SCREEN_READER

# -- Trigger the build ----------------------------------------------------------
Write-Host "==> Triggering iOS build from $CONFIG ..."
Write-Host "    App   : $APP"
Write-Host "    Suite : $TEST_SUITE"
Write-Host ""

$RESPONSE = curl.exe -s -u "${BS_USER}:${BS_KEY}" `
    -X POST "https://api-cloud.browserstack.com/app-automate/maestro/v2/ios/build" `
    -H "Content-Type: application/json" `
    -d $PAYLOAD

$RESPONSE | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    bid = d.get('build_id') or d.get('id') or '(see response)'
    print('Build triggered!')
    print('  Build ID :', bid)
    print('  Dashboard: https://app-automate.browserstack.com/builds/' + str(bid))
except Exception:
    print(sys.stdin.read())
"

# -- Cleanup --------------------------------------------------------------------
if (Test-Path ios_flows.zip) {
    Remove-Item ios_flows.zip
    Write-Host "==> Cleaned up ios_flows.zip"
}
