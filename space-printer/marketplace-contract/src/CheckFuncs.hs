{-# LANGUAGE BangPatterns          #-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE DeriveAnyClass        #-}
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE DerivingStrategies    #-}
{-# LANGUAGE DerivingVia           #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE ImportQualifiedPost   #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NamedFieldPuns        #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}
-- Options
{-# OPTIONS_GHC -fno-strictness               #-}
{-# OPTIONS_GHC -fno-ignore-interface-pragmas #-}
{-# OPTIONS_GHC -fno-omit-interface-pragmas   #-}
{-# OPTIONS_GHC -fobject-code                 #-}
{-# OPTIONS_GHC -fno-specialise               #-}
{-# OPTIONS_GHC -fexpose-all-unfoldings       #-}
module CheckFuncs
  ( isValueContinuing
  , isPKHGettingPaid
  , isAddrGettingPaid
  , isSingleScript
  , createAddress
  ) where
import qualified Plutus.V1.Ledger.Address as Address
import qualified Plutus.V1.Ledger.Value   as Value
import           Ledger                   hiding (singleton)
import           PlutusTx.Prelude
import           Plutus.V1.Ledger.Credential
{- |
  Author   : The Ancient Kraken
  Copyright: 2022
  Version  : Rev 0
-}
-------------------------------------------------------------------------
-- | Create an address, either payment or staking depending on inputs
-------------------------------------------------------------------------
createAddress :: PubKeyHash -> PubKeyHash -> Address
createAddress pkh sc = if getPubKeyHash sc == emptyByteString then Address (PubKeyCredential pkh) Nothing else Address (PubKeyCredential pkh) (Just $ StakingHash $ PubKeyCredential sc)

-------------------------------------------------------------------------------
-- | Search each TxOut for a value.
-------------------------------------------------------------------------------
isValueContinuing :: [TxOut] -> Value -> Bool
isValueContinuing [] _ = False
isValueContinuing (x:xs) val
  | checkVal  = True
  | otherwise = isValueContinuing xs val
  where
    checkVal :: Bool
    checkVal = txOutValue x == val

-------------------------------------------------------------------------------
-- | Search each TxOut for an address and value.
-------------------------------------------------------------------------------
isAddrGettingPaid :: [TxOut] -> Address -> Value -> Bool
isAddrGettingPaid [] _addr _val = False
isAddrGettingPaid (x:xs) addr val
  | checkAddr && checkVal = True
  | otherwise             = isAddrGettingPaid xs addr val
  where
    checkAddr :: Bool
    checkAddr = txOutAddress x == addr

    checkVal :: Bool
    checkVal = Value.geq (txOutValue x) val

-------------------------------------------------------------------------------
-- | Search each TxOut for an address and value.
-------------------------------------------------------------------------------
isPKHGettingPaid :: [TxOut] -> PubKeyHash -> Value -> Bool
isPKHGettingPaid [] _pkh _val = False
isPKHGettingPaid (x:xs) pkh val
  | checkAddr && checkVal = True
  | otherwise             = isPKHGettingPaid xs pkh val
  where
    checkAddr :: Bool
    checkAddr = txOutAddress x == Address.pubKeyHashAddress pkh

    checkVal :: Bool
    checkVal = txOutValue x == val

-------------------------------------------------------------------------------
-- | Force a single script utxo input.
-------------------------------------------------------------------------------
isSingleScript :: [TxInInfo] -> Bool
isSingleScript txInputs = loopInputs txInputs 0
  where
    loopInputs :: [TxInInfo] -> Integer -> Bool
    loopInputs []      counter = counter == 1
    loopInputs (x:xs) !counter =
      case txOutDatumHash $ txInInfoResolved x of
        Nothing -> do counter <= 1 && loopInputs xs counter
        Just _  -> do counter <= 1 && loopInputs xs (counter + 1)
