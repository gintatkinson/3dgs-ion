from dataclasses import dataclass, field
from typing import List, Dict, Set, Optional, Tuple, Any

@dataclass
class MetaRules:
    version: str = "1.0.0"
    description: str = ""
    upstream_repository: str = ""
    troubleshooting_instruction: str = ""
    constitution_path: str = ""
    profiles_directory: str = ""
    walkthrough_directory: str = ""
    walkthrough_pattern: str = ""
    reconciliation_script_path: str = ""
    behavioral_triggers_path: str = ""

@dataclass
class BacklogDirectories:
    epics: str = "docs/epics"
    features: str = "docs/features"
    user_stories: str = "docs/user-stories"
    use_cases: str = "docs/use-cases"
    schemas: str = "schema"

@dataclass
class TargetDirectories:
    flutter: str = "app_flutter"

    @property
    def react(self) -> Optional[str]:
        return None

@dataclass
class FlutterRules:
    file_extensions: List[str] = field(default_factory=lambda: [".dart"])
    exclusions: List[str] = field(default_factory=lambda: ["build", ".dart_tool", ".git"])
    ui_directories: List[str] = field(default_factory=lambda: ["widgets", "screens"])
    network_directories: List[str] = field(default_factory=lambda: ["io"])
    selection_setters: List[str] = field(default_factory=lambda: ["set selected", "set active", "set selection", "setSelectedNode", "setActiveNode"])
    selection_triggers: List[str] = field(default_factory=lambda: ["onChanged", "onSelected", "notifyListeners", "dispatch"])
    loop_guard_keywords: List[str] = field(default_factory=lambda: ["userinitiated", "programmatic", "fromuser", "isuser", "userinteraction"])
    forbidden_words: List[str] = field(default_factory=list)
    forbidden_words_message: str = "UI widget/screen but references forbidden libraries directly. Calculations must run exclusively in a background Isolate."
    write_lock_keywords: List[str] = field(default_factory=lambda: ["writelock", "lockwrite", "sendlock", "mutationlock"])
    playhead_clamp_regex: List[str] = field(default_factory=lambda: ["0\\.9\\b", "1\\.1\\b"])
    ffi_keywords: List[str] = field(default_factory=lambda: ["dart:ffi"])
    ffi_finalizer_keywords: List[str] = field(default_factory=lambda: ["nativefinalizer"])
    ffi_refcount_keywords: List[str] = field(default_factory=lambda: ["refcount", "referencecount", "addref", "release", "finalizer"])
    viewport_file_patterns: List[str] = field(default_factory=lambda: ["viewport"])
    network_file_patterns: List[str] = field(default_factory=lambda: ["gateway", "socket", "client", "connection"])

@dataclass
class PythonRules:
    exclusions: List[str] = field(default_factory=lambda: ["node_modules", "build", "dist", "coverage", ".git", "skills", ".tessl-plugin"])
    scan_directories: Optional[List[str]] = None

@dataclass
class SpecRules:
    dom_leak_patterns: List[str] = field(default_factory=lambda: ["\\baria-\\w+", "\\brole=[\"']\\w+"])
    pixel_leak_patterns: List[str] = field(default_factory=lambda: ["\\b\\d+px\\b"])
    spec_files: List[str] = field(default_factory=lambda: [".pipeline/logical-ui/logical-components.md"])
    design_tokens_path: str = ".pipeline/logical-ui/design-tokens.json"
    forbidden_standards_blocklist: List[str] = field(default_factory=list)

