<!-- Copyright Gint Atkinson, gint.atkinson@gmail.com -->

---
name: schema-specification-engineering
description: "Transforms structural schemas and normative specification documents into Agile Epics and Features. Use when you need to extract platform-independent feature specifications from structural schemas with exhaustive constraint parsing and Given-When-Then acceptance criteria."
compatibility: "Requires issue tracker CLI and git. Works with modern agentic development environments."
metadata:
  title: "Schema Specification Engineering (Structural Extraction)"
  risk: medium
  source: custom
  version: "2.0"
---

# Schema Specification Engineering

Use this as the single canonical workflow for translating structural schemas and their normative specification documents into highly rigorous, implementation-ready Agile specifications for sub-agents. 

> [!TIP]
> This skill operates in the spirit of the `andrej-karpathy` methodology: focus deeply on the fundamentals, enforce exhaustive structural rigor, leave absolutely zero ambiguity in the acceptance criteria, and instrument the outputs flawlessly into project tracking systems.

> [!IMPORTANT]
> **EXHAUSTIVE SEMANTIC MODELING MANDATE**
> Do NOT blindly map every isolated schema attribute (e.g., `x`, `y`, `z`) to a separate Feature. You MUST semantically model the schema by grouping cohesive properties into a single logical Feature (e.g., "Cartesian Coordinates"). However, "zero abstraction" still applies: within that grouped Feature, you MUST exhaustively document EVERY underlying attribute/node, capturing its exact data type, mathematical constraints (value ranges, units), defaults, and verbatim specification text. No constraint detail may be lost or summarized away.

## Step 1: Forensic Audit & Module Decomposition

1. **Parse the Schema:** Read the primary structural schema file and its imports.
2. **Identify Top-Level Trees:** Decompose the high-level structural attributes (e.g., system configuration, users, orders) into discrete logical groupings.
3. **Dispatch Epic Subagents:** For each high-level structure/subsystem identified:
   - Invoke a **new, fresh subagent with an isolated context**.
   - Pass only the specific high-level schema nodes/attributes for this subsystem, and the Epic template. Do not pass other subsystems' context.
   - The subagent drafts the Epic markdown file (e.g., `docs/epics/epic-01-name.md`) containing:
     - An overarching **System-Level UML Class Diagram** illustrating the subsystem's classes and their relationships.
     - A **UML Component** representing the subsystem, specifying its provided/required interfaces and operations.
     - A **System State Machine Diagram** representing the macro-level domain, combining the individual structures and lifecycles that will be broken down into child features.

## Step 2: Isolated Feature Extraction (Subagent Dispatch Loop)

