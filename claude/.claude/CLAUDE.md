# Global Agent Guidance

## Global Paths

- The canonical global agent instructions file is
  `~/.claude/CLAUDE.md`, in the Claude Code configuration folder.
- Put reusable scripts created by agents under
  `~/Documents/feedme-infrastructure/sre-docs/scripts/`.
- Put generated JSON artifacts under
  `~/Documents/feedme-infrastructure/sre-docs/json/`.
- Prefer Python for scripts and data transformations. Continue using dedicated
  file tools for simple reads, edits, and searches.
- Put all handwritten notes, plans, and personal scribbles created by agents under
  `~/Documents/feedme-infrastructure/sre-docs/quanian/`.

## SRE Workspace Repository Discovery

- `~/Documents/feedme-infrastructure` is the SRE workspace. When operating from
  this workspace, check local directories first before using GitHub search,
  `gh repo list`, or cloning remote repositories.
- For requests that name a repository, branch, PR, service, or feature, first
  inspect likely local workspaces under `~/Documents/feedme-app/`,
  `~/Documents/feedme-infrastructure/`, and `~/Documents/feedme-scripts/`.
- Prefer local Git remotes, branches, PR metadata, and checked-out working trees
  as the source of truth for discovery. Use GitHub queries only after local
  discovery does not identify the target repository or PR.
- If a repo is not present locally and must be modified, clone it to
  `/var/folders/ht/vf_q07sj0rb4xt0x5_rlcz8c0000gp/T/opencode/` rather than into
  the SRE workspace.

## `gitops` vs `gitops-apps` — which repo does a workload go in?

Both repos deploy through ArgoCD, and picking the wrong one is a silent
mistake: the manifest renders fine, the PR looks reasonable, and it only
surfaces as an ownership/structure problem later. Decide before writing any
YAML.

**`gitops-apps`** — business-facing services and CI/CD-managed services.

- FeedMe product/business services that a delivery team owns and ships
  (`main-backend`, `payment-service`, `inventory-backend`, …).
- Anything whose image tag is bumped automatically by a service repo's own
  CI/CD pipeline on merge to `main`.
- Layout: `clusters/<env>/<COUNTRY>/<service>.yaml` for the ArgoCD app config
  plus `manifests/<service>/<COUNTRY>/<env>/` for the Kustomize overlay.
- Known exception: **`incident-commander`** lives here despite being an
  internal SRE tool, because it is treated as a critical service with the
  same deploy lifecycle as a product service.

**`gitops`** — cluster dependencies and non-FeedMe-managed services.

- Third-party / upstream software we run but do not author: DevLake, Grafana,
  ArgoCD, Karpenter, cert-manager, external-secrets, Dagster, Flagsmith,
  Langfuse, JupyterHub, …
- Cluster-level infrastructure: CRDs, NodePools, secret stores, ingress
  controllers, ServiceMonitors, cluster roles.
- SRE-authored operational tooling that supports the cluster or an
  upstream service rather than serving business traffic — e.g.
  `volume-autoscaler`, `devlake-clickhouse-sync`. These are built in
  `platform-script/tooling/` and deployed as `job`-chart CronJobs/ScaledJobs.
- Layout: `kustomize/controllers/<component>/<cluster>/` for the overlay plus
  `clusters/<cluster>/systools/<component>.yaml` for the ArgoCD Application
  (named `<cluster>.sys.<component>`).

**Deciding rule.** Ask "does this serve FeedMe business traffic, and does a
product team's CI/CD own its image tag?" If yes → `gitops-apps`. If it is
infrastructure, an upstream product, or a job that supports one of those →
`gitops`.

**Corollary — colocate with what it depends on.** A sidecar job for an
upstream service belongs in the same repo, cluster path, and namespace as
that service. `devlake-clickhouse-sync` sits next to `devlake` in
`gitops/kustomize/controllers/` and runs in the `devlake` namespace so it can
reuse the `devlake-mysql-auth` secret directly instead of duplicating
credentials into a second Secrets Manager key.

## Local MCP Credentials

- Local MCP servers can run with a different `HOME` than the interactive shell.
  When an MCP server uses AWS SSO, set `HOME` explicitly in its Claude Code MCP
  `env` to the user's home directory so Boto3 can read both `~/.aws/config`
  and `~/.aws/sso/cache`.
- Also set the intended `AWS_PROFILE` and `AWS_REGION` explicitly for each AWS
  MCP server. Do not rely on the shell's default profile or region.
