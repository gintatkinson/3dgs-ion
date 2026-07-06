def normalize_case(name: str) -> str:
    if not name:
        return ""
    return name.lower().replace('-', '').replace('_', '').replace(' ', '')
