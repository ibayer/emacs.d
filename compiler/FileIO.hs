{-# LANGUAGE ScopedTypeVariables #-}

module FileIO where

import System.IO
import System.Process hiding (runCommand)
import System.Directory			(removeFile, doesFileExist)
import qualified Control.Exception as E

import Data.Char
import Data.List.Split
import Data.List

import Translations

type Connection = (Handle, Handle)

wrap :: Connection -> Bool -> String -> IO ()
wrap (inP, outP) flagS name = do
	send inP flagS name 
	exist <- doesFileExist name
	if exist
	  then receiveMsg outP
	  else return ()

send :: Handle -> Bool -> String -> IO () 
send h flagS name = do 
	exist <- doesFileExist name
	if not exist 
	  then do
	    putStrLn (name ++ " does not exist")
	    return ()
	  else do
	    let className = getClassName name
	    sfToJava h flagS name

getClassName :: String -> String
getClassName (x : xs) = (toUpper x) : (takeWhile (/= '.') xs)

sfToJava :: Handle -> Bool -> FilePath -> IO ()
sfToJava h flagS f = do 
	contents <- readFile f
	let className = getClassName f
	result <- E.try (sf2java 0 False compileAO className contents)
	case result of 
	  Left  (_ :: E.SomeException) -> do 
	  	putStrLn "invalid expression"
		removeFile f
	  Right javaFile	       -> do 
	  	sendMsg h (className ++ ".java")
		let file = javaFile ++ "\n" ++  "//end of file"
	  	sendFile h file
	  	case flagS of 
	    	  True -> do putStrLn contents
	  	  	     putStrLn file
	    	  False -> return () 
	
receiveMsg :: Handle -> IO () 
receiveMsg h = do
	msg <- hGetLine h
	if msg == "exit" 
	  then return () 
	  else do putStrLn msg
       		  s <- receiveMsg h
		  return ()

sendMsg :: Handle -> String -> IO ()
sendMsg h msg = do 
	hPutStrLn h msg

sendFile :: Handle -> String -> IO ()
sendFile h f = do
	hPutStrLn h f