- Diagnose AWS MCP authentication by testing the target profile with
  `aws sts get-caller-identity --profile <profile>`. If that succeeds but the
  MCP server returns `NoCredentialsError`, verify its `HOME`, `AWS_PROFILE`,
  and `AWS_REGION` environment values before changing AWS permissions.
- If the server still cannot authenticate after a full restart, set those
  values in the MCP `command` through `/usr/bin/env` instead of relying on the
  settings `env` field. Use an absolute `uvx` path so the launch is independent
  of the child process `PATH`.
- MCP servers are defined in `~/.claude/skills/feedme-mcp/.mcp.json`, a
  skills-directory plugin that Claude Code auto-loads. Edit that file and restart
  Claude Code; there is no install or sync step. Verify with
  `claude plugin details feedme-mcp@skills-dir`.

### direnv is the source of truth for MCP env vars

- Non-AWS MCP tokens/URLs are loaded via **direnv** from
  `~/Documents/.envrc` (auto-loaded when the shell `cd`s
  into `~/Documents` or any repo below it). Claude Code is normally launched from
  a directory below it, so any variable exported there is available to `${VAR}`
  placeholders in `.mcp.json`.
- When adding a new local MCP server that needs a token/URL, **first check
  `~/Documents/.envrc`** for existing variables and reuse
  their exact names — do not invent new env var names. Current variables in
  that file include `ARGOCD_SERVER`, `ARGOCD_AUTH_TOKEN`, `N8N_MCP_TOKEN`,
  `GRAFANA_MCP_SERVICE_ACCOUNT_TOKEN`.
- Do NOT hardcode tokens or URLs in `.mcp.json`. Always reference them via
  `${VAR}` and, if a needed variable is missing, add the `export` to the `.envrc`
  (never inline the secret in `.mcp.json` or in `CLAUDE.md`).
- If `direnv status` shows `No .envrc or .env loaded` even though an `.envrc`
  exists in the workspace, it usually needs `direnv allow` once. After that,
  restart Claude Code from the workspace directory so the child MCP processes
  inherit the exported vars.
- Diagnose missing MCP credentials with:
  `direnv exec ~/Documents env | rg '<VAR_NAME>'`
  If the var is present under `direnv exec` but not in the current shell,
  Claude Code was launched from a directory outside the `.envrc` scope.

## Infrastructure / Terraform (Atlantis)

- **Atlantis is the source of truth for credentials and runs.** All provider
  credentials (AWS, Twingate, Cloudflare, etc.) are already configured on the
  Atlantis server. `terraform plan`/`apply` run there via PR comments.
- **Do NOT run general authenticated provider queries or fetch arbitrary
  secrets locally.** Local AWS SSO sessions are often ReadOnlyAccess and cannot
  read Secrets Manager values (e.g. `twingate-feedme`). Attempting this wastes
  time and fails with AccessDenied.
- **Exception: MCP bootstrap tokens.** Agents may retrieve the explicitly
  documented Secrets Manager token needed to start an approved local MCP
  server, such as `N8N_MCP_TOKEN`. Never print the token, commit it, or use it
  outside the MCP authentication flow.
- When live resource IDs are needed for `import` blocks, get them from the user,
  the Twingate/AWS admin console, or an existing state/config file — not by
  querying the provider API locally.
- Write the Terraform config + `import` blocks, then let Atlantis run
  `atlantis plan` on the PR to validate and surface the real values/plan.
- **Never create or populate AWS Secrets Manager secrets directly via
  `aws secretsmanager create-secret`/`put-secret-value`.** All secrets must be
  provisioned as Terraform resources (`aws_secretsmanager_secret` +
  `aws_secretsmanager_secret_version`), sourced from Terraform-managed values
  (module outputs, other secret data sources) — never hardcoded or populated
  out-of-band. If a value genuinely can't originate in Terraform (e.g. a
  credential from a system Terraform doesn't manage, like GCP Cloud SQL),
  create the secret with a placeholder value and
  `lifecycle { ignore_changes = [secret_string] }` so the real value can be
  set manually once without Terraform reverting it on the next apply. See
  `terraform/services/whatsapp-multisession-service/dev/secretsmanager.tf`
  for the reference pattern (`dms_source`/`dms_target`). If a manually-created
  secret already exists from a prior mistake, delete it before the Terraform
  resource is applied so there's no orphaned out-of-band secret.


<!-- headroom:rtk-instructions -->
# RTK (Rust Token Killer) - Token-Optimized Commands

When running shell commands, **always prefix with `rtk`**. This reduces context
usage by 60-90% with zero behavior change. If rtk has no filter for a command,
it passes through unchanged — so it is always safe to use.

