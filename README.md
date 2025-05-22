# 📦 Auction Validator Project

### Updated by Coxygen Global - Bernard Sibanda

<<<<<<< HEAD
Plinth currently supports GHC `v9.6.x`. Cabal `v3.8+` is recommended.
=======
## 📑 Table of Contents
>>>>>>> 2ab0d4f (upgraded)

1. [⚙️ Project Overview](#1-project-overview)
2. [⚙️ Environment Setup](#2-environment-setup)
3. [📂 Directory Structure](#3-directory-structure)
4. [🛠️ Installation & Build](#4-installation--build)
5. [🔬 Testing](#5-testing)
6. [🧪 Property-Based Testing](#6-property-based-testing)
7. [🚀 Usage](#7-usage)
8. [📖 Glossary](#8-glossary)

---

## 1. ⚙️ Project Overview

This repository contains a Plutus-based Auction Validator smart contract along with tooling to generate Blueprints and comprehensive test suites. It is part of the **Plinth Template** for teaching on-chain development on Cardano.

## 2. ⚙️ Environment Setup

Follow these steps to prepare your environment:

```bash
# 1. Enter the Nix shell (requires Nix installed)
nix-shell

# 2. Update Cabal package index
cabal update

<<<<<<< HEAD
<details>
  <summary> With Nix (<b>recommended</b>) </summary>

  1. Follow [these instructions](https://github.com/input-output-hk/iogx/blob/main/doc/nix-setup-guide.md) to install and configure nix, <b>even if you already have it installed</b>.
     
  2. Then enter the shell using `nix develop`.

  > NOTE:  
  > The nix files inside this template follow the [`iogx` template](https://github.com/input-output-hk/iogx), but you can delete and replace them with your own. In that case, you might want to include the [`devx` flake](https://github.com/input-output-hk/devx/issues) in your flake inputs as a starting point to supply all the necessary dependencies, making sure to use one of the `-iog` flavors.

  > NOTE (for Windows users):<br>
  > Make sure to have [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install#upgrade-version-from-wsl-1-to-wsl-2) and the [WSL](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl) VSCode extension (if using VSCode) installed before the Nix setup.
</details>

<details>
  <summary> With Docker / Devcontainer / Codespaces </summary>
  
  - **Docker + Codespaces:** From the [GitHub web page](https://github.com/IntersectMBO/plinth-template), click the top-right green button:

    `Use this template -> Open in a codespace`

  - **Docker + Devcontainer:**
    1. Make sure to have [VSCode](https://code.visualstudio.com/) installed with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension.
    2. Open this project in VSCode and let it create a local codespace for you (See Dev Containers instructions, if needed).

  - **Stand-alone Docker:** Change the `/path/to/my-project` accordingly and run:

  ```
    docker run \
      -v /path/to/my-project:/workspaces/my-project \
      -it ghcr.io/input-output-hk/devx-devcontainer:x86_64-linux.ghc96-iog
  ```

  > NOTE:
  > You can modify your [`devcontainer.json`](./.devcontainer/devcontainer.json) file to customize the container (more info [here](https://github.com/input-output-hk/devx?tab=readme-ov-file#vscode-devcontainer--github-codespace-support)).

  > NOTE:  
  > When using this approach, you can ignore/delete/replace the Nix files entirely.

  > NOTE (for Windows users):<br>
  > It is recommended to install and run Docker on your native OS. If you want to run Docker Desktop inside a VM, read through [these notes](https://docs.docker.com/desktop/setup/vm-vdi/).
</details>

<details>
  <summary> With Demeter </summary>
  
  1. Create an account in [Demeter](https://demeter.run/).
  
  2. Follow [their instructions](https://docs.demeter.run/guides/getting-started) to setup a remote development environment.

  > IMPORTANT:  
  > Demeter uses its own infrastructure and packages. If something is not working correctly, please contact them before creating an issue.

  > NOTE:  
  > When using this approach, you can ignore/delete/replace the Nix files entirely.
</details>

<details>
  <summary> With manually-installed dependencies (<b>not recommended</b>) </summary>
  <br>
  
  Follow the instructions for [cardano-node](https://developers.cardano.org/docs/get-started/cardano-node/installing-cardano-node/) for a custom setup.

  > NOTE:  
  > When using this approach, you can ignore/delete/replace the Nix files entirely.
</details>
=======
# 3. Ensure project dependencies are available
cabal build --enable-tests
```

> **Note:** If you do not use Nix, skip the `nix-shell` step and ensure you have GHC and Cabal installed via the Haskell Platform.

## 3. 📂 Directory Structure

```text
auction/                     # Project root
├── app/                     # Executables for Blueprint generation
│   ├── GenAuctionValidatorBlueprint.hs
│   └── GenMintingPolicyBlueprint.hs
├── src/                     # On-chain library modules
│   └── AuctionValidator.hs
├── test/                    # Test suite files
│   ├── AuctionValidatorSpec.hs            # Unit tests
│   ├── AuctionMintingPolicySpec.hs        # Minting policy tests
│   └── AuctionValidatorProperties.hs      # QuickCheck properties
├── default.nix              # Nix definition (if applicable)
├── shell.nix                # Nix shell entry (if applicable)
├── auction.cabal            # Cabal project configuration
├── cabal.project            # Root project settings
└── cabal.project.local      # Local overrides (e.g., tests: True)
```

## 4. 🛠️ Installation & Build

1. **Enter Nix shell (optional)**:

   ```bash
   nix-shell
   ```
2. **Update Cabal index**:

   ```bash
   cabal update
   ```
3. **Install dependencies & build**:

   ```bash
   cabal build --enable-tests
   ```
4. **Generate Blueprints**:

   ```bash
   cabal run gen-auction-validator-blueprint -- ./blueprint-auction.json
   cabal run gen-minting-policy-blueprint -- ./blueprint-minting.json
   ```

## 5. 🔬 Testing

### Run Unit Tests

```bash
cabal test auction-tests
```

### Run All Tests
>>>>>>> 2ab0d4f (upgraded)

```bash
cabal test
```

* **`auction-tests`**: Unit tests for the Auction Validator.
* **`minting-tests`**: Unit tests for the Minting Policy (if configured).

## 6. 🧪 Property-Based Testing

To verify invariants using QuickCheck:

1. Add a QuickCheck test suite entry in your `.cabal`:

   ```cabal
   test-suite auction-properties
     type: exitcode-stdio-1.0
     main-is: AuctionValidatorProperties.hs
     hs-source-dirs: test
     build-depends:
         base >=4.7 && <5,
       , scripts,
       , QuickCheck,
       , plutus-ledger-api,
       , plutus-tx,
       , test-framework
     default-language: Haskell2010
   ```
2. Run the property suite:

   ```bash
   cabal test auction-properties
   ```

## 7. 🚀 Usage

* **Deploy** your compiled Plutus script on a Cardano network by submitting the generated blueprint JSON via your deployment tooling.
* **Customize** `AuctionParams` (seller, currency symbol, token name, minimum bid, end time) in `GenAuctionValidatorBlueprint.hs` before generating the blueprint.
* **Extend** the contract logic in `src/AuctionValidator.hs` and re-run tests to ensure correctness.

## 8. 📖 Glossary

| Term              | Description                                                                        |
| ----------------- | ---------------------------------------------------------------------------------- |
| **Cabal**         | Haskell’s package manager and build tool.                                          |
| **GHC**           | The Glasgow Haskell Compiler.                                                      |
| **Plutus**        | Cardano’s on-chain smart contract platform.                                        |
| **TxInfo**        | Metadata about a transaction passed to a Plutus validator.                         |
| **ScriptContext** | Context for script execution, including `TxInfo` and `ScriptPurpose`.              |
| **AssocMap**      | Plutus’s internal map type for associating keys to values (e.g., Datum, Redeemer). |
| **hspec**         | A behavior-driven testing framework for Haskell.                                   |
| **QuickCheck**    | A property-based testing library for Haskell.                                      |
| **Blueprint**     | JSON representation of a Plutus script and its parameters, for off-chain tooling.  |

---

*Updated by Coxygen Global - Bernard Sibanda*
*Date: 12 May 2025*

---

# 📦 Auction Validator Project

### Updated by Coxygen Global - Bernard Sibanda

## 📑 Table of Contents

1. [⚙️ Project Overview](#1. ⚙️ Project Overview)
2. [⚙️ Environment Setup](#2. ⚙️ Environment Setup)
3. [📂 Directory Structure](#3. 📂 Directory Structure)
4. [🛠️ Installation & Build](#4. 🛠️ Installation & Build)
5. [🔬 Testing](#5. 🔬 Testing)
6. [🧪 Property-Based Testing](#6. 🧪 Property-Based Testing)
7. [🚀 Usage](#7. 🚀 Usage)
8. [📖 Glossary](#8. 📖 Glossary)

---

## 1. ⚙️ Project Overview

This repository contains a Plutus-based Auction Validator smart contract along with tooling to generate Blueprints and comprehensive test suites. It is part of the **Plinth Template** for teaching on-chain development on Cardano.

## 2. ⚙️ Environment Setup

Follow these steps to prepare your environment:

```bash
# 1. Enter the Nix shell (requires Nix installed)
nix-shell

# 2. Update Cabal package index
cabal update

# 3. Ensure project dependencies are available
cabal build --enable-tests
```

> **Note:** If you do not use Nix, skip the `nix-shell` step and ensure you have GHC and Cabal installed via the Haskell Platform.

## 3. 📂 Directory Structure

```text
auction/                     # Project root
├── app/                     # Executables for Blueprint generation
│   ├── GenAuctionValidatorBlueprint.hs
│   └── GenMintingPolicyBlueprint.hs
├── src/                     # On-chain library modules
│   └── AuctionValidator.hs
├── test/                    # Test suite files
│   ├── AuctionValidatorSpec.hs            # Unit tests
│   ├── AuctionMintingPolicySpec.hs        # Minting policy tests
│   └── AuctionValidatorProperties.hs      # QuickCheck properties
├── default.nix              # Nix definition (if applicable)
├── shell.nix                # Nix shell entry (if applicable)
├── auction.cabal            # Cabal project configuration
├── cabal.project            # Root project settings
└── cabal.project.local      # Local overrides (e.g., tests: True)
```

## 4. 🛠️ Installation & Build

1. **Enter Nix shell (optional)**:

   ```bash
   nix-shell
   ```
2. **Update Cabal index**:

   ```bash
   cabal update
   ```
3. **Install dependencies & build**:

   ```bash
   cabal build --enable-tests
   ```
4. **Generate Blueprints**:

   ```bash
   cabal run gen-auction-validator-blueprint -- ./blueprint-auction.json
   cabal run gen-minting-policy-blueprint -- ./blueprint-minting.json
   ```

## 5. 🔬 Testing

### Run Unit Tests

```bash
cabal test auction-tests
```

### Run All Tests

```bash
cabal test
```

* **`auction-tests`**: Unit tests for the Auction Validator.
* **`minting-tests`**: Unit tests for the Minting Policy (if configured).

## 6. 🧪 Property-Based Testing

To verify invariants using QuickCheck:

1. Add a QuickCheck test suite entry in your `.cabal`:

   ```cabal
   test-suite auction-properties
     type: exitcode-stdio-1.0
     main-is: AuctionValidatorProperties.hs
     hs-source-dirs: test
     build-depends:
         base >=4.7 && <5,
       , scripts,
       , QuickCheck,
       , plutus-ledger-api,
       , plutus-tx,
       , test-framework
     default-language: Haskell2010
   ```
2. Run the property suite:

   ```bash
   cabal test auction-properties
   ```

## 7. 🚀 Usage

* **Deploy** your compiled Plutus script on a Cardano network by submitting the generated blueprint JSON via your deployment tooling.
* **Customize** `AuctionParams` (seller, currency symbol, token name, minimum bid, end time) in `GenAuctionValidatorBlueprint.hs` before generating the blueprint.
* **Extend** the contract logic in `src/AuctionValidator.hs` and re-run tests to ensure correctness.

## 8. 📖 Glossary

| Term              | Description                                                                        |
| ----------------- | ---------------------------------------------------------------------------------- |
| **Cabal**         | Haskell’s package manager and build tool.                                          |
| **GHC**           | The Glasgow Haskell Compiler.                                                      |
| **Plutus**        | Cardano’s on-chain smart contract platform.                                        |
| **TxInfo**        | Metadata about a transaction passed to a Plutus validator.                         |
| **ScriptContext** | Context for script execution, including `TxInfo` and `ScriptPurpose`.              |
| **AssocMap**      | Plutus’s internal map type for associating keys to values (e.g., Datum, Redeemer). |
| **hspec**         | A behavior-driven testing framework for Haskell.                                   |
| **QuickCheck**    | A property-based testing library for Haskell.                                      |
| **Blueprint**     | JSON representation of a Plutus script and its parameters, for off-chain tooling.  |

---

*Updated by Coxygen Global - Bernard Sibanda*
*Date: 12 May 2025*
