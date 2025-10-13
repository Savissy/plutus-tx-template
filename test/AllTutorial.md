# 🧠 **1. Introduction: Testing the Auction Validator**

This module defines **unit and property-based tests** for your Plutus `AuctionValidator`.
It uses:

* **Hspec** → to write behavior-driven tests.
* **QuickCheck** → to generate randomized property-based tests.
* A **mock `ScriptContext`** → to simulate blockchain transactions.

The goal is to verify that your **auction validation logic** behaves correctly in all key scenarios — new bids, lower bids, and payouts.


# ⚙️ **2. Language Extensions and Imports**

```haskell
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE StandaloneDeriving #-}
```

### 💡 Explanation

* `OverloadedStrings` → allows using string literals for `ByteString` and `Text`.
* `NumericUnderscores` → improves readability of large numeric literals (e.g., `1_000_000`).
* `TypeApplications` → makes generic type instantiation explicit.
* `StandaloneDeriving` → allows manual instance declarations if needed.


# 📦 **3. Imported Modules**

```haskell
import Test.Hspec
import Test.QuickCheck
import Test.Hspec.QuickCheck (modifyMaxSuccess)

import AuctionValidator

import PlutusLedgerApi.V1.Crypto (PubKeyHash (..))
import PlutusLedgerApi.V1 (Lovelace (..))
import PlutusLedgerApi.V1.Interval (always)
import PlutusLedgerApi.V2 (...)
import PlutusLedgerApi.V2.Contexts (...)
import qualified PlutusTx.AssocMap as AssocMap
```

### 🧩 Summary of Roles

* **`Test.Hspec`** → defines `describe` and `it` blocks for unit testing.
* **`Test.QuickCheck`** → defines `Property` tests with random data generation.
* **`AuctionValidator`** → imports your on-chain logic under test.
* **`PlutusLedgerApi`** → provides types for mock blockchain contexts.


# 🧱 **4. Arbitrary Instances for Property Testing**

```haskell
instance Arbitrary Bid where
  arbitrary = do
    addr <- elements ["addr1", "addr2", "addr3"]
    key  <- elements ["bidder1", "bidder2", "bidder3"]
    amt  <- Lovelace <$> choose (1, 1_000_000)
    return $ Bid addr (PubKeyHash key) amt

instance Arbitrary PubKeyHash where
  arbitrary = PubKeyHash <$> elements ["pkh1", "pkh2", "pkh3"]
```

### 🎲 Explanation

* Enables **QuickCheck** to randomly generate:

  * Different bidders (`addr`, `key`).
  * Random bid amounts in lovelace.
* Allows the test suite to **automatically check multiple cases** without manual input.


# 🧩 **5. Mocking a Plutus Script Context**

```haskell
mockScriptContext :: ScriptContext
mockScriptContext =
  ScriptContext
    { scriptContextTxInfo = TxInfo
        { txInfoInputs           = []
        , txInfoReferenceInputs  = []
        , txInfoOutputs          = []
        , txInfoFee              = mempty
        , txInfoMint             = mempty
        , txInfoDCert            = []
        , txInfoWdrl             = AssocMap.empty
        , txInfoValidRange       = always
        , txInfoSignatories      = []
        , txInfoData             = AssocMap.empty
        , txInfoId               = TxId ""
        , txInfoRedeemers        = AssocMap.empty
        }
    , scriptContextPurpose = Spending (TxOutRef (TxId "") 0)
    }
```

### 🧠 What It Does

* **Simulates a transaction environment** where:

  * No actual inputs/outputs exist (`[]`).
  * The valid range is unbounded (`always`).
  * The purpose is **Spending**, representing a contract UTxO being spent.

This lets you run `auctionTypedValidator` in isolation — without connecting to the real blockchain.


# 🧪 **6. Property-Based Tests**

These tests verify **general properties** about the auction logic, independent of specific hardcoded inputs.


### ✅ **Property 1: `property_newBidHigherThanPrevious`**

