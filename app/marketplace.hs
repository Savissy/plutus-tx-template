{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE DeriveAnyClass        #-}
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}

\-- Simple NFT Marketplace (educational, minimal)
\-- On-chain validator + off-chain contract endpoints (list, buy, delist)
-------------------------------------------------------------------------

\-- Notes:
\-- \* This is a simplified educational example. Real marketplace contracts need
\--   additional checks (reentrancy, fee/royalty accounting, datum size limits,
\--   handling multiple outputs, safety around token bundles, etc.)
\-- \* Requires a Plutus development environment (plutus-ledger-api, plutus-contract).
\-- \* You may need to adjust imports and minor API names to match the Plutus
\--   release you are using.
----------------------------

module Marketplace where

import qualified Plutus.V2.Ledger.Api      as V2
import qualified Plutus.V1.Ledger.Value    as V1
import           PlutusTx                   (BuiltinData, compile, CompiledCode)
import qualified PlutusTx
import           PlutusTx.Prelude           hiding (Semigroup(..), unless)
import           Prelude                    (Show)
import qualified Prelude                    as H

\-- Off-chain libraries
import           Ledger                     (PaymentPubKeyHash (..), TxOutRef, txOutRefTxId, txOutRefIdx)
import qualified Ledger
import qualified Ledger.Constraints         as Constraints
import           Plutus.Contract            as Contract
import qualified Data.Aeson                 as Aeson
import qualified Data.Map                   as Map
import           GHC.Generics               (Generic)
import           Data.Text                  (Text)

\-- | Datum for a listing: who sells and at what price (lovelace)
data ListingDatum = ListingDatum
{ seller  :: PaymentPubKeyHash
, price   :: Integer         -- price in lovelace
, asset   :: V1.AssetClass   -- the NFT asset being sold (policyId+tokenName)
} deriving (Generic, Show)

PlutusTx.unstableMakeIsData ''ListingDatum
PlutusTx.makeLift ''ListingDatum

\-- | Redeemer indicates the action: Buy (spend & pay seller) or Cancel (seller cancels)
data ListingRedeemer = Buy | Cancel
deriving Show

PlutusTx.unstableMakeIsData ''ListingRedeemer
PlutusTx.makeLift ''ListingRedeemer

---

## -- On-chain validator

