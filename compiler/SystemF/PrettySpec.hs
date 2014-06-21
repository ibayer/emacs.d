module SystemF.Spec where

import Test.Hspec
import Language.Java.Syntax as J

import SystemF.Syntax
import SystemF.Pretty

import qualified TestSuite

prettyPrintPFTyp :: PFTyp Int -> String
prettyPrintPFTyp = prettyPrint

prettyPrintPFExp :: PFExp Int Int -> String
prettyPrintPFExp = prettyPrint

(.->.) = FFun

(.$.) = FApp

main :: IO ()
main = hspec $ do
    describe "name" $ do
        it "a"  $ prettyPrintPFTyp (FTVar 0)  `shouldBe` "a" 
        it "z"  $ prettyPrintPFTyp (FTVar 25) `shouldBe` "z" 
        it "a1" $ prettyPrintPFTyp (FTVar 26) `shouldBe` "a1" 
        it "a2" $ prettyPrintPFTyp (FTVar 27) `shouldBe` "a2" 

    describe "Pretty-printing of types" $ do
        it "Int -> Int -> Int" $ prettyPrintPFTyp (PFInt .->. (PFInt .->. PFInt)) `shouldBe` "Int -> Int -> Int"

        it "forall a. forall b. b" $
            prettyPrintPFTyp (FForall (\a1 -> (FForall (\a2 -> FTVar a2)))) 
            `shouldBe` "forall a. forall b. b"

        it "forall a. forall b. (a -> b) -> a -> b" $
            prettyPrintPFTyp (FForall (\a -> FForall (\b -> (FTVar a .->. FTVar b) .->. (FTVar a .->. FTVar b)))) 
            `shouldBe` "forall a. forall b. (a -> b) -> a -> b" 

        it "forall a. forall b. forall c. (b -> c) -> (a -> b) -> a -> c" $
            prettyPrintPFTyp 
                (FForall (\a -> FForall (\b -> FForall (\c -> 
                    (FTVar b .->. FTVar c) .->. ((FTVar a .->. FTVar b) .->. (FTVar a .->. FTVar c))))))
            `shouldBe` "forall a. forall b. forall c. (b -> c) -> (a -> b) -> a -> c"

    describe "Pretty-printing of expressions" $ do
        it "4 / 2 / (4 / 2)" $
            prettyPrintPFExp (FPrimOp (FPrimOp (FLit 4) J.Div (FLit 2)) J.Div (FPrimOp (FLit 4) J.Div (FLit 2))) 
            `shouldBe` "4 / 2 / (4 / 2)"

        it "(1,(1,1),1)._2._1" $
            prettyPrintPFExp (FProj 1 (FProj 2 (FTuple [FLit 1, FTuple [FLit 1, FLit 1], FLit 1])))
            `shouldBe` "(1,(1,1),1)._2._1"

        it "\\(a : Int -> Int). \\(b : Int). (a b)._1" $
            prettyPrintPFExp (FLam (PFInt .->. PFInt) (\a -> FLam PFInt (\b -> FProj 1 (FVar a .$. FVar b))))
            `shouldBe` "\\(a : Int -> Int). \\(b : Int). (a b)._1" 

        it "/\\a. \\(a : a). \\(b : a). \\(c : a). \\(d : a). a b (c d)" $
            prettyPrintPFExp 
                (FBLam (\a -> 
                    FLam (FTVar a) (\a -> FLam (FTVar a) (\b -> FLam (FTVar a) (\c -> FLam (FTVar a) (\d -> 
                        (FVar a .$. FVar b) .$. (FVar c .$. FVar d)))))))
            `shouldBe` "/\\a. \\(a : a). \\(b : a). \\(c : a). \\(d : a). a b (c d)"

        it "/\\a. \\(a : a). a" $
            prettyPrintPFExp (FBLam (\a1 -> FLam (FTVar a1) (\a -> FVar a))) `shouldBe` "/\\a. \\(a : a). a" 

        it "fix a. \\(b : Int). a b : Int" $
            prettyPrintPFExp (FFix PFInt (\loop x -> FVar loop .$. FVar x) PFInt) 
            `shouldBe` "fix a. \\(b : Int). a b : Int"

        it "fix a. \\(b : Int). if0 b then 1 else b * a (b - 1) : Int" $ 
            prettyPrintPFExp 
                (FFix PFInt (\fact n -> 
                    Fif0 (FVar n) 
                        (FLit 1) 
                        (FPrimOp (FVar n) J.Mult (FVar fact .$. FPrimOp (FVar n) J.Sub (FLit 1)))) PFInt) 
            `shouldBe` "fix a. \\(b : Int). if0 b then 1 else b * a (b - 1) : Int" 

        it "fix a. \\(b : Int). if0 b - 2 then 1 else if0 b - 1 then 1 else a (b - 1) + a (b - 2) : Int" $
            prettyPrintPFExp 
                (FFix PFInt (\fibo n -> 
                    Fif0 (FPrimOp (FVar n) J.Sub (FLit 2))
                        (FLit 1) 
                        (Fif0 (FPrimOp (FVar n) J.Sub (FLit 1)) 
                            (FLit 1) 
                            (FPrimOp (FVar fibo .$. FPrimOp (FVar n) J.Sub (FLit 1)) 
                                J.Add (FVar fibo .$. FPrimOp (FVar n) J.Sub (FLit 2))))) PFInt) 
            `shouldBe` "fix a. \\(b : Int). if0 b - 2 then 1 else if0 b - 1 then 1 else a (b - 1) + a (b - 2) : Int"

        it "(\\(a : Int). a * a) 1 + 2" $
            prettyPrintPFExp (FPrimOp (FLam PFInt (\a -> FPrimOp (FVar a) J.Mult (FVar a)) .$. FLit 1) J.Add (FLit 2))
            `shouldBe` "(\\(a : Int). a * a) 1 + 2"

        it "(\\(a : Int). a * a) (1 + 2)" $
            prettyPrintPFExp (FLam PFInt (\a -> FPrimOp (FVar a) J.Mult (FVar a)) .$. FPrimOp (FLit 1) J.Add (FLit 2)) 
            `shouldBe` "(\\(a : Int). a * a) (1 + 2)"

        it "/\\a. (\\(a : a). a) (\\(a : a). a)" $
            prettyPrintPFExp (FBLam (\a -> FLam (FTVar a) (\a -> FVar a) .$. (FLam (FTVar a) (\a -> FVar a))))
            `shouldBe` "/\\a. (\\(a : a). a) (\\(a : a). a)" 

        it "/\\a. \\(a : a -> a). \\(b : a). a (a (a b))" $ 
            prettyPrintPFExp 
                (FBLam (\a -> 
                    FLam (FTVar a .->. FTVar a) (\a -> FLam (FTVar a) (\b -> 
                        FVar a .$. (FVar a .$. (FVar a .$. FVar b))))))
            `shouldBe` "/\\a. \\(a : a -> a). \\(b : a). a (a (a b))" 

        it "/\\a. /\\b. \\(a : a). (\\(b : b). a (b b)) (\\(b : b). a (b b))" $
            prettyPrintPFExp
                (FBLam (\a -> FBLam (\b ->
                    FLam (FTVar a) (\a ->
                        FLam (FTVar b) (\b -> FVar a .$. (FVar b .$. FVar b)) .$. FLam (FTVar b) (\b -> FVar a .$. (FVar b .$. FVar b))))))
            `shouldBe` "/\\a. /\\b. \\(a : a). (\\(b : b). a (b b)) (\\(b : b). a (b b))" 
