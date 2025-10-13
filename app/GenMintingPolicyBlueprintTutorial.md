# 🧠 **1.  The Auction Minting Policy Blueprint**

This tutorial demonstrates how to build a **Plutus blueprint** for a **minting policy** in Haskell.
The minting policy defines **rules for token creation** (and optionally burning) — in this case, linked to an auction system.

You’ll learn how to:

* Define compile-time minting parameters.
* Create a Plutus blueprint for a **minting validator**.
* Export the compiled policy as a **JSON blueprint** file.


# ⚙️ **2. Enabling GHC Language Extensions**

```haskell
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ViewPatterns #-}
```

### 💡 Explanation

These **language pragmas** unlock advanced features required for:

* **Generic deriving** (`DeriveGeneric`, `DeriveAnyClass`)
* **Flexible type definitions** (`FlexibleContexts`, `MultiParamTypeClasses`)
* **Advanced data modeling** (`GADTs`, `DataKinds`)
* **Cleaner syntax** (`LambdaCase`, `RecordWildCards`, `ViewPatterns`)

They are standard in **Plutus development** for writing both **validators** and **minting policies**.


# 📦 **3. Module and Imports**

```haskell
module Main where

import AuctionMintingPolicy
import Data.ByteString.Short qualified as Short
import Data.Set qualified as Set
import PlutusLedgerApi.Common (serialiseCompiledCode)
import PlutusTx.Blueprint
import System.Environment (getArgs)
```

### 🧩 Key Components

* **`AuctionMintingPolicy`**: The module containing your minting logic.
* **`PlutusTx.Blueprint`**: Provides constructors for generating blueprints.
* **`serialiseCompiledCode`**: Serializes Plutus Core code into binary form.
* **`Set` & `Short`**: Used for efficient collections and byte operations.
* **`getArgs`**: Reads command-line arguments for dynamic file output.


# 🧱 **4. Defining the Contract Blueprint**

```haskell
myContractBlueprint :: ContractBlueprint
myContractBlueprint =
  MkContractBlueprint
    { contractId = Just "auction-minting-policy"
    , contractPreamble = myPreamble
    , contractValidators = Set.singleton myValidator
    , contractDefinitions = deriveDefinitions @[AuctionMintingParams, ()]
    }
```

### 🧠 Explanation

This defines the overall **contract structure**:

* `contractId` → Unique identifier for this blueprint.
* `contractPreamble` → Metadata about the contract (title, version, etc.).
* `contractValidators` → A set containing one **minting validator**.
* `contractDefinitions` → Auto-generated type schema for parameters (`AuctionMintingParams`) and redeemer `()`.


# 🏷️ **5. Writing the Preamble (Metadata Section)**

```haskell
myPreamble :: Preamble
myPreamble =
  MkPreamble
    { preambleTitle = "Auction Minting Policy"
    , preambleDescription = Just "A simple minting policy"
    , preambleVersion = "1.0.0"
    , preamblePlutusVersion = PlutusV2
    , preambleLicense = Just "MIT"
    }
```

### 📘 Purpose

The preamble defines **contract metadata**:

* **Title & Description** → Human-readable identification.
* **Version** → Tracks compatibility and changes.
* **PlutusV2** → Ensures compatibility with Plutus smart contract version 2.
* **License** → Legal usage declaration (MIT license).


# 🧮 **6. Creating the Minting Validator Blueprint**

```haskell
myValidator :: ValidatorBlueprint referencedTypes
myValidator =
  MkValidatorBlueprint
    { validatorTitle = "Auction Minting Validator"
    , validatorDescription = Just "A simple minting validator"
    , validatorParameters =
        [ MkParameterBlueprint
            { parameterTitle = Just "Minting Validator Parameters"
            , parameterDescription = Just "Compile-time validator parameters"
            , parameterPurpose = Set.singleton Mint
            , parameterSchema = definitionRef @AuctionMintingParams
            }
        ]
    , validatorRedeemer =
        MkArgumentBlueprint
          { argumentTitle = Just "Redeemer for the minting policy"
          , argumentDescription = Just "The minting policy does not use a redeemer, hence ()"
          , argumentPurpose = Set.fromList [Mint]
          , argumentSchema = definitionRef @()
          }
    , validatorDatum = Nothing
    , validatorCompiled = do 
        let script = auctionMintingPolicyScript (error "Replace with seller public key hash")
        let code = Short.fromShort (serialiseCompiledCode script) 
        Just (compiledValidator PlutusV2 code)
    }
```


