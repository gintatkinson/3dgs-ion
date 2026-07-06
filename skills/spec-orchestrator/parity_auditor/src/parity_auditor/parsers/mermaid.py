import re
from typing import Dict, List, Optional
from .base import IParser
from ..core.models import (
    ParsedFlowchart, FlowchartNode, FlowchartConnection, FlowchartSubgraph,
    ParsedClassDiagram, ClassInfo, ClassRelationship, ClassNamespace, ClassAttribute, ClassMethod,
    ParsedSequenceDiagram, SequenceLifeline, SequenceMessage, SequenceFragment, SequenceFragmentBranch
)
from ..core.workspace import WorkspaceRepository

class MermaidFlowchartParser(IParser):
    def can_parse(self, mermaid_code: str) -> bool:
        clean = mermaid_code.strip().lower()
        return any(clean.startswith(x) for x in ("flowchart", "graph td", "graph lr", "graph"))

    def parse(self, mermaid_code: str) -> ParsedFlowchart:
        nodes = {}
        connections = []
        subgraphs = {}
        subgraph_stack = []

        def extract_node_from_part(part):
            part = part.strip()
            pattern = r'^([a-zA-Z0-9_\-.:]+)\s*(\(\[|\[\(|\(\(|\[\[|\{\{|\[\/|\[\\|\[|\(|>|\{)\s*(?:\"([^\"]*)\"|([^\"]*?))\s*(\]\)|\)\]|\)\)|\]\]|\}\}|\/\]|\\\]|\]|\)|\})$'
            match = re.match(pattern, part)
            if match:
                node_id = match.group(1)
                open_bracket = match.group(2)
                label = match.group(3) if match.group(3) is not None else match.group(4)
                if label:
                    label = label.strip()
                shape_map = {
                    '([': 'stadium',
                    '[(': 'database',
                    '((': 'circle',
                    '[[': 'subroutine',
                    '{{': 'hexagon',
                    '[/': 'parallelogram',
                    '[\\': 'parallelogram_alt',
                    '[': 'rectangle',
                    '(': 'round',
                    '{': 'rhombus',
                    '>': 'asymmetric',
                }
                shape = shape_map.get(open_bracket, 'unknown')
                return node_id, shape, label
            return part, None, None

        def parse_connection_line(line):
            line = line.strip()
            match = re.match(r'^(.*?)\s*-\.\s*(.+?)\s*\.-\s*>\s*(.*)$', line)
            if match:
                return match.group(1), match.group(3), "dotted_arrow", match.group(2).strip()
            match = re.match(r'^(.*?)\s*(-->|-\.-*->|==>)\s*\|([^|]+)\|\s*(.*)$', line)
            if match:
                arrow = match.group(2)
                label = match.group(3).strip()
                target = match.group(4)
                style = "solid_arrow"
                if "-.-" in arrow:
                    style = "dotted_arrow"
                elif "==" in arrow:
                    style = "thick_arrow"
                return match.group(1), target, style, label
            match = re.match(r'^(.*?)\s*(--|==)\s*([^-\s=].*?)\s*(-->|==>)\s*(.*)$', line)
            if match:
                connector = match.group(2)
                label = match.group(3).strip()
                target = match.group(5)
                style = "solid_arrow" if connector == "--" else "thick_arrow"
                return match.group(1), target, style, label
            match = re.match(r'^(.*?)\s*(-\.-*->|-\.-)\s*(.*)$', line)
            if match:
                arrow = match.group(2)
                style = "dotted_arrow" if "-->" in arrow or "->" in arrow else "dotted_line"
                return match.group(1), match.group(3), style, None
            match = re.match(r'^(.*?)\s*(-->|---|==>|==)\s*(.*)$', line)
            if match:
                arrow = match.group(2)
                style = "solid_arrow"
                if arrow == "---":
                    style = "solid_line"
                elif arrow == "==>":
                    style = "thick_arrow"
                elif arrow == "==":
                    style = "thick_line"
                return match.group(1), match.group(3), style, None
            return None

        lines = mermaid_code.splitlines()
        for line in lines:
            line = re.sub(r'%%.*$', '', line).strip()
            if not line or line.lower() in ("flowchart", "graph td", "graph lr", "graph", "flowchart td", "flowchart lr"):
                continue

            subgraph_match = re.match(r'^subgraph\s+([^\s\[\"\(]+)(?:\s+\[\s*\"([^\"]*)\"\s*\]|\s+\[([^\]]*)\]|\s+\"([^\"]*)\"|\s+(\S+))?', line, re.IGNORECASE)
            if subgraph_match:
                sub_id = subgraph_match.group(1)
                label = None
                for g in (subgraph_match.group(2), subgraph_match.group(3), subgraph_match.group(4), subgraph_match.group(5)):
                    if g is not None:
                        label = g.strip()
                        break
                if not label:
                    label = sub_id
                    
                sub_info = FlowchartSubgraph(
                    id=sub_id,
                    label=label,
                    parent=subgraph_stack[-1] if subgraph_stack else None,
                    nodes=[]
                )
                subgraphs[sub_id] = sub_info
                subgraph_stack.append(sub_id)
                continue

            if line.lower() == "end":
                if subgraph_stack:
                    subgraph_stack.pop()
                continue

            if line.startswith(("direction ", "style ", "classDef ", "class ", "linkStyle ", "click ")):
                continue

            conn_res = parse_connection_line(line)
            if conn_res:
                src_part, tgt_part, style, label = conn_res
                src_id, src_shape, src_label = extract_node_from_part(src_part)
                tgt_id, tgt_shape, tgt_label = extract_node_from_part(tgt_part)

                for node_id, shape, n_label in ((src_id, src_shape, src_label), (tgt_id, tgt_shape, tgt_label)):
                    if node_id not in nodes:
                        nodes[node_id] = FlowchartNode(
                            id=node_id,
                            shape=shape,
                            label=n_label or node_id,
                            subgraph=subgraph_stack[-1] if subgraph_stack else None
                        )
                    else:
                        if shape:
                            nodes[node_id].shape = shape
                        if n_label:
                            nodes[node_id].label = n_label

                if subgraph_stack:
                    current_sub = subgraph_stack[-1]
                    if src_id not in subgraphs[current_sub].nodes:
                        subgraphs[current_sub].nodes.append(src_id)
                    if tgt_id not in subgraphs[current_sub].nodes:
                        subgraphs[current_sub].nodes.append(tgt_id)

                connections.append(FlowchartConnection(
                    from_node=src_id,
                    to_node=tgt_id,
                    style=style,
                    label=label
                ))
            else:
                node_id, shape, label = extract_node_from_part(line)
                if node_id and (shape or label):
                    if node_id not in nodes:
                        nodes[node_id] = FlowchartNode(
                            id=node_id,
                            shape=shape,
                            label=label or node_id,
                            subgraph=subgraph_stack[-1] if subgraph_stack else None
                        )
                    else:
                        if shape:
                            nodes[node_id].shape = shape
                        if label:
                            nodes[node_id].label = label

                    if subgraph_stack:
                        current_sub = subgraph_stack[-1]
                        if node_id not in subgraphs[current_sub].nodes:
                            subgraphs[current_sub].nodes.append(node_id)

        return ParsedFlowchart(nodes=nodes, connections=connections, subgraphs=subgraphs)


