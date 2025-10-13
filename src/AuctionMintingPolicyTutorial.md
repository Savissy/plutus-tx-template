# 🧠 **1.  The Auction Minting Policy Logic**

This module implements the **core Plutus minting policy** that controls **token creation** for an auction system on Cardano.
It ensures that:

1. Only an **authorized wallet (public key hash)** can mint the token.
2. Exactly **one token** is minted during the transaction.


# ⚙️ **2. Language Extensions and GHC Options**

```haskell
{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ImportQualifiedPost        #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE PatternSynonyms            #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE Strict                     #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE ViewPatterns               #-}
{-# OPTIONS_GHC -fno-full-laziness #-}
{-# OPTIONS_GHC -fno-ignore-interface-pragmas #-}
{-# OPTIONS_GHC -fno-omit-interface-pragmas #-}
{-# OPTIONS_GHC -fno-spec-constr #-}
{-# OPTIONS_GHC -fno-specialise #-}
{-# OPTIONS_GHC -fno-strictness #-}
{-# OPTIONS_GHC -fno-unbox-small-strict-fields #-}
{-# OPTIONS_GHC -fno-unbox-strict-fields #-}
{-# OPTIONS_GHC -fplugin-opt PlutusTx.Plugin:target-version=1.1.0 #-}
```

### 💡 Key Highlights

* **`TemplateHaskell`**: Enables embedding of Plutus Core code into Haskell.
* **`Strict`**: Enforces strict evaluation for reliability in on-chain code.
* **`PlutusTx.Plugin`**: Instructs GHC to compile with the **Plutus compiler plugin**, targeting version 1.1.0.
* The `-fno-*` options ensure **accurate compilation** to Plutus Core by disabling Haskell optimizations that may change semantics.


# 📦 **3. Module and Imports**

```haskell
module AuctionMintingPolicy where

import PlutusCore.Version (plcVersion110)
import PlutusLedgerApi.V3 (PubKeyHash, ScriptContext(..), TxInfo(..), mintValueMinted)
import PlutusLedgerApi.V1.Value (flattenValue)
import PlutusLedgerApi.V3.Contexts (ownCurrencySymbol, txSignedBy)
import PlutusTx
import PlutusTx.Prelude qualified as PlutusTx
```

### 🧩 Breakdown

* **`PlutusLedgerApi.V3`**: Core Plutus types such as `ScriptContext`, `TxInfo`, and `PubKeyHash`.
* **`flattenValue`**: Flattens a `Value` into a list of `(CurrencySymbol, TokenName, Quantity)`.
* **`txSignedBy`**: Checks whether a given transaction was signed by a specific public key hash.
* **`ownCurrencySymbol`**: Retrieves the minting policy’s own identifier (hash).
* **`PlutusTx.Prelude`**: Plutus-safe replacements for standard Haskell Prelude.


# 🏷️ **4. Defining Types for the Policy**

```haskell
type AuctionMintingParams = PubKeyHash
type AuctionMintingRedeemer = ()
```

### 🧠 Explanation

* **`AuctionMintingParams`**: The *parameter* for the policy — identifies the **authorized seller** allowed to mint.
* **`AuctionMintingRedeemer`**: Defined as `()`, since this minting policy doesn’t require redeemer data.


# 🧮 **5. Typed Minting Policy Logic**

```haskell
{-# INLINEABLE auctionTypedMintingPolicy #-}
auctionTypedMintingPolicy ::
  AuctionMintingParams ->
  ScriptContext ->
  Bool
auctionTypedMintingPolicy pkh ctx@(ScriptContext txInfo _ _) =
  txSignedBy txInfo pkh PlutusTx.&& mintedExactlyOneToken
  where
    mintedExactlyOneToken = case flattenValue (mintValueMinted (txInfoMint txInfo)) of
      [(currencySymbol, _tokenName, quantity)] ->
        currencySymbol PlutusTx.== ownCurrencySymbol ctx PlutusTx.&& quantity PlutusTx.== 1
      _ -> False
```

### 🔍 Step-by-Step Breakdown

#### 🪙 1. Parameters

* **`pkh`**: Authorized minter’s public key hash.
* **`ctx`**: The **script execution context**, containing transaction details.

