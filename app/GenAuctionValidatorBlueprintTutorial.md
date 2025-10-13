# 🧠 **1.  The Auction Validator Blueprint**

This tutorial walks you through creating a **Plutus smart contract blueprint** in Haskell that defines, serializes, and exports an **auction validator**.
You’ll learn how each part of the code contributes to the contract lifecycle — from defining parameters to generating blueprint files.


# ⚙️ **2. Enabling GHC Language Extensions**

```haskell
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE DerivingStrategies    #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NumericUnderscores    #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE UndecidableInstances  #-}
```

### 💡 Explanation

* These pragmas enable advanced Haskell language features required by **Plutus** and **Template Haskell**-based modules.
* For example:

  * `GADTs` → enables precise data types.
  * `TypeApplications` → allows specifying type parameters explicitly.
  * `OverloadedStrings` → allows `String` literals to represent `ByteString`, `Text`, etc.


# 📦 **3. Module and Imports**

```haskell
module Main where

import           AuctionValidator
import qualified Data.ByteString.Short       as Short
import qualified Data.Set                    as Set
import           PlutusLedgerApi.Common      (serialiseCompiledCode)
import qualified PlutusLedgerApi.V1.Crypto   as Crypto
import qualified PlutusLedgerApi.V1.Time     as Time
import qualified PlutusLedgerApi.V1.Value    as Value
import           PlutusTx.Blueprint
import           PlutusTx.Builtins.HasOpaque (stringToBuiltinByteStringHex)
import           System.Environment          (getArgs)
```

### 🧩 Key Points

* **`AuctionValidator`**: Your custom Plutus validator module.
* **`PlutusTx.Blueprint`**: Generates contract blueprints for on-chain deployment.
* **`Crypto`, `Time`, `Value`**: Provide key types for public keys, timestamps, and token values.
* **`serialiseCompiledCode`**: Converts compiled Plutus Core to a serializable format for export.


# 💰 **4. Defining Auction Parameters**

```haskell
auctionParams :: AuctionParams
auctionParams =
  AuctionParams
    { apSeller = Crypto.PubKeyHash (
        stringToBuiltinByteStringHex "0000..."
      )
    , apCurrencySymbol = Value.CurrencySymbol (
        stringToBuiltinByteStringHex "0000..."
      )
    , apTokenName = Value.tokenName "MY_TOKEN"
    , apMinBid = 100
    , apEndTime = Time.fromMilliSeconds 1_725_227_091_000
    }
```

### 🧠 Explanation

* Defines **compile-time configuration** for your auction.
* `apSeller` is the **public key hash** of the auction creator.
* `apCurrencySymbol` and `apTokenName` define which token is being auctioned.
* `apMinBid` sets the minimum bid in **lovelace** (₳1 = 1,000,000 lovelace).
* `apEndTime` specifies when the auction closes.


# 🧾 **5. Defining the Contract Blueprint**

```haskell
myContractBlueprint :: ContractBlueprint
myContractBlueprint =
  MkContractBlueprint
    { contractId = Just "auction-validator"
    , contractPreamble = myPreamble
    , contractValidators = Set.singleton myValidator
    , contractDefinitions =
        deriveDefinitions @[AuctionParams, AuctionDatum, AuctionRedeemer]
    }
```

### 📘 What This Does

* Creates a **blueprint document** that defines:

  * The **unique contract ID**.
  * The **preamble** (metadata).
  * The **validator(s)** used in the contract.
  * Auto-derived type definitions (`AuctionParams`, `AuctionDatum`, `AuctionRedeemer`).


# 🏷️ **6. Adding Metadata (Preamble)**

```haskell
myPreamble :: Preamble
myPreamble =
  MkPreamble
    { preambleTitle = "Auction Validator"
    , preambleDescription =
        Just "Blueprint for a Plutus script validating auction transactions"
    , preambleVersion = "1.0.0"
    , preamblePlutusVersion = PlutusV2
    , preambleLicense = Just "MIT"
    }
```

### 🧩 Explanation

The **preamble** describes your contract for **Blueprint JSON output**, including:

