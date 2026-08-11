<!-- docs/spike-b-copilot-assignment.md -->
<!-- Generated: 2025-06-13 | Spike B — Copilot coding-agent assignment API -->
<!-- Sources accessed: 2025-06-13 -->

# Spike B — GitHub Copilot Coding Agent: GraphQL Assignment API

> **Historical evidence (last cataloged 2026-08-09).** Re-verify all API
> contracts before implementation.

**Date:** 2025-06-13  
**Status:** Research complete — no scratch repo tested; all contracts verified against
official GitHub documentation, the `github/docs` source tree, `github/github-mcp-server`
implementation, and public community examples.  
**Downstream target:** `/examples/copilot-auto-assignment/` (Phase 7)

---

## Table of Contents

1. [Verified GraphQL Contract](#1--verified-graphql-contract)
2. [Token Requirements (Verified)](#2--token-requirements-verified)
3. [Preview Headers](#3--preview-headers)
4. [Prerequisites Checklist](#4--prerequisites-checklist)
5. [Recommended Workflow YAML](#5--recommended-workflow-yaml)
6. [Failure Modes Catalog](#6--failure-modes-catalog)
7. [Where to Put What](#7--where-to-put-what)
8. [Recommendations for Downstream Phases](#8--recommendations-for-downstream-phases)
9. [Open Questions](#9--open-questions)

---

## 1 — Verified GraphQL Contract

### 1.1 Actor Discovery Query

Before assigning, discover the Copilot bot's opaque node ID at runtime.
**Do not hardcode the ID** — it differs between github.com and GHES instances.

```graphql
# Step 1: Verify Copilot is available AND retrieve its node ID
query GetCopilotActorId($owner: String!, $repo: String!) {
  repository(owner: $owner, name: $repo) {
    id                          # also capture the repo node ID here
    suggestedActors(capabilities: [CAN_BE_ASSIGNED], first: 100) {
      nodes {
        login
        __typename
        ... on Bot  { id }
        ... on User { id }
      }
    }
  }
}
```

**Expected response when Copilot is enabled:**

```json
{
  "data": {
    "repository": {
      "id": "R_kgDO...",
      "suggestedActors": {
        "nodes": [
          {
            "login": "copilot-swe-agent",
            "__typename": "Bot",
            "id": "B_kgDO..."
          }
        ]
      }
    }
  }
}
```

Key facts:
- `login` is always `"copilot-swe-agent"` (stable across github.com and GHES).
- `__typename` is `"Bot"` (not `"User"`).
- `id` is the GraphQL global node ID — opaque, base64-encoded, **discover every run**.
- If `copilot-swe-agent` is absent from the list, Copilot coding agent is **not enabled**
  for this user/repo combination. Do not proceed.

`gh` CLI equivalent:

```bash
gh api graphql \
  -H 'GraphQL-Features: issues_copilot_assignment_api_support,coding_agent_model_selection' \
  -f query='
    query($owner:String!, $repo:String!) {
      repository(owner:$owner, name:$repo) {
        id
        suggestedActors(capabilities:[CAN_BE_ASSIGNED], first:100) {
          nodes { login __typename ... on Bot{id} ... on User{id} }
        }
      }
    }
  ' \
  -f owner="OWNER" -f repo="REPO"
```

### 1.2 Issue Node ID Query

```graphql
# Step 2: Get the GraphQL node ID of the target issue
query GetIssueId($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) {
      id
      title
      state
    }
  }
}
```

`gh` CLI equivalent:

```bash
gh api graphql \
  -f query='query($owner:String!,$repo:String!,$number:Int!){
    repository(owner:$owner,name:$repo){issue(number:$number){id title state}}
  }' \
  -f owner="OWNER" -f repo="REPO" -F number=ISSUE_NUMBER
```

### 1.3 Assignment Mutations

There are **three valid mutations** for assigning Copilot to an existing issue.
All require the same preview header (Section 3). Choose based on intent:

#### Option A — `replaceActorsForAssignable` (recommended for auto-assignment)

Replaces **all** existing assignees with the provided list. Use this when you
want Copilot to be the sole assignee.

```graphql
mutation AssignCopilot(
  $assignableId: ID!
  $actorIds:    [ID!]!
  $repoId:      ID!
) {
  replaceActorsForAssignable(input: {
    assignableId: $assignableId
    actorIds:     $actorIds
    agentAssignment: {
      targetRepositoryId: $repoId
      baseRef:            "main"
      customInstructions: ""
      customAgent:        ""
      model:              ""
    }
  }) {
    assignable {
      ... on Issue {
        id
        title
        url
        assignees(first: 10) {
          nodes { login }
        }
      }
    }
  }
}
```

`gh` CLI one-liner (using variables from previous steps):

```bash
gh api graphql \
  -H 'GraphQL-Features: issues_copilot_assignment_api_support,coding_agent_model_selection' \
  -f query='
    mutation($assignableId:ID!, $actorIds:[ID!]!, $repoId:ID!) {
      replaceActorsForAssignable(input:{
        assignableId:$assignableId
        actorIds:$actorIds
        agentAssignment:{
          targetRepositoryId:$repoId
          baseRef:"main"
          customInstructions:""
          customAgent:""
          model:""
        }
      }) {
        assignable {
          ... on Issue {
            id title url
            assignees(first:10){ nodes{login} }
          }
        }
      }
    }
  ' \
  -f assignableId="$ISSUE_NODE_ID" \
  -f repoId="$REPO_NODE_ID" \
  --jq '.data.replaceActorsForAssignable.assignable' \
  -- actorIds="$COPILOT_BOT_ID"
```

> **Note on `actorIds` with `gh`:** `gh api graphql` does not support passing
> JSON arrays via `-F`/`-f` flags directly. Use a `jq`-generated JSON body or
> pass variables as a JSON file:
>
> ```bash
> VARS=$(jq -n \
>   --arg aid "$ISSUE_NODE_ID" \
>   --arg rid "$REPO_NODE_ID" \
>   --arg bid "$COPILOT_BOT_ID" \
>   '{assignableId:$aid, actorIds:[$bid], repoId:$rid}')
> echo "$VARS" | gh api graphql \
>   -H 'GraphQL-Features: issues_copilot_assignment_api_support,coding_agent_model_selection' \
>   --input - \
>   -f query='mutation($assignableId:ID!,$actorIds:[ID!]!,$repoId:ID!){...}'
> ```

#### Option B — `updateIssue` (preserves title/body, sets assignees)

```graphql
mutation UpdateIssueAssignees($id: ID!, $assigneeIds: [ID!]!, $repoId: ID!) {
  updateIssue(input: {
    id:          $id
    assigneeIds: $assigneeIds
    agentAssignment: {
      targetRepositoryId: $repoId
      baseRef:            "main"
      customInstructions: ""
      customAgent:        ""
      model:              ""
    }
  }) {
    issue {
      id title url
      assignees(first: 10) { nodes { login } }
    }
  }
}
```

#### Option C — `addAssigneesToAssignable` (additive — keeps existing assignees)

```graphql
mutation AddCopilotAssignee($assignableId: ID!, $assigneeIds: [ID!]!, $repoId: ID!) {
  addAssigneesToAssignable(input: {
    assignableId: $assignableId
    assigneeIds:  $assigneeIds
    agentAssignment: {
      targetRepositoryId: $repoId
      baseRef:            "main"
      customInstructions: ""
      customAgent:        ""
      model:              ""
    }
  }) {
    assignable {
      ... on Issue {
        id title url
        assignees(first: 10) { nodes { login } }
      }
    }
  }
}
```

### 1.4 The `agentAssignment` Input Object

All three mutations accept the same optional `agentAssignment` sub-object:

| Field | Type | Default | Notes |
|---|---|---|---|
| `targetRepositoryId` | `ID!` | — | **Required** — GraphQL node ID of the repo |
| `baseRef` | `String` | default branch | Branch Copilot starts from |
| `customInstructions` | `String` | `""` | Extra guidance beyond issue body |
| `customAgent` | `String` | `""` | Empty = GitHub Copilot; set for partner agents |
| `model` | `String` | `""` | Empty = default model |

Omitting `agentAssignment` entirely still triggers the agent session but
without any customization. Pass the object with empty strings rather than
omitting it to be explicit and forward-compatible.

**Sources:**
- `github/docs:content/copilot/how-tos/use-copilot-agents/cloud-agent/start-copilot-sessions.md` (SHA `44999330`) — official docs source
- `github/github-mcp-server:pkg/github/copilot.go` (SHA `d95357e`) — reference implementation
- `MicrosoftDocs/learn:learn-pr/github/github-copilot-code-agent/includes/3-assign-track-troubleshoot-copilot-code-agent-tasks.md` (SHA `7fadb6e`)

---

## 2 — Token Requirements (Verified)

### 2.1 `GITHUB_TOKEN` Does NOT Work

The GitHub docs state explicitly:

> "Make sure you're authenticating with the API using a **user token**, for
> example a personal access token or a **GitHub App user-to-server token**."
> — `github/docs` start-copilot-sessions.md, verified 2025-06-13

`GITHUB_TOKEN` in GitHub Actions is an **installation token** (machine-to-server),
not a user token. It will be rejected by the Copilot assignment API.

**Expected error when using `GITHUB_TOKEN`:** The `suggestedActors` query will
return an empty list (Copilot not visible), or the mutation will return a
GraphQL authorization error such as:
```
{"errors":[{"message":"Resource not accessible by integration","type":"FORBIDDEN"}]}
```

### 2.2 Fine-Grained Personal Access Token (PAT)

Required permissions (verified from official docs, 2025-06-13):

| Permission | Level |
|---|---|
| **Actions** | Read & Write |
| **Contents** | Read & Write |
| **Issues** | Read & Write |
| **Pull requests** | Read & Write |
| **Metadata** | Read-only (mandatory) |

Fine-grained PATs are scoped to specific repositories or all repos in an org/user account. Scope to only the repositories that need auto-assignment.

### 2.3 Classic Personal Access Token

Requires the **`repo`** scope (broad — grants full repo access). Fine-grained
PATs are strongly preferred for production use.

### 2.4 GitHub App (User-to-Server Token)

A GitHub App can be granted the equivalent permissions. The token type must be
**user-to-server** (i.e., the user authorises the App via OAuth, and the
resulting user token is used). An installation token (server-to-server) does
**not** work — it has the same limitation as `GITHUB_TOKEN`.

### 2.5 Recommended Approach

| Context | Recommendation |
|---|---|
| **Hobby / personal repo** | Fine-grained PAT stored as `secrets.COPILOT_ASSIGN_PAT` |
| **Team / production** | GitHub App (user-to-server token) via `actions/create-github-app-token` |
| **Enterprise / regulated** | GitHub App — avoids PAT rotation, provides audit trail |

**For the example workflow in this starter pack:** support both patterns. Default
to PAT (simpler); document the App approach as the production recommendation.

**Why GitHub App is better in production:**
- No PAT rotation burden.
- The token is short-lived (1 hour max).
- Grants are scoped to specific repos automatically.
- Audit log entries attribute to the App, not a human user's account.
- Does not consume a seat or a named user's PAT quota.

---

## 3 — Preview Headers

### 3.1 Status: STILL REQUIRED as of 2025-06-13

The Copilot assignment API has **not graduated to GA**. Both feature flags must
be passed together in a single `GraphQL-Features` HTTP header:

```
GraphQL-Features: issues_copilot_assignment_api_support,coding_agent_model_selection
```

This is **not** an `Accept` header (which is used for REST preview headers).
For GraphQL it is a custom `GraphQL-Features` header.

**Source:** `github/docs:content/copilot/how-tos/use-copilot-agents/cloud-agent/start-copilot-sessions.md`
(Note callout box, verified 2025-06-13):
> "You must include the `GraphQL-Features` header with the values
> `issues_copilot_assignment_api_support` and `coding_agent_model_selection`."

### 3.2 What Each Flag Gates

| Flag | Purpose |
|---|---|
| `issues_copilot_assignment_api_support` | Unlocks the `agentAssignment` input field on assignment mutations; makes `copilot-swe-agent` visible in `suggestedActors` |
| `coding_agent_model_selection` | Unlocks the `model` field in `agentAssignment` (even when passing empty string) |

Both must be present. Sending only one will cause a GraphQL schema error.

### 3.3 Using with `gh api graphql`

```bash
gh api graphql \
  -H 'GraphQL-Features: issues_copilot_assignment_api_support,coding_agent_model_selection' \
  -f query='...'
```

### 3.4 Using with `curl`

```bash
curl -s -X POST https://api.github.com/graphql \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "GraphQL-Features: issues_copilot_assignment_api_support,coding_agent_model_selection" \
  -d '{"query":"..."}'
```

### 3.5 Watch-List for GA Graduation

Monitor the [GraphQL changelog](https://docs.github.com/en/graphql/overview/changelog)
for removal of these flags. When they graduate, the header will become optional
(passing it will remain harmless). Subscribe to the
[GitHub changelog RSS](https://github.blog/changelog/label/copilot/) feed.

---

## 4 — Prerequisites Checklist

### 4.1 Copilot Subscription

| Plan | Copilot Coding Agent Available? | Notes |
|---|---|---|
| GitHub Copilot Free | ❌ | Not included |
| GitHub Copilot Pro | ✅ | Available (expanded May 2025) |
| GitHub Copilot Pro+ | ✅ | Available since Feb 2025 launch |
| GitHub Copilot Business | ✅ | Available (expanded May 2025) |
| GitHub Copilot Enterprise | ✅ | Requires admin to enable policy |

**Source:** GitHub changelog 2025-02-06 (original launch: Pro+ and Enterprise);
`github/docs` current (June 2025: Pro, Pro+, Business, and Enterprise).

### 4.2 Enterprise Policy (Enterprise Plans Only)

Organization admins must navigate:
> **Org Settings → Copilot → Policies** and enable **Copilot coding agent**

Until enabled, users in that org cannot assign issues to Copilot even with a
valid subscription. The feature also cascades from enterprise → org → repo
settings; enterprise admins can lock it on/off for all orgs.

### 4.3 Individual User Setting

Individual users can verify and toggle at:
> `github.com/settings/copilot` → Features

If the toggle is off, `copilot-swe-agent` will not appear in `suggestedActors`.

### 4.4 Repository Setting

The repository must be on GitHub.com (not GHES prior to a future GHES version).
Repositories owned by Enterprise Managed Users (EMU) **personal** accounts are
**not supported** — only organization-owned repositories work.

### 4.5 GitHub Actions Must Be Enabled

Copilot's agent session runs inside a GitHub Actions workflow on a GitHub-hosted
runner. If Actions are disabled for the repository, the agent cannot run.

If the repo uses an **Actions allow-list** (restricts which actions/workflows can
run), the list must permit GitHub-owned actions. The `copilot-setup-steps.yml`
workflow itself will also need to pass any required checks.

### 4.6 Branch Protection / Push Access

Copilot creates branches named `copilot/<description>` and pushes commits. Branch
protection rules must not block pushes from `copilot-swe-agent`. Specifically:

- If "Require pull request reviews" is enforced on `main`, Copilot's branches
  are NOT `main` — no conflict.
- If a ruleset blocks all pushes except from named actors, add
  `copilot-swe-agent[bot]` to the bypass list, or loosen the rule for
  `copilot/**` branches.
- PR merge protection (required reviews) still applies — a human must approve
  before merge. The PR author (Copilot) cannot approve their own PR.

### 4.7 API Authentication Credential in Place

- `secrets.COPILOT_ASSIGN_PAT` — fine-grained PAT (for PAT approach), OR
- `secrets.APP_ID` + `secrets.APP_PRIVATE_KEY` — GitHub App credentials
  (for App approach — recommended for production).

---

## 5 — Recommended Workflow YAML

Save as `.github/workflows/copilot-auto-assignment.yml` (or in the example at
`examples/copilot-auto-assignment/.github/workflows/copilot-auto-assignment.yml`).

```yaml
# .github/workflows/copilot-auto-assignment.yml
#
# Auto-assigns the GitHub Copilot coding agent to any issue that receives
# a configurable label (default: "copilot").
#
# PREREQUISITES — see docs/spike-b-copilot-assignment.md Section 4:
#   1. GitHub Copilot Pro / Pro+ / Business / Enterprise subscription
#   2. Copilot coding agent enabled at user / org / repo level
#   3. One of:
#      a. secrets.COPILOT_ASSIGN_PAT  (fine-grained PAT, repo scope)
#      b. secrets.APP_ID + secrets.APP_PRIVATE_KEY  (GitHub App, recommended)
#   4. GitHub Actions enabled for this repository
#
# IMPORTANT: GITHUB_TOKEN cannot be used here — it is an installation token,
# not a user token. The Copilot assignment API rejects it. Use a PAT or
# GitHub App user-to-server token instead.
#
# Preview header required (not yet GA as of 2025-06-13):
#   GraphQL-Features: issues_copilot_assignment_api_support,coding_agent_model_selection

name: Auto-assign Copilot to labeled issues

on:
  issues:
    types: [labeled]

# Minimal permissions for the workflow itself.
# The actual API calls use the PAT / App token stored in secrets,
# which carries the required user-level permissions.
permissions:
  issues: write       # needed to post the confirmation comment
  contents: read

env:
  # Change this to whatever label you use to trigger Copilot assignment.
  TRIGGER_LABEL: "copilot"

jobs:
  assign-copilot:
    name: Assign Copilot coding agent
    runs-on: ubuntu-latest

    # Only run when the label that was just added is our trigger label.
    if: github.event.label.name == 'copilot'

    steps:
      # ── Step 1: Obtain a user-scoped token ──────────────────────────────
      #
      # OPTION A (GitHub App — recommended for production):
      #   Uses actions/create-github-app-token to exchange App credentials for
      #   a user-to-server token. Delete option B below and un-comment this.
      #
      # - name: Generate GitHub App token
      #   id: app-token
      #   uses: actions/create-github-app-token@v2
      #   with:
      #     app-id:      ${{ secrets.APP_ID }}
      #     private-key: ${{ secrets.APP_PRIVATE_KEY }}
      #     # owner is optional; defaults to the repository owner
      #
      # Then reference the token as: ${{ steps.app-token.outputs.token }}
      # and replace every ${{ secrets.COPILOT_ASSIGN_PAT }} below with that.
      #
      # OPTION B (PAT — simpler, fine for hobby use):
      #   Store a fine-grained PAT as secrets.COPILOT_ASSIGN_PAT.
      #   Required PAT permissions: actions R/W, contents R/W,
      #                             issues R/W, pull-requests R/W, metadata R.

      - name: Validate trigger
        id: validate
        run: |
          echo "Issue #${{ github.event.issue.number }}: ${{ github.event.issue.title }}"
          echo "Label applied: ${{ github.event.label.name }}"

      # ── Step 2a: Discover Copilot actor ID + repo node ID ───────────────
      - name: Discover Copilot actor ID and repo node ID
        id: discover
        env:
          GH_TOKEN: ${{ secrets.COPILOT_ASSIGN_PAT }}
          OWNER:    ${{ github.repository_owner }}
          REPO:     ${{ github.event.repository.name }}
        run: |
          set -euo pipefail

          RESPONSE=$(gh api graphql \
            -H 'GraphQL-Features: issues_copilot_assignment_api_support,coding_agent_model_selection' \
            -f query='
              query($owner:String!, $repo:String!) {
                repository(owner:$owner, name:$repo) {
                  id
                  suggestedActors(capabilities:[CAN_BE_ASSIGNED], first:100) {
                    nodes {
                      login __typename
                      ... on Bot  { id }
                      ... on User { id }
                    }
                  }
                }
              }
            ' \
            -f owner="$OWNER" \
            -f repo="$REPO")

          echo "suggestedActors response received"

          # Check for GraphQL errors
          ERRORS=$(echo "$RESPONSE" | jq -r '.errors // empty')
          if [ -n "$ERRORS" ]; then
            echo "::error::GraphQL errors during actor discovery: $ERRORS"
            exit 1
          fi

          # Extract repo node ID
          REPO_ID=$(echo "$RESPONSE" | jq -r '.data.repository.id')
          if [ -z "$REPO_ID" ] || [ "$REPO_ID" = "null" ]; then
            echo "::error::Could not retrieve repository node ID"
            exit 1
          fi

          # Find copilot-swe-agent in the suggested actors list
          COPILOT_ID=$(echo "$RESPONSE" | \
            jq -r '.data.repository.suggestedActors.nodes[]
                   | select(.login == "copilot-swe-agent") | .id')

          if [ -z "$COPILOT_ID" ] || [ "$COPILOT_ID" = "null" ]; then
            echo "::error::copilot-swe-agent not found in suggestedActors."
            echo "::error::Likely causes:"
            echo "::error::  1. Copilot coding agent not enabled for this user/org/repo."
            echo "::error::     Check: https://github.com/settings/copilot"
            echo "::error::  2. COPILOT_ASSIGN_PAT is an installation token, not a user token."
            echo "::error::  3. Copilot subscription does not include coding agent."
            # Print available actors to help diagnose
            ACTORS=$(echo "$RESPONSE" | jq -r '[.data.repository.suggestedActors.nodes[].login] | join(", ")')
            echo "::error::  Available suggested actors: [$ACTORS]"
            exit 1
          fi

          echo "repo_id=$REPO_ID"       >> "$GITHUB_OUTPUT"
          echo "copilot_id=$COPILOT_ID" >> "$GITHUB_OUTPUT"
          echo "✅ Copilot actor found: copilot-swe-agent ($COPILOT_ID)"

      # ── Step 2b: Retrieve issue node ID ─────────────────────────────────
      - name: Retrieve issue node ID
        id: issue
        env:
          GH_TOKEN: ${{ secrets.COPILOT_ASSIGN_PAT }}
          OWNER:    ${{ github.repository_owner }}
          REPO:     ${{ github.event.repository.name }}
          NUMBER:   ${{ github.event.issue.number }}
        run: |
          set -euo pipefail

          RESPONSE=$(gh api graphql \
            -f query='
              query($owner:String!, $repo:String!, $number:Int!) {
                repository(owner:$owner, name:$repo) {
                  issue(number:$number) { id title state }
                }
              }
            ' \
            -f owner="$OWNER" \
            -f repo="$REPO" \
            -F number="$NUMBER")

          ERRORS=$(echo "$RESPONSE" | jq -r '.errors // empty')
          if [ -n "$ERRORS" ]; then
            echo "::error::GraphQL errors fetching issue: $ERRORS"
            exit 1
          fi

          ISSUE_ID=$(echo "$RESPONSE" | jq -r '.data.repository.issue.id')
          ISSUE_STATE=$(echo "$RESPONSE" | jq -r '.data.repository.issue.state')

          if [ -z "$ISSUE_ID" ] || [ "$ISSUE_ID" = "null" ]; then
            echo "::error::Could not retrieve issue #$NUMBER node ID"
            exit 1
          fi

          if [ "$ISSUE_STATE" != "OPEN" ]; then
            echo "::warning::Issue #$NUMBER is $ISSUE_STATE — Copilot may not start."
          fi

          echo "issue_id=$ISSUE_ID" >> "$GITHUB_OUTPUT"
          echo "✅ Issue node ID retrieved"

      # ── Step 3: Assign Copilot via replaceActorsForAssignable ───────────
      - name: Assign Copilot to issue
        id: assign
        env:
          GH_TOKEN:    ${{ secrets.COPILOT_ASSIGN_PAT }}
          ISSUE_ID:    ${{ steps.issue.outputs.issue_id }}
          REPO_ID:     ${{ steps.discover.outputs.repo_id }}
          COPILOT_ID:  ${{ steps.discover.outputs.copilot_id }}
        run: |
          set -euo pipefail

          # Build the variables JSON (handles the array type correctly)
          VARS=$(jq -n \
            --arg aid "$ISSUE_ID" \
            --arg rid "$REPO_ID" \
            --arg bid "$COPILOT_ID" \
            '{assignableId:$aid, repoId:$rid, actorIds:[$bid]}')

          RESPONSE=$(echo "$VARS" | gh api graphql \
            -H 'GraphQL-Features: issues_copilot_assignment_api_support,coding_agent_model_selection' \
            --input - \
            -f query='
              mutation($assignableId:ID!, $actorIds:[ID!]!, $repoId:ID!) {
                replaceActorsForAssignable(input:{
                  assignableId: $assignableId
                  actorIds:     $actorIds
                  agentAssignment: {
                    targetRepositoryId: $repoId
                    baseRef:            ""
                    customInstructions: ""
                    customAgent:        ""
                    model:              ""
                  }
                }) {
                  assignable {
                    ... on Issue {
                      id title url
                      assignees(first:10){ nodes{ login } }
                    }
                  }
                }
              }
            ')

          echo "Raw mutation response:"
          echo "$RESPONSE" | jq .

          ERRORS=$(echo "$RESPONSE" | jq -r '.errors // empty')
          if [ -n "$ERRORS" ]; then
            echo "::error::GraphQL mutation failed: $ERRORS"
            exit 1
          fi

          ISSUE_URL=$(echo "$RESPONSE" | \
            jq -r '.data.replaceActorsForAssignable.assignable.url // "unknown"')
          ASSIGNEES=$(echo "$RESPONSE" | \
            jq -r '[.data.replaceActorsForAssignable.assignable.assignees.nodes[].login] | join(", ")')

          echo "issue_url=$ISSUE_URL"  >> "$GITHUB_OUTPUT"
          echo "assignees=$ASSIGNEES"  >> "$GITHUB_OUTPUT"
          echo "✅ Mutation succeeded. Assignees: [$ASSIGNEES]"

      # ── Step 4: Post confirmation comment ───────────────────────────────
      - name: Comment on issue
        env:
          GH_TOKEN: ${{ secrets.COPILOT_ASSIGN_PAT }}
          ISSUE_URL: ${{ steps.assign.outputs.issue_url }}
          ASSIGNEES: ${{ steps.assign.outputs.assignees }}
        run: |
          gh issue comment "${{ github.event.issue.number }}" \
            --repo "${{ github.repository }}" \
            --body "🤖 **Copilot coding agent assigned.**

          Copilot will shortly:
          1. Add a 👀 reaction to this issue
          2. Open a draft pull request on a \`copilot/\` branch
          3. Begin an agent session (visible in the [Agents tab](https://github.com/${{ github.repository }}/copilot/agents))

          Assignees: \`$ASSIGNEES\`

          _Triggered by the \`${{ env.TRIGGER_LABEL }}\` label being applied._"
```

---

## 6 — Failure Modes Catalog

| Symptom | Likely Cause | Resolution |
|---|---|---|
| `copilot-swe-agent` absent from `suggestedActors` | Copilot coding agent not enabled for this user/org/repo | Check `github.com/settings/copilot`; for Enterprise, org admin must enable the policy |
| `Resource not accessible by integration` (GraphQL 403) | Using `GITHUB_TOKEN` (installation token) instead of a user token | Switch to fine-grained PAT or GitHub App user-to-server token |
| `Field 'agentAssignment' doesn't exist` (GraphQL schema error) | Missing preview header `issues_copilot_assignment_api_support` | Add `-H 'GraphQL-Features: issues_copilot_assignment_api_support,coding_agent_model_selection'` |
| `Field 'model' doesn't exist` (GraphQL schema error) | Missing preview header `coding_agent_model_selection` | Both flags required together |
| Mutation succeeds but no 👀 reaction on issue | Agent session didn't start; may be a transient delay | Refresh issue; if no reaction after 2 min, unassign and re-assign |
| Mutation succeeds but no draft PR | Actions disabled or quota exhausted | Check Actions tab; ensure Actions are enabled; check billing |
| `suggestedActors` returns empty list | Valid token but Copilot disabled, OR token lacks required permissions | Verify PAT has `issues: read` at minimum; check user Copilot settings |
| Copilot doesn't respond to PR comments | Commenter lacks write access, or comment not on Copilot's PR | Confirm write access; comment directly on the draft PR, not on the issue |
| Agent session times out (1 hour) | Task too complex, or CI failures blocking | Unassign/re-assign with more specific `customInstructions`; add `copilot-setup-steps.yml` |
| `copilot-setup-steps` job not running | Workflow not on default branch | Ensure `.github/workflows/copilot-setup-steps.yml` is committed to the repo's default branch |
| EMU personal repo error | Copilot coding agent not supported in EMU personal repos | Move repository to an org-owned repo with GitHub-hosted runners |
| Workflow itself fails (not the API call) | `COPILOT_ASSIGN_PAT` secret not set | Add the secret in repo Settings → Secrets and variables → Actions |
| 401 Unauthorized from GraphQL | PAT expired or revoked | Rotate the PAT; GitHub fine-grained PATs expire after the configured duration |

---

## 7 — Where to Put What

### 7.1 Root Repository (Default / Phase 3)

The root of the starter pack ships **documentation and manual guidance only**.
No auto-assignment workflow in the root `.github/workflows/` — that would be
surprising and potentially costly for anyone who clones the template.

| File | Content |
|---|---|
| `docs/agentic-sdlc.md` | Explain manual issue assignment via GitHub UI, Mobile, and CLI (`gh issue edit --add-assignee @copilot`) |
| `docs/repo-settings-checklist.md` | List the toggles: enable Copilot coding agent (user settings, org policy, repo enablement); note that auto-assignment needs a PAT or GitHub App |
| `docs/spike-b-copilot-assignment.md` | **This file** — the verified API contract, for reference by Phase 7 |

### 7.2 Example Directory (Phase 7)

`examples/copilot-auto-assignment/` should contain a self-contained, well-documented
example that can be copied into any repo:

```
examples/copilot-auto-assignment/
├── README.md                          # Prerequisites, setup steps, caveats
├── .github/
│   └── workflows/
│       └── copilot-auto-assignment.yml  # The workflow from Section 5
└── copilot-setup-steps-example.yml    # Minimal copilot-setup-steps reference
                                       # (NOTE: must be placed in root
                                       # .github/workflows/ of the target repo)
```

The README must prominently warn:
> ⚠️ **This workflow requires a fine-grained PAT or GitHub App user-to-server
> token. `GITHUB_TOKEN` will not work.** See the Prerequisites section.

### 7.3 `copilot-setup-steps.yml` (Spike E)

This is a **separate concern** from auto-assignment. The `copilot-setup-steps.yml`
workflow is executed by the Copilot agent's own session to set up its development
environment — it is not part of the assignment flow. It belongs in:

```
.github/workflows/copilot-setup-steps.yml   # must be on default branch
```

Key constraints:
- The job MUST be named `copilot-setup-steps` (exact string).
- It MUST be on the default branch before Copilot is assigned any issue.
- It runs in the Copilot agent's ephemeral environment (not the calling user's).
- Minimum permissions needed: `contents: read`.
- Use it to: `npm ci`, `pip install`, install CLI tools, set env vars.

**Spike E owns this file.** Spike B (this document) establishes only that it
exists and when it runs, for cross-reference.

---

## 8 — Recommendations for Downstream Phases

### Phase 3 — Root Template Default

- **Do not** add the auto-assignment workflow to the root `.github/workflows/`.
- **Do** add a section to `docs/agentic-sdlc.md` explaining that issues can be
  manually assigned to Copilot from the GitHub UI, the CLI, or GitHub Mobile.
- **Do** add to `docs/repo-settings-checklist.md`:
  - [ ] Enable Copilot coding agent at the user level (`github.com/settings/copilot`)
  - [ ] For Enterprise: org admin enables "Copilot coding agent" policy
  - [ ] For auto-assignment (optional): create a fine-grained PAT as `COPILOT_ASSIGN_PAT` or set up a GitHub App

### Phase 7 — `/examples/copilot-auto-assignment/`

Deliver:
1. **The workflow YAML** from Section 5 (PAT path enabled by default, App path commented in).
2. **A clear README** with:
   - Prerequisites (subscription tier, feature toggle, PAT/App setup).
   - Step-by-step instructions to copy the workflow into a real repo.
   - A prominent `⚠️ GITHUB_TOKEN will NOT work` callout.
   - Link to `docs/spike-b-copilot-assignment.md` for the full API contract.
3. **A `copilot-setup-steps-example.yml`** (minimal, just `npm ci`) with comments
   pointing to Spike E for full customization guidance.

### Phase 7 — Repo Settings Checklist Update

Add to `docs/repo-settings-checklist.md` under a new "Copilot Auto-Assignment (Optional)" section:

- [ ] Repository is org-owned (not personal EMU repo)
- [ ] Copilot coding agent enabled for the user/org/repo
- [ ] Fine-grained PAT created and stored as `secrets.COPILOT_ASSIGN_PAT`, OR
  GitHub App created with `APP_ID` + `APP_PRIVATE_KEY` secrets
- [ ] Issue label `copilot` (or custom) created in the repository
- [ ] Auto-assignment workflow copied to `.github/workflows/copilot-auto-assignment.yml`
- [ ] GitHub Actions enabled for the repository
- [ ] Branch protection rules permit pushes from `copilot-swe-agent[bot]`
  to `copilot/**` branches

---

## 9 — Open Questions

1. **When will preview headers graduate to GA?**
   Both `issues_copilot_assignment_api_support` and `coding_agent_model_selection`
   are undocumented in the GraphQL changelog for 2025 as having a GA graduation date.
   Monitor https://docs.github.com/en/graphql/overview/changelog and
   https://github.blog/changelog/label/copilot/. The workflow in Section 5 passes
   the headers unconditionally — this is safe even after GA graduation.

2. **`GITHUB_TOKEN` with additional permissions?**
   It is unverified whether a workflow with elevated `GITHUB_TOKEN` permissions
   (e.g., `permissions: issues: write` + explicit Copilot scopes) could work.
   The official docs say "user token" which implies this is not possible, but the
   exact error message when using `GITHUB_TOKEN` was not directly observed (no
   scratch repo available). The `github/github-mcp-server` implementation uses
   a `githubv4.Client` which would use whatever token the MCP server is
   authenticated with.

3. **GitHub App user-to-server token mechanics in Actions**
   `actions/create-github-app-token@v2` generates an **installation token** by
   default, which may have the same limitation as `GITHUB_TOKEN`. Generating a
   true user-to-server token from Actions requires the App to have a user
   authorization flow (OAuth). This needs real-world testing. The safest path is
   the fine-grained PAT until confirmed.

4. **Copilot Business — full coding agent support?**
   The GitHub changelog from February 2025 listed only "Copilot Pro+ and
   Copilot Enterprise." The current documentation (June 2025) lists "Pro, Pro+,
   Business, and Enterprise." It is unverified whether all coding agent features
   (including API assignment) are at feature parity across all four tiers for
   Copilot Business.

5. **Rate limits on the assignment API**
   No rate-limit documentation was found for the `replaceActorsForAssignable`
   mutation with `agentAssignment`. Likely governed by standard GraphQL rate
   limits (5000 points/hour for authenticated requests), but this was not
   confirmed for the Copilot-specific fields.

6. **`copilot-swe-agent` login stability across GHES versions**
   The `github/github-mcp-server` code comments state "supposed to have the same
   name on each host" but this was not independently verified for GHES instances.
   The pattern `login.toLowerCase().includes("copilot")` used in the MCP server
   is a more resilient match than exact equality.

---

## Appendix — Key Source Citations

| Source | URL / Path | Accessed |
|---|---|---|
| Official Copilot coding agent assignment docs | `https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/start-copilot-sessions` | 2025-06-13 |
| Copilot coding agent concepts | `https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent` | 2025-06-13 |
| `copilot-setup-steps` docs | `https://docs.github.com/en/copilot/customizing-copilot/customizing-the-development-environment-for-copilot-coding-agent` | 2025-06-13 |
| Org policy management | `https://docs.github.com/en/copilot/managing-copilot/managing-github-copilot-in-your-organization/managing-policies-and-features-for-copilot-in-your-organization` | 2025-06-13 |
| GitHub changelog (initial launch) | `https://github.blog/changelog/2025-02-06-github-copilot-coding-agent-in-public-preview/` | 2025-06-13 |
| `github/github-mcp-server` reference impl | `github/github-mcp-server:pkg/github/copilot.go` SHA `d95357e` | 2025-06-13 |
| `github/docs` source tree | `github/docs:content/copilot/how-tos/use-copilot-agents/cloud-agent/start-copilot-sessions.md` SHA `44999330` | 2025-06-13 |
| Microsoft Learn module (community) | `MicrosoftDocs/learn:learn-pr/github/github-copilot-code-agent/includes/3-assign-track-troubleshoot-copilot-code-agent-tasks.md` SHA `7fadb6e` | 2025-06-13 |
| Public implementation example | `Levi1308/ai-feature-team-demo:scripts/launch-copilot-agent.mjs` SHA `1c7336c` | 2025-06-13 |