@dataclass
class ValidationRules:
    uml_primitives: List[str] = field(default_factory=lambda: ["String", "Integer", "Real", "Boolean"])
    visibility_prefixes: List[str] = field(default_factory=lambda: ["+", "-", "#", "~"])
    playhead_rate_limits: List[float] = field(default_factory=lambda: [0.90, 1.10])
    relationship_connectors: str = "(\\*--|o--|<\\|--|--|-->)"
    choice_stereotypes: List[str] = field(default_factory=lambda: ["<<choice>>"])
    sequence_replies: List[str] = field(default_factory=lambda: ["-->", "-->>"])
    fragment_keywords: List[str] = field(default_factory=lambda: ["alt", "loop", "opt", "par", "critical", "else", "option"])
    use_case_flow_limit: int = 2
    use_case_step_limit: int = 2
    max_body_characters: int = 65536
    schema_exclude_keywords: List[str] = field(default_factory=lambda: ["description", "reference", "organization", "contact", "revision", "import", "prefix", "namespace", "yang-version"])
    multiplicity_regex: str = "\\[[^\\]]+\\]"
    essential_feature_sections: List[str] = field(default_factory=lambda: ["Class Diagram", "Interface Requirements"])
    required_diagrams: Dict[str, List[str]] = field(default_factory=lambda: {
        "epic": ["classDiagram", "stateDiagram-v2"],
        "feature": ["classDiagram"],
        "user_story": ["sequenceDiagram"],
        "use_case": ["(?:graph|flowchart)", "stateDiagram"]
    })
    mermaid_dotted_link_regex: str = "-\\.-*->\\s*\\|"
    forbidden_diagram_types: List[str] = field(default_factory=lambda: ["erDiagram"])
    use_case_stadium_nodes_only: bool = True
    use_case_undirected_actor_links_only: bool = True
    use_case_extend_arrow_direction_check: bool = True
    naming_conventions: Dict[str, str] = field(default_factory=lambda: {
        "use_case": "^uc-\\d{2}-[a-z0-9\\-]+\\.md$"
    })
    test_data_shape_regex: str = "###\\s+1\\.\\s+Test\\s+Data\\s+Shape"
    test_data_block_regex: str = "```json"
    bdd_scenario_regexes: List[str] = field(default_factory=lambda: [
        "(?:Given|When|Then)",
        "As a\\s+.*\\s+I want to\\s+.*\\s+so that\\s+.*"
    ])
    required_features_matrix_regex: str = "##\\s+Required\\s+Features(?:\\s+Matrix)?(.*?)(?=##|\\Z)"
    checkbox_syntax_regex: str = "-\\s+\\[[ xX]\\]\\s+.*"
    use_case_alternate_flows_header: str = "## 5. Alternate and Exception Flows"
    use_case_numbered_step_regex: str = "\\b\\d+\\.\\s+\\S+"
    use_case_flow_list_regex: str = "(?:-|\\*)\\s+\\*\\*\\d+[a-zA-Z]+\\..*?(?=(?:\\n\\s*(?:-|\\*)\\s+\\*\\*\\d+[a-zA-Z]+\\.)|\\Z)"
    realization_matrix_header: str = "## 8. Realization Matrix"
    realization_stories_header: str = "### Required User Stories"
    realization_features_header: str = "### Required Features"
    alternative_schema_extensions: List[str] = field(default_factory=lambda: [".yaml", ".yml", ".json", ".proto", ".asn", ".asn1", ".msg", ".srv", ".xsd"])
    schema_patterns: Dict[str, Any] = field(default_factory=dict)
    required_sections: Dict[str, List[List[str]]] = field(default_factory=lambda: {})

@dataclass
class CodebaseRules:
    meta: MetaRules = field(default_factory=MetaRules)
    tracker_rules: Dict[str, Any] = field(default_factory=dict)
    backlog_directories: BacklogDirectories = field(default_factory=BacklogDirectories)
    target_directories: TargetDirectories = field(default_factory=TargetDirectories)
    flutter_rules: FlutterRules = field(default_factory=FlutterRules)
    python_rules: PythonRules = field(default_factory=PythonRules)
    spec_rules: SpecRules = field(default_factory=SpecRules)
    validation_rules: ValidationRules = field(default_factory=ValidationRules)

    @property
    def react_rules(self) -> Any:
        class DummyReactRules:
            file_extensions = []
            exclusions = []
            ui_directories = []
            network_directories = []
            forbidden_words = []
            forbidden_words_message = ""
            write_lock_keywords = []
            selection_keywords = []
            interaction_keywords = []
            playhead_clamp_regex = []
            playhead_clamp_range = []
            ast_compliance_method = ""
            viewport_file_patterns = []
            network_file_patterns = []
        return DummyReactRules()

