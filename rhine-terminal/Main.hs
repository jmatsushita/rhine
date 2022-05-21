{- | Example application for the @terminal@ wrapper. -}

{-# LANGUAGE Arrows #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import Prelude hiding (putString, putChar)

import Data.Time.Clock ( getCurrentTime, UTCTime )
import Control.Monad.IO.Class ( MonadIO, liftIO )

-- rhine
import Control.Monad.Catch (MonadMask)
import Control.Monad.Schedule ()

import Data.Text (Text)
import qualified Data.Text as T
import System.Terminal
import System.Terminal.Internal
import FRP.Rhine
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Reader (ReaderT)
import Data.List (singleton)
import System.IO hiding (putChar)
import System.Terminal (MonadScreen(moveCursorForward))

type App = AppT IO
type AppT = TerminalT LocalTerminal

data TerminalEventClock = TerminalEventClock

instance (MonadIO m) => Clock (AppT m) TerminalEventClock where
  type Time TerminalEventClock = UTCTime
  type Tag  TerminalEventClock = Either Interrupt Event

  initClock _ = do
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
  _ <> _ = TerminalEventClock

type KeyClock = SelectClock TerminalEventClock Char

keyClock :: KeyClock
keyClock = SelectClock { mainClock = TerminalEventClock, select = select }
  where
    select :: Tag TerminalEventClock -> Maybe Char
    select = \case
      Right (KeyEvent (CharKey key) _) -> Just key
      _ -> Nothing

type BeatClock = Millisecond 1000

beat :: Rhine App (LiftClock IO AppT BeatClock) () Text
beat = ((flip T.cons " > " ) . (cycle " ." !!) <$> count) @@ liftClock waitClock

-- Rhines

key :: ClSF App KeyClock () Char
key = tagS

type DisplayClock = ParClock App (LiftClock IO AppT BeatClock) KeyClock

terminalConcurrently
  :: ( Clock IO (RunTerminalClock cl1)
     , Clock IO (RunTerminalClock cl2)
     , Time cl1 ~ Time cl2
     )
  => LocalTerminal
  -> Schedule App cl1 cl2
terminalConcurrently term
  = Schedule $ \cl1 cl2 -> lift $ first liftTransS <$>
      initSchedule concurrently (runTerminalClock term cl1) (runTerminalClock term cl2)

type RunTerminalClock cl = HoistClock App IO cl

runTerminalClock :: LocalTerminal -> cl -> RunTerminalClock cl
runTerminalClock term unhoistedClock = HoistClock
  { monadMorphism = flip runTerminalT term
  , ..
  }

sensor :: LocalTerminal -> Rhine App DisplayClock () (Either Text Char)
sensor term = beat ++@ terminalConcurrently term @++ key @@ keyClock

display :: ClSF App cl (Maybe (Either Text Char)) ()
display = arrMCl $ \case
  Just (Left prompt) -> do
    pos@(Position row col) <- getCursorPosition
    if col /= 0 then do
      moveCursorBackward col
      putText prompt
      setCursorColumn col
    else putText prompt
    flush
  Just (Right k) -> do
    putChar $ k
    flush
  Nothing -> do
    pure ()

actuate :: Rhine App (LiftClock IO AppT BeatClock) (Maybe (Either Text Char)) ()
actuate = display @@ liftClock waitClock

type AppClock = SequentialClock App DisplayClock (LiftClock IO AppT BeatClock)

mainRhine
 :: LocalTerminal
 -> Rhine App AppClock () ()
mainRhine term =  sensor term >-- fifoUnbounded -@- terminalConcurrently term --> actuate

main :: IO ()
main = do
  hSetBuffering stdin NoBuffering
  hSetBuffering stdout NoBuffering
  withTerminal $ \term -> runTerminalT (flow $ mainRhine term) term
