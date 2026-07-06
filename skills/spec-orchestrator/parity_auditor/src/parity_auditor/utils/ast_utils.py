import ast
import os
from typing import Optional

def walk_json_ast_for_compliance(ast_tree, target_method="stopPropagation", ast_rules=None) -> bool:
    if not ast_rules:
        ast_rules = {}
    call_expr = ast_rules.get("call_expression", "CallExpression")
    member_expr = ast_rules.get("member_expression", "MemberExpression")
    callee_key = ast_rules.get("callee", "callee")
    prop_key = ast_rules.get("property", "property")
    name_key = ast_rules.get("name", "name")
    
    stack = [ast_tree]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            if node.get("type") == call_expr:
                callee = node.get(callee_key, {})
                if callee.get("type") == member_expr:
                    property_name = callee.get(prop_key, {}).get(name_key)
                    if property_name == target_method:
                        return True
            stack.extend(node.values())
        elif isinstance(node, list):
            stack.extend(node)
            
    return False

def verify_python_ast(filepath: str, forbidden_colors) -> Optional[str]:
    with open(filepath, "r", encoding="utf-8") as f:
        code = f.read()
    try:
        tree = ast.parse(code, filename=filepath)
        for node in ast.walk(tree):
            if isinstance(node, ast.Constant) and isinstance(node.value, str):
                val = node.value.lower()
                for color in forbidden_colors:
                    if color in val:
                        return f"Python Constant in {os.path.basename(filepath)} contains hardcoded color '{color}'"
    except Exception as e:
        return f"Python file {os.path.basename(filepath)} has AST parsing errors: {e}"
    return None