def load_from_dict(data: dict) -> CodebaseRules:
    meta_data = data.get("meta", {})
    meta = MetaRules(**{k: v for k, v in meta_data.items() if k in MetaRules.__dataclass_fields__})
    
    bd_data = data.get("backlog_directories", {})
    backlog_directories = BacklogDirectories(**{k: v for k, v in bd_data.items() if k in BacklogDirectories.__dataclass_fields__})
    
    td_data = data.get("target_directories", {})
    target_directories = TargetDirectories(**{k: v for k, v in td_data.items() if k in TargetDirectories.__dataclass_fields__})
    
    flutter_data = data.get("flutter_rules", {})
    flutter_rules = FlutterRules(**{k: v for k, v in flutter_data.items() if k in FlutterRules.__dataclass_fields__})
    
    py_data = data.get("python_rules", {})
    python_rules = PythonRules(**{k: v for k, v in py_data.items() if k in PythonRules.__dataclass_fields__})
    
    spec_data = data.get("spec_rules", {})
    spec_rules = SpecRules(**{k: v for k, v in spec_data.items() if k in SpecRules.__dataclass_fields__})
    
    val_data = data.get("validation_rules", {})
    validation_rules = ValidationRules(**{k: v for k, v in val_data.items() if k in ValidationRules.__dataclass_fields__})
    
    return CodebaseRules(
        meta=meta,
        tracker_rules=data.get("tracker_rules", {}),
        backlog_directories=backlog_directories,
        target_directories=target_directories,
        flutter_rules=flutter_rules,
        python_rules=python_rules,
        spec_rules=spec_rules,
        validation_rules=validation_rules
    )

# Parsed Diagram Models
@dataclass
class FlowchartNode:
    id: str
    shape: Optional[str] = None
    label: Optional[str] = None
    subgraph: Optional[str] = None

@dataclass
class FlowchartConnection:
    from_node: str
    to_node: str
    style: str
    label: Optional[str] = None

@dataclass
class FlowchartSubgraph:
    id: str
    label: str
    parent: Optional[str] = None
    nodes: List[str] = field(default_factory=list)

@dataclass
class ParsedFlowchart:
    nodes: Dict[str, FlowchartNode] = field(default_factory=dict)
    connections: List[FlowchartConnection] = field(default_factory=list)
    subgraphs: Dict[str, FlowchartSubgraph] = field(default_factory=dict)

@dataclass
class ClassAttribute:
    visibility: Optional[str]
    name: str
    type: Optional[str]
    multiplicity: Optional[str]
    constraints: List[str]
    raw: str

@dataclass
class ClassMethod:
    visibility: Optional[str]
    name: str
    parameters: List[Dict[str, Optional[str]]]
    return_type: Optional[str]
    constraints: List[str]
    raw: str

@dataclass
class ClassInfo:
    name: str
    namespace: Optional[str] = None
    attributes: List[ClassAttribute] = field(default_factory=list)
    methods: List[ClassMethod] = field(default_factory=list)

@dataclass
class ClassRelationship:
    type: str
    from_class: str
    to_class: str
    from_multiplicity: Optional[str] = None
    to_multiplicity: Optional[str] = None
    direction: str = "none"
    label: Optional[str] = None
    raw: str = ""

@dataclass
class ClassNamespace:
    name: str
    classes: List[str] = field(default_factory=list)

@dataclass
class ParsedClassDiagram:
    classes: Dict[str, ClassInfo] = field(default_factory=dict)
    relationships: List[ClassRelationship] = field(default_factory=list)
    namespaces: Dict[str, ClassNamespace] = field(default_factory=dict)

@dataclass
class SequenceMessage:
    sender: str
    receiver: str
    arrow: str
    arrow_type: str
    activation: Optional[str] = None
    operation: Optional[str] = None
    parameters: List[Dict[str, Optional[str]]] = field(default_factory=list)
    assignment: Optional[str] = None
    raw: str = ""
    fragment_context: List[Dict[str, str]] = field(default_factory=list)

@dataclass
class SequenceFragmentBranch:
    guard: Optional[str]
    messages: List[SequenceMessage] = field(default_factory=list)

@dataclass
class SequenceFragment:
    type: str
    branches: List[SequenceFragmentBranch] = field(default_factory=list)
    nested: List['SequenceFragment'] = field(default_factory=list)

@dataclass
class SequenceLifeline:
    name: str
    role: str
    instance_name: str
    classifier_name: Optional[str] = None
    label: str = ""

@dataclass
class ParsedSequenceDiagram:
    lifelines: Dict[str, SequenceLifeline] = field(default_factory=dict)
    messages: List[SequenceMessage] = field(default_factory=list)
    fragments: List[SequenceFragment] = field(default_factory=list)

@dataclass
class FeatureFile:
    filename: str
    labels: List[str]
    content: str