### 🧩 Section Breakdown

#### 🪙 **Parameters**

* `parameterPurpose = Mint`
  → Indicates this blueprint applies to a **minting policy** (not spending or staking).
* `parameterSchema`
  → Connects to `AuctionMintingParams`, defining constants like authorized minter or auction settings.

#### 🔁 **Redeemer**

* The redeemer is set to `()` because **no redeemer** is required when minting in this policy.
  Plutus minting policies often use only the context and parameters.

#### 🧰 **Compilation**

```haskell
let script = auctionMintingPolicyScript (error "Replace with seller public key hash")
let code = Short.fromShort (serialiseCompiledCode script)
Just (compiledValidator PlutusV2 code)
```

* Compiles the **on-chain minting policy**.
* `serialiseCompiledCode` converts it into a **binary format** that can be embedded in the blueprint.
* The placeholder `error "Replace with seller public key hash"` should be replaced with an **actual `PubKeyHash`**.


# 💾 **7. Writing the Blueprint File**

```haskell
writeBlueprintToFile :: FilePath -> IO ()
writeBlueprintToFile path = writeBlueprint path myContractBlueprint
```

### 📤 Functionality

* Saves the contract blueprint as a **`.json`** file.
* Used for integrating the policy into wallets, off-chain code, or blueprint explorers.


# 🚀 **8. The Main Entry Point**

```haskell
main :: IO ()
main =
  getArgs >>= \case
    [arg] -> writeBlueprintToFile arg
    args -> fail $ "Expects one argument, got " <> show (length args)
```

### 💡 Usage

This simple CLI entry point expects **one argument**: the file path for output.

Example command:

```bash
cabal run auction-minting-blueprint ./minting-blueprint.json
```


# 🧭 **9. Summary Workflow**

| Step | Description                                        | Output                  |
| ---- | -------------------------------------------------- | ----------------------- |
| 1    | Define Minting Parameters (`AuctionMintingParams`) | Policy configuration    |
| 2    | Define Preamble Metadata                           | Human-readable metadata |
| 3    | Build Validator Blueprint                          | Binary Plutus script    |
| 4    | Serialize & Write Blueprint                        | JSON blueprint file     |


# 📚 **10. Glossary of Key Terms**

| Term                      | Description                                                         |
| ------------------------- | ------------------------------------------------------------------- |
| **Minting Policy**        | A Plutus script that defines rules for creating or burning tokens.  |
| **Blueprint**             | JSON-based metadata format describing Plutus contracts and scripts. |
| **Validator**             | In this context, a compiled minting policy script.                  |
| **Redeemer**              | Input data passed to a script when executing (unused here → `()`).  |
| **AuctionMintingParams**  | Type containing fixed parameters like authorized key or auction ID. |
| **PlutusV2**              | The latest Plutus script version used for Cardano smart contracts.  |
| **serialiseCompiledCode** | Converts compiled Plutus code into a portable binary.               |
| **Mint**                  | Validator purpose indicating token creation/burning logic.          |
| **ContractBlueprint**     | Aggregates preamble, validators, and type definitions.              |
| **PubKeyHash**            | A hashed form of a public key, used for authentication in Plutus.   |


# 🧩 **11. Final Thoughts**

You’ve now built a **minting policy blueprint** that defines the token minting logic for an **auction-based system**.
This structure parallels the **auction validator** blueprint but focuses on **token issuance**, ensuring **secure and rule-based minting** on the Cardano blockchain.

