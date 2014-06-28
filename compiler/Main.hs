{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses, RankNTypes, FlexibleContexts, TypeOperators, OverlappingInstances #-}
{-# OPTIONS_GHC -fwarn-incomplete-patterns #-}
module Main where

import Prelude hiding (const)
import qualified Data.Char as Char (toUpper)
import qualified Data.Map  as Map
import Language.Java.Syntax as J
import Language.Java.Pretty
import System.IO                (hFlush, stdout)
import System.Cmd               (system)
import System.Directory         (setCurrentDirectory)
import System.Environment       (getArgs)
import System.FilePath          (takeDirectory, takeBaseName, takeFileName, (</>))

-- import HMParser         (readHM)
-- import qualified HM
-- import ApplyTransCFJava
import BaseTransCFJava
import ClosureF
import Inheritance
import MonadLib
import SystemF.Syntax
import Translations
import qualified SystemF.Parser

type M1 = StateT (Map.Map String Int) (State Int)

type M2 = StateT Int (State (Map.Map J.Exp Int)) 
type M3 = StateT Int (Writer Bool) 

type MAOpt = StateT Int (StateT (Map.Map J.Exp Int) (Writer Bool)) 

sopt :: Translate MAOpt  -- instantiation; all coinstraints resolved
sopt = naive

{-
sopt :: ApplyOptTranslate MAOpt 
sopt = applyopt
-}

translate ::  PCExp Int (Var, PCTyp Int) -> MAOpt ([BlockStmt], Exp, PCTyp Int)
translate = translateM (up sopt) 

compile ::  PFExp Int (Var, PCTyp Int) -> (Block, Exp, PCTyp Int)
compile e = 
  case fst $ runWriter $ evalStateT (evalStateT (translate (fexp2cexp e)) 0) Map.empty of
      (ss,e1,t) -> (J.Block ss,e1, t)

{-
type MAOpt = StateT Int (StateT (Map J.Exp Int) (Reader (Set.Set Int))) 
sopt :: Translate MAOpt  -- instantiation; all coinstraints resolved
sopt = naive

translate ::  PCExp Int (Var, PCTyp Int) -> MAOpt ([BlockStmt], Exp, PCTyp Int)
translate e = translateM (up sopt) e

compile ::  PFExp Int (Var, PCTyp Int) -> (Block, Exp, PCTyp Int)
compile e = 
  case runReader (evalStateT (evalStateT (translate (fexp2cexp e)) 0) empty) Set.empty of
      (ss,exp,t) -> (J.Block ss,exp, t)
-}
{-
sopt :: ApplyOptTranslate Translate MAOpt  -- instantiation; all coinstraints resolved
sopt = applyopt

translate e = translateM (to sopt) e
-}
{-
sopt :: TranslateStack (ApplyOptTranslate Translate) MAOpt
sopt = stack

translate e = translateM (to sopt) e
-}

prettyJ :: Pretty a => a -> IO ()
prettyJ = putStrLn . prettyPrint

compilePretty :: PFExp Int (Var, PCTyp Int) -> IO ()
compilePretty e = let (b,e1,t) = compile e in (prettyJ b >> prettyJ e1 >> print t)

compileCU :: String -> PFExp Int (Var, PCTyp Int) -> Maybe String -> IO ()
compileCU className e (Just nameStr) = let (cu,t) = createCU className (compile e) (Just nameStr) in (prettyJ cu >> print t)
compileCU className e Nothing = let (cu,t) = createCU className (compile e) Nothing in (prettyJ cu >> print t)

-- SystemF to Java
sf2java :: String -> String -> String
sf2java className src = let (cu, _) = createCU className (compile (SystemF.Parser.reader src)) Nothing in prettyPrint cu

-- `compilesf2java srcPath outputPath` loads a SystemF file at `srcPath`,
-- and writes the compiled Java code to `outputPath`.
-- Example:
--      compilesf2java "id.sf" "id.java"
compilesf2java :: FilePath -> FilePath -> IO ()
compilesf2java srcPath outputPath = do
    src <- readFile srcPath
    let output = sf2java (inferClassName outputPath) src
    writeFile outputPath output

compileJava :: FilePath -> IO ()
compileJava srcPath = system ("javac " ++ srcPath) >> return ()

runJava :: FilePath -> IO ()
runJava srcPath = do
    -- Must "cd" into that directory in order to run the compiled Java code
    setCurrentDirectory (takeDirectory srcPath)
    system $ "java "  ++ takeBaseName srcPath
    system $ "rm *.class"
    setCurrentDirectory ".."

inferOutputPath :: FilePath -> FilePath
inferOutputPath srcPath = directory </> className ++ ".java"
    where directory = takeDirectory srcPath
          className = capitalize $ takeBaseName srcPath

inferClassName :: FilePath -> String
inferClassName outputPath = capitalize $ takeBaseName outputPath

capitalize :: String -> String
capitalize "" = ""
capitalize (s:ss) = Char.toUpper s : ss

main :: IO ()
main = do 
    args <- getArgs
    if length args < 1
        then putStrLn "Usage: f2j <source files>"
        else do 
            let inputPaths = args 
            forM_ inputPaths (\srcPath -> do
                putStr (takeFileName srcPath) >> hFlush stdout
                let outputPath = inferOutputPath srcPath

                putStr (" -> Java source") >> hFlush stdout
                compilesf2java srcPath outputPath 

                putStrLn (" -> Java bytecode") >> hFlush stdout
                compileJava outputPath

                putStr "=> " >> hFlush stdout
                runJava outputPath
                putStrLn ""

                )
