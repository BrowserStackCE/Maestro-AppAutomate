# iOS — Maestro on BrowserStack App Automate

Run Maestro UI flows for the **SastaMart iOS app** on real iOS devices using BrowserStack App Automate.

---

## Repository structure

```
maestro-ui-automation/
├── ios/                              # iOS platform directory
│   ├── tests/                        # Maestro flows (uploaded as test suite)
│   │   ├── sastamart-generalFlow-aiVerify.yaml   # Home screen AI verification
│   │   ├── sastamart-scroll-aiAssert.yaml        # Scroll product listing + AI defect audit
│   │   ├── sastamart-swipe-aiAssert.yaml         # Swipe filter row to Keyboards + AI audit
│   │   ├── sastamart-addToCart-aiVerify.yaml     # Add to cart flow + AI verification
│   │   ├── sastamart-aiExtract.yaml              # AI text extraction flow
│   │   └── subflows/
│   │       └── skipOnboarding.yaml               # Reusable sub-flow: skip onboarding as guest
│   ├── browserstack.yml              # All capabilities, devices, shards & run profile
│   ├── run-ios.sh                    # macOS / Linux runner
│   ├── run-ios.ps1                   # Windows PowerShell runner
│   ├── run-ios.bat                   # Windows CMD runner
│   └── README.md                     # ← You are here
├── android/                          # Android platform directory (see android/README.md)
├── app/
│   ├── SastaMart.ipa                 # iOS test app
│   └── WikipediaSample.apk           # Android test app
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
  - iPhone 15 Pro-17
  - iPhone 16-18
  - iPhone 17-26
  - iPhone 18 Pro Max-27

# Maestro runtime — must be "latest" for AI commands (assertNoDefectsWithAI, assertWithAI, extractTextWithAI)
maestroVersion: latest

# Observability & debugging
# NOTE: keep networkLogs and accessibility disabled for this build
testObservability: false
networkLogs: false
deviceLogs: true
appProfiling: true
retryTestsOnFailure: true

# Sharding — 1 flow per shard, run in parallel
# PARALLEL SESSION CALCULATION:
#   deviceSelection: any  → sessions = numberOfShards (1 per shard)
#   deviceSelection: all  → sessions = numberOfShards × number of devices
shards:
  numberOfShards: 5
  deviceSelection: any
  mapping:
    - name: "Shard 1 - scroll AI assert"
      values:
        execute: [sastamart-scroll-aiAssert.yaml]
    - name: "Shard 2 - swipe AI assert"
      values:
        execute: [sastamart-swipe-aiAssert.yaml]
    - name: "Shard 3 - AI extract"
      values:
        execute: [sastamart-aiExtract.yaml]
    - name: "Shard 4 - add to cart AI verify"
      values:
        execute: [sastamart-addToCart-aiVerify.yaml]
    - name: "Shard 5 - general flow AI verify"
      values:
        execute: [sastamart-generalFlow-aiVerify.yaml]
```

---

## Step 3 — Run the build

Run scripts must be executed from the `ios/` directory.

### First run (or when IPA / flows change) — upload then build

**macOS / Linux**
```bash
cd ios
./run-ios.sh --upload
```

**Windows (PowerShell)**
```powershell
cd ios
.\run-ios.ps1 -Upload
```

**Windows (CMD)**
```cmd
cd ios
run-ios.bat --upload
```

The `--upload` flag:
1. Uploads `../app/SastaMart.ipa` with `custom_id=SastaMartIOS`
2. Zips `tests/` and uploads the test suite with `custom_id=iOSFlows`
3. Triggers the build using all settings from `browserstack.yml`
4. Cleans up the local `ios_flows.zip`

### Subsequent runs (flows unchanged) — build only

**macOS / Linux**
```bash
cd ios
./run-ios.sh
```

**Windows (PowerShell)**
```powershell
cd ios
.\run-ios.ps1
```

**Windows (CMD)**
```cmd
cd ios
run-ios.bat
```

---

## Key notes

| Capability | Note |
|---|---|
| `maestroVersion: latest` | **Required** for AI commands (`assertNoDefectsWithAI`, `assertWithAI`, `extractTextWithAI`). Resolves to Maestro 2.6.1+. Omitting or pinning an older version causes `TESTSUITE_PARSE_ERROR`. |
| `networkLogs` / `testObservability` | Keep `false` for standard builds — enabling them can cause parse issues with certain Maestro versions. |
| `retryTestsOnFailure` | Works with both sharded and non-sharded builds. |
| `deviceSelection: any` | BrowserStack picks one available device per shard. Total sessions = number of shards (5). |
| `deviceSelection: all` | Each shard runs on **every** listed device. Total sessions = shards × devices (5 × 4 = 20). |
| `custom_id` | Re-uploading with the same `custom_id` updates the alias — no need to update `bs://` URLs. |
| Filter row swipe | Swipe coordinates `start: 350, 205` → `end: 50, 205` target the category filter row centre (y=205px, verified via Appium). |

---

## View results

Visit [app-automate.browserstack.com](https://app-automate.browserstack.com) to see build results, session videos, device logs, and network logs.
