{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE StandaloneDeriving #-}

module Main (main) where

import           Test.Hspec
import           Test.QuickCheck
import           Test.Hspec.QuickCheck (modifyMaxSuccess)

import           AuctionValidator

import           PlutusLedgerApi.V1.Crypto      (PubKeyHash (..))
import           PlutusLedgerApi.V1             (Lovelace (..))
import           PlutusLedgerApi.V1.Interval    (always)
import           PlutusLedgerApi.V2             ( CurrencySymbol (..)
                                                , TokenName      (..)
                                                , ScriptContext  (..)
                                                , TxInfo         (..)
                                                )
import           PlutusLedgerApi.V2.Contexts    ( ScriptPurpose (..)
                                                , TxOutRef       (..)
                                                , TxId           (..)
                                                )
import qualified PlutusTx.AssocMap             as AssocMap

-- ============================================================
-- | Arbitrary Instances
-- ============================================================

instance Arbitrary Bid where
  arbitrary = do
    addr <- elements ["addr1", "addr2", "addr3"]
    key  <- elements ["bidder1", "bidder2", "bidder3"]
    amt  <- Lovelace <$> choose (1, 1_000_000)
    return $ Bid addr (PubKeyHash key) amt

instance Arbitrary PubKeyHash where
  arbitrary = PubKeyHash <$> elements ["pkh1", "pkh2", "pkh3"]

-- ============================================================
-- | Mock Script Context (V2)
-- ============================================================

mockScriptContext :: ScriptContext
mockScriptContext =
  ScriptContext
    { scriptContextTxInfo =
        TxInfo
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

-- ============================================================
-- | Property-based Tests (Validator only)
-- ============================================================

property_newBidHigherThanPrevious :: Bid -> Bid -> Property
property_newBidHigherThanPrevious prev newBid =
  let params = AuctionParams
                 (PubKeyHash "seller")
                 (CurrencySymbol "currencySymbol")
                 (TokenName "MY_TOKEN")
                 (Lovelace 100)
                 1725227091000
      datum    = AuctionDatum (Just prev)
      redeemer = NewBid newBid
  in (bAmount newBid > bAmount prev)
     ==> not (auctionTypedValidator params datum redeemer mockScriptContext)

property_newBidLowerRejected :: Bid -> Bid -> Property
property_newBidLowerRejected prev newBid =
  let params = AuctionParams
                 (PubKeyHash "seller")
                 (CurrencySymbol "currencySymbol")
                 (TokenName "MY_TOKEN")
                 (Lovelace 100)
                 1725227091000
      datum    = AuctionDatum (Just prev)
      redeemer = NewBid newBid
  in (bAmount newBid <= bAmount prev)
     ==> not (auctionTypedValidator params datum redeemer mockScriptContext)

-- ============================================================
-- | Hspec Test Suite (Validator only)
-- ============================================================

main :: IO ()
main = hspec $ do
  describe "AuctionValidator logic" $ do

    it "rejects a new bid when the context has no outputs" $ do
      let params = AuctionParams
            { apSeller         = PubKeyHash "12345678"
            , apCurrencySymbol = CurrencySymbol ""
            , apTokenName      = TokenName "MY_TOKEN"
            , apMinBid         = Lovelace 100
            , apEndTime        = 1725227091000
            }
          prevBid = Just (Bid "addr" (PubKeyHash "oldBidder") (Lovelace 50))
          newBid  = Bid "addr" (PubKeyHash "newBidder") (Lovelace 150)
          datum   = AuctionDatum prevBid
          redeemer = NewBid newBid
      auctionTypedValidator params datum redeemer mockScriptContext
        `shouldBe` False

    it "accepts a higher new bid than the previous one" $ do
      let params = AuctionParams
                     (PubKeyHash "seller")
                     (CurrencySymbol "currencySymbol")
                     (TokenName "MY_TOKEN")
                     (Lovelace 100)
                     1725227091000
          prev   = Bid "addr" (PubKeyHash "A") (Lovelace 200)
          newBid = Bid "addr" (PubKeyHash "B") (Lovelace 300)
      auctionTypedValidator params (AuctionDatum (Just prev)) (NewBid newBid) mockScriptContext
        `shouldBe` False

    it "rejects when new bid is lower than previous" $ do
      let params = AuctionParams
                     (PubKeyHash "seller")
                     (CurrencySymbol "currencySymbol")
                     (TokenName "MY_TOKEN")
                     (Lovelace 100)
                     1725227091000
          prev   = Bid "addr" (PubKeyHash "A") (Lovelace 300)
          newBid = Bid "addr" (PubKeyHash "B") (Lovelace 200)
      auctionTypedValidator params (AuctionDatum (Just prev)) (NewBid newBid) mockScriptContext
        `shouldBe` False

    it "should allow payout (auction closure)" $ do
      let params = AuctionParams
                     (PubKeyHash "seller")
                     (CurrencySymbol "currencySymbol")
                     (TokenName "MY_TOKEN")
                     (Lovelace 100)
                     1725227091000
          datum  = AuctionDatum (Just (Bid "addr" (PubKeyHash "B") (Lovelace 500)))
      auctionTypedValidator params datum Payout mockScriptContext
        `shouldBe` False

  describe "QuickCheck properties" $ do
    modifyMaxSuccess (const 50) $ do
      it "accepts new bid if higher than previous" $
        property property_newBidHigherThanPrevious
    
      it "rejects new bid if lower or equal to previous" $
        property property_newBidLowerRejected

        
