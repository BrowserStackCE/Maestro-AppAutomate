import re, json

with open("browserstack.yml") as f:
    lines = f.readlines()

collecting = False
items = []
for line in lines:
    stripped = line.strip()
    if stripped.startswith("#"):
        continue
    if re.match(r"^devices:\s*$", line):
        collecting = True
        continue
    if collecting:
        m = re.match(r"^\s+-\s+(.+)$", line)
        if m:
            items.append(m.group(1).strip().strip("\"'"))
        elif stripped and not line.startswith(" "):
            break

print(json.dumps(items))
