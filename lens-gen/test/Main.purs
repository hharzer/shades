module Test.Main where

import Data.Show (show)
import Effect (Effect)
import Lens (TSType(..), compact, getbase, idx, lens, modbase, path, setbase, traversal)
import Prelude (Unit, discard, ($), (>>>))
import Test.Spec (describe, it, itOnly)
import Test.Spec.Assertions (shouldEqual)
import Test.Spec.Reporter.Console (consoleReporter)
import Test.Spec.Runner (run)

main :: Effect Unit
main = run [consoleReporter] do
  describe "tests" do
    describe "utils" do
      it "should compact functors" do
        let
          f = TSVar "F"
          t1 = TSVar "T1"
          t2 = TSVar "T2"
        (compact $ TSFunctor {functor: f, inType: t1, outType: t1}) `shouldEqual` f
        (compact $ TSFunctor {functor: f, inType: t1, outType: TSFunctor { functor: t1, inType: t2, outType: t2 } }) `shouldEqual` f
        (compact $ TSIndex $ TSIndex $ TSFunctor {functor: f, inType: t1, outType: TSFunctor { functor: t1, inType: t2, outType: TSFunctor {functor: t2, inType: f, outType: f} } }) `shouldEqual` (TSIndex $ TSIndex f)
        (compact $ TSFunctor {functor: f, inType: t1, outType: TSFunctor { functor: f, inType: t2, outType: t2 } }) `shouldEqual` (TSFunctor {functor: f, inType: t1, outType: f})
    describe "get tests" do
      it "should ouput basic signatures" do 
        (show $ path getbase) `shouldEqual` "declare function get<K1 extends string>(k1: K1): <S extends HasKey<K1>>(s: S) => S[K1]"
        (show $ idx getbase) `shouldEqual` "declare function get(i1: number): <S extends Indexable>(s: S) => Index<S>"
        (show $ traversal getbase) `shouldEqual` "declare function get<T1>(t1: Traversal<T1>): <F1 extends Collection<T1>>(s: F1) => F1"
        (show $ lens getbase) `shouldEqual` "declare function get<S1, A1>(l1: Lens<S1, A1>): (s: S1) => A1"
      
      it "should stack signatures together (w/o traversals)" do
        (show $ (path >>> path) getbase) `shouldEqual` "declare function get<K1 extends string, K2 extends string>(k1: K1, k2: K2): <S extends HasKey<K1, HasKey<K2>>>(s: S) => S[K1][K2]"
        (show $ (path >>> idx) getbase) `shouldEqual` "declare function get<K1 extends string>(k1: K1, i2: number): <S extends HasKey<K1, Indexable>>(s: S) => Index<S[K1]>"
        (show $ (idx >>> path) getbase) `shouldEqual` "declare function get<K2 extends string>(i1: number, k2: K2): <S extends Indexable<HasKey<K2>>>(s: S) => Index<S>[K2]"
        (show $ (idx >>> idx) getbase) `shouldEqual` "declare function get(i1: number, i2: number): <S extends Indexable<Indexable>>(s: S) => Index<Index<S>>"

      describe "should stack with traversals" do
        it "should handle paths" do
          (show $ (path >>> traversal) getbase) `shouldEqual` "declare function get<K1 extends string, T2>(k1: K1, t2: Traversal<T2>): <F2 extends Collection<T2>>(s: HasKey<K1, F2>) => F2"
          (show $ (traversal >>> path) getbase) `shouldEqual` "declare function get<T1 extends HasKey<K2>, K2 extends string>(t1: Traversal<T1>, k2: K2): <F1 extends Collection<T1>>(s: F1) => Functor<F1, T1, T1[K2]>"
            
        it "should handle index" do
          (show $ (traversal >>> idx) getbase) `shouldEqual` "declare function get<T1 extends Indexable>(t1: Traversal<T1>, i2: number): <F1 extends Collection<T1>>(s: F1) => Functor<F1, T1, Index<T1>>"
          (show $ (idx >>> traversal) getbase) `shouldEqual` "declare function get<T2>(i1: number, t2: Traversal<T2>): <F2 extends Collection<T2>>(s: Indexable<F2>) => F2"
            
        it "should handle traversal on traversal actions" do
          (show $ (traversal >>> traversal) getbase) `shouldEqual` "declare function get<T1 extends Collection<T2>, T2>(t1: Traversal<T1>, t2: Traversal<T2>): <F1 extends Collection<T1>>(s: F1) => F1"

        it "should only apply constraints to last traversal" do
          (show $ (traversal >>> traversal >>> path) getbase) `shouldEqual` "declare function get<T1 extends Collection<T2>, T2 extends HasKey<K3>, K3 extends string>(t1: Traversal<T1>, t2: Traversal<T2>, k3: K3): <F1 extends Collection<T1>>(s: F1) => Functor<F1, T1, Functor<T1, T2, T2[K3]>>"
      
      describe "should stack with lenses" do
        it "lens on prim" do
          (show $ (path >>> lens) getbase) `shouldEqual` "declare function get<K1 extends string, S2, A2>(k1: K1, l2: Lens<S2, A2>): (s: HasKey<K1, S2>) => A2"
          (show $ (lens >>> path) getbase) `shouldEqual` "declare function get<S1, A1 extends HasKey<K2>, K2 extends string>(l1: Lens<S1, A1>, k2: K2): (s: S1) => A1[K2]"
          (show $ (idx >>> lens) getbase) `shouldEqual` "declare function get<S2, A2>(i1: number, l2: Lens<S2, A2>): (s: Indexable<S2>) => A2"
          (show $ (lens >>> idx) getbase) `shouldEqual` "declare function get<S1, A1 extends Indexable>(l1: Lens<S1, A1>, i2: number): (s: S1) => Index<A1>"

        it "should stack lenses on lenses" do
          (show $ (lens $ lens getbase)) `shouldEqual` "declare function get<S1, A1, A2>(l1: Lens<S1, A1>, l2: Lens<A1, A2>): (s: S1) => A2"
        
        it "stacks with traversals" do
          (show $ (traversal >>> lens) getbase) `shouldEqual` "declare function get<T1, A2>(t1: Traversal<T1>, l2: Lens<T1, A2>): <F1 extends Collection<T1>>(s: F1) => Functor<F1, T1, A2>"
          (show $ (lens >>> traversal) getbase) `shouldEqual` "declare function get<S1, A1 extends Collection<T2>, T2>(l1: Lens<S1, A1>, t2: Traversal<T2>): (s: S1) => A1"

      describe "spot check of complex combos" do
        it "TPP" do
          (show $ (traversal >>> path >>> path) getbase) `shouldEqual` "declare function get<T1 extends HasKey<K2, HasKey<K3>>, K2 extends string, K3 extends string>(t1: Traversal<T1>, k2: K2, k3: K3): <F1 extends Collection<T1>>(s: F1) => Functor<F1, T1, T1[K2][K3]>"
        it "TPT" do
          (show $ (traversal >>> path >>> traversal) getbase) `shouldEqual` "declare function get<T1 extends HasKey<K2, Collection<T3>>, K2 extends string, T3>(t1: Traversal<T1>, k2: K2, t3: Traversal<T3>): <F1 extends Collection<T1>>(s: F1) => Functor<F1, T1, T1[K2]>"
        it "PTP" do 
          (show $ (path >>> traversal >>> path) getbase) `shouldEqual` "declare function get<K1 extends string, T2 extends HasKey<K3>, K3 extends string>(k1: K1, t2: Traversal<T2>, k3: K3): <F2 extends Collection<T2>>(s: HasKey<K1, F2>) => Functor<F2, T2, T2[K3]>"
        it "TTPPI" do
          (show $ (traversal >>> traversal >>> path >>> path >>> idx) getbase) `shouldEqual` "declare function get<T1 extends Collection<T2>, T2 extends HasKey<K3, HasKey<K4, Indexable>>, K3 extends string, K4 extends string>(t1: Traversal<T1>, t2: Traversal<T2>, k3: K3, k4: K4, i5: number): <F1 extends Collection<T1>>(s: F1) => Functor<F1, T1, Functor<T1, T2, Index<T2[K3][K4]>>>"
        it "ITKK" do 
          (show $ (idx >>> traversal >>> path >>> path) getbase) `shouldEqual` "declare function get<T2 extends HasKey<K3, HasKey<K4>>, K3 extends string, K4 extends string>(i1: number, t2: Traversal<T2>, k3: K3, k4: K4): <F2 extends Collection<T2>>(s: Indexable<F2>) => Functor<F2, T2, T2[K3][K4]>"
        it "TIKK" do
          (show $ (traversal >>> idx >>> path >>> path) getbase) `shouldEqual` "declare function get<T1 extends Indexable<HasKey<K3, HasKey<K4>>>, K3 extends string, K4 extends string>(t1: Traversal<T1>, i2: number, k3: K3, k4: K4): <F1 extends Collection<T1>>(s: F1) => Functor<F1, T1, Index<T1>[K3][K4]>"
        it "TPL" do
          (show $ (traversal >>> path >>> lens) getbase) `shouldEqual` "declare function get<T1 extends HasKey<K2>, K2 extends string, A3>(t1: Traversal<T1>, k2: K2, l3: Lens<T1[K2], A3>): <F1 extends Collection<T1>>(s: F1) => Functor<F1, T1, A3>"
        it "PPLL" do
          (show $ (path >>> path >>> lens >>> lens) getbase) `shouldEqual` "declare function get<K1 extends string, K2 extends string, S3, A3, A4>(k1: K1, k2: K2, l3: Lens<S3, A3>, l4: Lens<A3, A4>): (s: HasKey<K1, HasKey<K2, S3>>) => A4"
        it "LLPTP" do
          (show $ (lens >>> lens >>> path >>> traversal >>> path) getbase) `shouldEqual` "declare function get<S1, A1, A2 extends HasKey<K3, Collection<T4>>, K3 extends string, T4 extends HasKey<K5>, K5 extends string>(l1: Lens<S1, A1>, l2: Lens<A1, A2>, k3: K3, t4: Traversal<T4>, k5: K5): (s: S1) => Functor<A2[K3], T4, T4[K5]>"
        it "LLPTL" do
          (show $ (lens >>> lens >>> path >>> traversal >>> lens) getbase) `shouldEqual` "declare function get<S1, A1, A2 extends HasKey<K3, Collection<T4>>, K3 extends string, T4, A5>(l1: Lens<S1, A1>, l2: Lens<A1, A2>, k3: K3, t4: Traversal<T4>, l5: Lens<T4, A5>): (s: S1) => Functor<A2[K3], T4, A5>"

  describe "set tests" do
      it "should ouput basic signatures" do 
        (show $ path setbase) `shouldEqual` "declare function set<K1 extends string>(k1: K1): <V>(v: V) => <S extends HasKey<K1, V>>(s: S) => S"
        (show $ idx setbase) `shouldEqual` "declare function set(i1: number): <V>(v: V) => <S extends Indexable<V>>(s: S) => S"
        (show $ traversal setbase) `shouldEqual` "declare function set<T1>(t1: Traversal<T1>): (v: T1) => <S extends Collection<T1>>(s: S) => S"
        (show $ lens setbase) `shouldEqual` "declare function set<S1, A1>(l1: Lens<S1, A1>): (v: A1) => (s: S1) => S1"
      
      it "should stack signatures together (w/o traversals)" do
        (show $ (path >>> path) setbase) `shouldEqual` "declare function set<K1 extends string, K2 extends string>(k1: K1, k2: K2): <V>(v: V) => <S extends HasKey<K1, HasKey<K2, V>>>(s: S) => S"
        (show $ (path >>> idx) setbase) `shouldEqual` "declare function set<K1 extends string>(k1: K1, i2: number): <V>(v: V) => <S extends HasKey<K1, Indexable<V>>>(s: S) => S"
        (show $ (idx >>> path) setbase) `shouldEqual` "declare function set<K2 extends string>(i1: number, k2: K2): <V>(v: V) => <S extends Indexable<HasKey<K2, V>>>(s: S) => S"
        (show $ (idx >>> idx) setbase) `shouldEqual` "declare function set(i1: number, i2: number): <V>(v: V) => <S extends Indexable<Indexable<V>>>(s: S) => S"
          
      describe "should stack with traversals" do
        it "should handle paths" do
          (show $ (path >>> traversal) setbase) `shouldEqual` "declare function set<K1 extends string, T2>(k1: K1, t2: Traversal<T2>): (v: T2) => <S extends HasKey<K1, Collection<T2>>>(s: S) => S"
          (show $ (traversal >>> path) setbase) `shouldEqual` "declare function set<T1 extends HasKey<K2>, K2 extends string>(t1: Traversal<T1>, k2: K2): (v: T1[K2]) => <S extends Collection<T1>>(s: S) => S"
            
        it "should handle index" do
          (show $ (traversal >>> idx) setbase) `shouldEqual` "declare function set<T1 extends Indexable>(t1: Traversal<T1>, i2: number): (v: Index<T1>) => <S extends Collection<T1>>(s: S) => S"
          (show $ (idx >>> traversal) setbase) `shouldEqual` "declare function set<T2>(i1: number, t2: Traversal<T2>): (v: T2) => <S extends Indexable<Collection<T2>>>(s: S) => S"
            
        it "should handle traversal on traversal actions" do
          (show $ (traversal >>> traversal) setbase) `shouldEqual` "declare function set<T1 extends Collection<T2>, T2>(t1: Traversal<T1>, t2: Traversal<T2>): (v: T2) => <S extends Collection<T1>>(s: S) => S"

        it "should only apply constraints to last traversal" do
          (show $ (traversal >>> traversal >>> path) setbase) `shouldEqual` "declare function set<T1 extends Collection<T2>, T2 extends HasKey<K3>, K3 extends string>(t1: Traversal<T1>, t2: Traversal<T2>, k3: K3): (v: T2[K3]) => <S extends Collection<T1>>(s: S) => S"
      
      describe "should stack with lenses" do
        it "lens on prim" do
          (show $ (path >>> lens) setbase) `shouldEqual` "declare function set<K1 extends string, S2, A2>(k1: K1, l2: Lens<S2, A2>): (v: A2) => <S extends HasKey<K1, S2>>(s: S) => S"
          (show $ (lens >>> path) setbase) `shouldEqual` "declare function set<S1, A1 extends HasKey<K2>, K2 extends string>(l1: Lens<S1, A1>, k2: K2): (v: A1[K2]) => (s: S1) => S1"
          (show $ (idx >>> lens) setbase) `shouldEqual` "declare function set<S2, A2>(i1: number, l2: Lens<S2, A2>): (v: A2) => <S extends Indexable<S2>>(s: S) => S"
          (show $ (lens >>> idx) setbase) `shouldEqual` "declare function set<S1, A1 extends Indexable>(l1: Lens<S1, A1>, i2: number): (v: Index<A1>) => (s: S1) => S1"

        it "should stack lenses on lenses" do
          (show $ (lens $ lens setbase)) `shouldEqual` "declare function set<S1, A1, A2>(l1: Lens<S1, A1>, l2: Lens<A1, A2>): (v: A2) => (s: S1) => S1"
        
        it "stacks with traversals" do
          (show $ (traversal >>> lens) setbase) `shouldEqual` "declare function set<T1, A2>(t1: Traversal<T1>, l2: Lens<T1, A2>): (v: A2) => <S extends Collection<T1>>(s: S) => S"
          (show $ (lens >>> traversal) setbase) `shouldEqual` "declare function set<S1, A1 extends Collection<T2>, T2>(l1: Lens<S1, A1>, t2: Traversal<T2>): (v: T2) => (s: S1) => S1"

      describe "spot check of complex combos" do
        it "PTP" do 
          (show $ (path >>> traversal >>> path) setbase) `shouldEqual` "declare function set<K1 extends string, T2 extends HasKey<K3>, K3 extends string>(k1: K1, t2: Traversal<T2>, k3: K3): (v: T2[K3]) => <S extends HasKey<K1, Collection<T2>>>(s: S) => S"
        it "TTPPI" do
          (show $ (traversal >>> traversal >>> path >>> path >>> idx) setbase) `shouldEqual` "declare function set<T1 extends Collection<T2>, T2 extends HasKey<K3, HasKey<K4, Indexable>>, K3 extends string, K4 extends string>(t1: Traversal<T1>, t2: Traversal<T2>, k3: K3, k4: K4, i5: number): (v: Index<T2[K3][K4]>) => <S extends Collection<T1>>(s: S) => S"
        it "ITKK" do 
          (show $ (idx >>> traversal >>> path >>> path) setbase) `shouldEqual` "declare function set<T2 extends HasKey<K3, HasKey<K4>>, K3 extends string, K4 extends string>(i1: number, t2: Traversal<T2>, k3: K3, k4: K4): (v: T2[K3][K4]) => <S extends Indexable<Collection<T2>>>(s: S) => S"
        it "TIKK" do
          (show $ (traversal >>> idx >>> path >>> path) setbase) `shouldEqual` "declare function set<T1 extends Indexable<HasKey<K3, HasKey<K4>>>, K3 extends string, K4 extends string>(t1: Traversal<T1>, i2: number, k3: K3, k4: K4): (v: Index<T1>[K3][K4]) => <S extends Collection<T1>>(s: S) => S"
        it "TPL" do
          (show $ (traversal >>> path >>> lens) setbase) `shouldEqual` "declare function set<T1 extends HasKey<K2>, K2 extends string, A3>(t1: Traversal<T1>, k2: K2, l3: Lens<T1[K2], A3>): (v: A3) => <S extends Collection<T1>>(s: S) => S"
        it "PPLL" do
          (show $ (path >>> path >>> lens >>> lens) setbase) `shouldEqual` "declare function set<K1 extends string, K2 extends string, S3, A3, A4>(k1: K1, k2: K2, l3: Lens<S3, A3>, l4: Lens<A3, A4>): (v: A4) => <S extends HasKey<K1, HasKey<K2, S3>>>(s: S) => S"
        it "LLPTP" do
          (show $ (lens >>> lens >>> path >>> traversal >>> path) setbase) `shouldEqual` "declare function set<S1, A1, A2 extends HasKey<K3, Collection<T4>>, K3 extends string, T4 extends HasKey<K5>, K5 extends string>(l1: Lens<S1, A1>, l2: Lens<A1, A2>, k3: K3, t4: Traversal<T4>, k5: K5): (v: T4[K5]) => (s: S1) => S1"
        it "LLPTL" do
          (show $ (lens >>> lens >>> path >>> traversal >>> lens) setbase) `shouldEqual` "declare function set<S1, A1, A2 extends HasKey<K3, Collection<T4>>, K3 extends string, T4, A5>(l1: Lens<S1, A1>, l2: Lens<A1, A2>, k3: K3, t4: Traversal<T4>, l5: Lens<T4, A5>): (v: A5) => (s: S1) => S1"

  describe "mod tests" do
      it "should ouput basic signatures" do 
        (show $ path modbase) `shouldEqual` "declare function mod<K1 extends string>(k1: K1): <V>(f: (v: V) => V) => <S extends HasKey<K1, V>>(s: S) => S"
        (show $ idx modbase) `shouldEqual` "declare function mod(i1: number): <V>(f: (v: V) => V) => <S extends Indexable<V>>(s: S) => S"
        (show $ traversal modbase) `shouldEqual` "declare function mod<T1>(t1: Traversal<T1>): (f: (v: T1) => T1) => <S extends Collection<T1>>(s: S) => S"
      
      it "should stack signatures together (w/o traversals)" do
        (show $ (path >>> path) modbase) `shouldEqual` "declare function mod<K1 extends string, K2 extends string>(k1: K1, k2: K2): <V>(f: (v: V) => V) => <S extends HasKey<K1, HasKey<K2, V>>>(s: S) => S"
        (show $ (path >>> idx) modbase) `shouldEqual` "declare function mod<K1 extends string>(k1: K1, i2: number): <V>(f: (v: V) => V) => <S extends HasKey<K1, Indexable<V>>>(s: S) => S"
        (show $ (idx >>> path) modbase) `shouldEqual` "declare function mod<K2 extends string>(i1: number, k2: K2): <V>(f: (v: V) => V) => <S extends Indexable<HasKey<K2, V>>>(s: S) => S"
        (show $ (idx >>> idx) modbase) `shouldEqual` "declare function mod(i1: number, i2: number): <V>(f: (v: V) => V) => <S extends Indexable<Indexable<V>>>(s: S) => S"

      describe "should stack with traversals" do
        it "should handle paths" do
          (show $ (path >>> traversal) modbase) `shouldEqual` "declare function mod<K1 extends string, T2>(k1: K1, t2: Traversal<T2>): (f: (v: T2) => T2) => <S extends HasKey<K1, Collection<T2>>>(s: S) => S"
          (show $ (traversal >>> path) modbase) `shouldEqual` "declare function mod<T1 extends HasKey<K2>, K2 extends string>(t1: Traversal<T1>, k2: K2): (f: (v: T1[K2]) => T1[K2]) => <S extends Collection<T1>>(s: S) => S"
            
        it "should handle index" do
          (show $ (traversal >>> idx) modbase) `shouldEqual` "declare function mod<T1 extends Indexable>(t1: Traversal<T1>, i2: number): (f: (v: Index<T1>) => Index<T1>) => <S extends Collection<T1>>(s: S) => S"
          (show $ (idx >>> traversal) modbase) `shouldEqual` "declare function mod<T2>(i1: number, t2: Traversal<T2>): (f: (v: T2) => T2) => <S extends Indexable<Collection<T2>>>(s: S) => S"
            
        it "should handle traversal on traversal actions" do
          (show $ (traversal >>> traversal) modbase) `shouldEqual` "declare function mod<T1 extends Collection<T2>, T2>(t1: Traversal<T1>, t2: Traversal<T2>): (f: (v: T2) => T2) => <S extends Collection<T1>>(s: S) => S"

        it "should only apply constraints to last traversal" do
          (show $ (traversal >>> traversal >>> path) modbase) `shouldEqual` "declare function mod<T1 extends Collection<T2>, T2 extends HasKey<K3>, K3 extends string>(t1: Traversal<T1>, t2: Traversal<T2>, k3: K3): (f: (v: T2[K3]) => T2[K3]) => <S extends Collection<T1>>(s: S) => S"
      
      describe "should stack with lenses" do
        it "lens on prim" do
          (show $ (path >>> lens) modbase) `shouldEqual` "declare function mod<K1 extends string, S2, A2>(k1: K1, l2: Lens<S2, A2>): (f: (v: A2) => A2) => <S extends HasKey<K1, S2>>(s: S) => S"
          (show $ (lens >>> path) modbase) `shouldEqual` "declare function mod<S1, A1 extends HasKey<K2>, K2 extends string>(l1: Lens<S1, A1>, k2: K2): (f: (v: A1[K2]) => A1[K2]) => (s: S1) => S1"
          (show $ (idx >>> lens) modbase) `shouldEqual` "declare function mod<S2, A2>(i1: number, l2: Lens<S2, A2>): (f: (v: A2) => A2) => <S extends Indexable<S2>>(s: S) => S"
          (show $ (lens >>> idx) modbase) `shouldEqual` "declare function mod<S1, A1 extends Indexable>(l1: Lens<S1, A1>, i2: number): (f: (v: Index<A1>) => Index<A1>) => (s: S1) => S1"

        it "should stack lenses on lenses" do
          (show $ (lens $ lens modbase)) `shouldEqual` "declare function mod<S1, A1, A2>(l1: Lens<S1, A1>, l2: Lens<A1, A2>): (f: (v: A2) => A2) => (s: S1) => S1"
        
        it "stacks with traversals" do
          (show $ (traversal >>> lens) modbase) `shouldEqual` "declare function mod<T1, A2>(t1: Traversal<T1>, l2: Lens<T1, A2>): (f: (v: A2) => A2) => <S extends Collection<T1>>(s: S) => S"
          (show $ (lens >>> traversal) modbase) `shouldEqual` "declare function mod<S1, A1 extends Collection<T2>, T2>(l1: Lens<S1, A1>, t2: Traversal<T2>): (f: (v: T2) => T2) => (s: S1) => S1"

      describe "spot check of complex combos" do
        it "PTP" do 
          (show $ (path >>> traversal >>> path) modbase) `shouldEqual` "declare function mod<K1 extends string, T2 extends HasKey<K3>, K3 extends string>(k1: K1, t2: Traversal<T2>, k3: K3): (f: (v: T2[K3]) => T2[K3]) => <S extends HasKey<K1, Collection<T2>>>(s: S) => S"
        it "TTPPI" do
          (show $ (traversal >>> traversal >>> path >>> path >>> idx) modbase) `shouldEqual` "declare function mod<T1 extends Collection<T2>, T2 extends HasKey<K3, HasKey<K4, Indexable>>, K3 extends string, K4 extends string>(t1: Traversal<T1>, t2: Traversal<T2>, k3: K3, k4: K4, i5: number): (f: (v: Index<T2[K3][K4]>) => Index<T2[K3][K4]>) => <S extends Collection<T1>>(s: S) => S"
        it "ITKK" do 
          (show $ (idx >>> traversal >>> path >>> path) modbase) `shouldEqual` "declare function mod<T2 extends HasKey<K3, HasKey<K4>>, K3 extends string, K4 extends string>(i1: number, t2: Traversal<T2>, k3: K3, k4: K4): (f: (v: T2[K3][K4]) => T2[K3][K4]) => <S extends Indexable<Collection<T2>>>(s: S) => S"
        it "TIKK" do
          (show $ (traversal >>> idx >>> path >>> path) modbase) `shouldEqual` "declare function mod<T1 extends Indexable<HasKey<K3, HasKey<K4>>>, K3 extends string, K4 extends string>(t1: Traversal<T1>, i2: number, k3: K3, k4: K4): (f: (v: Index<T1>[K3][K4]) => Index<T1>[K3][K4]) => <S extends Collection<T1>>(s: S) => S"
        it "TPL" do
          (show $ (traversal >>> path >>> lens) modbase) `shouldEqual` "declare function mod<T1 extends HasKey<K2>, K2 extends string, A3>(t1: Traversal<T1>, k2: K2, l3: Lens<T1[K2], A3>): (f: (v: A3) => A3) => <S extends Collection<T1>>(s: S) => S"
        it "PPLL" do
          (show $ (path >>> path >>> lens >>> lens) modbase) `shouldEqual` "declare function mod<K1 extends string, K2 extends string, S3, A3, A4>(k1: K1, k2: K2, l3: Lens<S3, A3>, l4: Lens<A3, A4>): (f: (v: A4) => A4) => <S extends HasKey<K1, HasKey<K2, S3>>>(s: S) => S"
        it "LLPTP" do
          (show $ (lens >>> lens >>> path >>> traversal >>> path) modbase) `shouldEqual` "declare function mod<S1, A1, A2 extends HasKey<K3, Collection<T4>>, K3 extends string, T4 extends HasKey<K5>, K5 extends string>(l1: Lens<S1, A1>, l2: Lens<A1, A2>, k3: K3, t4: Traversal<T4>, k5: K5): (f: (v: T4[K5]) => T4[K5]) => (s: S1) => S1"
        it "LLPTL" do
          (show $ (lens >>> lens >>> path >>> traversal >>> lens) modbase) `shouldEqual` "declare function mod<S1, A1, A2 extends HasKey<K3, Collection<T4>>, K3 extends string, T4, A5>(l1: Lens<S1, A1>, l2: Lens<A1, A2>, k3: K3, t4: Traversal<T4>, l5: Lens<T4, A5>): (f: (v: A5) => A5) => (s: S1) => S1"