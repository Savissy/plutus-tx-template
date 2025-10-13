# 🧰 **Automating Plutus Version Updates with GitHub Actions**

## 📑 **Table of Contents**

1. [🚀 Introduction](#1-introduction)
2. [⚙️ What is a GitHub Actions Workflow?](#2-what-is-a-github-actions-workflow)
3. [🎯 Why Use a Workflow for Plutus Version Updates?](#3-why-use-a-workflow-for-plutus-version-updates)
4. [🔁 How the “Bump Plutus Version” Workflow Works](#4-how-the-bump-plutus-version-workflow-works)

   * 4.1 [⏯ Triggering the Workflow](#41-triggering-the-workflow)
   * 4.2 [🧱 The Workflow Jobs and Steps](#42-the-workflow-jobs-and-steps)
5. [🔀 When to Use Each Merge Method](#5-when-to-use-each-merge-method)
6. [📜 Example Workflow YAML Explained](#6-example-workflow-yaml-explained)
7. [🪜 Commit Strategies: Merge, Squash, and Rebase](#7-commit-strategies-merge-squash-and-rebase)
8. [🧩 Example Diagrams](#8-example-diagrams)
9. [📚 Glossary of Terms](#9-glossary-of-terms)


## 🚀 **1. Introduction**

Modern projects often depend on external libraries such as **Plutus** (Cardano’s smart contract toolkit).
Each time a new Plutus version is released, you may need to **update** your `.cabal`, `cabal.project`, and `flake.lock` files.

Instead of updating these manually, you can **automate** the process using **GitHub Actions**, ensuring consistency, reproducibility, and zero manual errors.


## ⚙️ **2. What is a GitHub Actions Workflow?**

A **GitHub Actions workflow** is an automated process (defined in YAML) that runs one or more **jobs** based on **triggers**.

🔸 Each workflow:

* 📁 Lives in `.github/workflows/`
* 🧩 Defines tasks (build, test, publish, etc.)
* 🕹 Runs automatically or on-demand on GitHub’s servers


## 🎯 **3. Why Use a Workflow for Plutus Version Updates?**

| 💡 **Reason**                 | 🧭 **Description**                                                             |
| ----------------------------- | ------------------------------------------------------------------------------ |
| ⚙️ **Automation**             | Avoids manual edits and reduces human error when updating Plutus dependencies. |
| 📏 **Consistency**            | Follows the same process every time — edit → build → test → PR → merge.        |
| 🧾 **Traceability**           | Each change is documented in a PR with commits and version tags.               |
| 🔄 **Continuous Integration** | Automatically integrates changes once all tests and checks pass.               |


## 🔁 **4. How the “Bump Plutus Version” Workflow Works**

This workflow automates the **entire update pipeline** — from editing files to creating a PR and merging it automatically.


### ⏯ **4.1 Triggering the Workflow**

```yaml
on:
  workflow_dispatch:
    inputs:
      version:
        description: Plutus Release Version (e.g. 1.26.0.0)
        required: true
```

**🎬 What Happens:**

* The workflow runs **manually** from the GitHub Actions tab.
* You must provide a **Plutus version number**, e.g. `1.26.0.0`.

**🧭 Why:**

* Manual triggering ensures control — you decide when to upgrade, preventing unwanted automatic updates.


### 🧱 **4.2 The Workflow Jobs and Steps**

#### 🧮 Job: `bump-plutus-version`

Runs on **Ubuntu** and performs a sequence of automated steps:

| 🪜 **Step**                   | ⚡ **Action**                                   | 🧠 **Purpose**                                                   |
| ----------------------------- | ---------------------------------------------- | ---------------------------------------------------------------- |
| 🧰 **1. Checkout**            | `actions/checkout@v4.1.1`                      | Pulls your repository into the workflow runner.                  |
| 🧩 **2. Change Versions**     | `sed` shell commands                           | Updates `.cabal` and `cabal.project` files with the new version. |
| 🧱 **3. Install Nix**         | `DeterminateSystems/nix-installer-action@main` | Installs **Nix** for reproducible dependency management.         |
| 🔄 **4. Update Lock File**    | `nix flake update`                             | Refreshes `flake.lock` for CHaP and Hackage sources.             |
| 🧾 **5. Create Pull Request** | `peter-evans/create-pull-request@v6.0.5`       | Commits, pushes, and opens a PR with the updated files.          |
| 🤖 **6. Enable Auto-Merge**   | `peter-evans/enable-pull-request-automerge@v3` | Automatically merges the PR after checks succeed.                |


## 🔀 **5. When to Use Each Merge Method**

| 🔧 **Merge Method** | 🕒 **When to Use**                                | ✅ **Pros**                           | ⚠️ **Cons**                      |
| ------------------- | ------------------------------------------------- | ------------------------------------ | -------------------------------- |
| 🔗 **Merge**        | When preserving full commit history is important. | Keeps all commit history.            | Can clutter the commit graph.    |
| 📦 **Squash**       | For automated or small PRs like version bumps.    | Creates a single clean commit.       | Loses detailed commit breakdown. |
| 🪄 **Rebase**       | When syncing local branches with `main`.          | Produces a linear, readable history. | Risky on shared branches.        |

Your workflow uses:

```yaml
merge-method: squash
```

✅ Ideal for **automated updates** — keeps the history clean and easy to review.


## 📜 **6. Example Workflow YAML Explained**

```yaml
name: Bump Plutus Version

on:
  workflow_dispatch:
    inputs:
      version:
        description: Plutus Release Version (e.g. 1.26.0.0)
        required: true

jobs:
  bump-plutus-version:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4.1.1

      - name: Change Plutus Versions
        run: |
          CURRENT_DATE=$(date +"%Y-%m-%dT%H:%M:%SZ")
          sed -i "s/\(hackage.haskell.org \).*\$/\1$CURRENT_DATE/" cabal.project
          sed -i "s/\(cardano-haskell-packages \).*\$/\1$CURRENT_DATE/" cabal.project
          
          PLUTUS_VERSION=${{ github.event.inputs.version }}
          sed -i "s/\(plutus-core \).*\$/\1\^>=$PLUTUS_VERSION/" "plinth-template.cabal"
          sed -i "s/\(plutus-ledger-api \).*\$/\1\^>=$PLUTUS_VERSION/" "plinth-template.cabal"
          sed -i "s/\(plutus-tx \).*\$/\1\^>=$PLUTUS_VERSION/" "plinth-template.cabal"
          sed -i "s/\(plutus-tx-plugin \).*\$/\1\^>=$PLUTUS_VERSION/" "plinth-template.cabal"

      - uses: DeterminateSystems/nix-installer-action@main
      - run: nix flake update CHaP hackage --accept-flake-config

      - uses: peter-evans/create-pull-request@v6.0.5
        with:
          branch: "bump-plutus-${{ github.event.inputs.version }}"
          title: Bump Plutus Version to ${{ github.event.inputs.version }}
          commit-message: Bump Plutus Version to ${{ github.event.inputs.version }}
          delete-branch: true
          token: ${{ secrets.GITHUB_TOKEN }}

      - uses: peter-evans/enable-pull-request-automerge@v3
        with:
          pull-request-number: ${{ steps.cpr.outputs.pull-request-number }}
          merge-method: squash
          token: ${{ secrets.GITHUB_TOKEN }}
```


## 🪜 **7. Commit Strategies: Merge, Squash, and Rebase**

### 🔗 **Merge (Default)**

```bash
git merge feature-branch
```

Creates a *merge commit* connecting both branches.

```
A---B---C---M
     \     /
      D---E
```


### 📦 **Squash (Used Here)**

```bash
git merge --squash feature-branch
git commit -m "Bump Plutus version"
```

Result:

```
A---B---C---S
```

Single clean commit — perfect for automation.


### 🪄 **Rebase**

```bash
git rebase main
```

Applies commits from your branch **on top of main**.

```
Before:
A---B---C
     \
      D---E

After:
A---B---C---D'---E'
```


## 🧩 **8. Example Diagrams**

### 🔧 **Workflow Overview**

```
┌────────────────────────────┐
│  Manual trigger (version)  │
└────────────┬───────────────┘
             ↓
┌────────────────────────────┐
│  Update cabal & flake.lock │
└────────────┬───────────────┘
             ↓
┌────────────────────────────┐
│ Create branch + commit     │
└────────────┬───────────────┘
             ↓
┌────────────────────────────┐
│  Open Pull Request (PR)    │
└────────────┬───────────────┘
             ↓
┌────────────────────────────┐
│ Enable Auto-Merge (squash) │
└────────────┬───────────────┘
             ↓
✅ PR merged → main branch updated
```


## 📚 **9. Glossary of Terms**

| 🧩 **Term**              | 🧠 **Meaning**                                             |
| ------------------------ | ---------------------------------------------------------- |
| 🦾 **GitHub Actions**    | CI/CD platform built into GitHub for automation.           |
| ⚙️ **Workflow**          | A YAML-defined automation pipeline.                        |
| 🧱 **Job**               | A group of steps executed on a single virtual environment. |
| 🪜 **Step**              | A single shell command or GitHub action inside a job.      |
| 🧊 **Nix**               | Reproducible package manager used for Cardano projects.    |
| 📦 **Flake**             | A Nix configuration file describing project inputs.        |
| 📁 **cabal.project**     | File defining Haskell build dependencies.                  |
| 🔀 **PR (Pull Request)** | A request to merge code changes between branches.          |
| 🤖 **Auto-Merge**        | Automatically merges a PR once checks pass.                |
| 📜 **Squash**            | Combines multiple commits into one before merging.         |


## ✅ **Summary**

This workflow:

* ⚙️ Automates **Plutus dependency updates**.
* 🧹 Keeps your main branch clean using **squash merges**.
* 🔁 Uses **GitHub Actions** and **Nix** for reproducibility.
* 💼 Saves developer time with automatic PR creation and merging.

