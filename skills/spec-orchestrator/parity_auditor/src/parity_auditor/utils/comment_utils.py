import re

def strip_c_style_comments(content: str) -> str:
    """Strips C-style block (/* */) and line (//) comments from content."""
    pattern = r'("(?:\\.|[^"\\\\])*"|\'(?:\\.|[^\'\\])*\'|`(?:\\.|[^`\\\\])*`)|(/\*.*?\*/)|(//[^\n]*)'
    
    def replacer(match):
        if match.group(2) or match.group(3): 
            return " "
        return match.group(1)
        
    return re.sub(pattern, replacer, content, flags=re.DOTALL)

strip_js_comments = strip_c_style_comments
strip_dart_comments = strip_c_style_comments
