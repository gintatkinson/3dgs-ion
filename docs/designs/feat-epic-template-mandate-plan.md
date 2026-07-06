# Implementation Plan: Safe Workspace Restoration & Epic Reconstruction

This plan details the steps to safely reconstruct the target restoration workspace (e.g. `<jail_dir>/digipipe-tst16`) and regenerate the Geographic Location Epic (`epic-01-geo-location.md`) with the required UML Class and State Machine diagrams.

To comply with the **Workspace Boundary Isolation** rules, we will **not** scan adjacent directories or search the user's files. Instead, we will reconstruct the workspace by pulling files from the active repository (our workspace) and downloading specifications directly from the remote issue tracker (the canonical source of truth).

## Proposed Workflow

### Phase 1: Workspace Re-initialization
1. Copy the `rules/` and `skills/` directories from the active repository `<active_repo_dir>` into `<restore_workspace_dir>/`.
2. Reconstruct the `.pipeline/constitution.md` using the standard dynamic protocol-agnostic constitution.
3. Download the official `ietf-geo-location@2022-02-11.yang` schema from the standard YangModels GitHub repository using `curl`.

### Phase 2: Metadata Extraction & Specification Reconstruction
1. Run a script to fetch the descriptions of Issues #1 to #12 from the remote `gintatkinson/digipipe-tst16` repository via the `gh` CLI.
2. For each issue, extract the description, parse the Markdown metadata table at the top, convert it back into the standard YAML frontmatter block, and save it in the correct directory:
   - **Issues #1 to #4** $\rightarrow$ `docs/features/`
   - **Issues #6 to #9** $\rightarrow$ `docs/user-stories/`
   - **Issues #10 to #12** $\rightarrow$ `docs/use-cases/`
This restores all child features, stories, and use cases to the local disk without accessing any adjacent projects.

### Phase 3: Epic Reconstruction (Pipeline-Safe)
1. Generate `docs/epics/epic-01-geo-location.md` dynamically according to the mandated template.
2. Incorporate the overall **System-Level UML Class Diagram** depicting the composed domain model structure using clean PascalCase names:
   ```mermaid
   classDiagram
       class GeoLocation {
           +ReferenceFrame referenceFrame
           +LocationChoice locationChoice
           +Velocity velocity
           +TemporalValidity temporalValidity
       }
       class ReferenceFrame {
           +AlternateSystem alternateSystem
           +AstronomicalBody astronomicalBody
           +GeodeticSystem geodeticSystem
       }
       class GeodeticSystem {
           +GeodeticDatum geodeticDatum
           +CoordAccuracy coordAccuracy
           +HeightAccuracy heightAccuracy
       }
       class LocationChoice {
           <<choice>>
       }
       class EllipsoidLocation {
           +Latitude latitude
           +Longitude longitude
           +Height height
       }
       class CartesianLocation {
           +X x
           +Y y
           +Z z
       }
       class Velocity {
           +VNorth vNorth
           +VEast vEast
           +VUp vUp
       }
       GeoLocation *-- ReferenceFrame
       ReferenceFrame *-- GeodeticSystem
       LocationChoice <|-- EllipsoidLocation
       LocationChoice <|-- CartesianLocation
       GeoLocation *-- LocationChoice
       GeoLocation o-- Velocity
   ```
3. Incorporate the **System State Machine Diagram** in a `stateDiagram-v2` block modeling transitions (`Unconfigured` $\rightarrow$ `Configured` $\rightarrow$ `Active` $\rightarrow$ `Expired`):
   ```mermaid
   stateDiagram-v2
       [*] --> Unconfigured
       Unconfigured --> Configured : Configure reference-frame
       Configured --> Active : Set location coordinates
       Active --> Expired : System time > valid-until
       Active --> Configured : Clear coordinates
       Expired --> Active : Update valid-until / coordinates
   ```
4. Reassemble the `## Child Features` checklist using the exact live Issue IDs (`#1` through `#4`) and absolute file links to prevent 404 navigation errors.

### Phase 4: Verification
1. Run the newly updated model coverage linter script:
   ```bash
   python3 <active_repo_dir>/skills/spec-orchestrator/scripts/verify_model_coverage.py <restore_workspace_dir>/yang <restore_workspace_dir>/docs/features
   ```
2. Verify that the command succeeds with `exit code 0`, 100% coverage, and 100% UML compliance.
