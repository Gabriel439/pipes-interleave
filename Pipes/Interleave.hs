module Pipes.Interleave ( interleave
                        , combine
                        , merge
                        ) where
                        
import Control.Applicative
import Data.List (sortBy)
import Data.Function (on)
import Data.Either (rights)
import Pipes

-- | Interleave elements from a set of 'Producers' such that the interleaved
-- stream is increasing with respect to the given ordering
interleave :: (Monad m, Functor m)
           => (a -> a -> Ordering) -> [Producer a m ()] -> Producer a m ()
interleave compare producers = do
    xs <- lift $ rights <$> mapM Pipes.next producers
    go xs
  where --go :: (Monad m, Functor m) => [(a, Producer a m ())] -> Producer a m ()
        go [] = return ()
        go xs = do let (a,producer):xs' = sortBy (compare `on` fst) xs
                   yield a
                   x' <- lift $ next producer
                   go $ either (const xs') (:xs') x'

-- | Given a stream of increasing elements, combine those equal under the 
-- given equality relation
combine :: (Monad m)
        => (a -> a -> Bool)    -- ^ equality test
        -> (a -> a -> m a)     -- ^ combine operation
        -> Producer a m r -> Producer a m r
combine eq append producer = lift (next producer) >>= either return (uncurry go)
  where go a producer' = do
          n <- lift $ next producer'
          case n of
            Left r                 -> yield a >> return r
            Right (a', producer'')
              | a `eq` a'          -> do a'' <- lift $ append a a'
                                         go a'' producer''
              | otherwise          -> yield a >> go a' producer''
   
-- | Equivalent to 'combine' composed with 'interleave'
merge :: (Monad m, Functor m)
      => (a -> a -> Ordering) -> (a -> a -> m a)
      -> [Producer a m ()] -> Producer a m ()
merge compare append =
    combine (\a b->compare a b == EQ) append . interleave compare
