import json, sys, os, re

def b(v):
    return v.strip().lower() == "true"

(app, test_suite, project, maestro_version,
 test_obs, network_logs, device_logs, app_profiling, retry,
 accessibility, wcag_version, best_practice, needs_review, screen_reader) = sys.argv[1:]

devices = json.loads(os.environ["DEVICES_JSON"])

payload = {
    "app":                 app,
    "testSuite":           test_suite,
    "project":             project,
    "devices":             devices,
    "networkLogs":         b(network_logs),
    "deviceLogs":          b(device_logs),
    "appProfiling":        b(app_profiling),
    "retryTestsOnFailure": b(retry),
}

# Only include maestroVersion when explicitly set in the yml.
# IMPORTANT: AI commands (assertNoDefectsWithAI, assertWithAI, extractTextWithAI)
# require maestroVersion: latest (resolves to 2.6.1+).
# Accessibility scanning (accessibility: true) is NOT supported with maestroVersion: latest —
# omit maestroVersion entirely when accessibility is enabled so BrowserStack picks a
# compatible version automatically.
mv = maestro_version.strip()
if mv:
    payload["maestroVersion"] = mv

# Only include testObservability when true
if b(test_obs):
    payload["testObservability"] = True

# Only include accessibility block when enabled
if b(accessibility):
    payload["accessibility"] = True
    payload["accessibilityOptions"] = {
        "wcagVersion": wcag_version,
        "includeIssueType": {
            "bestPractice": b(best_practice),
            "needsReview":  b(needs_review)
        },
        "screenReaderAutomationReport": b(screen_reader)
    }

# Parse shards block from browserstack.yml if present
config_file = os.environ["CONFIG"]
with open(config_file) as f:
    raw_lines = f.readlines()

# Strip comment-only lines
lines = [l for l in raw_lines if not l.strip().startswith("#")]

# Find the shards: top-level key
shard_start = None
for i, line in enumerate(lines):
    if re.match(r"^shards:\s*$", line):
        shard_start = i
        break

if shard_start is not None:
    shard_lines = ["shards:\n"]
    for line in lines[shard_start + 1:]:
        if line.strip() == "":
            continue
        if line[0] not in (" ", "\t"):
            break
        shard_lines.append(line)

    shard_text = "".join(shard_lines)
    n_shards = int(re.search(r"numberOfShards:\s*(\d+)", shard_text).group(1))
    dev_sel_m = re.search(r"deviceSelection:\s*(\S+)", shard_text)
    dev_sel = dev_sel_m.group(1) if dev_sel_m else "any"

    mapping = []
    current = None
    for line in shard_lines:
        m = re.match(r'\s+-\s+name:\s*["\']?(.+?)["\']?\s*$', line)
        if m:
            if current:
                mapping.append(current)
            current = {"name": m.group(1), "values": {"execute": []}}
            continue
        if current:
            m2 = re.match(r"\s+-\s+(\S+\.yaml)\s*$", line)
            if m2:
                current["values"]["execute"].append(m2.group(1))
    if current:
        mapping.append(current)

    payload["shards"] = {
        "numberOfShards": n_shards,
        "deviceSelection": dev_sel,
        "mapping": mapping
    }

print(json.dumps(payload, indent=2))
