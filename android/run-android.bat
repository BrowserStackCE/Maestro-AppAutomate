@echo off
REM run-android.bat
REM Reads device selection and capabilities from browserstack.yml and
REM triggers an Android Maestro build on BrowserStack App Automate.
REM
REM Usage:
REM   set BROWSERSTACK_USERNAME=your-username
REM   set BROWSERSTACK_ACCESS_KEY=your-access-key
REM   cd android
REM   run-android.bat
REM
REM Optional -- upload fresh app/suite before running:
REM   run-android.bat --upload

setlocal enabledelayedexpansion

set CONFIG=browserstack.yml
set PAYLOAD_FILE=%TEMP%\bs_payload.json

REM -- Credentials check ---------------------------------------------------------
if "%BROWSERSTACK_USERNAME%"=="" (
    echo ERROR: Set BROWSERSTACK_USERNAME before running.
    exit /b 1
)
if "%BROWSERSTACK_ACCESS_KEY%"=="" (
    echo ERROR: Set BROWSERSTACK_ACCESS_KEY before running.
    exit /b 1
)

set BS_USER=%BROWSERSTACK_USERNAME%
set BS_KEY=%BROWSERSTACK_ACCESS_KEY%

REM -- Read scalar values from browserstack.yml ----------------------------------
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); lines=[l for l in t.splitlines() if not l.strip().startswith('#')]; t=chr(10).join(lines); m=re.search(r'^app:\s*(.+)$',t,re.M); print(m.group(1).strip()) if m else print('')"') do set APP=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); lines=[l for l in t.splitlines() if not l.strip().startswith('#')]; t=chr(10).join(lines); m=re.search(r'^testSuite:\s*(.+)$',t,re.M); print(m.group(1).strip()) if m else print('')"') do set TEST_SUITE=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); lines=[l for l in t.splitlines() if not l.strip().startswith('#')]; t=chr(10).join(lines); m=re.search(r'^project:\s*(.+)$',t,re.M); print(m.group(1).strip()) if m else print('')"') do set PROJECT=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); lines=[l for l in t.splitlines() if not l.strip().startswith('#')]; t=chr(10).join(lines); m=re.search(r'^maestroVersion:\s*(.+)$',t,re.M); print(m.group(1).strip()) if m else print('')"') do set MAESTRO_VER=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); m=re.search(r'testObservability:\s*(\S+)',t); print(m.group(1).lower()) if m else print('true')"') do set TEST_OBS=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); m=re.search(r'networkLogs:\s*(\S+)',t); print(m.group(1).lower()) if m else print('true')"') do set NETWORK_LOGS=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); m=re.search(r'deviceLogs:\s*(\S+)',t); print(m.group(1).lower()) if m else print('true')"') do set DEVICE_LOGS=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); m=re.search(r'appProfiling:\s*(\S+)',t); print(m.group(1).lower()) if m else print('true')"') do set APP_PROFILING=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); m=re.search(r'retryTestsOnFailure:\s*(\S+)',t); print(m.group(1).lower()) if m else print('false')"') do set RETRY=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); m=re.search(r'^accessibility:\s*(\S+)',t,re.M); print(m.group(1).lower()) if m else print('true')"') do set ACCESSIBILITY=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); m=re.search(r'wcagVersion:\s*(\S+)',t); print(m.group(1)) if m else print('wcag22aa')"') do set WCAG_VERSION=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); m=re.search(r'bestPractice:\s*(\S+)',t); print(m.group(1).lower()) if m else print('true')"') do set BEST_PRACTICE=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); m=re.search(r'needsReview:\s*(\S+)',t); print(m.group(1).lower()) if m else print('false')"') do set NEEDS_REVIEW=%%i
for /f "delims=" %%i in ('python3 -c "import re; t=open('browserstack.yml').read(); m=re.search(r'screenReaderAutomationReport:\s*(\S+)',t); print(m.group(1).lower()) if m else print('false')"') do set SCREEN_READER=%%i

REM -- Optional upload step ------------------------------------------------------
if "%1"=="--upload" (
    echo =^> Uploading app ^(custom_id: %APP%^)...
    curl.exe -s -u "%BS_USER%:%BS_KEY%" -X POST "https://api-cloud.browserstack.com/app-automate/maestro/v2/app" -F "file=@..\app\WikipediaSample.apk" -F "custom_id=%APP%"

    echo =^> Zipping tests/ flows...
    if exist android_flows.zip del android_flows.zip
    tar -a -c -f android_flows.zip tests

    echo =^> Uploading test suite ^(custom_id: AndroidFlows^)...
    for /f "delims=" %%u in ('curl.exe -s -u "%BS_USER%:%BS_KEY%" -X POST "https://api-cloud.browserstack.com/app-automate/maestro/v2/test-suite" -F "file=@android_flows.zip" -F "custom_id=AndroidFlows" ^| python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get(\"test_suite_url\",\"\"))"') do set SUITE_URL=%%u
    echo   test_suite_url: !SUITE_URL!
    REM Use the direct bs:// URL to avoid custom_id resolution issues
    set TEST_SUITE=!SUITE_URL!
)

REM -- Build JSON payload and write to temp file ---------------------------------
set DEVICES_JSON=
for /f "delims=" %%i in ('python3 -c "import re,json; lines=open(\"browserstack.yml\").readlines(); collecting=False; items=[]; exec(\"\"\"for l in lines:\n s=l.strip()\n if s.startswith(chr(35)): continue\n if re.match(r\\\"^devices:\\\\s*$\\\",l): collecting=True; continue\n if collecting:\n  m=re.match(r\\\"^\\\\s+-\\\\s+(.+)$\\\",l)\n  if m: items.append(m.group(1).strip().strip(chr(39)+chr(34)))\n  elif s and not l.startswith(chr(32)): break\"\"\"); print(json.dumps(items))"') do set DEVICES_JSON=%%i

python3 ..\build_payload.py %APP% %TEST_SUITE% %PROJECT% %MAESTRO_VER% %TEST_OBS% %NETWORK_LOGS% %DEVICE_LOGS% %APP_PROFILING% %RETRY% %ACCESSIBILITY% %WCAG_VERSION% %BEST_PRACTICE% %NEEDS_REVIEW% %SCREEN_READER% > "%PAYLOAD_FILE%"

if not exist "%PAYLOAD_FILE%" (
    echo ERROR: Failed to build payload.
    exit /b 1
)

REM -- Trigger the build ---------------------------------------------------------
echo =^> Triggering Android build from %CONFIG% ...
echo     App   : %APP%
echo     Suite : %TEST_SUITE%
echo.

curl.exe -s -u "%BS_USER%:%BS_KEY%" ^
  -X POST "https://api-cloud.browserstack.com/app-automate/maestro/v2/android/build" ^
  -H "Content-Type: application/json" ^
  -d "@%PAYLOAD_FILE%"

REM -- Cleanup -------------------------------------------------------------------
if exist android_flows.zip (
    del android_flows.zip
    echo =^> Cleaned up android_flows.zip
)
if exist "%PAYLOAD_FILE%" del "%PAYLOAD_FILE%"

endlocal
