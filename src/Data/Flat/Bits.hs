{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE RankNTypes           #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE TypeSynonymInstances #-}

-- |Utilities to represent and display bit sequences
module Data.Flat.Bits (
    Bits,
    toBools,
    fromBools,
    bits,
    paddedBits,
    asBytes,
    asBits,
    ) where

import           Data.Bits                      hiding (Bits)
import qualified Data.ByteString                as B
import           Data.Flat.Class
import           Data.Flat.Decoder
import           Data.Flat.Filler
import           Data.Flat.Run
import qualified Data.Vector.Unboxed            as V
import           Data.Word
import           Text.PrettyPrint.HughesPJClass

-- |A sequence of bits
type Bits = V.Vector Bool

toBools :: Bits -> [Bool]
toBools = V.toList

fromBools :: [Bool] -> Bits
fromBools = V.fromList

-- |The sequence of bits corresponding to the serialization of the passed value (without any final byte padding)
bits :: forall a. Flat a => a -> Bits
bits v = let lbs = flat v
             Right (PostAligned _ f) = unflatRaw lbs :: Decoded (PostAligned a)
         in takeBits (8 * B.length lbs - fillerLength f) lbs

-- |The sequence of bits corresponding to the byte-padded serialization of the passed value
paddedBits :: forall a. Flat a => a -> Bits
paddedBits v = let lbs = flat v
               in takeBits (8 * B.length lbs) lbs

takeBits :: Int -> B.ByteString -> Bits
takeBits numBits lbs  = V.generate (fromIntegral numBits) (\n -> let (bb,b) = n `divMod` 8 in testBit (B.index lbs (fromIntegral bb)) (7-b))

-- | asBits (5::Word8)
-- | > [False,False,False,False,False,True,False,True]
asBits :: FiniteBits a => a -> Bits
asBits w = let s = finiteBitSize w in V.generate s (testBit w . (s-1-))

-- |Convert a sequence of bits to the corresponding list of bytes
asBytes :: Bits -> [Word8]
asBytes = map byteVal . bytes .  V.toList

-- |Convert to the corresponding value (most significant bit first)
byteVal :: [Bool] -> Word8
byteVal = sum . map (\(e,b) -> if b then e else 0). zip [2 ^ n | n <- [7::Int,6..0]]

-- |Split a list in groups of 8 elements or less
bytes :: [t] -> [[t]]
bytes [] = []
bytes l  = let (w,r) = splitAt 8 l in w : bytes r

instance Pretty Bits where pPrint = hsep . map prettyBits . bytes .  V.toList

prettyBits :: Foldable t => t Bool -> Doc
prettyBits l = text . take (length l) . concatMap (\b -> if b then "1" else "0") $ l

