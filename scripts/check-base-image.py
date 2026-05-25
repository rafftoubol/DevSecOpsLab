# devsecops-pipelines/scripts/check-base-images.py
import json
import re
import sys


def extract_base_images(dockerfile_path):
    images = []
    with open(dockerfile_path) as f:
        for line in f:
            match = re.match(r"FROM\s+(\S+)", line.strip(), re.IGNORECASE)
            if match:
                image = match.group(1)
                if image.upper() not in ("SCRATCH", "AS"):
                    images.append(image)
    return images


dockerfile = sys.argv[1]
allowlist = sys.argv[2]

with open(allowlist) as f:
    allowed = {image["ref"] for image in json.load(f)["images"]}

failed = False
for image in extract_base_images(dockerfile):
    if image not in allowed:
        print(f"BLOCKED: {image}")
        failed = True
    else:
        print(f"ALLOWED: {image}")

sys.exit(1 if failed else 0)