\-- Validate that:
\--  - For Buy: buyer pays the seller >= price and the NFT is consumed by buyer (we check that the output contains the token).
\--  - For Cancel: only the seller may cancel (the tx is signed by the seller).
{-# INLINABLE mkValidator #-}
mkValidator :: ListingDatum -> ListingRedeemer -> V2.ScriptContext -> Bool
mkValidator dat red ctx =
case red of
Buy    -> validateBuy dat ctx
Cancel -> validateCancel dat ctx

\-- Check buyer pays seller at least price and that NFT is included in outputs (basic checks).
{-# INLINABLE validateBuy #-}
validateBuy :: ListingDatum -> V2.ScriptContext -> Bool
validateBuy ListingDatum{seller=PaymentPubKeyHash sellerPkh, price=p, asset=assetClass} ctx =
let
info :: V2.TxInfo
info = V2.scriptContextTxInfo ctx

```
    -- total lovelace paid to seller's pubkey hash
    paidToSeller :: Integer
    paidToSeller =
      let outputs = V2.txInfoOutputs info
          payments = fmap (V2.txOutValue) outputs
          -- reduce to lovelace paid to the seller by checking PubKeyHash addresses
          amounts = fmap (\o -> if toSeller o then V1.valueOf (V2.txOutValue o) V1.adaSymbol V1.adaToken else 0) outputs
      in foldr (+) 0 amounts

    -- check output to seller's pubkey address
    toSeller :: V2.TxOut -> Bool
    toSeller o =
      case V2.txOutAddress o of
        V2.Address (V2.PubKeyCredential pkh) _ -> pkh == sellerPkh
        _                                      -> False

    -- simple check: at least one output contains the asset (buyer receiving)
    buyerGetsNFT :: Bool
    buyerGetsNFT =
      let hasAsset v = V1.assetClassValueOf (V1.valueFromValue v) assetClass >= 1
      in any (hasAsset . V2.txOutValue) (V2.txInfoOutputs info)
in
    traceIfFalse "insufficient payment to seller" (paidToSeller >= p) &&
    traceIfFalse "buyer must receive the asset" buyerGetsNFT
```

\-- Check only seller can cancel (tx signed by seller)
{-# INLINABLE validateCancel #-}
validateCancel :: ListingDatum -> V2.ScriptContext -> Bool
validateCancel ListingDatum{seller=PaymentPubKeyHash sellerPkh} ctx =
let info = V2.scriptContextTxInfo ctx
in traceIfFalse "seller's signature missing" (V2.txInfoSignatories info `contains` sellerPkh)

{-# INLINABLE contains #-}
contains :: \[V2.PubKeyHash] -> V2.PubKeyHash -> Bool
contains xs x = any (\y -> y == x) xs

\-- Compile validator
validator :: V2.Validator
validator = V2.mkValidatorScript \$\$(PlutusTx.compile \[|| wrap ||])
where
wrap = PlutusTx.applyCode (PlutusTx.liftCode mkValidator) (PlutusTx.liftCode ())

---

## -- Off-chain contract (very minimal)

type MarketplaceSchema =
Endpoint "list" ListParams
./ Endpoint "buy" BuyParams
./ Endpoint "cancel" CancelParams

data ListParams = ListParams
{ lpAsset :: V1.AssetClass
, lpPrice :: Integer
} deriving (Generic, ToJSON, FromJSON, Show)

data BuyParams = BuyParams
{ bpTxOutRef :: TxOutRef
} deriving (Generic, ToJSON, FromJSON, Show)

data CancelParams = CancelParams
{ cpTxOutRef :: TxOutRef
} deriving (Generic, ToJSON, FromJSON, Show)

\-- List: lock the NFT in a script UTxO with ListingDatum
listEndpoint :: AsContractError e => Promise () MarketplaceSchema e ()
listEndpoint = endpoint @"list" \$ \ListParams{lpAsset=assetClass, lpPrice=price} -> do
pkh <- Contract.ownPaymentPubKeyHash
utxos <- utxosAt (Ledger.pubKeyHashAddress (Ledger.unPaymentPubKeyHash pkh) Nothing)
\-- Find one UTxO that contains the asset
let mUtxo = findAssetUtxo assetClass utxos
case mUtxo of
Nothing -> Contract.logError @H.String "No UTxO found with that asset"
Just (oref, o) -> do
let datum = ListingDatum { seller = pkh, price = price, asset = assetClass }
tx   = Constraints.mustPayToTheScript datum (V1.assetClassValue assetClass 1)
<> Constraints.mustValidateIn (Ledger.toSlotRange Ledger.always)
<> Constraints.mustSpendPubKeyOutput oref
ledgerTx <- submitTxConstraints (V2.validatorScript validator) tx
awaitTxConfirmed \$ Ledger.getCardanoTxId ledgerTx
Contract.logInfo @H.String "Listed NFT"

\-- Buy: consume the script UTxO with Buy redeemer, paying seller
buyEndpoint :: AsContractError e => Promise () MarketplaceSchema e ()
buyEndpoint = endpoint @"buy" \$ \BuyParams{bpTxOutRef = oref} -> do
\-- Grab UTxO and datum from chain, construct spend.
utxos <- utxosAt (Ledger.scriptHashAddress \$ V2.validatorHash validator)
case Map.lookup oref utxos of
Nothing -> Contract.logError @H.String "Listing not found"
Just o  -> do
\-- extract datum from o
let datumMb = maybeTrace "no datum" (V2.txOutDatum o)
case datumMb of
Nothing -> Contract.logError @H.String "No datum attached"
Just d  -> do
\-- Build tx: spend script output with redeemer Buy, pay seller price
let redeemer = PlutusTx.toBuiltinData Buy
tx = Constraints.mustSpendScriptOutput oref (V2.Redeemer redeemer)
ledgerTx <- submitTxConstraintsSpending (V2.validatorScript validator) (Map.singleton oref o) tx
awaitTxConfirmed \$ Ledger.getCardanoTxId ledgerTx
Contract.logInfo @H.String "Bought NFT"

\-- Cancel: seller cancels the listing
cancelEndpoint :: AsContractError e => Promise () MarketplaceSchema e ()
cancelEndpoint = endpoint @"cancel" \$ \CancelParams{cpTxOutRef = oref} -> do
utxos <- utxosAt (Ledger.scriptHashAddress \$ V2.validatorHash validator)
case Map.lookup oref utxos of
Nothing -> Contract.logError @H.String "Listing not found"
Just \_  -> do
let redeemer = PlutusTx.toBuiltinData Cancel
tx = Constraints.mustSpendScriptOutput oref (V2.Redeemer redeemer)
ledgerTx <- submitTxConstraintsSpending (V2.validatorScript validator) (Map.singleton oref undefined) tx
awaitTxConfirmed \$ Ledger.getCardanoTxId ledgerTx
Contract.logInfo @H.String "Cancelled listing"

\-- Utility helpers (very minimal; production code requires more robust helpers)
findAssetUtxo :: V1.AssetClass -> Map.Map TxOutRef Ledger.TxOutTx -> Maybe (TxOutRef, Ledger.TxOutTx)
findAssetUtxo ac mp = fmap ((oref,txout) -> (oref, txout)) \$
find ((\_,o) -> V1.assetClassValueOf (Ledger.txOutValue \$ Ledger.txOutTxOut o) ac >= 1) (Map.toList mp)

maybeTrace :: a -> Maybe b -> b
maybeTrace \_ (Just b) = b
maybeTrace msg Nothing = traceError "missing datum or value"

\-- Combine endpoints
marketplaceContract :: AsContractError e => Contract () MarketplaceSchema e ()
marketplaceContract = selectList \[listEndpoint, buyEndpoint, cancelEndpoint] >> marketplaceContract

\-- Boilerplate to expose the validator as a serialised file (off-chain helper)
writeValidator :: IO ()
writeValidator = do
let s = V2.validatorScript validator
\-- The helper to write the script depends on your local utilities; replace as needed.
H.putStrLn "Write validator to file (implement write helper for your environment)."