```haskell
property_newBidHigherThanPrevious :: Bid -> Bid -> Property
property_newBidHigherThanPrevious prev newBid =
  (bAmount newBid > bAmount prev)
     ==> not (auctionTypedValidator params datum redeemer mockScriptContext)
```

💡 **Expected Behavior:**
Even if the new bid is higher, with the mock context (no outputs), it still fails — ensuring the validator **requires outputs** like refund and continuing UTxOs.


### ❌ **Property 2: `property_newBidLowerRejected`**

```haskell
(bAmount newBid <= bAmount prev)
     ==> not (auctionTypedValidator params datum redeemer mockScriptContext)
```

💡 **Expected Behavior:**
A lower or equal bid must always be **rejected** by the validator.


# 🧾 **7. Hspec Test Suite**

The Hspec tests verify **specific expected behaviors** using controlled input values.


### 🧱 **Test 1: Rejects new bid with no outputs**

```haskell
auctionTypedValidator params datum redeemer mockScriptContext
  `shouldBe` False
```

Ensures the contract fails when there’s **no continuing UTxO** (which should contain updated auction state).


### 💰 **Test 2: Accepts a higher new bid**

```haskell
auctionTypedValidator params (AuctionDatum (Just prev)) (NewBid newBid) mockScriptContext
  `shouldBe` False
```

Even though the new bid is higher, the lack of actual transaction outputs causes the validator to reject — confirming internal consistency.


### 🚫 **Test 3: Rejects lower bids**

```haskell
auctionTypedValidator params (AuctionDatum (Just prev)) (NewBid newBid) mockScriptContext
  `shouldBe` False
```

Lower or equal bids should fail validation regardless of context.


### 🏁 **Test 4: Allows payout after auction end**

```haskell
auctionTypedValidator params datum Payout mockScriptContext
  `shouldBe` False
```

Checks that **payout attempts** under an empty mock context also fail safely — confirming that **fund distribution rules** must be explicitly met.


# 🔄 **8. QuickCheck Integration**

```haskell
describe "QuickCheck properties" $ do
  modifyMaxSuccess (const 50) $ do
    it "accepts new bid if higher than previous" $
      property property_newBidHigherThanPrevious
    it "rejects new bid if lower or equal to previous" $
      property property_newBidLowerRejected
```

### 🧠 Explanation

* Runs each property test **50 times** with random data.
* Helps confirm that your validator behaves consistently across **multiple edge cases**.


# 📊 **9. Execution Summary**

| Type               | Tool                 | Purpose                                      |
| ------------------ | -------------------- | -------------------------------------------- |
| **Unit Tests**     | Hspec                | Validate known logical rules.                |
| **Property Tests** | QuickCheck           | Randomized input testing for robustness.     |
| **Mock Context**   | Simulated blockchain | Enables off-chain testing of on-chain logic. |


# 📚 **10. Glossary of Key Terms**

| Term                 | Meaning                                                             |
| -------------------- | ------------------------------------------------------------------- |
| **Hspec**            | Behavior-driven testing framework for Haskell.                      |
| **QuickCheck**       | Randomized property testing framework.                              |
| **Property**         | Logical statement about a function that should hold for all inputs. |
| **Mock Context**     | Simulated Plutus transaction environment for testing.               |
| **ScriptContext**    | Data structure describing the current transaction.                  |
| **Spending Purpose** | Indicates validator is used to unlock a UTxO.                       |
| **Bid**              | Structure containing bidder info and bid amount.                    |
| **Datum / Redeemer** | Persistent and transactional inputs to Plutus contracts.            |


# 🧩 **11. Final Thoughts**

This test suite ensures your **auction validator logic** behaves correctly across all critical paths — from bidding to payout.

By combining:

* **Unit testing** (for known scenarios), and
* **Property testing** (for generalized correctness),

You’ve built a **robust, reproducible test harness** for verifying Plutus contracts **without deploying to chain**.