class MermaidClassDiagramParser(IParser):
    def __init__(self, workspace_repo: WorkspaceRepository):
        self.workspace_repo = workspace_repo

    def can_parse(self, mermaid_code: str) -> bool:
        return "classdiagram" in mermaid_code.strip().lower()

    def parse(self, mermaid_code: str) -> ParsedClassDiagram:
        classes = {}
        relationships = []
        namespaces = {}
        block_stack = []

        rules = self.workspace_repo.get_codebase_rules()
        val_rules = rules.validation_rules

        visibility_prefixes = val_rules.visibility_prefixes
        vis_pattern = r'^(' + '|'.join(re.escape(p) for p in visibility_prefixes) + r')\s*(.*)$'

        rel_connectors = val_rules.relationship_connectors
        if not rel_connectors.startswith('('):
            rel_connectors = f"({rel_connectors})"

        def parse_attribute_signature(sig):
            sig = sig.strip()
            constraints = []
            constraint_match = re.search(r'\{([^}]+)\}', sig)
            if constraint_match:
                constraints = [c.strip() for c in constraint_match.group(1).split(',')]
                sig = re.sub(r'\{([^}]+)\}', '', sig).strip()
                
            visibility = None
            vis_match = re.match(vis_pattern, sig)
            if vis_match:
                visibility = vis_match.group(1)
                sig = vis_match.group(2).strip()
                
            multiplicity = None
            mult_match = re.search(r'\[([^\]]+)\]', sig)
            if mult_match:
                multiplicity = mult_match.group(1).strip()
                sig = re.sub(r'\[([^\]]+)\]', '', sig).strip()
                
            name = sig
            attr_type = None
            if ':' in sig:
                parts = sig.split(':', 1)
                name = parts[0].strip()
                attr_type = parts[1].strip()
            else:
                parts = sig.split()
                if len(parts) > 1:
                    name = parts[-1].strip()
                    attr_type = ' '.join(parts[:-1]).strip()
                    
            return ClassAttribute(
                visibility=visibility,
                name=name,
                type=attr_type,
                multiplicity=multiplicity,
                constraints=constraints,
                raw=sig
            )

        def parse_method_signature(sig):
            sig = sig.strip()
            constraints = []
            constraint_match = re.search(r'\{([^}]+)\}', sig)
            if constraint_match:
                constraints = [c.strip() for c in constraint_match.group(1).split(',')]
                sig = re.sub(r'\{([^}]+)\}', '', sig).strip()
                
            visibility = None
            vis_match = re.match(vis_pattern, sig)
            if vis_match:
                visibility = vis_match.group(1)
                sig = vis_match.group(2).strip()
                
            param_match = re.search(r'\(([^)]*)\)', sig)
            parameters = []
            method_name = sig
            return_type = None
            
            if param_match:
                param_text = param_match.group(1).strip()
                if param_text:
                    raw_params = param_text.split(',')
                    for rp in raw_params:
                        rp = rp.strip()
                        if ':' in rp:
                            p_parts = rp.split(':', 1)
                            parameters.append({"name": p_parts[0].strip(), "type": p_parts[1].strip()})
                        else:
                            p_parts = rp.split()
                            if len(p_parts) > 1:
                                parameters.append({"name": p_parts[-1].strip(), "type": ' '.join(p_parts[:-1]).strip()})
                            else:
                                parameters.append({"name": rp, "type": None})
                                
                left_part = sig[:param_match.start()].strip()
                right_part = sig[param_match.end():].strip()
                
                if right_part.startswith(':'):
                    return_type = right_part[1:].strip()
                    method_name = left_part
                elif right_part:
                    return_type = right_part
                    method_name = left_part
                else:
                    left_parts = left_part.split()
                    if len(left_parts) > 1:
                        method_name = left_parts[-1].strip()
                        return_type = ' '.join(left_parts[:-1]).strip()
                    else:
                        method_name = left_part
                        
            return ClassMethod(
                visibility=visibility,
                name=method_name,
                parameters=parameters,
                return_type=return_type,
                constraints=constraints,
                raw=sig
            )

        lines = mermaid_code.splitlines()
        for line in lines:
            line = re.sub(r'%%.*$', '', line).strip()
            if not line or line.lower() == "classdiagram":
                continue

            namespace_match = re.match(r'^namespace\s+([a-zA-Z0-9_\-]+)\s*\{', line, re.IGNORECASE)
            if namespace_match:
                ns_name = namespace_match.group(1)
                namespaces[ns_name] = ClassNamespace(name=ns_name, classes=[])
                block_stack.append({"type": "namespace", "name": ns_name})
                continue

            class_block_match = re.match(r'^class\s+([a-zA-Z0-9_\-.:]+)\s*\{', line, re.IGNORECASE)
            if class_block_match:
                cls_name = class_block_match.group(1)
                current_ns = next((b["name"] for b in reversed(block_stack) if b["type"] == "namespace"), None)
                classes[cls_name] = ClassInfo(name=cls_name, namespace=current_ns, attributes=[], methods=[])
                if current_ns:
                    namespaces[current_ns].classes.append(cls_name)
                block_stack.append({"type": "class", "name": cls_name})
                continue

            if line == "}":
                if block_stack:
                    block_stack.pop()
                continue

            class_decl_match = re.match(r'^class\s+([a-zA-Z0-9_\-.:]+)$', line, re.IGNORECASE)
            if class_decl_match:
                cls_name = class_decl_match.group(1)
                if cls_name not in classes:
                    current_ns = next((b["name"] for b in reversed(block_stack) if b["type"] == "namespace"), None)
                    classes[cls_name] = ClassInfo(name=cls_name, namespace=current_ns, attributes=[], methods=[])
                    if current_ns:
                        namespaces[current_ns].classes.append(cls_name)
                continue

            rel_match = re.match(
                r'^\s*([a-zA-Z0-9_\-.:]+)\s*(?:\"([^\"]*)\")?\s*' + rel_connectors + r'\s*(?:\"([^\"]*)\")?\s*([a-zA-Z0-9_\-.:]+)(?:\s*:\s*(.*))?$',
                line
            )
            if rel_match:
                from_cls = rel_match.group(1)
                from_mult = rel_match.group(2)
                rel_symbol = rel_match.group(3)
                to_mult = rel_match.group(4)
                to_cls = rel_match.group(5)
                label = rel_match.group(6)
                if label:
                    label = label.strip()

                for cls_name in (from_cls, to_cls):
                    if cls_name not in classes:
                        current_ns = next((b["name"] for b in reversed(block_stack) if b["type"] == "namespace"), None)
                        classes[cls_name] = ClassInfo(name=cls_name, namespace=current_ns, attributes=[], methods=[])
                        if current_ns:
                            namespaces[current_ns].classes.append(cls_name)

                rel_type = "association"
                direction = "none"
                if rel_symbol in ("*--", "--*", "*..", "..*"):
                    rel_type = "composition"
                elif rel_symbol in ("o--", "--o", "o..", "..o"):
                    rel_type = "aggregation"
                elif rel_symbol in ("<|--", "--|>", "<|..", "..|>"):
                    rel_type = "generalization"
                elif rel_symbol in ("-->", "<--", "..>", "<.."):
                    rel_type = "dependency"

                if rel_symbol in ("-->", "..>", "--|>", "..|>", "--*", "..*", "--o", "..o"):
                    direction = "forward"
                elif rel_symbol in ("<--", "<..", "<|--", "<|..", "*--", "*..", "o--", "o.."):
                    direction = "backward"

                relationships.append(ClassRelationship(
                    type=rel_type,
                    from_class=from_cls,
                    to_class=to_cls,
                    from_multiplicity=from_mult,
                    to_multiplicity=to_mult,
                    direction=direction,
                    label=label,
                    raw=line
                ))
                continue

            member_match = re.match(r'^([a-zA-Z0-9_\-.:]+)\s*:\s*(.*)$', line)
            if member_match:
                cls_name = member_match.group(1)
                member_sig = member_match.group(2).strip()

                if cls_name not in classes:
                    current_ns = next((b["name"] for b in reversed(block_stack) if b["type"] == "namespace"), None)
                    classes[cls_name] = ClassInfo(name=cls_name, namespace=current_ns, attributes=[], methods=[])
                    if current_ns:
                        namespaces[current_ns].classes.append(cls_name)

                if '(' in member_sig:
                    classes[cls_name].methods.append(parse_method_signature(member_sig))
                else:
                    classes[cls_name].attributes.append(parse_attribute_signature(member_sig))
                continue

            if block_stack and block_stack[-1]["type"] == "class":
                cls_name = block_stack[-1]["name"]
                if '(' in line:
                    classes[cls_name].methods.append(parse_method_signature(line))
                else:
                    classes[cls_name].attributes.append(parse_attribute_signature(line))

        return ParsedClassDiagram(classes=classes, relationships=relationships, namespaces=namespaces)


