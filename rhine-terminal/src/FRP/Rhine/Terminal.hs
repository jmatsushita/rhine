{- | Wrapper to write @terminal@ applications in Rhine, using concurrency.
-}

{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE RecordWildCards #-}
module FRP.Rhine.Terminal where

-- base
import Prelude hiding (putChar)
import Control.Concurrent ()
import Control.Concurrent.MVar ()
import Data.IORef ()
import Unsafe.Coerce (unsafeCoerce)

-- monad-schedule
import Control.Monad.Schedule.Class

-- time
import Data.Time.Clock ( getCurrentTime )

-- terminal
import System.Terminal ( awaitEvent, runTerminalT, Event, Interrupt, TerminalT (..), MonadInput )
import System.Terminal.Internal ( Terminal )

-- transformers
import Control.Monad.Trans.Reader

-- rhine
import FRP.Rhine.Clock.Proxy ()
import FRP.Rhine
import Control.Monad.Trans.Class (lift)
import Control.Monad.Catch (MonadMask)

-- | A clock that ticks whenever events or interrupts on the terminal arrive.
data TerminalEventClock = TerminalEventClock

instance (MonadInput m, MonadIO m) => Clock m TerminalEventClock
  where
    type Time TerminalEventClock = UTCTime
    type Tag  TerminalEventClock = Either Interrupt Event

    initClock TerminalEventClock = do
      initialTime <- liftIO getCurrentTime
      return
        ( constM $ do
            event <- awaitEvent
            time <- liftIO getCurrentTime
            return (time, event)
        , initialTime
        )

instance GetClockProxy TerminalEventClock

instance Semigroup TerminalEventClock where
  t <> _ = t

-- | A function wrapping `flow` to use at the top level
-- in order to run a `Rhine (TerminalT t m) cl ()`
--
-- Example:
--
-- @
--
-- mainRhine :: MonadIO m => Rhine (TerminalT LocalTerminal m) TerminalEventClock () ()
-- mainRhine = tagS >-> arrMCl (liftIO . print) @@ TerminalEventClock
--
-- main :: IO ()
-- main = withTerminal $ \term -> `flowTerminal` term mainRhine
--
-- @

flowTerminal
  :: ( MonadIO m
     , MonadMask m
     , Terminal t
     , Clock (TerminalT t m) cl
     , GetClockProxy cl
     , Time cl ~ Time (In  cl)
     , Time cl ~ Time (Out cl)
     )
  => t
  -> Rhine (TerminalT t m) cl () ()
  -> m ()
flowTerminal term clsf = flip runTerminalT term $ flow clsf

instance (Monad m, MonadSchedule m) => MonadSchedule (TerminalT t m) where
  -- schedule actions = GlossConcT $ fmap (second $ map GlossConcT) $ schedule $ unGlossConcT <$> actions
  schedule actions = TerminalT $ fmap (second $ map TerminalT) $ schedule $ unTerminalT <$> actions

-- -- | A schedule in the 'TerminalT LocalTerminal' transformer,
-- --   supplying the same backend connection to its scheduled clocks.
-- terminalConcurrently
--   :: forall t cl1 cl2. (
--        Terminal t
--      , Clock (TerminalT t IO) cl1
--      , Clock (TerminalT t IO) cl2
--      , Time cl1 ~ Time cl2
--      )
--   => Schedule (TerminalT t IO) cl1 cl2
-- terminalConcurrently
--   = Schedule $ \cl1 cl2 -> do
--       term <- terminalT ask
--       lift $ first liftTransS <$>
--         initSchedule concurrently (runTerminalClock term cl1) (runTerminalClock term cl2)

-- Workaround TerminalT constructor not being exported. Should be safe in practice.
unTerminalT :: TerminalT t m a -> ReaderT t m a
unTerminalT (TerminalT t) = t

-- type RunTerminalClock m t cl = HoistClock (TerminalT t m) m cl

-- runTerminalClock
--   :: Terminal t
--   => t
--   -> cl
--   -> RunTerminalClock IO t cl
-- runTerminalClock term unhoistedClock = HoistClock
--   { monadMorphism = flip runTerminalT term
--   , ..
--   }
