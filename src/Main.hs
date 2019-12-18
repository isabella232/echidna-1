module Main where

import Control.Lens (view, (^.))
import Control.Monad (when)
import Control.Monad.Reader (runReaderT)
import Control.Monad.Random (getRandom)
import Data.Text (pack, unpack)
import Data.Version (showVersion)
import Options.Applicative
import Paths_echidna (version)
import System.Exit (exitWith, exitSuccess, ExitCode(..))
import System.IO (hPutStrLn, stderr)

import Echidna.ABI
import Echidna.Config
import Echidna.Solidity
import Echidna.Campaign
import Echidna.UI

import qualified Data.List.NonEmpty as NE

data Options = Options
  { filePath         :: FilePath
  , selectedContract :: Maybe String
  , configFilepath   :: Maybe FilePath
  }

options :: Parser Options
options = Options <$> argument str (metavar "FILE"
                        <> help "Solidity file to analyze")
                  <*> optional (argument str $ metavar "CONTRACT"
                        <> help "Contract to analyze")
                  <*> optional (option str $ long "config"
                        <> help "Config file")

versionOption :: Parser (a -> a)
versionOption = infoOption
                  ("Echidna " ++ showVersion version)
                  (long "version" <> help "Show version")

opts :: ParserInfo Options
opts = info (helper <*> versionOption <*> options) $ fullDesc
  <> progDesc "EVM property-based testing framework"
  <> header "Echidna"

main :: IO ()
main = do Options f c conf <- execParser opts
          g   <- getRandom
          EConfigWithUsage cfg ks _ <- maybe (pure (EConfigWithUsage defaultConfig mempty mempty)) parseConfig conf
          when (cfg ^. sConf . quiet == False) $ mapM_ (hPutStrLn stderr . ("Warning: unused option: " ++) . unpack) ks
          cpg <- flip runReaderT cfg $ do
            cs       <- contracts f
            ads      <- addresses
            (v,w,ts) <- loadSpecified (pack <$> c) cs >>= prepareForTest
            ui v w ts (Just $ mkGenDict (dictFreq $ view cConf cfg) (extractConstants cs ++ NE.toList ads) [] g (returnTypes cs))
          if not . isSuccess $ cpg then exitWith $ ExitFailure 1 else exitSuccess
