# 🧠 **1.  The Auction Validator**

This module implements the **on-chain validator logic** for a Cardano **auction smart contract**.
The validator ensures that:

* Only valid bids are accepted before the auction deadline.
* The highest bid wins the auction.
* The seller and winning bidder receive the correct payouts.

This code forms the **heart of the auction system**, used by your blueprint files to compile and serialize the validator into a deployable Plutus script.


# ⚙️ **2. Language Extensions and Compiler Options**

```haskell
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE Strict #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ViewPatterns #-}
{-# OPTIONS_GHC -fno-full-laziness #-}
{-# OPTIONS_GHC -fno-ignore-interface-pragmas #-}
{-# OPTIONS_GHC -fno-omit-interface-pragmas #-}
{-# OPTIONS_GHC -fno-spec-constr #-}
{-# OPTIONS_GHC -fno-specialise #-}
{-# OPTIONS_GHC -fno-strictness #-}
{-# OPTIONS_GHC -fno-unbox-small-strict-fields #-}
{-# OPTIONS_GHC -fno-unbox-strict-fields #-}
{-# OPTIONS_GHC -fplugin-opt PlutusTx.Plugin:target-version=1.0.0 #-}
```

### 💡 Explanation

* Enables **Template Haskell** for on-chain compilation.
* Enforces **strict evaluation** for deterministic execution.
* Disables certain GHC optimizations to maintain **on-chain consistency**.
* The **PlutusTx plugin** compiles Haskell code into Plutus Core (v1.0.0).


# 📦 **3. Module and Imports**

```haskell
module AuctionValidator where

import GHC.Generics (Generic)
import PlutusCore.Version (plcVersion100)
import PlutusLedgerApi.V1 (...)
import PlutusLedgerApi.V2 (...)
import PlutusLedgerApi.V2.Contexts (getContinuingOutputs)
import PlutusTx
import PlutusTx.AsData qualified as PlutusTx
import PlutusTx.Blueprint
import PlutusTx.Prelude qualified as PlutusTx
import PlutusTx.Show qualified as PlutusTx
import PlutusTx.List qualified as List
```

### 🧩 Key Imports

* **`PlutusLedgerApi.V1` & `V2`** → foundational Cardano types and scripts.
* **`getContinuingOutputs`** → retrieves the continuing UTxO for the contract.
* **`PlutusTx`** and **`Prelude`** → compile-safe functional toolkit.
* **`Blueprint`** → enables generation of off-chain contract metadata.


# 🧱 **4. Auction Parameters and Supporting Types**

### *(BLOCK1)*

```haskell
data AuctionParams = AuctionParams
  { apSeller         :: PubKeyHash
  , apCurrencySymbol :: CurrencySymbol
  , apTokenName      :: TokenName
  , apMinBid         :: Lovelace
  , apEndTime        :: POSIXTime
  } deriving stock (Generic)
    deriving anyclass (HasBlueprintDefinition)
```

### 💡 Explanation

Defines **contract configuration**:

* `apSeller`: Address of the auction creator.
* `apCurrencySymbol`, `apTokenName`: Identify the auctioned token.
* `apMinBid`: Minimum acceptable bid in lovelace.
* `apEndTime`: Deadline for placing bids.


### 🧍‍♂️ **Bid Type**

```haskell
data Bid = Bid
  { bAddr   :: PlutusTx.BuiltinByteString
  , bPkh    :: PubKeyHash
  , bAmount :: Lovelace
  }
```

Represents a participant’s bid.
Includes the bidder’s wallet address, public key hash, and bid amount.

### 📜 **Datum and Redeemer**

```haskell
newtype AuctionDatum = AuctionDatum {adHighestBid :: Maybe Bid}
data AuctionRedeemer = NewBid Bid | Payout
```

* **Datum** → stores state (current highest bid).
* **Redeemer** → defines user intent (either **place a bid** or **close auction**).


# 🔍 **5. The Typed Validator Function**

### *(BLOCK2–BLOCK7)*

```haskell
auctionTypedValidator ::
  AuctionParams -> AuctionDatum -> AuctionRedeemer -> ScriptContext -> Bool
auctionTypedValidator params (AuctionDatum highestBid) redeemer ctx@(ScriptContext txInfo _) =
  List.and conditions
  where
    conditions = case redeemer of
      NewBid bid -> [...]
      Payout     -> [...]
```

This is the **core validator** — it checks if a transaction spending the auction UTxO follows the auction rules.

Let’s break down both branches 👇


## 🏦 **6. Branch 1 — NewBid**

### 🧮 Conditions for a valid bid

```haskell
sufficientBid bid
validBidTime
refundsPreviousHighestBid
correctOutput bid
```

### ✅ 1. **sufficientBid**

```haskell
amt > amt'  or  amt >= apMinBid params
```

* Ensures the **new bid is higher** than the current one (or at least meets the minimum bid).


### ⏰ 2. **validBidTime**

```haskell
to (apEndTime params) `contains` txInfoValidRange txInfo
```

* The bid must occur **before the auction end time**.


### 💸 3. **refundsPreviousHighestBid**