## Key Commands
```bash
# Git (59-80% savings)
rtk git status          rtk git diff            rtk git log

# Files & Search (60-75% savings)
rtk ls <path>           rtk read <file>         rtk grep <pattern>
rtk find <pattern>      rtk diff <file>

# Test (90-99% savings) — shows failures only
rtk pytest tests/       rtk cargo test          rtk test <cmd>

# Build & Lint (80-90% savings) — shows errors only
rtk tsc                 rtk lint                rtk cargo build
rtk prettier --check    rtk mypy                rtk ruff check

# Analysis (70-90% savings)
rtk err <cmd>           rtk log <file>          rtk json <file>
rtk summary <cmd>       rtk deps                rtk env

# GitHub (26-87% savings)
rtk gh pr view <n>      rtk gh run list         rtk gh issue list

# Infrastructure (85% savings)
rtk docker ps           rtk kubectl get         rtk docker logs <c>

# Package managers (70-90% savings)
rtk pip list            rtk pnpm install        rtk npm run <script>
```

## Rules
- In command chains, prefix each segment: `rtk git add . && rtk git commit -m "msg"`
- For debugging, use raw command without rtk prefix
- `rtk proxy <cmd>` runs command without filtering but tracks usage
<!-- /headroom:rtk-instructions -->

## User Preferences

- Do not add comments to generated code. Write self-explanatory code; only include comments when the user explicitly requests them.
- Keep git commit messages and PR descriptions succinct and bullet-pointed. Avoid elaborate prose, verbose explanations, or long narrative paragraphs.
- Commit messages follow conventional commits: `<type>(<scope>): <imperative summary>`.
  Types: feat, fix, refactor, perf, docs, test, chore, build, ci, style, revert.
  Imperative mood ("add", not "added"/"adds"). Subject ≤50 chars where possible,
  hard cap 72, no trailing period. Add a body only for a non-obvious why, a
  breaking change, a migration note, or a linked issue — always for breaking
  changes, security fixes, data migrations and reverts. Wrap the body at 72,
  bullet with `-`, reference issues at the end (`Closes #42`). Never write "this
  commit does X", "I"/"we"/"now", or "as requested by" (use a `Co-authored-by`
  trailer), and do not restate a filename the scope already names.
- Code review comments are one line per finding: `<file>:L<line>: <problem>. <fix>.`
  Prefix with severity when it varies: 🔴 bug (broken, will cause an incident),
  🟡 risk (works but fragile), 🔵 nit (style/naming, ignorable), ❓ q (a real
  question, not a suggestion). Keep exact line numbers, exact symbol names in
  backticks, and a concrete fix rather than "consider refactoring". Drop "I
  noticed that", "it seems like", "you might want to consider", per-comment
  praise, and restatements of what the line does. If unsure use `q:` rather than
  hedging. Write full prose instead for security findings, architectural
  disagreements, and anyone being onboarded.
- PR descriptions must follow this structure (omit sections that are not applicable, but keep the headings in this order):

  ```
  ## What

  ## Why

  ## Resources Affected

  ## Ticket Link

  ## Other PRs that depends on this PR

  ## Other PRs that this PR depends on
  ```
- Before opening a PR, always ask for the ticket if neither a ticket key nor URL has been provided. A ticket key such as `SRE-222` is sufficient: use it verbatim in the `## Ticket Link` section and do not ask for or fabricate a URL. Do not silently omit the section; if the user confirms there is no ticket, leave it with an explicit `N/A`.
- Lead with a concise causal summary, avoid unnecessary process detail, and use the user's operational terminology.
- Prefer the simplest correct solution over generalized abstractions or speculative flexibility.
- Bias toward the fewest steps, nodes, and config needed to meet the stated goal. Do not add retries, error handling, notifications, or other robustness features unless explicitly requested; instead surface them as options.
- Root-cause fixes by verifying against authoritative sources (official API/tool docs, type definitions) rather than guessing parameter names, HTTP methods, payload formats, or field shapes.
- Make surgical changes and avoid unrelated cleanup, refactoring, or formatting changes.
- Preserve existing conventions unless there is a concrete reason to change them.
- When independent concerns have different failure modes, keep them independently gated rather than coupling them for less duplication.
- Base actions on the narrowest relevant condition instead of triggering on broad or incidental changes.
- Validate behavior with focused cases, including both positive and negative cases.
- Use locally available tooling to test changes realistically; if a tool depends on a runtime or service, diagnose and enable that dependency when practical.
- Before creating a PR, inspect the branch base and diff so unrelated history is not included.
- Keep temporary test changes and branches isolated, and clean them up after verification.
- Continue through implementation, verification, and delivery when the requested outcome is clear.
- Report limitations plainly when a requested test or operation cannot be completed.
- **All code changes must be delivered through PRs.** Never leave changes as
  local-only edits or uncommitted diffs. Clone the repo (to temp if outside the
  workspace), create a feature branch, commit, push, and open a PR.
