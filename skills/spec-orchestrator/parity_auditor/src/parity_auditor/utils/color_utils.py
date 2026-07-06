import re

def extract_hex_colors_from_json(data) -> set:
    colors = set()
    if isinstance(data, dict):
        for k, v in data.items():
            colors.update(extract_hex_colors_from_json(v))
    elif isinstance(data, list):
        for item in data:
            colors.update(extract_hex_colors_from_json(item))
    elif isinstance(data, str):
        if re.match(r'^#[0-9a-fA-F]{6}$', data) or re.match(r'^#[0-9a-fA-F]{3}$', data):
            colors.add(data.lower())
    return colors