For each cohesive functional feature group identified during the decomposition (e.g., a "User Profile" containing `first-name`, `last-name`):
1. **Dispatch Feature Subagent:** Invoke a **new, fresh subagent with an isolated context** to draft the feature specification. Pass ONLY the schema nodes and properties for this specific feature group, along with the relevant normative specification text. The subagent must have no visibility into other features.
2. **Execution within Subagent Context:**
   - **Platform Independence:** Feature specifications MUST be purely functional and platform-independent. Describe *what* the system must do (data to store, validations to enforce, information to display) — never *how* (no framework-specific components, no platform-specific patterns).
   - **Exhaustive Constraint Parsing:** For EVERY attribute within the grouped feature, analyze and record all structural constraints:
     - conditional clauses
     - type definitions (value ranges, string patterns, references)
     - units and default values
     - read-only vs configurable access control
   - **UML Class Diagram:** Every Feature specification MUST include a **UML Class Diagram** (using Mermaid `classDiagram`).
     - *UML Classifier Mapping*: Feature specifications must map to a primary UML Class or DataType representing the schema entity, and MUST illustrate its relationship (e.g. composition `*--` or aggregation `o--`) to its parent container class or its child components to ensure no isolated classes exist. Classes that will cross serialization boundaries (Web Workers via `structuredClone`, Flutter Isolates via `SendPort`) MUST be modeled as pure data classes (DTOs) without methods. Service methods (e.g. `save()`, `validate()`) MUST be placed in separate service/repository classes that are NOT transferred across threads.
     - *Choice/Case Representation*: Model schema alternative structures as abstract classes or classes with the `<<choice>>` stereotype, and their constituent choices as classes inheriting (`<|--`) from the choice class.
     - *UML Standard Primitive Types*: All attributes in class diagrams must use standard capitalized UML primitives (`String`, `Integer`, `Real`, `Boolean`) instead of format-specific or custom types.
     - *Visibility & Multiplicity*: Every attribute/operation must use visibility indicators (`+`/`-`) and standard multiplicities (e.g. `[1]`, `[0..1]`, `[0..*]`).
     - *UML Constraints*: Schema-level constraints must map to formal UML `{constraint}` elements or structured notes.
     - *Multiplicity Bracket Rendering*: Note that unquoted brackets `[0..1]` inside Mermaid class bodies may cause rendering failures in some engines (GitHub, Mermaid CLI). Represent multiplicity on relationship lines instead.
     - *Double-Declaration Redundancy*: Do NOT list object-typed attributes inside the class body if they are already represented as named relationship lines.
   - **Interface Requirements:** Every feature spec MUST explicitly include a `## Interface Requirements` section divided into dynamic structured sub-sections based on the `interface_type` (defined in frontmatter as `ui`, `api`, or `m2m`):
     - *For UI Interfaces (`interface_type: ui`)*:
       - `1. Test Data Shape (JSON Payload Example)`: A concrete, copy-pasteable JSON payload schema example block.
       - `2. Validation & Constraints`: Exhaustive list of ranges, regex patterns, mandatory fields, and conditions.
       - `3. Visual Layout & Arrangement`: Detailed, platform-independent description of the visual layout and hierarchy. Mandate CSS resets (box-sizing), scoped naming (CSS Modules/BEM) to avoid specificity conflicts, layout containment parameters (restricting containment to outer layout splitters and forbidding it on scrollable child panels), and valid DOM nesting for tree structures (recursive lists nested inside parent list-items).
       - `4. Interactive Flow & States`: System states (read-only, edit, empty, loading, error highlighting). Mandate computed-style assertions (such as verifying scroll dimensions or highlight colors) in the test guidelines for components with visual, selection, or highlight states.
     - *For API or M2M Interfaces (`interface_type: api` or `m2m`)*:
       - `1. Payload Schema (JSON Schema/Protobuf)`: Target request/response payload definition.
       - `2. Validation & Constraints`: Schema field constraints, type validations, and logical conditions.
       - `3. Logical Operations & Interface Messages`: Abstract definitions of logical endpoints, methods (GET/POST/Publish/Subscribe or read/write operations), logical paths, or routing channels.
       - `4. Logical Exception States & Validation Failures`: Expected logical error states, exception/failure flows, and timeouts.
   - **Acceptance Criteria Translation:** Transform these programmatic constraints and interface requirements into exhaustive Given-When-Then Logical Acceptance Criteria. Criteria MUST be platform-independent.
   - **Specification Context Injection (Verbatim):** Embed the exact paragraphs and sections from the canonical normative text explaining the behavioral logic of this specific structural container under a `## Specification Context (Verbatim)` section.
   - **Draft the Feature Spec File:** Write the Feature as a local markdown file (e.g., `docs/features/feat-01-name.md`).
3. **Return Control:** The subagent completes the task and returns control to the worker agent.

## Step 3: Specification Context Injection (Verbatim)

1. **Locate Normative Text:** Find the canonical normative text document (e.g. specification standard documents) associated with the schema.
2. **Extract Line-by-Line Context:** Identify the exact paragraphs and sections that explain the behavioral logic of the specific structural container.
3. **Embed Context:** Inject this verbatim text directly into the feature specification under a `## Specification Context (Verbatim)` section. This guarantees that implementing sub-agents have ground-truth knowledge and are not hallucinating implementation details.

## Step 4: Output Formatting & Strict GitHub Instrumentation

