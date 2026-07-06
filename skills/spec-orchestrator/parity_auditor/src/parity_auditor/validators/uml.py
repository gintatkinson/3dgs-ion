"""
Validator that enforces UML diagram compliance across feature, epic,
user-story, and use-case specification files.

Verifies class-diagram syntax, forbidden diagram types, required sections,
sequence-diagram lifeline/method alignment with global class definitions,
use-case diagram structural rules, and epic checklist formatting.
"""

import os
import re
from typing import List, Dict, Any, Set
from .base import IValidator
from ..core.workspace import WorkspaceRepository
from ..core.models import FeatureFile
from ..parsers.mermaid import MermaidClassDiagramParser, MermaidFlowchartParser, MermaidSequenceDiagramParser

class UmlValidator(IValidator):
    def validate(self, repo: WorkspaceRepository, **kwargs) -> List[str]:
        global_classes = kwargs.get("global_classes")
        
        rules = repo.get_codebase_rules()
        val_rules = rules.validation_rules
        backlog_dirs = rules.backlog_directories
        
        features_dir = os.path.join(repo.workspace_dir, backlog_dirs.features)
        user_stories_dir = os.path.join(repo.workspace_dir, backlog_dirs.user_stories)
        use_cases_dir = os.path.join(repo.workspace_dir, backlog_dirs.use_cases)
        epics_dir = os.path.join(repo.workspace_dir, backlog_dirs.epics)
        
        errors = []
        
        def get_md_files(d):
            if not os.path.exists(d):
                return []
            return [os.path.join(d, f) for f in os.listdir(d) if f.endswith(".md")]
            
        if global_classes is None:
            global_classes = self.build_global_classes(repo, features_dir, epics_dir)
            
        dotted_link_pattern = val_rules.mermaid_dotted_link_regex
        forbidden_diagram_types = val_rules.forbidden_diagram_types
        required_sections = val_rules.required_sections
        required_diagrams = val_rules.required_diagrams
        
        uml_primitives = set(val_rules.uml_primitives)
        visibility_prefixes = set(val_rules.visibility_prefixes)
        relationship_connectors = val_rules.relationship_connectors
        choice_stereotypes = val_rules.choice_stereotypes
        multiplicity_regex = val_rules.multiplicity_regex
        essential_feature_sections = val_rules.essential_feature_sections
        
        test_data_shape_regex = val_rules.test_data_shape_regex
        test_data_block_regex = val_rules.test_data_block_regex
        bdd_scenario_regexes = val_rules.bdd_scenario_regexes
        required_features_matrix_regex = val_rules.required_features_matrix_regex
        checkbox_syntax_regex = val_rules.checkbox_syntax_regex
        use_case_alternate_flows_header = val_rules.use_case_alternate_flows_header
        use_case_numbered_step_regex = val_rules.use_case_numbered_step_regex
        use_case_flow_list_regex = val_rules.use_case_flow_list_regex
        realization_matrix_header = val_rules.realization_matrix_header
        realization_stories_header = val_rules.realization_stories_header
        realization_features_header = val_rules.realization_features_header
        
        class_parser = MermaidClassDiagramParser(repo)
        flowchart_parser = MermaidFlowchartParser()
        sequence_parser = MermaidSequenceDiagramParser()
        
        feature_files = get_md_files(features_dir)
        for filepath in feature_files:
            filename = os.path.basename(filepath)
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception as e:
                errors.append(f"System Error: Failed to read feature file '{filename}': {e}")
                continue
                
            self._validate_subagent_isolation(content, "Feature", filename, errors)
            self._validate_placeholders_and_links(content, "Feature", filename, errors, checkbox_syntax_regex)
                
            if re.search(dotted_link_pattern, content):
                errors.append(f"Feature {filename} contains invalid Mermaid dotted link label syntax. Use standard label formatting.")
                
            mermaid_blocks = re.findall(r'```mermaid\s*\n(.*?)```', content, re.DOTALL)
            mermaid_content = "\n".join(mermaid_blocks)
            for ftype in forbidden_diagram_types:
                if re.search(ftype, mermaid_content):
                    errors.append(f"Feature {filename} contains forbidden '{ftype}' diagram type.")
                    
            interface_type = "ui"
            frontmatter_match = re.match(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL)
            if frontmatter_match:
                frontmatter_text = frontmatter_match.group(1)
                for fm_line in frontmatter_text.splitlines():
                    if ":" in fm_line:
                        fm_parts = fm_line.split(":", 1)
                        fm_key = fm_parts[0].strip()
                        fm_val = fm_parts[1].strip().strip('"').strip("'")
                        if fm_key in ("interface_type", "interface-type"):
                            interface_type = fm_val.lower()
                            
            req_key = f"feature_{interface_type}"
            required_feature_sections = required_sections.get(req_key)
            if required_feature_sections is None:
                required_feature_sections = required_sections.get("feature")
            if required_feature_sections is None:
                errors.append(f"System Error: Missing '{req_key}' or 'feature' required sections config.")
                continue
                
            has_essential_sections = True
            for pattern, header_name in required_feature_sections:
                if not re.search(pattern, content, re.IGNORECASE):
                    errors.append(f"Feature {filename} is missing section '{header_name}'.")
                    if any(essential in header_name for essential in essential_feature_sections):
                        has_essential_sections = False
                        
            if not has_essential_sections:
                continue
                
            feature_req_diagrams = required_diagrams.get("feature")
            if feature_req_diagrams is None:
                errors.append("System Error: Missing required_diagrams.feature config.")
                continue
                
            has_diag_error = False
            for diag_type in feature_req_diagrams:
                if not re.search(r"```mermaid\s*\n\s*" + diag_type, content):
                    errors.append(f"Feature {filename} is missing a valid diagram of type '{diag_type}'.")
                    has_diag_error = True
            if has_diag_error:
                continue
                
            self._validate_class_diagram(
                "Feature", filename, content, errors, class_parser, val_rules,
                uml_primitives, visibility_prefixes, relationship_connectors,
                choice_stereotypes, multiplicity_regex
            )
                        
            if re.search(test_data_shape_regex, content, re.IGNORECASE):
                if not re.search(test_data_shape_regex + r".*?" + test_data_block_regex, content, re.DOTALL | re.IGNORECASE):
                    errors.append(f"Feature {filename} is missing a payload example ({test_data_block_regex} block) under Test Data Shape.")
                    
        story_files = get_md_files(user_stories_dir)
        for filepath in story_files:
            filename = os.path.basename(filepath)
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception as e:
                errors.append(f"System Error: Failed to read user story file '{filename}': {e}")
                continue
                
            self._validate_subagent_isolation(content, "User Story", filename, errors)
            self._validate_placeholders_and_links(content, "User Story", filename, errors, checkbox_syntax_regex)
                
            if re.search(dotted_link_pattern, content):
                errors.append(f"User Story {filename} contains invalid Mermaid dotted link label syntax. Use standard label formatting.")
                
            mermaid_blocks = re.findall(r'```mermaid\s*\n(.*?)```', content, re.DOTALL)
            mermaid_content = "\n".join(mermaid_blocks)
            for ftype in forbidden_diagram_types:
                if re.search(ftype, mermaid_content):
                    errors.append(f"User Story {filename} contains forbidden '{ftype}' diagram type.")
                    
            required_story_sections = required_sections.get("user_story")
            if required_story_sections is None:
                errors.append("System Error: Missing required_sections.user_story config.")
                continue
                
            has_essential_sections = True
            for pattern, header_name in required_story_sections:
                if not re.search(pattern, content, re.IGNORECASE):
                    errors.append(f"User Story {filename} is missing section '{header_name}'.")
                    if "Sequence Diagram" in header_name:
                        has_essential_sections = False
                        
            if not has_essential_sections:
                continue
                
            story_req_diagrams = required_diagrams.get("user_story")
            if story_req_diagrams is None:
                errors.append("System Error: Missing required_diagrams.user_story config.")
                continue
                
            has_seq = False
            seq_diagram_matches = []
            for diag_type in story_req_diagrams:
                for match in re.finditer(r"```mermaid\s*\n\s*" + diag_type + r"(.*?)(?=```|\Z)", content, re.DOTALL):
                    has_seq = True
                    seq_diagram_matches.append(match)
                    
            for seq_match in seq_diagram_matches:
                seq_code = seq_match.group(0)
                parsed = sequence_parser.parse(seq_code)
                lifelines = parsed.lifelines
                messages = parsed.messages
                
                for alias, lf in lifelines.items():
                    label = lf.label
                    if not lf.classifier_name:
                        errors.append(f"User Story {filename} sequence diagram lifeline '{alias}' is missing the name : Classifier pattern in its label: '{label}'")
                    else:
                        cls_name = lf.classifier_name
                        if cls_name not in global_classes:
                            errors.append(f"User Story {filename} sequence diagram lifeline '{alias}' specifies classifier '{cls_name}' which is not defined in any feature class diagram.")
                            
                for msg in messages:
                    if msg.arrow_type in ("sync", "async"):
                        op_name = msg.operation
                        if not op_name:
                            errors.append(f"User Story {filename} sequence diagram message '{msg.raw}' is missing an operation signature.")
                            continue
                        receiver = msg.receiver
                        rx_lf = lifelines.get(receiver)
                        rx_cls = rx_lf.classifier_name if rx_lf else None
                        if rx_cls:
                            if rx_cls in global_classes:
                                cls_methods = global_classes[rx_cls]["methods"]
                                method_found = None
                                for m in cls_methods:
                                    if m["name"] == op_name:
                                        method_found = m
                                        break
                                if not method_found:
                                    errors.append(f"User Story {filename} sequence diagram message '{msg.raw}' calls operation '{op_name}' which is not defined on class '{rx_cls}' in any class diagram.")
                                elif method_found["visibility"] != "+":
                                    errors.append(f"User Story {filename} sequence diagram message '{msg.raw}' calls non-public operation '{op_name}' on class '{rx_cls}' (visibility must be '+').")
                                    
                    if msg.arrow_type == "reply":
                        sequence_replies = val_rules.sequence_replies
                        if msg.arrow not in sequence_replies:
                            errors.append(f"User Story {filename} sequence diagram return message '{msg.raw}' uses invalid reply arrow '{msg.arrow}'. Return arrows must strictly use standard open arrowhead {', '.join(sequence_replies)}.")
                            
                        raw_msg_text = msg.raw.split(":", 1)[1].strip() if ":" in msg.raw else msg.raw
                        if "(" in raw_msg_text or ")" in raw_msg_text:
                            errors.append(f"User Story {filename} sequence diagram return message '{msg.raw}' looks like an operation call (contains parentheses). Return messages must be simple assignments or return values (e.g. status : Status).")
                            
                for line in seq_code.splitlines():
                    line_clean = line.strip()
                    line_clean = re.sub(r'%%.*$', '', line_clean).strip()
                    if not line_clean:
                        continue
                    fragment_keywords = val_rules.fragment_keywords
                    frag_pattern = r'^\s*(' + '|'.join(re.escape(k) for k in fragment_keywords) + r')(?:\s+(.*))?$'
                    frag_match = re.match(frag_pattern, line_clean, re.IGNORECASE)
                    if frag_match:
                        keyword = frag_match.group(1).lower()
                        guard_part = frag_match.group(2)
                        if guard_part:
                            guard_part = guard_part.strip()
                            if guard_part and not (guard_part.startswith('[') and guard_part.endswith(']')):
                                errors.append(f"User Story {filename} sequence diagram contains a combined fragment '{keyword}' with guard '{guard_part}' that is not enclosed in square brackets [].")
                                
            if not has_seq:
                errors.append(f"User Story {filename} is missing a required diagram matching pattern(s): {', '.join(story_req_diagrams)}")
                
            bdd_scenario_present = any(re.search(pat, content, re.DOTALL | re.IGNORECASE) for pat in bdd_scenario_regexes)
            if not bdd_scenario_present:
                errors.append(f"User Story {filename} must contain a valid BDD scenario (Given-When-Then or As a/I want to/So that).")
                
            rf_match = re.search(required_features_matrix_regex, content, re.DOTALL | re.IGNORECASE)
            if not rf_match:
                errors.append(f"User Story {filename} is missing '## Required Features Matrix' section.")
            else:
                rf_section = rf_match.group(1)
                checkboxes = re.findall(checkbox_syntax_regex, rf_section)
                if not checkboxes:
                    errors.append(f"User Story {filename} must have at least one feature reference checklist item in its Required Features Matrix.")
                for cb in checkboxes:
                    url_match = re.search(r"\]\((https?://[^)]+)\)", cb)
                    if not url_match:
                        errors.append(f"User Story {filename} contains a checklist item with a missing or non-absolute URL: '{cb.strip()}'.")
                    else:
                        link = url_match.group(1)
                        if not re.match(r"^https?://[a-zA-Z0-9.-]+/", link):
                            errors.append(f"User Story {filename} contains a non-absolute/invalid URL in Required Features Matrix: '{link}'.")
                            
                    justification_match = re.search(r"\s+\(([^)]+)\)$", cb)
                    if not justification_match or (url_match and justification_match.group(1) == url_match.group(1)):
                        errors.append(f"User Story {filename} contains a checklist item with a missing or invalid parenthetical semantic justification at the end: '{cb.strip()}'.")
                        
        usecase_files = get_md_files(use_cases_dir)
        use_case_naming = val_rules.naming_conventions.get("use_case", r"^uc-\d{2}-[a-z0-9\-]+\.md$")
        for filepath in usecase_files:
            basename = os.path.basename(filepath)
            
            if not re.match(use_case_naming, basename):
                errors.append(f"Use Case file '{basename}' does not follow the naming convention '{use_case_naming}'.")
                
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception as e:
                errors.append(f"System Error: Failed to read use case file '{basename}': {e}")
                continue
                
            self._validate_subagent_isolation(content, "Use Case", basename, errors)
            self._validate_placeholders_and_links(content, "Use Case", basename, errors, checkbox_syntax_regex)
                
            if re.search(dotted_link_pattern, content):
                errors.append(f"Use Case {basename} contains invalid Mermaid dotted link label syntax. Use standard label formatting.")
                
            mermaid_blocks = re.findall(r'```mermaid\s*\n(.*?)```', content, re.DOTALL)
            mermaid_content = "\n".join(mermaid_blocks)
            for ftype in forbidden_diagram_types:
                if re.search(ftype, mermaid_content):
                    errors.append(f"Use Case {basename} contains forbidden '{ftype}' diagram type.")
                    
            required_usecase_sections = required_sections.get("use_case")
            if required_usecase_sections is None:
                errors.append("System Error: Missing required_sections.use_case config.")
                continue
                
            has_essential_sections = True
            for pattern, header_name in required_usecase_sections:
                if not re.search(pattern, content, re.IGNORECASE):
                    errors.append(f"Use Case {basename} is missing section '{header_name}'.")
                    if "Diagrams" in header_name:
                        has_essential_sections = False
                        
            if not has_essential_sections:
                continue
                
            usecase_req_diagrams = required_diagrams.get("use_case")
            if usecase_req_diagrams is None:
                errors.append("System Error: Missing required_diagrams.use_case config.")
                continue
                
            for diag_type in usecase_req_diagrams:
                diag_matches = list(re.finditer(r"```mermaid\s*\n\s*" + diag_type + r"(.*?)(?=```|\Z)", content, re.DOTALL))
                if not diag_matches:
                    errors.append(f"Use Case {basename} is missing a valid diagram matching pattern '{diag_type}'.")
                elif "graph" in diag_type or "flowchart" in diag_type:
                    for match in diag_matches:
                        diagram_code = match.group(0)
                        parsed = flowchart_parser.parse(diagram_code)
                        
                        boundary_sub = None
                        for sub_id, sub_info in parsed.subgraphs.items():
                            if "boundary" in sub_id.lower() or "system" in sub_id.lower() or \
                               (sub_info.label and ("boundary" in sub_info.label.lower() or "system" in sub_info.label.lower())):
                                boundary_sub = sub_info
                                break
                                
                        if not boundary_sub:
                            errors.append(f"Use Case {basename} is missing a system boundary subgraph (e.g. ID or label containing 'boundary' or 'system').")
                            continue
                            
                        boundary_sub_id = boundary_sub.id
                        
                        def is_actor_node(node):
                            if not node:
                                return False
                            return (node.shape == "circle") or \
                                   ("actor" in node.id.lower()) or \
                                   (node.label and "actor" in node.label.lower())
                                   
                        for node_id, node in parsed.nodes.items():
                            is_actor = is_actor_node(node)
                            if is_actor:
                                if node.subgraph is not None:
                                    errors.append(f"Use Case {basename} actor node '{node_id}' must be placed outside the system boundary subgraph (found in subgraph '{node.subgraph}').")
                            else:
                                if node.subgraph != boundary_sub_id:
                                    errors.append(f"Use Case {basename} use case node '{node_id}' must be defined inside the system boundary subgraph '{boundary_sub_id}'.")
                                    
                                if val_rules.use_case_stadium_nodes_only:
                                    if node.shape != "stadium":
                                        errors.append(f"Use Case {basename} use case node '{node_id}' must use the Mermaid stadium/oval shape ('stadium').")
                                        
                        for conn in parsed.connections:
                            src_id = conn.from_node
                            tgt_id = conn.to_node
                            src_node = parsed.nodes.get(src_id)
                            tgt_node = parsed.nodes.get(tgt_id)
                            
                            src_is_actor = is_actor_node(src_node)
                            tgt_is_actor = is_actor_node(tgt_node)
                            
                            if val_rules.use_case_undirected_actor_links_only:
                                if (src_is_actor and not tgt_is_actor) or (not src_is_actor and tgt_is_actor):
                                    if "arrow" in conn.style:
                                        errors.append(f"Use Case {basename} connection from '{src_id}' to '{tgt_id}' between Actor and Use Case must use an undirected link, not '{conn.style}'.")
                                        
                            if val_rules.use_case_extend_arrow_direction_check:
                                if conn.label and "extend" in conn.label.lower():
                                    src_has_ext = "extend" in src_id.lower() or "ext" in src_id.lower() or (src_node and src_node.label and ("extend" in src_node.label.lower() or "ext" in src_node.label.lower()))
                                    tgt_has_ext = "extend" in tgt_id.lower() or "ext" in tgt_id.lower() or (tgt_node and tgt_node.label and ("extend" in tgt_node.label.lower() or "ext" in tgt_node.label.lower()))
                                    if tgt_has_ext and not src_has_ext:
                                        errors.append(f"Use Case {basename} extend arrow from '{src_id}' to '{tgt_id}' is reversed. Extend arrows must point from the extending Use Case (client) to the base Use Case (supplier).")
                                        
            flows_block_match = re.search(re.escape(use_case_alternate_flows_header) + r"(.*?)(?=##\s+6\.\s+Postconditions|\Z)", content, re.DOTALL | re.IGNORECASE)
            if flows_block_match:
                flows_block = flows_block_match.group(1)
                # Parse flows using configured regex
                flows = re.findall(use_case_flow_list_regex, flows_block, re.DOTALL)
                use_case_flow_limit = val_rules.use_case_flow_limit
                use_case_step_limit = val_rules.use_case_step_limit
                
                # Count validation/negative constraints across referenced features
                total_constraints = 0
                features_section_match = re.search(r"###\s+Required\s+Features(.*?)(?=###\s+Required\s+User\s+Stories|##\s+Source\s+References|\Z)", content, re.DOTALL | re.IGNORECASE)
                if features_section_match:
                    feature_checkboxes = re.findall(r"(?:-|\*)\s+\[[ xX]\]\s+.*", features_section_match.group(1))
                    
                    def norm_t(t):
                        if not t: return ""
                        t = t.strip().strip("\"'\u201c\u201d")
                        t = re.sub(r"^(epic|feature|feat|user[- ]story|use[- ]case|us|uc)[s]?(?:[- ]*\d+\s*[:\-]?|:)\s*", "", t, flags=re.IGNORECASE)
                        t = t.replace("-", " ")
                        t = re.sub(r"[^\w\s]", "", t)
                        return " ".join(t.split()).lower()

                    def ext_t(c):
                        tm = re.search(r"^title:\s*(['\"]?)(.*?)\1\s*$", c, re.MULTILINE)
                        if tm: return tm.group(2).strip()
                        hm = re.search(r"^#\s+(.*?)$", c, re.MULTILINE)
                        if hm: return hm.group(1).strip()
                        return None

                    features_dir = kwargs.get("features_dir")
                    if not features_dir:
                        features_dir = os.path.join(repo.workspace_dir, backlog_dirs.features)
                    
                    title_to_feature_path = {}
                    try:
                        for f_file in repo.get_feature_files(features_dir):
                            title_to_feature_path[f_file.filename.lower()] = os.path.join(features_dir, f_file.filename)
                            f_title = ext_t(f_file.content)
                            if f_title:
                                title_to_feature_path[norm_t(f_title)] = os.path.join(features_dir, f_file.filename)
                    except Exception as e:
                        print(f"Warning: Failed to scan features directory: {e}")

                    for cb in feature_checkboxes:
                        feat_path = None
                        feat_file_match = re.search(r"/(feat-\d{2,}-[a-z0-9\-]+\.md)", cb)
                        if feat_file_match:
                            feat_filename = feat_file_match.group(1)
                            feat_path = os.path.join(features_dir, feat_filename)
                            if not os.path.exists(feat_path):
                                # fallback: search recursively
                                for root, _, files in os.walk(repo.workspace_dir):
                                    if feat_filename in files:
                                        feat_path = os.path.join(root, feat_filename)
                                        break
                        else:
                            # Try matching by link text (Feature Title)
                            link_text_match = re.search(r"\[([^\]]+)\]\((?:https?://[^)]+)\)", cb)
                            if link_text_match:
                                feat_path = title_to_feature_path.get(norm_t(link_text_match.group(1)))
                        
                        if feat_path and os.path.exists(feat_path):
                            try:
                                with open(feat_path, "r", encoding="utf-8") as f:
                                    feat_content = f.read()
                                constraints_match = re.search(r"###\s+(?:\d+\.\s+)?Validation\s+&\s+Constraints(.*?)(?=###|##|\Z)", feat_content, re.DOTALL | re.IGNORECASE)
                                if constraints_match:
                                    constraints_block = constraints_match.group(1)
                                    constraints = re.findall(r"^\s*[-*+]\s+\S+", constraints_block, re.MULTILINE)
                                    total_constraints += len(constraints)
                            except Exception as e:
                                print(f"Warning: Failed to parse feature constraints for {feat_path}: {e}")
                
                required_flow_count = max(use_case_flow_limit, total_constraints)
                if len(flows) < required_flow_count:
                    errors.append(f"Use Case {basename} must contain at least {required_flow_count} detailed Alternate/Exception flows. Found only {len(flows)} flows. (Referenced features define {total_constraints} schema validation constraints, requiring at least that many alternate flows, with a minimum floor of {use_case_flow_limit}.)")
                else:
                    for idx, flow in enumerate(flows):
                        steps = re.findall(use_case_numbered_step_regex, flow)
                        if len(steps) < use_case_step_limit:
                            errors.append(f"Use Case {basename} alternate flow {idx+1} is too thin (must contain at least {use_case_step_limit} numbered steps).")
            else:
                errors.append(f"Use Case {basename} is missing '{use_case_alternate_flows_header}' content block.")
                
            if re.search(realization_matrix_header, content, re.IGNORECASE):
                if not re.search(realization_stories_header, content, re.IGNORECASE):
                    errors.append(f"Use Case {basename} is missing '{realization_stories_header}' under Realization Matrix.")
                if not re.search(realization_features_header, content, re.IGNORECASE):
                    errors.append(f"Use Case {basename} is missing '### Required Features' under Realization Matrix.")
                    
                stories_section_match = re.search(r"###\s+Required\s+User\s+Stories(.*?)(?=###\s+Required\s+Features|##\s+Source\s+References|\Z)", content, re.DOTALL | re.IGNORECASE)
                features_section_match = re.search(r"###\s+Required\s+Features(.*?)(?=###\s+Required\s+User\s+Stories|##\s+Source\s+References|\Z)", content, re.DOTALL | re.IGNORECASE)
                
                story_checkboxes = []
                if stories_section_match:
                    story_checkboxes = re.findall(r"-\s+\[[ xX]\]\s+.*", stories_section_match.group(1))
                    
                feature_checkboxes = []
                if features_section_match:
                    feature_checkboxes = re.findall(r"-\s+\[[ xX]\]\s+.*", features_section_match.group(1))
                    
                if not story_checkboxes:
                    errors.append(f"Use Case {basename} Realization Matrix contains no User Story checkboxes under '### Required User Stories'.")
                if not feature_checkboxes:
                    errors.append(f"Use Case {basename} Realization Matrix contains no Feature checkboxes under '### Required Features'.")
                    
                all_checkboxes = story_checkboxes + feature_checkboxes
                for cb in all_checkboxes:
                    url_match = re.search(r"\]\((https?://[^)]+)\)", cb)
                    if not url_match:
                        errors.append(f"Use Case {basename} contains a checklist item with a missing or non-absolute markdown link URL: '{cb.strip()}'.")
                    else:
                        url_str = url_match.group(1)
                        if not re.match(r"^https?://[a-zA-Z0-9.-]+/", url_str):
                            errors.append(f"Use Case {basename} contains an invalid URL in realization matrix: '{url_str}'.")
                            
                    justification_match = re.search(r"\s+\(([^)]+)\)$", cb)
                    if not justification_match or (url_match and justification_match.group(1) == url_match.group(1)):
                        errors.append(f"Use Case {basename} contains a checklist item with a missing or invalid parenthetical semantic justification at the end: '{cb.strip()}'.")
                        
        epic_files = get_md_files(epics_dir)
        for filepath in epic_files:
            filename = os.path.basename(filepath)
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception as e:
                errors.append(f"System Error: Failed to read epic file '{filename}': {e}")
                continue
                
            self._validate_subagent_isolation(content, "Epic", filename, errors)
            self._validate_placeholders_and_links(content, "Epic", filename, errors, checkbox_syntax_regex)
                
            if re.search(dotted_link_pattern, content):
                errors.append(f"Epic {filename} contains invalid Mermaid dotted link label syntax. Use standard label formatting.")
                
            mermaid_blocks = re.findall(r'```mermaid\s*\n(.*?)```', content, re.DOTALL)
            mermaid_content = "\n".join(mermaid_blocks)
            for ftype in forbidden_diagram_types:
                if re.search(ftype, mermaid_content):
                    errors.append(f"Epic {filename} contains forbidden '{ftype}' diagram type.")
                    
            required_epic_sections = required_sections.get("epic")
            if required_epic_sections is None:
                errors.append("System Error: Missing required_sections.epic config.")
                continue
            for pattern, header_name in required_epic_sections:
                if not re.search(pattern, content, re.IGNORECASE):
                    errors.append(f"Epic {filename} is missing section '{header_name}'.")
                    
            epic_req_diagrams = required_diagrams.get("epic")
            if epic_req_diagrams is None:
                errors.append("System Error: Missing required_diagrams.epic config.")
                continue
            for diag_type in epic_req_diagrams:
                if not re.search(r"```mermaid\s*\n\s*" + diag_type, content):
                    errors.append(f"Epic {filename} is missing a valid diagram of type '{diag_type}'.")
                elif diag_type == "classDiagram":
                    self._validate_class_diagram(
                        "Epic", filename, content, errors, class_parser, val_rules,
                        uml_primitives, visibility_prefixes, relationship_connectors,
                        choice_stereotypes, multiplicity_regex
                    )
                    
        return errors

    def _validate_subagent_isolation(self, content: str, doc_type: str, filename: str, errors: List[str]):
        frontmatter_match = re.match(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL)
        has_subagent_tag = False
        if frontmatter_match:
            frontmatter_text = frontmatter_match.group(1)
            for fm_line in frontmatter_text.splitlines():
                if ":" in fm_line:
                    fm_parts = fm_line.split(":", 1)
                    fm_key = fm_parts[0].strip().lower()
                    fm_val = fm_parts[1].strip().strip('"').strip("'").lower()
                    if fm_key in ("generation_mode", "generation-mode") and fm_val == "subagent":
                        has_subagent_tag = True
                        break
                    if fm_key in ("subagent_drafted", "subagent-drafted") and fm_val == "true":
                        has_subagent_tag = True
                        break
        if not has_subagent_tag:
            errors.append(f"{doc_type} {filename} violates the Item-Level Subagent Context Isolation mandate. Specifications must be drafted strictly inside a context-isolated subagent with 'generation_mode: subagent' in the frontmatter.")

    def _validate_placeholders_and_links(self, content: str, doc_type: str, filename: str, errors: List[str], checkbox_syntax_regex: str):
        if "IssueID" in content:
            errors.append(f"{doc_type} {filename} contains unresolved placeholder 'IssueID' or '#[IssueID]'.")
            
        if doc_type == "Epic":
            req_match = re.search(r"##\s+2\.\s+Requirements\s+&\s+Checklist(.*?)(?=##|\Z)", content, re.DOTALL | re.IGNORECASE)
            if req_match:
                req_section = req_match.group(1)
                checkboxes = re.findall(checkbox_syntax_regex, req_section)
                for cb in checkboxes:
                    if not re.search(r"\[[^\]]+\]\(https?://[^)]+\)", cb):
                        errors.append(f"Epic {filename} checklist item '{cb.strip()}' must be a valid markdown link pointing to the feature file absolute URL.")

    def _validate_class_diagram(self, doc_type: str, filename: str, content: str, errors: List[str], class_parser, val_rules, uml_primitives, visibility_prefixes, relationship_connectors, choice_stereotypes, multiplicity_regex):
        class_diagram_matches = re.finditer(r"```mermaid\s*\n\s*classDiagram(.*?)(?=```|\Z)", content, re.DOTALL)
        for match in class_diagram_matches:
            diagram_body = match.group(1)
            diagram_full = match.group(0)
            
            # Issue 17: Flag curly braces conflict
            for line_idx, line in enumerate(diagram_body.splitlines()):
                line_strip = line.strip()
                if not line_strip:
                    continue
                if "{" in line_strip or "}" in line_strip:
                    is_block_start = re.match(r'^(class|namespace)\s+[a-zA-Z0-9_\-.:]+\s*\{', line_strip, re.IGNORECASE)
                    is_block_end = (line_strip == "}")
                    if not is_block_start and not is_block_end:
                        errors.append(f"{doc_type} {filename} contains a syntax conflict in classDiagram on line {line_idx+1}: '{line_strip}'. Curly braces '{{}}' inside members/attributes are prohibited due to Mermaid parse errors. Use standard attribute notation or separate notes for constraints.")

            if not re.search(relationship_connectors, diagram_body):
                errors.append(f"{doc_type} {filename} contains a UML Class Diagram with no relationships. Isolated classes are prohibited; you must illustrate containment/inheritance/choice composition.")
                
            try:
                parsed_cd = class_parser.parse(diagram_full)
            except Exception as e:
                errors.append(f"{doc_type} {filename} contains an unparsable UML Class Diagram: {e}")
                continue
                
            classes = parsed_cd.classes
            relationships = parsed_cd.relationships
            
            adj = {c: set() for c in classes}
            for rel in relationships:
                u = rel.from_class
                v = rel.to_class
                if u not in adj:
                    adj[u] = set()
                if v not in adj:
                    adj[v] = set()
                adj[u].add(v)
                adj[v].add(u)
                
            for c, neighbors in adj.items():
                if len(neighbors) == 0:
                    errors.append(f"{doc_type} {filename} contains class '{c}' with zero relationships. Isolated classes are prohibited.")
                    
            if classes:
                start_node = next(iter(classes))
                visited = set()
                queue = [start_node]
                visited.add(start_node)
                while queue:
                    curr = queue.pop(0)
                    for neighbor in adj.get(curr, []):
                        if neighbor not in visited:
                            visited.add(neighbor)
                            queue.append(neighbor)
                unvisited = set(classes.keys()) - visited
                if unvisited:
                    errors.append(f"{doc_type} {filename} contains a disconnected UML Class Diagram. Classes {list(unvisited)} are not structurally connected to '{start_node}'.")
                    
            for cls_name, cls_info in classes.items():
                is_enum = any("<<enumeration>>" in (a.name or "") or "<<enumeration>>" in (a.raw or "") for a in cls_info.attributes)
                for attr in cls_info.attributes:
                    if attr.raw and "<<" in attr.raw and ">>" in attr.raw:
                        continue
                    if is_enum:
                        continue
                    attr_type = attr.type
                    if not attr_type:
                        errors.append(f"{doc_type} {filename} class '{cls_name}' attribute '{attr.name}' is missing a type.")
                        continue
                    if attr_type not in uml_primitives and attr_type not in classes:
                        errors.append(f"{doc_type} {filename} class '{cls_name}' attribute '{attr.name}' has invalid type '{attr_type}'. UML primitive types must be {', '.join(sorted(uml_primitives))} (case-sensitive), or reference another class.")
                        
            choice_classes = set()
            for line in diagram_full.splitlines():
                line_clean = line.strip()
                for st in choice_stereotypes:
                    st_esc = re.escape(st)
                    m1 = re.search(st_esc + r"\s*([a-zA-Z0-9_\-.:]+)", line_clean, re.IGNORECASE)
                    if m1:
                        choice_classes.add(m1.group(1))
                    m2 = re.search(r"class\s+([a-zA-Z0-9_\-.:]+)\s+.*" + st_esc, line_clean, re.IGNORECASE)
                    if m2:
                        choice_classes.add(m2.group(1))
            for cls_name, cls_info in classes.items():
                for st in choice_stereotypes:
                    if st in cls_name:
                        choice_classes.add(cls_name)
                    for attr in cls_info.attributes:
                        if attr.raw and st in attr.raw:
                            choice_classes.add(cls_name)
                            
            for choice_cls in choice_classes:
                has_subclass = False
                for rel in relationships:
                    if rel.type == "generalization":
                        is_parent = False
                        if rel.direction == "backward" and rel.from_class == choice_cls:
                            is_parent = True
                        elif rel.direction == "forward" and rel.to_class == choice_cls:
                            is_parent = True
                        if is_parent:
                            has_subclass = True
                            break
                if not has_subclass:
                    errors.append(f"{doc_type} {filename} choice class '{choice_cls}' must have at least one subclass inheriting from it via generalization (<|--).")
                    
            for cls_name, cls_info in classes.items():
                is_enum = any("<<enumeration>>" in (a.name or "") or "<<enumeration>>" in (a.raw or "") for a in cls_info.attributes)
                for attr in cls_info.attributes:
                    if attr.raw and "<<" in attr.raw and ">>" in attr.raw:
                        continue
                    if is_enum:
                        continue
                    if attr.visibility not in visibility_prefixes:
                        errors.append(f"{doc_type} {filename} class '{cls_name}' attribute '{attr.name}' is missing a valid UML visibility prefix ({', '.join(sorted(visibility_prefixes))}).")
                    if not attr.multiplicity:
                        errors.append(f"{doc_type} {filename} class '{cls_name}' attribute '{attr.name}' is missing a multiplicity (e.g. [1], [0..1], [0..*]).")
                        
                for method in cls_info.methods:
                    if method.visibility not in visibility_prefixes:
                        errors.append(f"{doc_type} {filename} class '{cls_name}' method '{method.name}' is missing a valid UML visibility prefix ({', '.join(sorted(visibility_prefixes))}).")
                    if not method.return_type or method.return_type.lower() in ("void", "none"):
                        continue
                    has_mult = False
                    if method.return_type and re.search(multiplicity_regex, method.return_type):
                        has_mult = True
                    elif re.search(r'\)\s*' + multiplicity_regex, method.raw) or re.search(multiplicity_regex + r'\s*$', method.raw):
                        has_mult = True
                    if not has_mult:
                        errors.append(f"{doc_type} {filename} class '{cls_name}' method '{method.name}' is missing a multiplicity (e.g. [1], [0..1], [0..*]) in its return signature.")
        
    def build_global_classes(self, repo: WorkspaceRepository, features_dir: str, epics_dir: str = None) -> Dict[str, Any]:
        """
        Build a global class dictionary from class diagrams in feature and epic files.

        Parses all feature spec files, then optionally epic spec files, merging
        their UML class diagrams into a single dictionary keyed by class name.
        Duplicate attributes and methods are skipped (first-writer wins).

        Args:
            repo: WorkspaceRepository for accessing feature files.
            features_dir: Path to the directory containing feature markdown files.
            epics_dir: Optional path to epic markdown files; when provided, class
                       diagrams from epic files are also merged.

        Returns:
            Dict mapping class names to dicts with keys ``name``, ``attributes``,
            and ``methods``.  Empty dict if no UML class diagrams are found.
        """
        global_classes = {}
        feature_files = repo.get_feature_files(features_dir)
        parser = MermaidClassDiagramParser(repo)
        for feat in feature_files:
            content = feat.content
            class_diagram_matches = re.finditer(r"```mermaid\s*\n\s*classDiagram(.*?)(?=```|\Z)", content, re.DOTALL)
            for match in class_diagram_matches:
                parsed_cd = parser.parse(match.group(0))
                for class_name, class_info in parsed_cd.classes.items():
                    if class_name not in global_classes:
                        global_classes[class_name] = {
                            "name": class_name,
                            "attributes": [],
                            "methods": []
                        }
                    existing_attrs = {a["name"] for a in global_classes[class_name]["attributes"]}
                    for attr in class_info.attributes:
                        if attr.name and "<<" in attr.name and ">>" in attr.name:
                            continue
                        if attr.name not in existing_attrs:
                            global_classes[class_name]["attributes"].append({
                                "name": attr.name,
                                "visibility": attr.visibility,
                                "type": attr.type,
                                "multiplicity": attr.multiplicity,
                                "constraints": attr.constraints,
                                "raw": attr.raw
                            })
                    existing_methods = {m["name"] for m in global_classes[class_name]["methods"]}
                    for method in class_info.methods:
                        if method.name not in existing_methods:
                            global_classes[class_name]["methods"].append({
                                "name": method.name,
                                "visibility": method.visibility,
                                "parameters": method.parameters,
                                "return_type": method.return_type,
                                "constraints": method.constraints,
                                "raw": method.raw
                            })
        if epics_dir and os.path.exists(epics_dir):
            epic_files = [os.path.join(epics_dir, f) for f in os.listdir(epics_dir) if f.endswith(".md")]
            for ep_path in epic_files:
                try:
                    with open(ep_path, "r", encoding="utf-8") as f:
                        content = f.read()
                except Exception:
                    continue
                class_diagram_matches = re.finditer(r"```mermaid\s*\n\s*classDiagram(.*?)(?=```|\Z)", content, re.DOTALL)
                for match in class_diagram_matches:
                    parsed_cd = parser.parse(match.group(0))
                    for class_name, class_info in parsed_cd.classes.items():
                        if class_name not in global_classes:
                            global_classes[class_name] = {
                                "name": class_name,
                                "attributes": [],
                                "methods": []
                            }
                        existing_attrs = {a["name"] for a in global_classes[class_name]["attributes"]}
                        for attr in class_info.attributes:
                            if attr.name and "<<" in attr.name and ">>" in attr.name:
                                continue
                            if attr.name not in existing_attrs:
                                global_classes[class_name]["attributes"].append({
                                    "name": attr.name,
                                    "visibility": attr.visibility,
                                    "type": attr.type,
                                    "multiplicity": attr.multiplicity,
                                    "constraints": attr.constraints,
                                    "raw": attr.raw
                                })
                        existing_methods = {m["name"] for m in global_classes[class_name]["methods"]}
                        for method in class_info.methods:
                            if method.name not in existing_methods:
                                global_classes[class_name]["methods"].append({
                                    "name": method.name,
                                    "visibility": method.visibility,
                                    "parameters": method.parameters,
                                    "return_type": method.return_type,
                                    "constraints": method.constraints,
                                    "raw": method.raw
                                })
        return global_classes
        
    def build_classes_from_features(self, matching_features: List[FeatureFile], repo: WorkspaceRepository) -> Dict[str, Any]:
        classes = {}
        parser = MermaidClassDiagramParser(repo)
        for feat in matching_features:
            content = feat.content
            class_diagram_matches = re.finditer(r"```mermaid\s*\n\s*classDiagram(.*?)(?=```|\Z)", content, re.DOTALL)
            for match in class_diagram_matches:
                parsed_cd = parser.parse(match.group(0))
                for class_name, class_info in parsed_cd.classes.items():
                    if class_name not in classes:
                        classes[class_name] = {
                            "name": class_name,
                            "attributes": [],
                            "methods": []
                        }
                    existing_attrs = {a["name"] for a in classes[class_name]["attributes"]}
                    for attr in class_info.attributes:
                        if attr.name not in existing_attrs:
                            classes[class_name]["attributes"].append({
                                "name": attr.name,
                                "visibility": attr.visibility,
                                "type": attr.type,
                                "multiplicity": attr.multiplicity,
                                "constraints": attr.constraints,
                                "raw": attr.raw
                            })
                    existing_methods = {m["name"] for m in classes[class_name]["methods"]}
                    for method in class_info.methods:
                        if method.name not in existing_methods:
                            classes[class_name]["methods"].append({
                                "name": method.name,
                                "visibility": method.visibility,
                                "parameters": method.parameters,
                                "return_type": method.return_type,
                                "constraints": method.constraints,
                                "raw": method.raw
                            })
        return classes