class MermaidSequenceDiagramParser(IParser):
    def can_parse(self, mermaid_code: str) -> bool:
        return "sequencediagram" in mermaid_code.strip().lower()

    def parse(self, mermaid_code: str) -> ParsedSequenceDiagram:
        lifelines = {}
        messages = []
        fragments = []
        fragment_stack = []

        def parse_lifeline_label(label):
            if not label:
                return None, None
            if ':' in label:
                parts = label.split(':', 1)
                return parts[0].strip(), parts[1].strip()
            return label.strip(), None

        def extract_guard(guard_str):
            guard_str = guard_str.strip()
            if guard_str.startswith('[') and guard_str.endswith(']'):
                return guard_str[1:-1].strip()
            return guard_str

        def parse_sequence_message_text(text, is_reply):
            text = text.strip()
            assignment = None
            operation_part = text
            
            if not is_reply:
                assign_match = re.match(r'^([a-zA-Z0-9_\-.]+)\s*(?:=|:=)\s*(.*)$', text)
                if assign_match:
                    assignment = assign_match.group(1).strip()
                    operation_part = assign_match.group(2).strip()
                    
            param_match = re.search(r'\(([^)]*)\)', operation_part)
            operation = operation_part
            parameters = []
            
            if param_match:
                operation = operation_part[:param_match.start()].strip()
                param_text = param_match.group(1).strip()
                if param_text:
                    raw_params = param_text.split(',')
                    for rp in raw_params:
                        rp = rp.strip()
                        if ':' in rp:
                            p_parts = rp.split(':', 1)
                            parameters.append({"name": p_parts[0].strip(), "type": p_parts[1].strip()})
                        else:
                            p_parts = rp.split()
                            if len(p_parts) > 1:
                                parameters.append({"name": p_parts[-1].strip(), "type": ' '.join(p_parts[:-1]).strip()})
                            else:
                                parameters.append({"name": rp, "type": None})
            else:
                if is_reply:
                    assignment = operation_part
                    operation = None
                    
            return {
                "operation": operation,
                "parameters": parameters,
                "assignment": assignment,
                "raw": text
            }

        lines = mermaid_code.splitlines()
        for line in lines:
            line = re.sub(r'%%.*$', '', line).strip()
            if not line or line.lower() == "sequencediagram":
                continue

            lifeline_match = re.match(
                r'^\s*(actor|participant)\s+([a-zA-Z0-9_\-.:]+)(?:\s+as\s+(?:\"([^\"]*)\"|([^\s]+)))?$',
                line,
                re.IGNORECASE
            )
            if lifeline_match:
                role = lifeline_match.group(1).lower()
                alias = lifeline_match.group(2)
                label = lifeline_match.group(3) if lifeline_match.group(3) is not None else lifeline_match.group(4)
                
                if not label:
                    label = alias
                    
                inst_name, class_name = parse_lifeline_label(label)
                if not inst_name:
                    inst_name = alias
                    
                lifelines[alias] = SequenceLifeline(
                    name=alias,
                    role=role,
                    instance_name=inst_name,
                    classifier_name=class_name,
                    label=label
                )
                continue

            frag_start_match = re.match(r'^\s*(alt|loop|opt|par|critical)\s*(.*)$', line, re.IGNORECASE)
            if frag_start_match:
                frag_type = frag_start_match.group(1).lower()
                guard = extract_guard(frag_start_match.group(2))
                
                branch = SequenceFragmentBranch(guard=guard, messages=[])
                frag_node = SequenceFragment(
                    type=frag_type,
                    branches=[branch],
                    nested=[]
                )
                
                if fragment_stack:
                    fragment_stack[-1].nested.append(frag_node)
                else:
                    fragments.append(frag_node)
                    
                fragment_stack.append(frag_node)
                continue

            frag_branch_match = re.match(r'^\s*(else|option)\s*(.*)$', line, re.IGNORECASE)
            if frag_branch_match:
                guard = extract_guard(frag_branch_match.group(2))
                if fragment_stack:
                    parent_frag = fragment_stack[-1]
                    branch = SequenceFragmentBranch(guard=guard, messages=[])
                    parent_frag.branches.append(branch)
                continue

            if line.lower() == "end":
                if fragment_stack:
                    fragment_stack.pop()
                continue

            msg_match = re.match(
                r'^\s*([a-zA-Z0-9_.:]+(?:-[a-zA-Z0-9_.:]+)*)\s*(-->>|->>|-->|->|--x|-x)([+-]?)\s*([a-zA-Z0-9_.:]+(?:-[a-zA-Z0-9_.:]+)*)([+-]?)\s*:\s*(.*)$',
                line
            )
            if msg_match:
                sender = msg_match.group(1)
                arrow = msg_match.group(2)
                act1 = msg_match.group(3)
                receiver = msg_match.group(4)
                act2 = msg_match.group(5)
                msg_text = msg_match.group(6).strip()

                for participant in (sender, receiver):
                    if participant not in lifelines:
                        lifelines[participant] = SequenceLifeline(
                            name=participant,
                            role="participant",
                            instance_name=participant,
                            classifier_name=None,
                            label=participant
                        )

                is_reply = arrow in ("-->", "-->>")
                msg_details = parse_sequence_message_text(msg_text, is_reply)
                
                arrow_type = "other"
                if arrow == "->>":
                    arrow_type = "sync"
                elif arrow == "->":
                    arrow_type = "async"
                elif arrow in ("-->", "-->>"):
                    arrow_type = "reply"

                msg_record = SequenceMessage(
                    sender=sender,
                    receiver=receiver,
                    arrow=arrow,
                    arrow_type=arrow_type,
                    activation=(act1 or act2 or None),
                    operation=msg_details["operation"],
                    parameters=msg_details["parameters"],
                    assignment=msg_details["assignment"],
                    raw=line,
                    fragment_context=[
                        {
                            "type": f.type,
                            "guard": f.branches[-1].guard
                        } for f in fragment_stack
                    ]
                )
                
                messages.append(msg_record)
                if fragment_stack:
                    fragment_stack[-1].branches[-1].messages.append(msg_record)
                continue

        return ParsedSequenceDiagram(lifelines=lifelines, messages=messages, fragments=fragments)