- When modifying a repo that is not the current workspace, clone it to
  `/var/folders/ht/vf_q07sj0rb4xt0x5_rlcz8c0000gp/T/opencode/` (the temp
  directory), make changes there, and push a PR back to the remote.
- **Before pushing a follow-up commit to an existing PR branch, verify the PR
  is still open.** In a long-running discussion where the user has been
  iterating on the same PR, that PR may have been merged (or closed) by the
  user between messages. Check with `gh pr view <n> --repo <owner/repo> --json
  state` before assuming the branch is still the right place to push. If the
  PR is `MERGED` or `CLOSED`, open a new PR against `main` for the follow-up
  fix instead of pushing to the now-orphaned feature branch. When a merge is
  squash-based, also confirm which of your local commits actually made it onto
  `main` (via `git log origin/main -- <path>` and content diff) rather than
  assuming all commits on the feature branch landed together.

## n8n Python Code Nodes (`pythonNative`)

The `pythonNative` sandbox in n8n's Code node (`n8n-nodes-base.code` v2) has a
different runtime surface than the JavaScript sandbox. Do not mechanically
translate JS Code-node snippets to Python — the globals and cross-node access
model differ.

### Available globals (pythonNative)

- `_items` — list of input items in the form `[{ "json": {...}, "binary": ... }, ...]`.
  This is the **only** reliable way to read input in this sandbox.
- `_json` — shorthand for `_items[0]["json"]` when there is exactly one item.
- Built-ins with underscore prefix mirror JS `$` helpers where implemented,
  e.g. `_today`, `_jmespath`.
- Standard library modules can be imported (`import os`, `import json`,
  `from datetime import datetime, timezone`, etc.). `boto3`, `botocore`, and
  a few other third-party packages are available when the container image
  provides them, but do not assume — check with a working node in the same
  workflow first.

### Not available / commonly-mistaken

- `_input` is **not defined**. `_input.all()`, `_input.first()`, and
  `_input.item` are JavaScript-only. Using them raises
  `name '_input' is not defined`.
- `_("Node Name")` / `$("Node Name")` cross-node accessors are
  **not available** in `pythonNative`. A Python Code node can only see the
  items on its own input pin.
- `os.environ` is **cleared** before user code runs (n8n's
  `N8N_BLOCK_RUNNER_ENV_ACCESS`). Read env-derived data another way — e.g.
  the projected file at `/var/run/secrets/eks.amazonaws.com/serviceaccount/token`
  is unaffected and can be read directly.
- `return` statements at module top level work (the sandbox wraps the code),
  but you must return `[{"json": {...}}, ...]` — a list of items — not a bare
  dict.

### Correct patterns

- Reading the single upstream item:
  ```python
  data = _items[0]["json"] if _items else {}
  ```
- Merging data from two upstream branches: place an
  `n8n-nodes-base.merge` node before the Python node (mode:
  `combine → mergeByPosition` or `append`) so both branches arrive on the
  same input pin. Then walk `_items` and split by shape / a marker field
  you set upstream.
- Never write `_input.all()` or `_("Some Node").all()` in `pythonNative`;
  use `_items` from the merged upstream instead.

### Verifying the sandbox before writing code

The existing "Scan LB Ownership & Traffic (Python)" node in the LB orphan
detector workflow is a good reference: it opens with
`CONFIG = _items[0]['json']` and imports `boto3` — matching what this
`pythonNative` sandbox actually supports.

## n8n Workflow Authoring

### Language choice for Code nodes

- Default to **JavaScript** for filter, transform, and formatting nodes.
  JavaScript Code nodes can reach any upstream node with
  `$('Node Name').first().json` / `.all()`, which removes the need for
  Merge nodes just to combine two upstream streams.
- Use **`pythonNative`** only when the logic genuinely needs a Python-only
  dependency (e.g. `boto3`, `botocore`, custom SSL/HTTP handling). The
  Python sandbox does not expose `$('Node Name')` cross-node accessors and
  can only read its direct input via `_items`, which forces extra Merge
  nodes for otherwise-simple joins. Do not pay that cost by default.

### Topology preferences

- Prefer the fewest nodes and the least indirection that meet the goal.
  When a design starts requiring Merge nodes, cross-node HTTP calls, or
  chained Set nodes to shuffle shape around, stop and consider whether a
  single JS node reading from `$('...')` upstream would collapse the
  design. It almost always does.
