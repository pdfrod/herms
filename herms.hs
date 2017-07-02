module Main where

import System.Environment
import System.Directory
import System.IO
import Control.Monad
import Data.Char
import Data.Ratio
import Data.List
import Data.Maybe
import Control.Applicative
import Text.Read
import Herms.Utils
import Herms.AddCLI
import Herms.Types

-- Global constant
fileName = "recipes"

getRecipeBook :: IO ([Recipe])
getRecipeBook = do
  contents <- readFile fileName
  return $ map read $ lines contents

getRecipe :: String -> [Recipe] -> Maybe Recipe
getRecipe target = listToMaybe . filter ((target ==) . recipeName)

add :: [String] -> IO ()
add _ = do
  input <- getAddInput 
  let newRecipe = readRecipe input
  putStrLn $ showRecipe newRecipe
  putStrLn "Save recipe? (Y)es  (N)o"
  response <- getLine
  if response == "y" || response == "Y" 
    then do 
    appendFile fileName (show newRecipe ++ "\n")
    putStrLn "Recipe saved!"
  else
    putStrLn "Recipe discarded."

view :: [String] -> IO ()
view targets = do
  recipeBook <- getRecipeBook
  forM_ targets $ \ target -> do
    let index = (safeLookup recipeBook . pred =<< readMaybe target)
                <|> getRecipe target recipeBook
    putStr $ case index of
      Nothing   -> target ++ " does not exist\n"
      Just recp -> showRecipe recp

list :: [String] -> IO ()
list _  = do
  recipes <- getRecipeBook
  let recipeList = map recipeName recipes
      size       = length $ show $ length recipeList
      indices    = map (padLeft size . show) [1..]
  putStr $ unlines $ zipWith (\ i -> ((i ++ ". ") ++)) indices recipeList

remove :: [String] -> IO ()
remove targets = forM_ targets $ \ target -> do
  recipeBook <- getRecipeBook
  (tempName, tempHandle) <- openTempFile "." "herms_temp"
  let (Just recp) = getRecipe target recipeBook
      newRecpBook = delete recp recipeBook
  putStrLn $ "Removing recipe: " ++ recipeName recp ++ "..."
  hPutStr tempHandle $ unlines $ show <$> newRecpBook
  hClose tempHandle
  removeFile fileName
  renameFile tempName fileName
  putStrLn "Recipe deleted."


help :: [String] -> IO ()
help _ = putStr $ unlines $ "Usage:" : usage where

  usage = map (\ (c, d) -> concat [ padRight size c, " - ", d ]) desc
  size  = maximum $ map (length . fst) desc
  desc  = [ ("./herms list", "list recipes")
          , ("./herms view (\"Recipe Name\"|Index)", "view a particular recipe")
          , ("./herms add", "add a new recipe (interactive)")
          , ("./herms remove \"Recipe Name\"", " remove a particular recipe")
          , ("./herms help", "display this help")
          ]

dispatch :: [(String, [String] -> IO ())]
dispatch = [ ("add", add)
           , ("view", view)
           , ("remove", remove)
           , ("list", list)
           , ("help", help)
           ]

herms :: [String]      -- command line arguments
      -> Maybe (IO ()) -- failure or resulting IO action
herms args = do
  guard (not $ null args)
  action <- lookup (head args) dispatch
  return $ action (tail args)

main :: IO ()
main = do
  testCmd <- getArgs
  case herms testCmd of
    Nothing -> help [""]
    Just io -> io