```haskell
List.find (\o -> toPubKeyHash (txOutAddress o) == Just bidderPkh
          && lovelaceValueOf (txOutValue o) == amt)
```

* If there was a previous highest bidder, they must be **refunded**.


### 🧾 4. **correctOutput**

```haskell
getContinuingOutputs ctx
```

* Checks that there is **exactly one continuing output** (the new auction UTxO).
* Verifies that:

  * Its datum reflects the new **highest bid**.
  * Its value contains the **new bid amount** + **auctioned asset**.


## 🧧 **7. Branch 2 — Payout**

### 🧮 Conditions for a valid payout

```haskell
validPayoutTime
sellerGetsHighestBid
highestBidderGetsAsset
```

### 🕐 1. **validPayoutTime**

```haskell
from (apEndTime params) `contains` txInfoValidRange txInfo
```

* Auction can only close **after** the deadline.


### 💰 2. **sellerGetsHighestBid**

* Ensures the **seller** receives the **winning bid amount** in lovelace.


### 🪙 3. **highestBidderGetsAsset**

* Ensures the **winning bidder** (or seller if no bids) receives the **auctioned token**.


# 🧩 **8. Untyped Validator Wrapper**

### *(BLOCK8)*

```haskell
auctionUntypedValidator ::
  AuctionParams -> BuiltinData -> BuiltinData -> BuiltinData -> PlutusTx.BuiltinUnit
auctionUntypedValidator params datum redeemer ctx =
  PlutusTx.check
    ( auctionTypedValidator
        params
        (PlutusTx.unsafeFromBuiltinData datum)
        (PlutusTx.unsafeFromBuiltinData redeemer)
        (PlutusTx.unsafeFromBuiltinData ctx)
    )
```

### 🧠 Purpose

* Converts the **typed validator** to an **untyped** version, compatible with on-chain execution.
* All arguments (`datum`, `redeemer`, `ctx`) come in as **raw `BuiltinData`**.


# ⚗️ **9. Compiling the Validator Script**

```haskell
auctionValidatorScript ::
  AuctionParams ->
  CompiledCode (BuiltinData -> BuiltinData -> BuiltinData -> PlutusTx.BuiltinUnit)
auctionValidatorScript params =
  $$(PlutusTx.compile [||auctionUntypedValidator||])
    `PlutusTx.unsafeApplyCode` PlutusTx.liftCode plcVersion100 params
```

### 🔧 Explanation

* Compiles the validator into **Plutus Core** (version 1.0.0).
* Embeds the **auction parameters** (`AuctionParams`) as a compile-time constant.
* Produces a **ready-to-deploy validator script**.


# 🧱 **10. Supporting Schema Types**

### *(BLOCK9)*

```haskell
PlutusTx.asData
  [d|
    data Bid' = Bid' { bPkh' :: PubKeyHash, bAmount' :: Lovelace }
      deriving newtype (Eq, Ord, PlutusTx.ToData, FromData, UnsafeFromData)
    data AuctionRedeemer' = NewBid' Bid | Payout'
      deriving newtype (Eq, Ord, PlutusTx.ToData, FromData, UnsafeFromData)
  |]
```

### 🧩 Purpose

These alternative schema representations (`Bid'`, `AuctionRedeemer'`)
are for **Blueprint and off-chain interoperability**, allowing serialization and inspection by wallets or explorers.


# 📊 **11. Validation Summary**

| Action     | Validation Rules                                                               | On Success                               |
| ---------- | ------------------------------------------------------------------------------ | ---------------------------------------- |
| **NewBid** | Must be before end time, higher than previous, refund old bidder, update datum | Auction continues with new highest bid   |
| **Payout** | Must be after end time, pay seller, give asset to highest bidder               | Auction UTxO is consumed, auction closes |


# 📚 **12. Glossary of Key Terms**

| Term                           | Definition                                                    |
| ------------------------------ | ------------------------------------------------------------- |
| **Validator**                  | On-chain script that decides if a transaction is valid.       |
| **Datum**                      | Persistent on-chain data (contract state).                    |
| **Redeemer**                   | Action input that triggers contract logic.                    |
| **UTxO**                       | Unspent Transaction Output; represents locked contract funds. |
| **ScriptContext**              | Info about the transaction invoking the validator.            |
| **POSIXTime**                  | Plutus time format (milliseconds since epoch).                |
| **CurrencySymbol / TokenName** | Identifiers for the token being auctioned.                    |
| **CompiledCode**               | Serialized Plutus Core program ready for deployment.          |
| **from / to / contains**       | Interval functions for checking time validity.                |
| **traceError / traceIfFalse**  | On-chain debugging functions that abort or log messages.      |


# 🧩 **13. Final Thoughts**

This **AuctionValidator** module defines a complete **on-chain auction contract** in Plutus.
It enforces the lifecycle rules from bidding to payout with mathematical precision and **deterministic validation**.

Combined with your **minting policy** and **blueprint scripts**, you now have a **full-stack auction dApp**:

1. **Minting Policy** — controls token creation.
2. **Validator** — enforces bidding and payout.
3. **Blueprints** — provide metadata for off-chain integration.