- Do not add retries, validation nodes, or error branches unless the user
  asks for them. Surface them as options instead.

### IDs and references

- Data table IDs, chat IDs, and other stable identifiers may be hardcoded
  in the workflow JSON when the user prefers that over env var / `$vars`
  indirection. Ask once, then honour the answer for the rest of the
  workflow.
- Always look up the actual data-table schema (columns and types) via the
  n8n MCP `search_data_tables` before writing a node that reads it — do
  not guess column names.

### Digest / message formatting

- User-facing digest messages should surface **findings** only. Do not
  print internal machinery counts such as "N suppressed by skiplist",
  "M items merged", or diagnostic timings unless the user asks for them.
- Return **no items** when there is nothing to alert on. Silent clean
  runs are the expected default for scheduled workflows.
- When emphasising fields in a digest, the user's convention is:
  - **Bold** the primary identifier line (classification + resource name).
  - *Italicise* the note / annotation line.

### Lark send nodes — verify formatting before assuming Markdown

- `CUSTOM.larkMessenger` and other Lark community nodes send messages as
  Lark `text` message type by default, which **does not render Markdown**.
  Sending `**bold**` in a `text` payload shows literal asterisks to the
  user.
- Before writing Markdown into a Lark message body, confirm one of:
  - the node supports switching message type to `post` / `rich_text`, or
  - the workflow builds a Lark rich-text (`post`) payload directly.
  If neither is available, either drop the formatting or switch to a
  card / HTTP call to the `/im/v1/messages` endpoint with a properly
  structured `post` message.
- Check the reference workflow at `EPcITHnxCYgeaQkq` (the Grafana alert
  workflow with `Send a message - SRE`) for the current standard Lark
  send node configuration and credential wiring in this instance.

## Answer Style for n8n Work

- When the user pushes back on a design as "overcomplicated" or asks to
  "do it simply", first list two or three simpler alternatives and let
  the user pick. Do not silently rewrite in one direction — the earlier
  Merge-node design was one such case where a JS rewrite would have been
  the right first proposal.
- Root-cause runtime errors like `name '_input' is not defined` by
  reading a known-working node in the same workflow (or in a sibling
  workflow) before proposing a fix. The sandbox globals differ between
  language modes and versions; the authoritative source is what already
  runs, not general n8n documentation.
- Confirm every ID, credential name, and data-table schema via MCP or
  a direct read of the workflow JSON before writing code that references
  them. Names in the UI, exported JSON, and API responses can differ.

## Grafana Dashboard Authoring

- When replacing or reordering dashboard rows, always update `gridPos.y` on each
  row panel to match the intended visual order. Grafana renders by `gridPos.y`,
  not by array index — mismatched values cause rows to appear in the wrong order.
- When saving a dashboard JSON locally (e.g. to `sre-docs/`), also save it to
  Grafana only when explicitly requested. Default to local-only saves.
- The ClickHouse production datasource is **feedme-prod**
  (UID `PFBB86B2188878B82`, type `grafana-clickhouse-datasource`). The default
  traces table is `default.otel_traces` with OTel schema (`Timestamp`,
  `SpanName`, `SpanKind`, `ServiceName`, `StatusCode`, `Duration` in
  nanoseconds, `SpanAttributes` map).
- `SpanKind` values are `Server`, `Client`, `Internal` (not `SPAN_KIND_*`).
- `StatusCode` values are `Unset` and `Error`. Use `StatusCode != 'Error'` for
  success and `StatusCode = 'Error'` for failures.
- `Duration` is stored as `UInt64` nanoseconds. Divide by `1e6` for milliseconds.
- Use `$__timeFilter(Timestamp)` and `$__timeInterval(Timestamp)` macros for
  time-range panels. Use explicit `Timestamp >= now() - INTERVAL 28 DAY` for
  fixed-window SLI/SLO stat panels (with `timeFrom: "28d"`).
- The standard 6-panel spanmetrics row pattern is:
  1. Error Budget (Latency) — stat, 28d window
  2. Error Budget (Requests) — stat, 28d window
  3. `<Label>` Successfully — stat, success rate, 28d window
  4. Requests — timeseries, request count with success/error breakdown
  5. `<Label>` within Latency Threshold — stat, 28d window
  6. Latency (Successful Responses) — timeseries, p50/p90/p95/p99
- Dashboard variables `$SLO` (percentage) and `$target_latency` (ms) are
  referenced in error budget and threshold queries via `${SLO}` and
  `${target_latency}` inside ClickHouse SQL.
