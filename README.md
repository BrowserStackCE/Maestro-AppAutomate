# Maestro UI Automation — BrowserStack App Automate

Run declarative Maestro UI flows for **Android** (Wikipedia) and **iOS** (Wikipedia) apps on real devices using BrowserStack App Automate.

---

## Repository structure

```
maestro-ui-automation/
├── android/                          # Android platform
│   ├── tests/                        # Maestro flows
│   │   ├── wiki-generalFlow-aiVerify.yaml    # Explore home screen AI verification
│   │   ├── wiki-scroll-aiAssert.yaml         # Scroll feed + AI defect audit
│   │   ├── wiki-swipe.yaml                   # Onboarding swipe + GET STARTED assertion
│   │   ├── wiki-aiExtract.yaml               # AI text extraction (Einstein article)
│   │   ├── wiki-conditional-nestedFlows.yaml # Conditional scroll to Top read
│   │   ├── common/functions/
│   │   │   ├── scroll.yaml                   # Reusable scroll sub-flow
│   │   │   └── swipe.yaml                    # Reusable swipe sub-flow
│   │   └── subflows/
│   │       └── skipOnboarding.yaml           # Skip onboarding / dismiss dialogs
│   ├── browserstack.yml              # Capabilities, devices, shards & run profile
│   ├── run-android.sh                # macOS / Linux runner
│   ├── run-android.ps1               # Windows PowerShell runner
│   ├── run-android.bat               # Windows CMD runner
│   └── README.md
├── ios/                              # iOS platform
│   ├── tests/                        # Maestro flows
│   │   ├── wiki-generalFlow-aiVerify.yaml    # Explore home screen AI verification
│   │   ├── wiki-scroll-aiAssert.yaml         # Scroll feed + AI defect audit
│   │   ├── wiki-swipe.yaml                   # Onboarding swipe + Get started assertion
│   │   ├── wiki-aiExtract.yaml               # AI text extraction (Einstein article)
│   │   ├── wiki-conditional-nestedFlows.yaml # Conditional scroll to On this day
│   │   ├── common/functions/
│   │   │   ├── scroll.yaml                   # Reusable scroll sub-flow
│   │   │   └── swipe.yaml                    # Reusable swipe sub-flow
│   │   └── subflows/
│   │       ├── skipOnboarding.yaml           # Skip onboarding / dismiss permission dialogs
│   │       └── dismissGotIt.yaml             # Dismiss first-time-use "Got it" popovers
│   ├── browserstack.yml
│   ├── run-ios.sh
│   ├── run-ios.ps1
│   ├── run-ios.bat
│   └── README.md
├── app/
│   ├── Wikipedia.ipa                 # iOS test app
│   └── WikipediaSample.apk           # Android test app
├── build_payload.py                  # Builds the BrowserStack API JSON payload
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

## Quick start

### 1 — Set credentials

**macOS / Linux**
```bash
export BROWSERSTACK_USERNAME="your-username"
export BROWSERSTACK_ACCESS_KEY="your-access-key"
```

**Windows (PowerShell)**
```powershell
$env:BROWSERSTACK_USERNAME="your-username"
$env:BROWSERSTACK_ACCESS_KEY="your-access-key"
```

### 2 — Run Android

```bash
cd android
./run-android.sh --upload   # first run: upload app + suite, then trigger build
./run-android.sh            # subsequent runs: trigger build only
```

### 3 — Run iOS

```bash
cd ios
./run-ios.sh --upload       # first run: upload app + suite, then trigger build
./run-ios.sh                # subsequent runs: trigger build only
```

---

## AI commands used

| Command | Purpose |
|---|---|
| `assertWithAI` | Validate complex UI states with natural language |
| `assertNoDefectsWithAI` | Visual/functional audit for UI bugs and broken layouts |
| `extractTextWithAI` | Extract dynamic content (e.g. article text, prices) |

> **Requires** `maestroVersion: latest` (iOS) or `maestroVersion: 1.39.13` (Android) in `browserstack.yml`.

---

## Observability & capabilities

| Capability | Android | iOS | Notes |
|---|---|---|---|
| `maestroVersion` | `1.39.13` | `latest` | Android pins to the version that supports accessibility scanning; iOS uses latest for AI commands |
| `testObservability` | `false` | `false` | Must be `false` on Android when accessibility is disabled; keep `false` on iOS to avoid accessibility report interference |
| `deviceLogs` | `true` | `true` | Device system logs captured for both platforms |
| `appProfiling` | `true` | `true` | CPU / memory metrics recorded for performance analysis |
| `networkLogs` | `true` | `false` | HTTP traffic captured on Android; disabled on iOS |
| `retryTestsOnFailure` | `true` | `true` | Failed tests retried once before marking as failed |

---

## Accessibility scanning

Both platforms run BrowserStack App Accessibility with WCAG 2.2 AAA coverage.

| Option | Android | iOS |
|---|---|---|
| `wcagVersion` | `wcag22aaa` | `wcag22aaa` |
| `bestPractice` | `true` | `true` |
| `needsReview` | `true` | `true` |
| `screenReaderAutomationReport` | `true` | `false` |

> **Screen reader automation report** is enabled on Android to generate a TalkBack-driven accessibility report. It is disabled on iOS as VoiceOver automation report generation require enhancements.

---

## View results

Visit [app-automate.browserstack.com](https://app-automate.browserstack.com) to see build results, session videos, device logs, network logs, app performance profiles, and accessibility reports.
