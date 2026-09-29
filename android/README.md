# Android — Maestro on BrowserStack App Automate

Run Maestro UI flows for the **Wikipedia Android app** on real Android devices using BrowserStack App Automate.

---

## Repository structure

```
maestro-ui-automation/
├── android/                          # Android platform directory
│   ├── tests/                        # Maestro flows (uploaded as test suite)
│   │   ├── wiki-generalFlow-aiVerify.yaml  # Search for article, AI-verify page content
│   │   ├── wiki-conditional-nestedFlows.yaml  # Conditionally scroll until Top read section is visible
│   │   ├── wiki-scroll-aiAssert.yaml     # Scroll through news feed + AI assertion
│   │   ├── wiki-swipe.yaml               # Swipe through onboarding, assert GET STARTED on last page
│   │   ├── wiki-aiExtract.yaml           # extractTextWithAI, assertWithAI, use extracted value as input
│   │   ├── common/
│   │   │   └── functions/
│   │   │       ├── swipe.yaml            # Reusable sub-flow (3× horizontal swipe)
│   │   │       └── scroll.yaml           # Reusable sub-flow (2× vertical scroll)
│   │   └── subflows/
│   │       └── skipOnboarding.yaml       # Reusable sub-flow: dismiss notification dialog & skip onboarding
│   ├── browserstack.yml              # All capabilities, devices, shards & run profile
│   ├── run-android.sh                # macOS / Linux runner
│   ├── run-android.ps1               # Windows PowerShell runner
│   ├── run-android.bat               # Windows CMD runner
│   └── README.md                     # ← You are here
├── ios/                              # iOS platform directory (see ios/README.md)
├── app/
│   ├── WikipediaSample.apk           # Android test app
│   └── SastaMart.ipa                 # iOS test app
├── build_payload.py                  # Builds the BrowserStack API JSON payload from browserstack.yml
└── read_devices.py                   # Reads device list from browserstack.yml
```

---

## Prerequisites

| Tool | macOS | Windows |
|---|---|---|
| curl | Pre-installed | Pre-installed on Windows 10+ |
| python3 | Pre-installed on macOS 12+ | [python.org](https://www.python.org/downloads/) |
| zip / tar | Pre-installed | Pre-installed on Windows 10+ |

> **Credentials** — find yours at [app-automate.browserstack.com](https://app-automate.browserstack.com) → **Account → Settings**.

---

## Step 1 — Set credentials

**macOS / Linux**
```bash
export BROWSERSTACK_USERNAME="your-username"
export BROWSERSTACK_ACCESS_KEY="your-access-key"
```

**Windows (Command Prompt)**
```cmd
set BROWSERSTACK_USERNAME=your-username
set BROWSERSTACK_ACCESS_KEY=your-access-key
```

**Windows (PowerShell)**
```powershell
$env:BROWSERSTACK_USERNAME="your-username"
$env:BROWSERSTACK_ACCESS_KEY="your-access-key"
```

---

## Step 2 — Configure `browserstack.yml`

All capabilities, devices, and sharding are configured in **`browserstack.yml`** — no need to edit curl commands.

```yaml
# Target devices (format: "<Device Name>-<osVersion>")
devices:
  - Samsung Galaxy S25-15.0
  - Samsung Galaxy S26-16.0

# Maestro version — pin to a stable version when accessibility is enabled
# NOTE: accessibility is not supported with maestroVersion: latest
# maestroVersion: 1.38.0

# Observability & debugging
testObservability: true   # Required when accessibility: true
networkLogs: true
deviceLogs: true
appProfiling: true
retryTestsOnFailure: true  # Works with both sharded and non-sharded builds

# Accessibility scanning
accessibility: true
accessibilityOptions:
  wcagVersion: wcag22aa
  includeIssueType:
    bestPractice: true
    needsReview: false
  screenReaderAutomationReport: true

# Sharding — 1 flow per shard, run in parallel
# PARALLEL SESSION CALCULATION:
#   deviceSelection: all  → sessions = numberOfShards × number of devices
#   deviceSelection: any  → sessions = numberOfShards (1 per shard)
shards:
  numberOfShards: 5
  deviceSelection: any
  mapping:
    - name: "Shard 1 - scroll AI assert"
      values:
        execute: [wiki-scroll-aiAssert.yaml]
    - name: "Shard 2 - swipe onboarding"
      values:
        execute: [wiki-swipe.yaml]
    ...
```

---

## Step 3 — Run the build

The run scripts read all configuration from `browserstack.yml` automatically. Run scripts must be executed from the `android/` directory.

### First run (or when APK / flows change) — upload then build

**macOS / Linux**
```bash
cd android
./run-android.sh --upload
```

**Windows (PowerShell)**
```powershell
cd android
.\run-android.ps1 -Upload
```

**Windows (CMD)**
```cmd
cd android
run-android.bat --upload
```

The `--upload` flag:
1. Uploads `../app/WikipediaSample.apk` with `custom_id=WikipediaSample`
2. Zips `tests/` and uploads the test suite with `custom_id=AndroidFlows`
3. Triggers the build using all settings from `browserstack.yml`
4. Cleans up the local `android_flows.zip`

### Subsequent runs (flows unchanged) — build only

**macOS / Linux**
```bash
cd android
./run-android.sh
```

**Windows (PowerShell)**
```powershell
cd android
.\run-android.ps1
```

**Windows (CMD)**
```cmd
cd android
run-android.bat
```

---

## Key notes

| Capability | Note |
|---|---|
| `maestroVersion: latest` | Accessibility scanning is **not supported** with `latest`. Pin to a specific version (e.g. `1.38.0`) when `accessibility: true`. |
| `retryTestsOnFailure` | Works with both sharded and non-sharded builds. |
| `deviceSelection: all` | Each shard runs on **every** listed device. Total sessions = shards × devices. Ensure your parallel limit covers this. |
| `deviceSelection: any` | BrowserStack picks one available device per shard. Total sessions = number of shards. |
| `testObservability` | Must be `true` when `accessibility: true`. |
| `custom_id` | Re-uploading with the same `custom_id` updates the alias — no need to update `bs://` URLs. |

---

## View results

Visit [app-automate.browserstack.com](https://app-automate.browserstack.com) to see build results, session videos, device logs, and network logs.