#### 🧾 2. Authorization Check

```haskell
txSignedBy txInfo pkh
```

* Ensures the transaction was **signed by the seller** (the only one allowed to mint).

#### 💰 3. Mint Quantity Check

```haskell
flattenValue (mintValueMinted (txInfoMint txInfo))
```

* Extracts all minted assets from the transaction.
* Checks that exactly **one token** was minted under this policy.

#### ✅ 4. Combined Rule

```haskell
txSignedBy txInfo pkh && mintedExactlyOneToken
```

* The minting policy succeeds **only if both conditions** are true.


# 🔁 **6. Untyped Minting Policy Wrapper**

```haskell
auctionUntypedMintingPolicy ::
  AuctionMintingParams ->
  BuiltinData ->
  PlutusTx.BuiltinUnit
auctionUntypedMintingPolicy pkh ctx =
  PlutusTx.check
    ( auctionTypedMintingPolicy
        pkh
        (PlutusTx.unsafeFromBuiltinData ctx)
    )
```

### 🧩 Purpose

The **untyped policy** acts as a wrapper so it can run in the on-chain Plutus interpreter, which uses **`BuiltinData`** (binary-encoded data).

* Converts `BuiltinData` to a `ScriptContext` using `unsafeFromBuiltinData`.
* Uses `PlutusTx.check` to enforce that the boolean result of the typed policy is **True**, otherwise fails.


# 🧬 **7. Compiling the Policy Script**

```haskell
auctionMintingPolicyScript ::
  AuctionMintingParams ->
  CompiledCode (BuiltinData -> PlutusTx.BuiltinUnit)
auctionMintingPolicyScript pkh =
  $$(PlutusTx.compile [||auctionUntypedMintingPolicy||])
    `PlutusTx.unsafeApplyCode` PlutusTx.liftCode plcVersion110 pkh
```

### ⚗️ Explanation

* **`PlutusTx.compile`**: Converts the minting policy to on-chain **Plutus Core code**.
* **`unsafeApplyCode`**: Applies the `pkh` parameter to the compiled function.
* **`liftCode plcVersion110 pkh`**: Lifts the parameter to Plutus Core representation compatible with version 1.1.0.

This produces a **compiled minting policy** ready for serialization and inclusion in a **blueprint**.


# 📜 **8. Summary of the Minting Logic**

| Step | Check                                       | Description                   |
| ---- | ------------------------------------------- | ----------------------------- |
| 1    | ✅ `txSignedBy txInfo pkh`                   | Only authorized user can mint |
| 2    | ✅ `quantity == 1`                           | Exactly one token minted      |
| 3    | ✅ `currencySymbol == ownCurrencySymbol ctx` | Token is from this policy     |
| 4    | ❌ Otherwise                                 | Transaction fails validation  |


# 📚 **9. Glossary of Key Terms**

| Term                  | Description                                                            |
| --------------------- | ---------------------------------------------------------------------- |
| **Minting Policy**    | A Plutus script that defines rules for token creation or burning.      |
| **ScriptContext**     | Contains information about the transaction that runs the script.       |
| **TxInfo**            | Record inside the context containing inputs, outputs, and signatories. |
| **PubKeyHash (pkh)**  | Identifies the authorized wallet allowed to mint tokens.               |
| **flattenValue**      | Deconstructs a token `Value` into a list of tuples.                    |
| **ownCurrencySymbol** | The identifier (hash) of the minting policy itself.                    |
| **txSignedBy**        | Verifies whether a given public key signed the transaction.            |
| **BuiltinData**       | Serialized binary format used for data on-chain.                       |
| **CompiledCode**      | The Plutus Core representation of your compiled Haskell function.      |
| **liftCode**          | Converts Haskell values into Plutus Core for embedding as parameters.  |


# 🧩 **10. Final Thoughts**

This module defines the **on-chain logic** that underpins your **auction minting policy blueprint**.
By combining this logic with your previous **blueprint modules**, you now have:

* ✅ A **secure** minting policy that restricts unauthorized minting.
* ✅ A **typed and untyped** Plutus interface for flexibility.
* ✅ A **compiled blueprint-ready script** for integration with wallets and dApps.

Together, these components form a complete **auction token issuance workflow** for Cardano smart contracts.


