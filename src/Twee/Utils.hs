-- | Miscellaneous utility functions.

{-# LANGUAGE CPP, MagicHash #-}
module Twee.Utils where

import Control.Arrow((&&&))
import Control.Exception
import Data.List(groupBy, sortBy)
import Data.Ord(comparing)
import System.IO
import GHC.Prim
import GHC.Types
import Data.Bits
--import Test.QuickCheck hiding ((.&.))

repeatM :: Monad m => m a -> m [a]
repeatM = sequence . repeat

partitionBy :: Ord b => (a -> b) -> [a] -> [[a]]
partitionBy value =
  map (map fst) .
  groupBy (\x y -> snd x == snd y) .
  sortBy (comparing snd) .
  map (id &&& value)

collate :: Ord a => ([b] -> c) -> [(a, b)] -> [(a, c)]
collate f = map g . partitionBy fst
  where
    g xs = (fst (head xs), f (map snd xs))

isSorted :: Ord a => [a] -> Bool
isSorted xs = and (zipWith (<=) xs (tail xs))

isSortedBy :: Ord b => (a -> b) -> [a] -> Bool
isSortedBy f xs = isSorted (map f xs)

usort :: Ord a => [a] -> [a]
usort = usortBy compare

usortBy :: (a -> a -> Ordering) -> [a] -> [a]
usortBy f = map head . groupBy (\x y -> f x y == EQ) . sortBy f

sortBy' :: Ord b => (a -> b) -> [a] -> [a]
sortBy' f = map snd . sortBy (comparing fst) . map (\x -> (f x, x))

usortBy' :: Ord b => (a -> b) -> [a] -> [a]
usortBy' f = map snd . usortBy (comparing fst) . map (\x -> (f x, x))

orElse :: Ordering -> Ordering -> Ordering
EQ `orElse` x = x
x  `orElse` _ = x

unbuffered :: IO a -> IO a
unbuffered x = do
  buf <- hGetBuffering stdout
  bracket_
    (hSetBuffering stdout NoBuffering)
    (hSetBuffering stdout buf)
    x

newtype Max a = Max { getMax :: Maybe a }

getMaxWith :: Ord a => a -> Max a -> a
getMaxWith x (Max (Just y)) = x `max` y
getMaxWith x (Max Nothing)  = x

instance Ord a => Monoid (Max a) where
  mempty = Max Nothing
  Max (Just x) `mappend` y = Max (Just (getMaxWith x y))
  Max Nothing  `mappend` y = y

newtype Min a = Min { getMin :: Maybe a }

getMinWith :: Ord a => a -> Min a -> a
getMinWith x (Min (Just y)) = x `min` y
getMinWith x (Min Nothing)  = x

instance Ord a => Monoid (Min a) where
  mempty = Min Nothing
  Min (Just x) `mappend` y = Min (Just (getMinWith x y))
  Min Nothing  `mappend` y = y

labelM :: Monad m => (a -> m b) -> [a] -> m [(a, b)]
labelM f = mapM (\x -> do { y <- f x; return (x, y) })

#if __GLASGOW_HASKELL__ < 710
isSubsequenceOf :: Ord a => [a] -> [a] -> Bool
[] `isSubsequenceOf` ys = True
(x:xs) `isSubsequenceOf` [] = False
(x:xs) `isSubsequenceOf` (y:ys)
  | x == y = xs `isSubsequenceOf` ys
  | otherwise = (x:xs) `isSubsequenceOf` ys
#endif

{-# INLINE fixpoint #-}
fixpoint :: Eq a => (a -> a) -> a -> a
fixpoint f x = fxp x
  where
    fxp x
      | x == y = x
      | otherwise = fxp y
      where
        y = f x

-- From "Bit twiddling hacks": branchless min and max
{-# INLINE intMin #-}
intMin :: Int -> Int -> Int
intMin x y =
  y `xor` ((x `xor` y) .&. negate (x .<. y))
  where
    I# x .<. I# y = I# (x <# y)

{-# INLINE intMax #-}
intMax :: Int -> Int -> Int
intMax x y =
  x `xor` ((x `xor` y) .&. negate (x .<. y))
  where
    I# x .<. I# y = I# (x <# y)

-- Split an interval (inclusive bounds) into a particular number of blocks
splitInterval :: Integral a => a -> (a, a) -> [(a, a)]
splitInterval k (lo, hi) =
  [ (lo+i*blockSize, (lo+(i+1)*blockSize-1) `min` hi)
  | i <- [0..k-1] ]
  where
    size = (hi-lo+1)
    blockSize = (size + k - 1) `div` k -- division rounding up
{-
prop_split_1 (Positive k) (lo, hi) =
  -- Check that all elements occur exactly once
  concat [[x..y] | (x, y) <- splitInterval k (lo, hi)] === [lo..hi]

-- Check that we have the correct number and distribution of blocks
prop_split_2 (Positive k) (lo, hi) =
  counterexample (show splits) $ conjoin
    [counterexample "Reason: too many splits" $
       length splits <= k,
     counterexample "Reason: too few splits" $
       length [lo..hi] >= k ==> length splits == k,
     counterexample "Reason: uneven distribution" $
      not (null splits) ==>
       minimum (map length splits) + 1 >= maximum (map length splits)]
  where
    splits = splitInterval k (lo, hi)
-}