> [!WARNING]
> You must strictly follow the operational sequencing below to ensure the `#IssueID` linkages are perfectly resolved.

1. **YAML Frontmatter:** Prepend strict YAML metadata to every `.md` file:
   ```yaml
   ---
   title: "[Title]"
   epic: "[Parent Epic]"
   type: "feature"
   interface_type: "ui" # Options: ui, api, m2m
   generation_mode: "subagent"
   labels: ["feature", "<domain-name>"]
   ---
   ```
   > **Note:** No `platform` field. Features are functional specs. Platform targeting occurs at implementation time via `feature-driven-implementation` and the project's implementation profiles.

2. **Epic File Structure / Template:** Every Epic specification markdown file MUST follow this exact section structure and ordering:
    ```markdown
    ---
    title: "[Epic Title]"
    type: "epic"
    generation_mode: "subagent"
    spec_source: "Project Constitution"
    ---

    # Epic: [Epic Title]

    ## 1. Context
    [High-level functional description and specification-engineering context of the schema module]

    ## 2. Requirements & Checklist
    - [ ] #[IssueID] - [Feature Title]([Repository Base URL]/<blob_path>/[Branch Name]/docs/features/feat-XX-name.md) (semantic linkage justification)

    ### Associated Use Cases & User Stories

    #### Associated Use Cases
    - [ ] #[IssueID] - [Use Case Title]([Repository Base URL]/<blob_path>/[Branch Name]/docs/use-cases/uc-XX-name.md) (semantic linkage justification)

    #### Associated User Stories
    - [ ] #[IssueID] - [User Story Title]([Repository Base URL]/<blob_path>/[Branch Name]/docs/user-stories/us-XX-name.md) (semantic linkage justification)

    ## 3. Architecture and System Interaction Diagrams

    ### Subsystem Component Definition
    Define the subsystem representing the Epic as a UML Component specifying provided/required interfaces and operations.
    ```mermaid
    classDiagram
        class SubsystemComponent {
            <<component>>
            +providedInterface() : Boolean [1]
            +requiredInterface() : String [1]
        }
    ```

    ## System-Level UML Class Diagram
    ```mermaid
    classDiagram
        class SubsystemComponent {
            <<component>>
        }
        class FeatureClassifier1 {
            +String attributeOne [1]
            -Boolean attributeTwo [0..1]
        }
        class FeatureClassifier2 {
            +Integer attributeThree [0..*]
            +operationOne(input : String) : Boolean [1]
        }
        SubsystemComponent *-- FeatureClassifier1
        SubsystemComponent *-- FeatureClassifier2
    ```

    ## 4. State Machine Definitions

    ## System State Machine Diagram
    ```mermaid
    stateDiagram-v2
        [*] --> InitialState
        InitialState --> [*] : Event / Action
    ```

    ## 5. Specification Context
    [Verbatim schema grouping/container descriptions from the normative specification]

    ## 6. Source References
    Structural Schema: [Schema File Name]
    Normative Specification: [RFC/Standard Name]
    ```

