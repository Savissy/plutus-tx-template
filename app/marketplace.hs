{-# LANGUAGE OverloadedStrings, DeriveGeneric #-}

module Main where

import Web.Scotty
import Data.Aeson (ToJSON, FromJSON)
import GHC.Generics (Generic)
import qualified Data.Text as T
import qualified Data.Map.Strict as Map
import Control.Concurrent.STM
import Control.Monad.IO.Class (liftIO)
import Network.HTTP.Types.Status (status400, status404)
import Data.Maybe (isJust)
import Data.Int (Int64)

-- | Domain types
data NFT = NFT
  { nftId       :: Int
  , nftName     :: T.Text
  , nftCreator  :: T.Text
  , nftOwner    :: T.Text
  , nftMeta     :: T.Text -- could be a URL or JSON string
  } deriving (Show, Generic)

instance ToJSON NFT
instance FromJSON NFT

data Listing = Listing
  { listingId   :: Int
  , listingNftId:: Int
  , listingSeller:: T.Text
  , listingPrice:: Double
  } deriving (Show, Generic)

instance ToJSON Listing
instance FromJSON Listing

-- | Simple in-memory database
data DB = DB
  { dbNextNft    :: TVar Int
  , dbNextList   :: TVar Int
  , dbNfts       :: TVar (Map.Map Int NFT)
  , dbListings   :: TVar (Map.Map Int Listing)
  }

-- | Initialize DB
initDB :: IO DB
initDB = atomically $ do
  n1 <- newTVar 1
  n2 <- newTVar 1
  n3 <- newTVar Map.empty
  n4 <- newTVar Map.empty
  return $ DB n1 n2 n3 n4

-- | Mint a new NFT (creator becomes owner)
mintNFT :: DB -> T.Text -> T.Text -> T.Text -> IO NFT
mintNFT db name creator meta = atomically $ do
  nid <- readTVar (dbNextNft db)
  modifyTVar' (dbNextNft db) (+1)
  let nft = NFT nid name creator creator meta
  modifyTVar' (dbNfts db) (Map.insert nid nft)
  return nft

-- | Create a listing for an owned NFT
createListing :: DB -> Int -> T.Text -> Double -> IO (Either T.Text Listing)
createListing db nid seller price = atomically $ do
  nmap <- readTVar (dbNfts db)
  case Map.lookup nid nmap of
    Nothing -> return $ Left "NFT not found"
    Just nft ->
      if nftOwner nft /= seller then
        return $ Left "Only owner can list the NFT"
      else do
        lid <- readTVar (dbNextList db)
        modifyTVar' (dbNextList db) (+1)
        let listing = Listing lid nid seller price
        modifyTVar' (dbListings db) (Map.insert lid listing)
        return $ Right listing

-- | Purchase a listing: transfer ownership and remove listing
buyListing :: DB -> Int -> T.Text -> IO (Either T.Text NFT)
buyListing db lid buyer = atomically $ do
  lmap <- readTVar (dbListings db)
  case Map.lookup lid lmap of
    Nothing -> return $ Left "Listing not found"
    Just listing -> do
      nmap <- readTVar (dbNfts db)
      case Map.lookup (listingNftId listing) nmap of
        Nothing -> return $ Left "NFT not found"
        Just nft -> do
          -- transfer ownership
          let nft' = nft { nftOwner = buyer }
          modifyTVar' (dbNfts db) (Map.insert (nftId nft') nft')
          -- remove listing
          modifyTVar' (dbListings db) (Map.delete lid)
          return $ Right nft'

-- | Helpers to fetch data
getAllListings :: DB -> IO [Listing]
getAllListings db = Map.elems <$> readTVarIO (dbListings db)

getNftById :: DB -> Int -> IO (Maybe NFT)
getNftById db nid = Map.lookup nid <$> readTVarIO (dbNfts db)

getNftsByOwner :: DB -> T.Text -> IO [NFT]
getNftsByOwner db owner = filter ((== owner) . nftOwner) . Map.elems <$> readTVarIO (dbNfts db)

-- | Web API: simple JSON endpoints using Scotty
main :: IO ()
main = do
  db <- initDB
  putStrLn "Starting Haskell NFT Marketplace on http://localhost:3000"
  scotty 3000 $ do
    -- Mint: POST /mint  { "name": "Cool Art", "creator": "alice", "meta": "ipfs://..." }
    post "/mint" $ do
      b <- jsonData `rescue` (const (raiseStatus status400 "Invalid JSON for mint"))
      case b of
        (obj :: NFT) -> do
          -- We only use name, creator, meta from client; id and owner are ignored
          let name = nftName obj
              creator = nftCreator obj
              meta = nftMeta obj
          nft <- liftIO $ mintNFT db name creator meta
          json nft

    -- Create listing: POST /list { "nftId": 1, "seller": "alice", "price": 2.5 }
    post "/list" $ do
      listingReq <- jsonData `rescue` (const (raiseStatus status400 "Invalid JSON for listing"))
      case listingReq of
        (l :: Listing) -> do
          res <- liftIO $ createListing db (listingNftId l) (listingSeller l) (listingPrice l)
          case res of
            Left err -> do
              status status400
              text err
            Right out -> json out

    -- Buy listing: POST /buy { "listingId": 1, "buyer": "bob" }
    post "/buy" $ do
      body <- jsonData `rescue` (const (raiseStatus status400 "Invalid JSON for buy"))
      case body of
        (o :: ObjectBuy) -> do
          res <- liftIO $ buyListing db (buyListingId o) (buyBuyer o)
          case res of
            Left err -> do
              status status400
              text err
            Right nft -> json nft

    -- Get all listings
    get "/listings" $ do
      ls <- liftIO $ getAllListings db
      json ls

    -- Get NFT by id
    get "/nft/:id" $ do
      sid <- param "id"
      let nid = (read sid :: Int)
      mn <- liftIO $ getNftById db nid
      case mn of
        Nothing -> do
          status status404
          text "NFT not found"
        Just nft -> json nft

    -- Get NFTs by owner
    get "/owner/:owner" $ do
      owner <- param "owner"
      nfts <- liftIO $ getNftsByOwner db owner
      json nfts

-- | Small helper type for buy endpoint parsing
data ObjectBuy = ObjectBuy { buyListingId :: Int, buyBuyer :: T.Text } deriving (Show, Generic)
instance FromJSON ObjectBuy
instance ToJSON ObjectBuy

-- Utility to raise an error with HTTP status
raiseStatus :: Status -> T.Text -> ActionM a
raiseStatus st msg = do
  status st
  text msg
  finish