* **Title** and **Description**
* **Versioning**
* **Plutus version (V2)** for compatibility
* **License information**


# 🧮 **7. Creating the Validator Blueprint**

```haskell
myValidator :: ValidatorBlueprint referencedTypes
myValidator =
  MkValidatorBlueprint
    { validatorTitle = "Auction Validator"
    , validatorDescription =
        Just "Plutus script validating auction transactions"
    , validatorParameters =
        [ MkParameterBlueprint
            { parameterTitle = Just "Parameters"
            , parameterDescription = Just "Compile-time validator parameters"
            , parameterPurpose = Set.singleton Spend
            , parameterSchema = definitionRef @AuctionParams
            }
        ]
    , validatorRedeemer =
        MkArgumentBlueprint
          { argumentTitle = Just "Redeemer"
          , argumentDescription = Just "Redeemer for the auction validator"
          , argumentPurpose = Set.fromList [Spend]
          , argumentSchema = definitionRef @()
          }
    , validatorDatum = Nothing
    , validatorCompiled = do
        let script = auctionValidatorScript auctionParams
        let code = Short.fromShort (serialiseCompiledCode script)
        Just (compiledValidator PlutusV2 code)
    }
```

### 🧠 Step-by-Step

1. **Metadata**

   * `validatorTitle` and `validatorDescription` describe the validator.
2. **Parameters Section**

   * `parameterSchema` references `AuctionParams` for compile-time constants.
3. **Redeemer Section**

   * Defines what data type (`()`) the redeemer uses at runtime.
4. **Compilation Section**

   * Serializes and embeds the **compiled Plutus script** into the blueprint.


# 💾 **8. Writing the Blueprint File**

```haskell
writeBlueprintToFile :: FilePath -> IO ()
writeBlueprintToFile path = writeBlueprint path myContractBlueprint
```

### 📤 Purpose

* Writes the **contract blueprint** to a file in JSON format.
* Enables **off-chain tools** (like `aiken` or `plutus-blueprint`) to interpret the validator structure.


# 🚀 **9. Main Entry Point**

```haskell
main :: IO ()
main =
  getArgs >>= \case
    [arg] -> writeBlueprintToFile arg
    args -> fail $ "Expects one argument, got " <> show (length args)
```

### 🧩 Usage

* Expects **one command-line argument**: the output path for the blueprint file.
* Example:

  ```bash
  cabal run auction-blueprint ./auction-blueprint.json
  ```


# 🧭 **10. Execution Summary**

| Step | Action                    | Output                   |
| ---- | ------------------------- | ------------------------ |
| 1    | Define Auction Parameters | `AuctionParams`          |
| 2    | Create Validator          | Serialized Plutus Script |
| 3    | Combine in Blueprint      | `ContractBlueprint`      |
| 4    | Export to File            | `auction-blueprint.json` |


# 📚 **Glossary of Terms**

| Term                      | Meaning                                                                             |
| ------------------------- | ----------------------------------------------------------------------------------- |
| **Blueprint**             | A JSON description of a smart contract and its metadata for tooling and deployment. |
| **Validator**             | A Plutus script that enforces spending conditions on UTxOs.                         |
| **Redeemer**              | Data provided when consuming a UTxO (used by the validator).                        |
| **Datum**                 | On-chain data attached to UTxOs.                                                    |
| **AuctionParams**         | Compile-time parameters such as seller, token info, and auction end time.           |
| **PlutusV2**              | The current version of the Plutus smart contract platform.                          |
| **serialiseCompiledCode** | Converts compiled Plutus Core to binary for on-chain execution.                     |
| **Spend**                 | Purpose indicating the validator is used when spending a UTxO.                      |
| **ByteString**            | Binary data type used in Plutus for cryptographic operations.                       |
| **Lovelace**              | The smallest unit of ADA (1 ADA = 1,000,000 lovelace).                              |


# 🧩 **11. Final Thoughts**

You’ve built a **fully defined Plutus contract blueprint** for an auction validator, ready for on-chain deployment or integration into Cardano dApps.
This design pattern — defining parameters, validators, and metadata — is reusable for any **parameterized smart contract**.