3. **Feature File Structure / Template:** Every feature specification markdown file MUST follow this exact section structure and ordering:
   ```markdown
   ---
   title: "[Feature Title]"
   type: "feature"
   interface_type: "ui" # Options: ui, api, m2m
   generation_mode: "subagent"
   spec_source: "Project Constitution"
   ---

   # Feature: [Feature Title]

   ## Parent Epic
   - [ ] #[EpicIssueID] - [Epic Title]([Repository Base URL]/<blob_path>/[Branch Name]/docs/epics/epic-XX-name.md) (semantic linkage justification)

   ## Description
   [Functional description of the feature]

     ## UML Class Diagram
     ```mermaid
     classDiagram
         class ParentContainer {
             +FeatureClassifier featureClassifier [1]
         }
         class FeatureClassifier {
             +String primaryAttribute [1]
             -Boolean optionalAttribute [0..1] {constraintText}
             +Integer listAttribute [0..*]
             +doSomething(param : String) : Boolean [1]
         }
         ParentContainer *-- FeatureClassifier
     ```

     ## Interface Requirements
     ### 1. Test Data Shape / Payload Schema (JSON Example)
     ```json
     {
       "example_key": "example_value"
     }
     ```

     ### 2. Validation & Constraints
     - [Field constraints, ranges, patterns, protocol/payload limits]

     ### 3. Visual Layout / Logical Operations & Interface Messages
      - [For UI: abstract grouping, zoning, hierarchy guidelines. Enforce CSS resets (box-sizing), scoped naming (CSS Modules/BEM) to avoid specificity conflicts, layout containment parameters (restricting containment to outer layout splitters and forbidding it on scrollable child panels), and valid DOM nesting for tree structures (recursive lists nested inside parent list-items). For API/M2M: logical methods, operations, abstract paths, or channels]

     ### 4. Interactive Flow & States / Logical Exception States & Validation Failures
     - [For UI: states, errors, loading. Mandate computed-style assertions (such as verifying scroll dimensions or highlight colors) in the test guidelines for visual or active selection states. For API/M2M: logical error states, timeouts, exception flows]

   ## Given-When-Then Acceptance Criteria
   [BDD scenarios]

   ## Specification Context (Verbatim)
   [Raw normative specification context paragraphs]

   ## 4. Source References
   [Source references links]

   ## 5. Logical UI & Layout Bindings
   - **Target LUI Component:** [e.g. PropertyGrid, TopologyMap, DensityTable, ConsoleLogger]
   - **Target Layout Container ID:** [Specify the container ID from logical-layout.json]
   - **Data Source Bindings:** [Specify the data source mappings from logical-layout.json]
   ```

3. **Source References Block (CRITICAL):**
   - At the bottom of every feature markdown file, you MUST append a `## 4. Source References` section containing dynamic references to the input structural schemas and specifications, formatted like this:
   ```markdown
   ## 4. Source References
   Structural Schema: [Target Schema File](link-to-schema)
   Normative Specification: [Normative Specification](link-to-specification)
   ```
   - Inject the exact absolute URLs pointing to the authoritative structural schema and normative text document provided by the user. Do not omit this.

4. **Logical UI & Layout Bindings Block (MANDATORY):**
   - Every feature specification markdown file MUST contain a `## 5. Logical UI & Layout Bindings` section at the end of the file.
   - You MUST map the feature's container and leaf nodes to:
     - The target LUI component (e.g. `PropertyGrid`, `TopologyMap`, `DensityTable`, `ConsoleLogger`).
     - The specific target layout container ID in `logical-layout.json`.
     - The data source bindings matching `logical-layout.json`.

2. **Tracker Label Bootstrapping:** Invoke the issue tracker's label bootstrap interface (e.g. creating "epic" and "feature" labels in the configured provider).

3. **Duplicate Detection (Idempotency Check):**
   - Before creating any issue, query the active tracker provider for all existing backlog issues to check if an issue with an identical or semantically equivalent title already exists.
   - If a duplicate is found: skip creation, and reuse the existing Issue ID for Epic linkage.
   - This ensures the pipeline is safe to re-run without creating duplicate issues.

4. **Feature Backlog Creation FIRST:**
   - Register each Feature specification with the active tracker provider, capturing the returned Issue ID/URL from the tracker.

5. **Epic Backlog Assembly:**
   - Now that you possess the actual live Issue IDs for all extracted features, inject them into the Epic's checklist.
   - Ensure the body of the Epic lists its child features as a tasklist referencing the Issue ID and the absolute repository URL of the feature document (relative links resolve incorrectly on tracker UI platforms). You MUST dynamically determine the repository base URL from the runtime configuration (`meta.upstream_repository` in `codebase_rules.json`) and construct the absolute link pointing to the file on the current branch using the configured URL template (e.g., `[Repository Base URL]/<blob_path>/[Branch Name]/docs/features/feat-01.md` where `<blob_path>` is resolved from configuration).

6. **Epic Backlog Creation LAST:**
   - Finally, register the Epic specification containing the fully resolved tasklist with the active tracker provider.

