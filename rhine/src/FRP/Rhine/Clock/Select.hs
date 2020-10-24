{- |
In the Rhine philosophy, _event sources are clocks_.
Often, we want to extract certain subevents from event sources,
e.g. single out only left mouse button clicks from all input device events.
This module provides a general purpose selection clock
that ticks only on certain subevents.
-}

{-# LANGUAGE Arrows #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeFamilies #-}
module FRP.Rhine.Clock.Select where

-- rhine
import FRP.Rhine.Clock
import FRP.Rhine.Clock.Proxy

-- dunai
import Data.MonadicStreamFunction.Async (concatS)

-- monad-schedule
import Control.Monad.Schedule.Class (MonadSchedule)

-- base
import Data.Maybe (maybeToList)

-- rhine
import Control.Monad.Event

-- | A clock that selects certain subevents of type 'a',
--   from the tag of a main clock.
--
--   If two 'SelectClock's would tick on the same type of subevents,
--   but should not have the same type,
--   one should @newtype@ the subevent.
data SelectClock cl a = SelectClock
  { mainClock :: cl -- ^ The main clock
  -- | Return 'Nothing' if no tick of the subclock is required,
  --   or 'Just a' if the subclock should tick, with tag 'a'.
  , select    :: Tag cl -> Maybe a
  }

instance (Semigroup a, Semigroup cl) => Semigroup (SelectClock cl a) where
  cl1 <> cl2 = SelectClock
    { mainClock = mainClock cl1 <> mainClock cl2
    , select = \tag -> select cl1 tag <> select cl2 tag
    }

instance (Monoid cl, Semigroup a) => Monoid (SelectClock cl a) where
  mempty = SelectClock
    { mainClock = mempty
    , select = const mempty
    }

-- FIXME This doesn't work
-- instance (Monad m, Clock m cl) => Clock (EventT (Tag cl) m) (SelectClock cl a) where
instance (Clock m cl, Monad m, MonadSchedule m, ev ~ (Time cl, Maybe (Tag cl))) => Clock (EventT ev m) (SelectClock cl a) where
  type Time (SelectClock cl a) = Time cl
  type Tag  (SelectClock cl a) = a
  initClock SelectClock {..} = do
    (initialTime, _initialEvent) <- listenUntil Just
    return (constM $ listenUntil selector, initialTime)
      where
        selector :: (Time cl, Maybe (Tag cl)) -> Maybe (Time cl, a)
        selector (time, evMaybe) = do
          ev <- evMaybe
          a <- select ev
          return (time, a)

instance GetClockProxy (SelectClock cl a)

-- | Helper function that runs an 'MSF' with 'Maybe' output
--   until it returns a value.
filterS :: Monad m => MSF m () (Maybe b) -> MSF m () b
filterS = concatS . (>>> arr maybeToList)
