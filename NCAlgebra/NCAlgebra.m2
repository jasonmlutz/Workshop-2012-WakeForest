newPackage("NCAlgebra",
     Headline => "Data types for Noncommutative algebras",
     Version => "0.5",
     Date => "September 8, 2013",
     Authors => {
	  {Name => "Frank Moore",
	   HomePage => "http://www.math.wfu.edu/Faculty/Moore.html",
	   Email => "moorewf@wfu.edu"},
	  {Name => "Andrew Conner",
	   HomePage => "http://www.math.wfu.edu/Faculty/Conner.html",
	   Email => "connerab@wfu.edu"}},
     AuxiliaryFiles => true,
     DebuggingMode => true
     )

export { NCRing, NCQuotientRing, NCPolynomialRing,
         generatorSymbols, weights,  -- can I get away with not exporting these somehow?
         NCRingElement, isReduced,
         NCGroebnerBasis, ncGroebnerBasis, maxNCGBDegree, minNCGBDegree,
         NCIdeal, NCLeftIdeal, NCRightIdeal,
         ncIdeal, ncLeftIdeal, ncRightIdeal,
         twoSidedNCGroebnerBasisBergman,
         gbFromOutputFile,
         CacheBergmanGB,
         ClearDenominators,
         InstallGB,
         ReturnIdeal,
         NumberOfBins,
         normalFormBergman,
         hilbertBergman, DegreeVariable,
         rightKernelBergman,
	 isLeftRegular,
         isRightRegular,
         centralElements,
         normalElements,
	 assignDegrees,
         normalAutomorphism,
         leftMultiplicationMap,
         rightMultiplicationMap,
         rightKernel,
         NCMatrix, ncMatrix,
 --        NCMonomial,
         monList,
         isCentral,
         ncMap,
         functionHash,
         oreExtension,oreIdeal,
         endomorphismRing,endomorphismRingGens,
         minimizeRelations,checkHomRelations,
         skewPolynomialRing,
	 abelianization,
	 skewAbelianization,
	 oppositeRing,
         quadraticClosure,
	 homogDual,
	 sparseCoeffs,
	 wallTiming
}

MAXDEG = 40
MAXSIZE = 40

-- Andy's bergman path
--bergmanPath = "/usr/local/bergman1.001"
-- Frank's bergman path
bergmanPath = "~/bergman"

NCRing = new Type of Ring
NCQuotientRing = new Type of NCRing
NCPolynomialRing = new Type of NCRing
NCRingElement = new Type of MutableHashTable
NCGroebnerBasis = new Type of HashTable
NCMatrix = new Type of MutableHashTable
NCMonomial = new Type of HashTable
NCIdeal = new Type of HashTable
NCLeftIdeal = new Type of HashTable
NCRightIdeal = new Type of HashTable
NCRingMap = new Type of HashTable

---------------------------------------------------------------
--- Helpful general-purpose functions
---------------------------------------------------------------

removeNulls = xs -> select(xs, x -> x =!= null)

removeZeroes = myHash -> select(myHash, c -> c != 0)

minUsing = (xs,f) -> (
   n := min (xs / f);
   first select(1,xs, x -> f x == n)
)

sortUsing = (xs,f) -> (sort apply(xs, x -> (f x, x))) / last
reverseSortUsing = (xs, f) -> (reverse sort apply(xs, x -> (f x, x))) / last

-- get base m representation of an integer n
rebase = (m,n) -> (
   if (n < 0) then error "Must provide an integer greater than or equal to 1";
   if n == 0 then return {};
   if n == 1 then return {1};
   k := floor (log_m n);
   loopn := n;
   reverse for i from 0 to k list (
      digit := loopn // m^(k-i);
      loopn = loopn % m^(k-i);
      digit
   )   
)

-- list-based mingle
functionMingle = method()
functionMingle (List, List, FunctionClosure) := (xs,ys,f) -> (
   -- This function merges the lists xs and ys together, but merges them according to the function f.
   -- If f(i) is true, then the function takes the next unused element from xs.  Otherwise, the next
   -- unused element of ys is taken.  If either list is 'asked' for an element and has run out,
   -- then the list built so far is returned.
   xlen := #xs;
   ylen := #ys;
   ix := -1;
   iy := -1;
   for ians from 0 to xlen+ylen-1 list (
      if f ians then (
         ix = ix + 1;
         if ix >= xlen then break;
         xs#ix
      )
      else (
         iy = iy + 1;
         if iy >= ylen then break;
         ys#iy
      )
   )
)

-------------------------------------------
--- NCRing methods ------------------------
-------------------------------------------
coefficientRing NCRing := A -> A.CoefficientRing

generators NCRing := opts -> A -> (
    if A.?generators then A.generators else {}
)

numgens NCRing := A -> #(A.generators)

use NCRing := A -> (scan(A.generatorSymbols, A.generators, (sym,val) -> sym <- val); A)

setWeights = method()
setWeights (NCRing,List) := (A,weightList) -> (
   gensA := A.generatorSymbols;
   A#(symbol weights) = new HashTable from apply(#gensA, i -> (gensA#i,weightList#i));
   A
)

promoteHash = (termHash,A) -> (
   hashTable apply(pairs termHash, p -> (ncMonomial(p#0#monList,A),p#1))
)

isHomogeneous NCRing := A -> (
   if instance(A,NCPolynomialRing) then true
   else isHomogeneous ideal A
)

-------------------------------------------
--- NCPolynomialRing methods --------------
-------------------------------------------

new NCPolynomialRing from List := (NCPolynomialRing, inits) -> new NCPolynomialRing of NCRingElement from new HashTable from inits

Ring List := (R, varList) -> (
   -- get the symbols associated to the list that is passed in, in case the variables have been used earlier.
   if #varList == 0 then error "Expected at least one variable.";
   if #varList == 1 and class varList#0 === Sequence then varList = toList first varList;
   varList = varList / baseName;
   A := new NCPolynomialRing from {(symbol generators) => {},
                                   (symbol generatorSymbols) => varList,
                                   (symbol CoefficientRing) => R,
                                   (symbol cache) => new CacheTable from {},
                                   "BergmanRing" => false};
   newGens := apply(varList, v -> v <- putInRing({v},A,1));

   if R === QQ or R === ZZ/(char R) then A#"BergmanRing" = true;

   A#(symbol generators) = newGens;
   
   setWeights(A, toList (#(gens A):1));
      
   promote (ZZ,A) := (n,A) -> putInRing({},A,promote(n,R));

   promote (QQ,A) := (n,A) -> putInRing({},A,promote(n,R));
   
   promote (R,A) := (n,A) -> putInRing({},A,n);
   
   promote (NCMatrix,A) := (M,A) -> (
       prom := ncMatrix apply(M.matrix, row -> apply(row, entry -> promote(entry,A)));
       if isHomogeneous M then
          assignDegrees(prom,M.target,M.source);
       prom
   );

   promote (A,A) := (f,A) -> f;
   
   A + A := (f,g) -> (
      newHash := new MutableHashTable from pairs f.terms;
   
      for s in pairs g.terms do (
         newMon := s#0;
         if newHash#?newMon then newHash#newMon = newHash#newMon + s#1 else newHash#newMon = s#1;
      );
      new A from hashTable {(symbol ring, f.ring),
	                    (symbol isReduced, false),
                            (symbol cache, new CacheTable from {}),
                            (symbol terms, removeZeroes hashTable pairs newHash)}   
   );
   A * A := (f,g) -> (
      newHash := new MutableHashTable;
      for t in pairs f.terms do (
         for s in pairs g.terms do (
            newMon := t#0 | s#0;
            newCoeff := (t#1)*(s#1);
            if newHash#?newMon then newHash#newMon = newHash#newMon + newCoeff else newHash#newMon = newCoeff;
         );
      );
      new A from hashTable {(symbol ring, f.ring),
  	                    (symbol isReduced, false),
                            (symbol cache, new CacheTable from {}),
                            (symbol terms, removeZeroes hashTable pairs newHash)}
   );

   A ^ ZZ := (f,n) -> product toList (n:f);

   R * A := (r,f) -> promote(r,A)*f;
   A * R := (f,r) -> r*f;
   QQ * A := (r,f) -> promote(r,A)*f;
   A * QQ := (f,r) -> r*f;
   ZZ * A := (r,f) -> promote(r,A)*f;

   A * ZZ := (f,r) -> r*f;
   A - A := (f,g) -> f + (-1)*g;
   - A := f -> (-1)*f;
   A + ZZ := (f,r) -> f + promote(r,A);
   ZZ + A := (r,f) -> f + r;
   A + QQ := (f,r) -> f + promote(r,A);
   QQ + A := (r,f) -> f + r;
   A + R  := (f,r) -> f + promote(r,A);
   R + A  := (r,f) -> f + r;
   
   A ? A := (f,g) -> (leadNCMonomial f) ? (leadNCMonomial g);

   A == A := (f,g) -> #(f.terms) == #(g.terms) and (sort pairs f.terms) == (sort pairs g.terms);
   A == ZZ := (f,n) -> (#(f.terms) == 0 and n == 0) or (#(f.terms) == 1 and ((first pairs f.terms)#0#monList === {}) and ((first pairs f.terms)#1 == n));
   ZZ == A := (n,f) -> f == n;
   A == QQ := (f,n) -> (#(f.terms) == 0 and n == 0) or (#(f.terms) == 1 and ((first pairs f.terms)#0#monList === {}) and ((first pairs f.terms)#1 == n));
   QQ == A := (n,f) -> f == n;
   A == R := (f,n) -> (#(f.terms) == 0 and n == 0) or (#(f.terms) == 1 and ((first pairs f.terms)#0#monList === {}) and ((first pairs f.terms)#1 == n));
   R == A := (n,f) -> f == n;

   A
)

net NCRing := A -> net A.CoefficientRing | net A.generators

ideal NCPolynomialRing := A ->
   new NCIdeal from new HashTable from {(symbol ring) => A,
                                        (symbol generators) => {},
                                        (symbol cache) => new CacheTable from {}}

-------------------------------------------

-------------------------------------------
--- NCQuotientRing functions --------------
-------------------------------------------

new NCQuotientRing from List := (NCQuotientRing, inits) -> new NCQuotientRing of NCRingElement from new HashTable from inits

NCPolynomialRing / NCIdeal := (A, I) -> (
   ncgb := ncGroebnerBasis I;
   B := new NCQuotientRing from {(symbol generators) => {},
                                 (symbol generatorSymbols) => A.generatorSymbols,
                                 (symbol CoefficientRing) => A.CoefficientRing,
                                 "BergmanRing" => false,
                                 (symbol ambient) => A,
                                 (symbol cache) => new CacheTable from {},
                                 (symbol ideal) => I};
   newGens := apply(B.generatorSymbols, v -> v <- new B from {(symbol ring) => B,
	    	    	    	    	    	    	      (symbol isReduced) => false,
                                                              (symbol cache) => new CacheTable from {},
                                                              (symbol terms) => new HashTable from {(ncMonomial({v},B),1)}});
   B#(symbol weights) = A.weights;
      
   B#(symbol generators) = newGens;
   
   R := A.CoefficientRing;
   
   if A#"BergmanRing" then B#"BergmanRing" = true;

   promote (A,B) := (f,B) -> new B from {(symbol ring) => B,
            	    	    	    	 (symbol isReduced) => f.isReduced,
                                         (symbol cache) => new CacheTable from {},
                                         (symbol terms) => promoteHash(f.terms,B)};
                                     
   promote (B,A) := (f,A) -> new A from {(symbol ring) => A,
            	    	    	    	 (symbol isReduced) => f.isReduced,
                                         (symbol cache) => new CacheTable from {},
                                         (symbol terms) => promoteHash(f.terms,A)};

   promote (ZZ,B) := (n,B) -> putInRing({},B,promote(n,A.CoefficientRing));

   promote (QQ,B) := (n,B) -> putInRing({},B,promote(n,A.CoefficientRing));
   
   promote (R,B) := (n,B) -> putInRing({},B,promote(n,A.CoefficientRing));
   
   promote (B,B) := (f,B) -> f;

   promote (NCMatrix,B) := (M,B) -> (
      promEntries := applyTable(M.matrix, e -> promote(e,B));
      prom := ncMatrix promEntries;
      if isHomogeneous M then
         assignDegrees(prom,M.target,M.source);
      prom
   );

   lift B := opts -> f -> promote(f,A);
   push := f -> (
      temp := if f.isReduced then f else f % ncgb;
      new B from {(symbol ring) => B,
	          (symbol isReduced) => true,
                  (symbol cache) => new CacheTable from {},
                  (symbol terms) => promoteHash(temp.terms,B)}
   );
   B * B := (f,g) -> push((lift f)*(lift g));
   B ^ ZZ := (f,n) -> product toList (n:f);
   B + B := (f,g) -> push((lift f)+(lift g));
   R * B := (r,f) -> push(r*(lift f));
   B * R := (f,r) -> r*f;
   A * B := (f,g) -> push(f*(lift g));
   B * A := (f,g) -> push((lift f)*g);
   QQ * B := (r,f) -> push(r*(lift f));
   B * QQ := (f,r) -> r*f;
   ZZ * B := (r,f) -> push(r*(lift f));
   B * ZZ := (f,r) -> r*f;
   B - B := (f,g) -> f + (-1)*g;
   - B := f -> (-1)*f;
   B + ZZ := (f,r) -> push((lift f) + r);
   ZZ + B := (r,f) -> f + r;
   B + QQ := (f,r) -> push((lift f) + r);
   QQ + B := (r,f) -> f + r;

   B == B := (f,g) -> (lift(f - g) % ncgb) == 0;
   B == ZZ := (f,n) -> (
       f = push(lift f);
       (#(f.terms) == 0 and n == 0) or 
       (#(f.terms) == 1 and ((first pairs f.terms)#0#monList === {}) and ((first pairs f.terms)#1 == n))
   );
   ZZ == B := (n,f) -> f == n;
   B == QQ := (f,n) -> (
       f = push(lift f);
       (#(f.terms) == 0 and n == 0) or 
       (#(f.terms) == 1 and ((first pairs f.terms)#0#monList === {}) and ((first pairs f.terms)#1 == n))
   );
   QQ == B := (n,f) -> f == n;
   B == R := (f,n) -> (
      f = push(lift f);
      (#(f.terms) == 0 and n == 0) or 
      (#(f.terms) == 1 and ((first pairs f.terms)#0#monList === {}) and ((first pairs f.terms)#1 == n))
   );
   R == B := (n,f) -> f == n;
   B
)

net NCQuotientRing := B -> net (B.ambient) |
                           net " / " |
			   net take(B.ideal.generators,10) |
			   net if (#(B.ideal.generators) > 10) then " + More..." else ""

ideal NCQuotientRing := B -> B.ideal;
ambient NCQuotientRing := B -> B.ambient;


quadraticClosure = method()
quadraticClosure NCQuotientRing := B -> (
   -- Input: An NCQuotientRing B 
   -- Output: The algebra A/J where J is defined using only the linear and quadratic relations of B
   I:=B.ideal;
   J:=quadraticClosure(I);
   A:=B.ambient;
   A/J
)


homogDual = method()
homogDual NCQuotientRing := B -> (
   -- Input: An NCQuotientRing B whose defining ideal I is pure of degree N
   -- Output: The algebra A/J where J is generated by the orthogonal complement to the generators of I under the natural pairing
   I:=B.ideal;
   J:=homogDual(I);
   A:=J.ring;
   A/J
)

-------------------------------------------------------
--- Commands to compute endomorphism ring presentations
-------------------------------------------------------

endomorphismRing = method()
endomorphismRing (Module,Symbol) := (M,X) -> (
   R := ring M;
   endM := End M;
   N := numgens endM;
   gensEndMaps := apply(N, i -> homomorphism endM_{i});
   W := coker relations endM;
   gensEndM := map(W,source gens endM,gens endM);
   endMVars := apply(N, i -> X_i);
   A := R endMVars;
   gensA := basis(1,A);
   -- build the squarefree relations
   twoSubsets := subsets(N,2);
   mons := twoSubsets | (twoSubsets / reverse) | apply(N, i -> {i,i});
   relsHomM := getHomRelations(gensA,gensEndM,mons,gensEndMaps);
   -- should now make some attempt at finding a minimal set of algebra generators
   I := ncIdeal relsHomM;
   Igb := ncGroebnerBasis(I,InstallGB=>true);
   B := A/I;
   B.cache#(symbol endomorphismRingGens) = gensEndMaps;
   B
)

getHomRelations = method()
getHomRelations (NCMatrix,Matrix,List,List) := (gensA,gensEndM,mons,gensEndMaps) -> (
   monMatrix := matrix {for m in mons list (
      comp := gensEndMaps#(m#0)*gensEndMaps#(m#1);
      matrix entries transpose flatten matrix comp
   )};
   monMatrix = map(target gensEndM,source monMatrix, monMatrix);
   linearParts := (monMatrix // gensEndM);
   linearParts = flatten entries (gensA*linearParts);
   varsA := flatten entries gensA;
   apply(#mons, i -> varsA#(mons#i#0)*varsA#(mons#i#1) - linearParts#i)
)

findLinearRelation = (x,relList) -> (
    xmon := (first pairs x.terms)#0#monList;
    i := 0;
    while i < #relList do (
        monMatches := select(2,pairs (relList#i).terms, m -> member(first xmon,m#0#monList));
        if #monMatches == 1 and monMatches#0#0#monList === xmon and isUnit monMatches#0#1 then
           return (i,monMatches#0#1);
        i = i + 1;
    );
)

removeConstants = f -> (
    coeff := leadCoefficient f;
    if isUnit coeff then
       (coeff)^(-1)*f
    else if isUnit leadCoefficient coeff then
       (leadCoefficient coeff)^(-1)*f
    else
       f
)

partialInterreduce = method(Options => {Verbosity => 0, "MaxLoops" => infinity})
partialInterreduce List := opts -> relList -> (
   redList := relList;   
   oldListLen := -1;
   numLoops := 0;
   while #redList != oldListLen and numLoops < opts#"MaxLoops" do
   (
      oldListLen = #redList;
      tempGb := ncGroebnerBasis(redList,InstallGB=>true);
      redList = for i from 0 to #redList-1 list (
         if opts#Verbosity > 0  then (
            << "Reducing " << toString redList#i << endl
            << "  (" << i+1 << " of " << #redList << ")" << endl
            << "  (Pass " << numLoops+1 << ")" << endl;
         );
         redListRem := remainderFunction(redList#i,tempGb,"DontUse"=>redList#i);
         if redListRem != 0 then redListRem
      );
      redList = (unique removeNulls redList) / removeConstants;
      numLoops = numLoops + 1;
   );
   redList
)

eliminateLinearVariables = method(Options => {Verbosity => 0})
eliminateLinearVariables List := opts -> rels -> (
   A := ring first rels;
   R := coefficientRing A;
   gensA := gens A;
   curRels := rels;
   linearRel := null;
   elimVars := 1;
   i := 0;
   while (i < #gensA) do (
      linearRel = findLinearRelation(gensA#i,curRels);
      if linearRel =!= null then break;
      i = i + 1;
   );
   while i != #gensA do (
      relIndex := first linearRel;
      relCoeff := last linearRel;
      phi := ncMap(A,A,apply(gensA, x -> if x === gensA#i then x - (relCoeff^(-1))*(curRels#relIndex) else x));
      elimVars = elimVars + 1;
      if opts#Verbosity > 0 then << "Eliminating variable " << gensA#i << endl;
      curRels = select(curRels / phi, f -> f != 0);
      i = 0;
      while (i < #gensA) do (
         linearRel = findLinearRelation(gensA#i,curRels);
         if linearRel =!= null then break;
         i = i + 1;
      );
   );
   unique curRels
)

minimizeRelations = method(Options => {Verbosity => 0})
minimizeRelations List := opts -> rels -> (
   numOldRels := -1;
   loopRels := rels;
   while numOldRels != #loopRels do (
      numOldRels = #loopRels;
      loopRels = eliminateLinearVariables(loopRels,opts);
      loopRels = partialInterreduce(loopRels,opts);
   );
   loopRels
)

checkHomRelations = method(Options => {Verbosity => 0})
checkHomRelations (List,List) := opts -> (rels,homGens) -> (
   if rels == {} then return null;
   A := ring first rels;
   gensA := A.generatorSymbols;
   genHash := new HashTable from pack(2,mingle(gensA,homGens));
   for f in rels do (
      relMatrix := sum for p in pairs (f.terms) list (
         prod := product apply(p#0#monList, x -> genHash#x);
         (p#1)*prod
      );
      if relMatrix != 0 then error "Endomorphism relations do not hold.";
   );
)

------------------------------------------------

------------------------------------------------
------------- NCIdeal --------------------------
------------------------------------------------

ncIdeal = method()
ncIdeal List := idealGens -> (
   if #idealGens == 0 then error "Expected at least one generator.";
   new NCIdeal from new HashTable from {(symbol ring) => (idealGens#0).ring,
                                        (symbol generators) => idealGens,
                                        (symbol cache) => new CacheTable from {}}
)

ncIdeal NCRingElement := f -> ncIdeal {f}

generators NCIdeal := opts -> I -> I.generators;

isHomogeneous NCIdeal := I -> all(gens I, isHomogeneous)

net NCIdeal := I -> "Two-sided ideal " | net (I.generators);

ring NCIdeal := I -> I.ring

NCIdeal + NCIdeal := (I,J) -> ncIdeal (gens I | gens J)


quadraticClosure NCIdeal := I -> (
   -- Input: An NCIdeal I
   -- Output: The NCIdeal J generated by the linear and quadratic generators of I.
   J:=select(I.generators, g-> (degree g)<=2);
   ncIdeal J
)

homogDual NCIdeal := I -> (
   -- Input: An NCIdeal I which is pure of degree d
   -- Output: The NCIdeal J whose generators are orthogonal to those of I under the natural pairing
   d:=degree I.generators_0;
   if not all(I.generators, g->(degree g)==d)
      then error "Expected a pure ideal.";
   A:=I.ring;
   bas := basis(d,A);
   mat := transpose sparseCoeffs(I.generators,Monomials=>flatten entries bas);
--   mat := transpose matrix {apply(I.generators, g->coefficients(g,Monomials=>flatten entries bas))}; -- this might be a good place to use sparseCoeffs
   dualGens := bas*(gens ker mat);
   J:=ncIdeal flatten entries dualGens
)

--basisAsCoeffs = method()
-- basisAsCoeffs (ZZ, NCIdeal) :=  (n,I) -> (
-- R:=ring I;
-- idealGens:=select(I.generators, g->degree g <= n);
-- varsList:=gens R;
-- << "Computing generatring set in degree " << n << endl;
-- V:= flatten apply(idealGens, r-> (
--        d:=degree r;
--        toBasis:=basis(d,R);
--        fromBasis:=toBasis;
--        degnList:={sparseCoeffs(r,Monomials=>flatten entries toBasis)};
--        if d<n then for i from 1 to n-d do (
--	    fromBasis=toBasis;
--            toBasis=basis(d+i,R);
--            degnList= flatten apply(varsList, v->
--                          flatten{leftMultiplicationMap(v,flatten entries fromBasis,flatten entries toBasis)*degnList, 
--				  rightMultiplicationMap(v,flatten entries fromBasis,flatten entries toBasis)*degnList}
--            );
--        );
--     degnList));
-- << "Done." << endl;
-- << "Converting to a matrix" << endl;
-- VasMatrix := matrix {V};
-- << "Done." << endl;
-- << "Minimizing" << endl;
-- M:=mingens image VasMatrix;
-- basis(n,R)*M
-- if desired, multiply by toBasis to revert to ring variables.
-- )




basis (ZZ,NCIdeal) := opts -> (n,I) -> (
   -- Input: An NCIdeal I and a degree n.
   -- Output: A basis for I in degree n. 
   R:=ring I;
   idealGens:=select(I.generators, g->degree g <= n);
   varsList:=gens R;
   V:= flatten apply(idealGens, r-> (
       	degnList:={r}; 
	d:=degree r; 
	if d<n then for i from 1 to n-d do (
          degnList= flatten apply(varsList, v->flatten{v*degnList,degnList*v});
	);
	degnList));
   terms := flatten entries basis(n,R);
   VasCoeffs := sparseCoeffs(V, Monomials=>terms);  
   minGens := mingens image VasCoeffs;
   ncMatrix{terms}*minGens
)



------------------------------------------------

------------------------------------------------
------------- NCRightIdeal ---------------------
------------------------------------------------

ncRightIdeal = method()
ncRightIdeal List := idealGens -> (
   if #idealGens == 0 then error "Expected at least one generator.";
   new NCRightIdeal from new HashTable from {(symbol ring) => (idealGens#0).ring,
                                             (symbol generators) => idealGens,
                                             (symbol cache) => new CacheTable from {}}
)

ncRightIdeal NCRingElement := f -> ncRightIdeal {f}

generators NCRightIdeal := opts -> I -> I.generators;

isHomogeneous NCRightIdeal := I -> all(gens I, isHomogeneous)

net NCRightIdeal := I -> "Right ideal " | net (I.generators);

ring NCRightIdeal := I -> I.ring

NCRightIdeal + NCRightIdeal := (I,J) -> ncRightIdeal (gens I | gens J)


basis (ZZ,NCRightIdeal) := opts -> (n,I) -> (
   R:=ring I;
   idealGens:=select(I.generators, g->degree g <= n);
   varsList:=gens R;
   V:= flatten apply(idealGens, r-> (
        degnList:={r};
        d:=degree r;
        if d<n then for i from 1 to n-d do (
           degnList=unique flatten apply(varsList, v->degnList*v);
        );
        degnList));
   terms := flatten entries basis(n,R);
   VasCoeffs := sparseCoeffs(V,Monomials=>terms);
   minGens := mingens image VasCoeffs;
   ncMatrix{terms}*minGens
)


------------------------------------------------

------------------------------------------------
------------- NCLeftIdeal ---------------------
------------------------------------------------

ncLeftIdeal = method()
ncLeftIdeal List := idealGens -> (
   if #idealGens == 0 then error "Expected at least one generator.";
   new NCLeftIdeal from new HashTable from {(symbol ring) => (idealGens#0).ring,
                                            (symbol generators) => idealGens,
                                            (symbol cache) => new CacheTable from {}}
)

ncLeftIdeal NCRingElement := f -> ncLeftIdeal {f}

generators NCLeftIdeal := opts -> I -> I.generators;

isHomogeneous NCLeftIdeal := I -> all(gens I, isHomogeneous)

net NCLeftIdeal := I -> "Left ideal " | net (I.generators);

ring NCLeftIdeal := I -> I.ring

NCLeftIdeal + NCLeftIdeal := (I,J) -> ncLeftIdeal (gens I | gens J)

basis (ZZ,NCLeftIdeal) := opts -> (n,I) -> (
   R:=ring I;
   idealGens:=select(I.generators, g->degree g <= n);
   varsList:=gens R;
   V:= flatten apply(idealGens, r-> (
        degnList:={r};
        d:=degree r;
        if d<n then for i from 1 to n-d do (
           degnList=unique flatten apply(varsList, v-> v*degnList);
        );
        degnList));
   terms := flatten entries basis(n,R);
   VasCoeffs := sparseCoeffs(V,Monomials=>terms);
   minGens := mingens image VasCoeffs;
   ncMatrix{terms}*minGens
)
------------------------------------------------

-------------------------------------------
--- NCMonomial functions ------------------
-------------------------------------------

ncMonomial = method()
ncMonomial (List,NCRing) := (monL,B) -> (
   newMon := new NCMonomial from {(symbol monList) => monL,
                                  (symbol ring) => B};
   newMon
)

NCMonomial | List := (mon,symList) -> ncMonomial(mon#monList | symList, mon.ring)
List | NCMonomial := (symList,mon) -> ncMonomial(symList | mon#monList, mon.ring)

NCMonomial | NCMonomial := (mon1,mon2) -> ncMonomial(mon1#monList | mon2#monList, mon1.ring)

net NCMonomial := mon -> (
   mon = mon#monList;
   if mon === {} then return net "";
   myNet := net "";
   tempVar := first mon;
   curDegree := 0;
   for v in mon do (
      if v === tempVar then curDegree = curDegree + 1
      else (
          myNet = myNet | (net tempVar) | if curDegree == 1 then (net "") else ((net curDegree)^1);
          tempVar = v;
          curDegree = 1;
      );
   );
   myNet | (net tempVar) | if curDegree == 1 then (net "") else ((net curDegree)^1)
)

toString NCMonomial := mon -> (
   mon = mon#monList;
   if mon === {} then return "";
   myNet := "";
   tempVar := first mon;
   curDegree := 0;
   for v in mon do (
      if v === tempVar then curDegree = curDegree + 1
      else (
          myNet = myNet | (toString tempVar) | if curDegree == 1 then "*" else "^" | curDegree | "*";
          tempVar = v;
          curDegree = 1;
      );
   );
   myNet | (toString tempVar) | if curDegree == 1 then "" else "^" | curDegree
)

degree NCMonomial := mon -> sum apply(#(mon#monList), i -> ((mon.ring).weights)#(mon#monList#i))

putInRing = method()
putInRing (NCMonomial, ZZ) := 
putInRing (NCMonomial, QQ) :=
putInRing (NCMonomial, RingElement) := (mon,coeff) ->
      new (mon.ring) from {(symbol ring) => mon.ring,
                           (symbol isReduced) => false,
			   (symbol cache) => new CacheTable from {},
                           (symbol terms) => new HashTable from {(mon,promote(coeff,coefficientRing (mon.ring)))}}
putInRing (List, NCRing, ZZ) := 
putInRing (List, NCRing, QQ) :=
putInRing (List, NCRing, RingElement) := (monList,A,coeff) -> (
    mon := ncMonomial(monList,A);
    new A from {(symbol ring) => A,
                (symbol isReduced, false),
                (symbol cache) => new CacheTable from {},
                (symbol terms) => new HashTable from {(mon,promote(coeff,coefficientRing A))}}
)

NCMonomial _ List := (mon,substr) -> ncMonomial((mon#monList)_substr,mon.ring)

findSubstring = method(Options => {"CheckPrefixOnly" => false})
findSubstring (NCMonomial,NCMonomial) := opts -> (lt, mon) -> (
   mon = mon#monList;
   lt = lt#monList;
   deg := length lt;
   if opts#"CheckPrefixOnly" and take(mon, deg) === lt then
      return true
   else if opts#"CheckPrefixOnly" then
      return false;
   if not isSubset(lt,mon) then return null;
   substrIndex := null;
   for i from 0 to #mon-1 do (
      if #mon - i < deg then break;
      if lt === mon_{i..i+deg-1} then (
         substrIndex = i;
         break;
      );
   );
   if substrIndex =!= null then (take(mon,substrIndex),take(mon,-#mon+deg+substrIndex)) else null
)

NCMonomial ? NCMonomial := (m,n) -> if (m#monList) === (n#monList) then symbol == else
                                    if #m < #n then symbol < else
                                    if #m > #n then symbol > else
                                    if (#m == #n and (toIndexList m) < (toIndexList n)) then symbol > else symbol <

NCMonomial == NCMonomial := (m,n) -> (m#monList) === (n#monList)

toIndexList = method()
toIndexList NCMonomial := mon -> (
   apply(mon#monList, x -> position(mon.ring.generatorSymbols, y -> x === y))
)

-----------------------------------------

-----------------------------------------
--- NCRingElement methods ---------------
-----------------------------------------

net NCRingElement := f -> (
   if #(f.terms) == 0 then return net "0";
   
   firstTerm := true;
   myNet := net "";
   for t in sort pairs f.terms do (
      tempNet := net t#1;
      printParens := ring t#1 =!= QQ and ring t#1 =!= ZZ and size t#1 > 1;
      myNet = myNet |
              (if not firstTerm and t#1 > 0 then
                 net "+"
              else 
                 net "") |
              (if printParens then net "(" else net "") | 
              (if t#1 != 1 and t#1 != -1 then
                 tempNet
               else if t#1 == -1 then net "-"
               else net "") |
              (if printParens then net ")" else net "") |
              (if t#0#monList === {} and (t#1 == 1 or t#1 == -1) then net "1" else net t#0);
      firstTerm = false;
   );
   myNet
)

toStringMaybeSort := method(Options => {"Sort" => false})
toStringMaybeSort NCRingElement := opts -> f -> (
   sortFcn := if opts#"Sort" then sort else identity;
   if #(f.terms) == 0 then "0" else (
      firstTerm := true;
      myNet := "";
      for t in sortFcn pairs f.terms do (
         tempNet := toString t#1;
         printParens := ring t#1 =!= QQ and ring t#1 =!= ZZ and size t#1 > 1;
         myNet = myNet |
                 (if not firstTerm and t#1 > 0 then
                    "+"
                 else 
                    "") |
                 (if printParens then "(" else "") | 
                 (if t#1 != 1 and t#1 != -1 then
                    tempNet | "*"
                  else if t#1 == -1 then "-"
                  else "") |
                 (if printParens then ")" else "") |
                 (if t#0#monList === {} and (t#1 == 1 or t#1 == -1) then "1" else toString t#0);
         firstTerm = false;
      );
      myNet
   )
)

clearDenominators = method()
clearDenominators NCRingElement := f -> (
   if coefficientRing ring f =!= QQ then f else (
      coeffDens := apply(values (f.terms), p -> if class p === QQ then denominator p else 1);
      myLCM := lcm coeffDens;
      (f*myLCM,myLCM)
   )
)

baseName NCRingElement := x -> (
   A := class x;
   pos := position(gens A, y -> y == x);
   if pos === null then error "Expected a generator";
   A.generatorSymbols#pos
)

ring NCRingElement := f -> f.ring


sparseCoeffs = method(Options => {Monomials => null})
sparseCoeffs NCRingElement := opts -> f -> (
  if opts#Monomials === null then
     sparseCoeffs({f})
  else
    sparseCoeffs({f},Monomials=>opts#Monomials)
)

sparseCoeffs List := opts -> L -> (
  -- computes coefficient vectors for the elements of the list using map(Module,Module,OptionList) for fast matrix assembly
  
  d:=L#(position(L,m->m!=0));
  if not all(L, m-> (isHomogeneous(m) and ((degree m)==(degree d) or m==0))) then 
	error "Expected homogeneous elements of the same degree.";
  B := (L#0).ring;
  R := coefficientRing B;
  mons := if opts#Monomials === null then (
              unique flatten apply(L, e-> flatten entries monomials e)) 
          else opts#Monomials;
  
  m := #mons;
  
  mons =  (mons / (m -> first keys m.terms));
  mons =  hashTable apply(m, i -> (mons#i,i));
   
  termsF := pairs (L#0).terms;
  
  coeffs := if (L#0)!=0 then (apply(termsF, (k,v) -> if v!=0 then (mons#k,0) => v)) else {};
  

  l:=length L;
  if l>1 then
     for i from 1 to l-1 do (
        if not isHomogeneous L#i then error "Extected a homogeneous element.";
        if (L#i) !=0 then (
        termsF = pairs (L#i).terms;
        newCoeffs := (apply(termsF, (k,v) -> if v!=0 then (mons#k,i) => v));
       
	coeffs = coeffs | newCoeffs;);
     ); 
   map(R^m , R^l, coeffs)
)

--coefficients NCRingElement := opts -> f -> (
--   B := f.ring;
--   if not isHomogeneous f then error "Extected a homogeneous element.";
--   mons := if opts#Monomials === null then flatten entries monomials f else opts#Monomials;
--   coeffs := transpose matrix {apply(mons, m -> (m' := first keys m.terms;
--                                                 if (f.terms)#?m' then
--                                                    promote((f.terms)#m',coefficientRing B)
--                                                 else
--                                                    promote(0,coefficientRing B)))};
   -- changed temporarily for speed, but need a workaround.  Maybe accept
   -- monomials as a matrix instead?
--   coeffs
   --(ncMatrix {mons},coeffs)
--)

monomials NCRingElement := opts -> f -> (
    ncMatrix {apply(sort keys f.terms, mon -> putInRing(mon,1))}
)
toString NCRingElement := f -> toStringMaybeSort(f,"Sort"=>true)
degree NCRingElement := f -> (
    fkeys := (keys f.terms);
    B := ring f;
    max (fkeys / degree)
)
size NCRingElement := f -> #(f.terms)
leadTerm NCRingElement := f -> (
    if f.cache.?leadTerm then return f.cache.leadTerm;
    degf := degree f;
    lt := first sort select((pairs f.terms), p -> degree p#0 == degf);
    retVal := putInRing(lt#0,lt#1);
    f.cache.leadTerm = retVal;
    retVal
)
leadMonomial NCRingElement := f -> putInRing(leadNCMonomial f,1);
leadNCMonomial = f -> first keys (leadTerm f).terms;
leadMonomialForGB = f -> (
   R := coefficientRing ring f;
   if isField R then
      (leadNCMonomial f, 1_R)
   else
      (leadNCMonomial f, leadMonomial leadCoefficient f)
)
leadCoefficient NCRingElement := f -> if size f == 0 then 0 else (pairs (leadTerm f).terms)#0#1;
isConstant NCRingElement := f -> f.terms === hashTable {} or (#(f.terms) == 1 and f.terms#?{})
isHomogeneous NCRingElement := f -> (
    B := ring f;
    if f == promote(0,B) then true
    else (
    fTerms := keys f.terms;
    degf := degree first fTerms;
    all(fTerms, g -> degree g == degf))
)
terms NCRingElement := f -> (
    for p in pairs (f.terms) list (
       putInRing(p#0,p#1)
    )
)
support NCRingElement := f -> (
   varSymbols := unique flatten apply(pairs (f.terms), (m,c) -> unique toList m#monList);
   apply(varSymbols, v -> putInRing({v},f.ring,1))
)

NCRingElement * List := (f,xs) -> apply(xs, x -> f*x);
List * NCRingElement := (xs,f) -> apply(xs, x -> x*f);

isCentral = method()
isCentral (NCRingElement, NCGroebnerBasis) := (f,ncgb) -> (
   varsList := gens f.ring;
   all(varsList, x -> (f*x - x*f) % ncgb == 0)
)

isCentral NCRingElement := f -> (
   varsList := gens f.ring;
   all(varsList, x -> (f*x - x*f) == 0)   
)

isCommutative NCRing := A -> all(gens A, x -> isCentral x)

abelianization = method()
abelianization NCRing := B -> (
   gensB := gens B;
   R := coefficientRing B;
   gensI := gens ideal B;
   abB := R [ gens B ];
   if gensI == {} then
      abB
   else (
      phi := ambient ncMap(abB,B,gens abB);
      abI := ideal flatten entries mingens ideal ((gensI) / phi);
      if abI == 0 then
         abB
      else
         abB/abI
   )
)

skewAbelianization = method()
skewAbelianization NCRing := B -> (
   gensB := gens B;
   R := coefficientRing B;
   gensI := gens ideal B;
   abB := R [ gens B, SkewCommutative => true];
   if gensI == {} then
      abB
   else (
      phi := ambient ncMap(abB,B,gens abB);
      abI := ideal flatten entries mingens ideal ((gensI) / phi);
      if abI == 0 then
         abB
      else
         abB/abI
   )
)

isNormal NCRingElement := f -> (
   if not isHomogeneous f then error "Expected a homogeneous element.";
   all(gens ring f, x -> findNormalComplement(f,x) =!= null)
)

normalAutomorphism = method()
normalAutomorphism NCRingElement := f -> (
   B := ring f;
   normalComplements := apply(gens B, x -> findNormalComplement(f,x));
   if any(normalComplements, f -> f === null) then error "Expected a normal element.";
   ncMap(B, B, normalComplements)
)

findNormalComplement = method()
findNormalComplement (NCRingElement,NCRingElement) := (f,x) -> (
   B := ring f;
   if B =!= ring x then error "Expected elements from the same ring.";
   if not isHomogeneous f or not isHomogeneous x then error "Expected homogeneous elements";
   n := degree f;
   m := degree x;
--   leftFCoeff := coefficients(f*x,Monomials=>flatten entries basis(n+m,B));
   leftFCoeff := sparseCoeffs(f*x,Monomials=>flatten entries basis(n+m,B));
   rightMultF := rightMultiplicationMap(f,m);
   factorMap := (leftFCoeff // rightMultF);
   if rightMultF * factorMap == leftFCoeff then
      first flatten entries (basis(m,B) * factorMap)
   else
      null
)

getMinMaxDegrees = gensList -> (
   minNCGBDeg := minCoeffDeg := infinity;
   maxNCGBDeg := maxCoeffDeg := -infinity;
   scan(gensList, f -> (degf := degree f;
                        degLeadCoeff := if isField coefficientRing ring f then 0 else first degree leadCoefficient f;
                        if degf > maxNCGBDeg then maxNCGBDeg = degf;
                        if degf < minNCGBDeg then minNCGBDeg = degf;
                        if degLeadCoeff > maxCoeffDeg then maxCoeffDeg = degLeadCoeff;
                        if degLeadCoeff < minCoeffDeg then minCoeffDeg = degLeadCoeff;));
   (minNCGBDeg,maxNCGBDeg,minCoeffDeg,maxCoeffDeg)
)

----------------------------------------

----------------------------------------
--- Bergman related functions
----------------------------------------

runCommand = cmd -> (
   --- comment this line out eventually, or add a verbosity option
   stderr << "--running: " << cmd << " ... " << flush;
   r := run cmd;
   if r != 0 then (
      << "Failed!" << endl;
      error("--command failed, error return code ",r);
   )
   else stderr << "Complete!" << endl;
)

makeVarListString = B -> (
   varListString := "vars ";
   gensB := gens B;
   lastVar := last gensB;
   varListString = varListString | (concatenate apply(drop(gensB,-1), x -> (toStringMaybeSort x) | ","));
   varListString | (toStringMaybeSort lastVar) | ";"
)

makeGenListString = genList -> (
   lastGen := last genList;
   genListString := concatenate apply(drop(genList,-1), f -> toStringMaybeSort first clearDenominators f | ",\n");
   genListString | (toStringMaybeSort first clearDenominators lastGen) | ";\n"
)

makeVarWeightString = (B,n) -> (
   gensB := gens B;
   numgensB := #gensB;
   adjust := if n == 0 then 0 else (
      minDeg := min (drop(gensB,numgensB - n) / degree);
      if minDeg <= 0 then 1-minDeg else 0
   );
   concatenate apply(#gensB,i -> (if i >= numgensB - n then toString ((degree gensB#i) + adjust) else toString degree gensB#i) | " ")
)

writeBergmanInputFile = method(Options => {"ComputeNCGB" => true,
                                           DegreeLimit => 10,
                                           "NumModuleVars" => 0})
writeBergmanInputFile (List, String) := opts -> (genList, tempInput) -> (
   B := ring first genList;
   charB := char coefficientRing B;
   maxDeg := max(opts#DegreeLimit, 2*(max(genList / degree)));
   genListString := makeGenListString genList;
   writeBergmanInputFile(B,
                         genListString,
                         tempInput,
                         "NumModuleVars" => opts#"NumModuleVars",
                         DegreeLimit => maxDeg,
                         "ComputeNCGB" => opts#"ComputeNCGB");
)

writeBergmanInputFile (NCRing,String,String) := opts -> (B,genListString,tempInput) -> (
   fil := openOut tempInput;
   varListString := makeVarListString B;
   charB := char coefficientRing B;
   weightString := makeVarWeightString(B,opts#"NumModuleVars");
   -- print the setup of the computation
   if not opts#"ComputeNCGB" then
   (
      -- if we don't want to recompute the GB, we need to tell Bergman that there are no
      -- Spairs to work on for twice the max degree of the gens we send it so it
      -- doesn't try to create any more Spairs.
      fil << "(load \"" << bergmanPath << "/lap/clisp/unix/hseries.fas\")" << endl;
      fil << "(setinterruptstrategy minhilblimits)" << endl;
      fil << "(setinterruptstrategy minhilblimits)" << endl;
      fil << "(sethseriesminima" << concatenate(opts#DegreeLimit:" skipcdeg") << ")" << endl;
   );
   fil << "(noncommify)" << endl;
   fil << "(setmodulus " << charB << ")" << endl;
   fil << "(setweights " << weightString << ")" << endl;
   fil << "(setmaxdeg " << opts#DegreeLimit << ")" << endl;
   
   if opts#"NumModuleVars" != 0 then
      fil << "(setq nmodgen " << opts#"NumModuleVars" << ")" << endl;
   
   fil << "(algforminput)" << endl;
   
   -- print out the list of variables we are using
   fil << varListString << endl;
   
   --- print out the generators of ideal
   fil << genListString << endl << close;
)

------------------------------------------------------
----- Bergman GB commands
------------------------------------------------------

writeGBInitFile = method()
writeGBInitFile (String, String, String) := (tempInit, tempInput, tempOutput) -> (
   fil := openOut tempInit;
   fil << "(simple \"" << tempInput << "\" \"" << tempOutput << "\")" << endl;
   fil << "(quit)" << endl << close;   
)

gbFromOutputFile = method(Options => {ReturnIdeal => false,
                                      CacheBergmanGB => true,
                                      ClearDenominators => true})
gbFromOutputFile(NCPolynomialRing,String) := opts -> (A,tempOutput) -> (
   fil := openIn tempOutput;
   totalFile := get fil;
   fileLines := drop(select(lines totalFile, l -> l != "" and l != "Done"),-1);
   gensString := select(fileLines, s -> s#0#0 != "%");
   numLines := #fileLines;
   fileLines = concatenate for i from 0 to numLines-1 list (
                              if i != numLines-1 then
                                 fileLines#i | "\n"
                              else
                                 replace(",",";",fileLines#i) | "\n"
                           );
   -- save the 'old' state to move to tensor algebra (should I be doing all this with dictionaries?)
   oldVarSymbols := A.generatorSymbols;
   oldVarValues := oldVarSymbols / value;
   use A;
   -- load dictionary on dictionaryPath if present.
   if A.cache#?Dictionary then dictionaryPath = prepend(A.cache#Dictionary,dictionaryPath);
   -- switch to tensor algebra
   gensList := select(gensString / value, f -> class f === Sequence) / first;
   -- roll back dictionaryPath, if present
   if A.cache#?Dictionary then dictionaryPath = drop(dictionaryPath,1);
   -- roll back to old variables (maybe no longer in tensor algebra)
   scan(oldVarSymbols, oldVarValues, (sym,val) -> sym <- val);
   if opts#ClearDenominators then
      gensList = apply(gensList, f -> (leadCoefficient f)^(-1)*f);
   (minNCGBDeg,maxNCGBDeg,minCoeffDeg,maxCoeffDeg) := getMinMaxDegrees(gensList);
   ncgb := new NCGroebnerBasis from hashTable {(symbol generators) => hashTable apply(gensList, f -> (leadMonomialForGB f,f)),
                                               (symbol cache) => new CacheTable from {},
                                               "MaxNCGBDegree" => maxNCGBDeg,
                                               "MinNCGBDegree" => minNCGBDeg,
                                               "MaxCoeffDegree" => maxCoeffDeg,
                                               "MinCoeffDegree" => minCoeffDeg};
   -- now write gb to file to be used later, and stash answer in ncgb's cache
   if opts#CacheBergmanGB then (
      cacheGB := temporaryFileName() | ".bigb";
      R := ring first gensList;
      maxDeg := 2*(max(gensList / degree));
      writeBergmanInputFile(R,
                            fileLines,
                            cacheGB,
                            "ComputeNCGB"=>false,
                            DegreeLimit=>maxDeg);
      ncgb.cache#"bergmanGBFile" = cacheGB;
   );
   if opts#ReturnIdeal then (
      I := ncIdeal gensList;
      I.cache#gb = ncgb;
      I
   )
   else
      ncgb
)

twoSidedNCGroebnerBasisBergman = method(Options=>{DegreeLimit=>10,
                                                  "NumModuleVars"=>0,
                                                  ClearDenominators=>true,
                                                  CacheBergmanGB=>true})
twoSidedNCGroebnerBasisBergman List := opts -> fList -> twoSidedNCGroebnerBasisBergman(ncIdeal fList,opts)
twoSidedNCGroebnerBasisBergman NCIdeal := opts -> I -> (
  if not I.ring#"BergmanRing" then
     error << "Bergman interface can only handle coefficients over QQ or ZZ/p at the present time." << endl;
  -- call Bergman for this, at the moment
  tempInit := temporaryFileName() | ".init";      -- init file
  tempInput := temporaryFileName() | ".bi";       -- gb input file
  tempOutput := temporaryFileName() | ".bo";      -- gb output goes here
  tempTerminal := temporaryFileName() | ".ter";   -- terminal output goes here
  gensI := gens I;
  writeBergmanInputFile(gensI,
                        tempInput,
                        DegreeLimit=>opts#DegreeLimit,
                        "NumModuleVars"=>opts#"NumModuleVars");
  writeGBInitFile(tempInit,tempInput,tempOutput);
  stderr << "--Calling Bergman for NCGB calculation." << endl;
  runCommand("bergman -i " | tempInit | " -on-error exit --silent > " | tempTerminal);
  gbFromOutputFile(ring I,
                   tempOutput,
                   ClearDenominators=>opts#ClearDenominators,
                   CacheBergmanGB=>opts#CacheBergmanGB)
)

------------------------------------------------------
----- Bergman Normal Form commands
------------------------------------------------------

writeNFInputFile = method(Options => {"UsePreviousGBOutput" => true})
writeNFInputFile (List,NCGroebnerBasis, List, ZZ) := opts -> (fList,ncgb, inputFileList, maxDeg) -> (
   genList := (pairs ncgb.generators) / last;
   --- set up gb computation
   -- need to also test if ncgb is in fact a gb, and if so, tell Bergman not to do the computation
   if opts#"UsePreviousGBOutput" then
      writeBergmanInputFile(genList,inputFileList#0,DegreeLimit=>maxDeg,"ComputeNCGB"=>false);
   --- now set up the normal form computation
   fil := openOut inputFileList#1;
   for f in fList do (
      fil << "(readtonormalform)" << endl;
      fil << toStringMaybeSort f << ";" << endl;
   );
   fil << close;
)
writeNFInputFile (NCRingElement, NCGroebnerBasis, List, ZZ) := (f, ncgb, inputFileList, maxDeg) ->
   writeNFInputFile({f},ncgb,inputFileList,maxDeg)

writeNFInitFile = method()
writeNFInitFile (String, String, String, String) := (tempInit, tempGBInput, tempNFInput, tempGBOutput) -> (
   fil := openOut tempInit;
   fil << "(simple \"" << tempGBInput << "\" \"" << tempGBOutput << "\")" << endl;
   fil << "(simple \"" << tempNFInput << "\")" << endl;
   fil << "(quit)" << endl << close;   
)

nfFromTerminalFile = method()
nfFromTerminalFile (NCRing,String) := (A,tempTerminal) -> (
   fil := openIn tempTerminal;
   outputLines := lines get fil;
   eltPositions := positions(outputLines, l -> l == "is reduced to");
   -- remember previous setup
   oldVarSymbols := A.generatorSymbols;
   oldVarValues := oldVarSymbols / value;
   -- switch to tensor algebra
   use A;
   retVal := outputLines_(apply(eltPositions, i -> i + 1)) / value / first;
   -- roll back to old variables
   scan(oldVarSymbols, oldVarValues, (sym,val) -> sym <- val);
   -- return normal form, promoted to A (in case there are any ZZ or QQ)
   retVal / (f -> promote(f,A))
)

normalFormBergman = method(Options => options twoSidedNCGroebnerBasisBergman)
normalFormBergman (List, NCGroebnerBasis) := opts -> (fList, ncgb) -> (
   -- don't send zero elements to bergman, or an error occurs
   fListLen := #fList;
   nonzeroIndices := positions(fList, f -> f != 0);
   fList = fList_nonzeroIndices;
   -- if there are no nonzero entries left, then return
   if fList == {} then return fList;
   nonzeroIndices = set nonzeroIndices;
   zeroIndices := (set (0..(fListLen-1)) - nonzeroIndices);
   A := (first fList).ring;
   if not A#"BergmanRing" then 
      error << "Bergman interface can only handle coefficients over QQ or ZZ/p at the present time." << endl;
   -- prepare the call to Bergman
   tempInit := temporaryFileName() | ".init";            -- init file
   usePreviousGBOutput := ncgb.cache#?"bergmanGBFile";
   tempGBInput := if usePreviousGBOutput then    -- gb input file
                     ncgb.cache#"bergmanGBFile"
                  else
                     temporaryFileName() | ".bigb";
   tempOutput := temporaryFileName() | ".bo";            -- gb output goes here
   tempTerminal := temporaryFileName() | ".ter";         -- terminal output goes here
   tempNFInput := temporaryFileName() | ".binf";         -- nf input file
   -- (**) clear denominators first, since Bergman doesn't like fractions
   newFList := apply(fList, f -> clearDenominators f);
   writeNFInputFile(newFList / first,ncgb,{tempGBInput,tempNFInput},opts#DegreeLimit,"UsePreviousGBOutput"=>usePreviousGBOutput);
   writeNFInitFile(tempInit,tempGBInput,tempNFInput,tempOutput);
   stderr << "--Calling Bergman for NF calculation for " << #nonzeroIndices << " elements." << endl;
   runCommand("bergman -i " | tempInit | " -on-error exit --silent > " | tempTerminal);
   -- these are now the nfs of the nonzero entries.  Need to splice back in
   -- the zeros where they were.
   nfList := nfFromTerminalFile(A,tempTerminal);
   -- (**) then put denominators back
   nfList = apply(#nfList, i -> ((newFList#i#1)^(-1))*nfList#i);
   functionMingle(nfList,toList((#zeroIndices):0), i -> member(i,nonzeroIndices))
)

normalFormBergman (NCRingElement, NCGroebnerBasis) := opts -> (f,ncgb) ->
   first normalFormBergman({f},ncgb,opts)

------------------------------------------------------
----- Bergman Hilbert commands
------------------------------------------------------

-- can't be a method.  Too many arguments
--writeHSInitFile = method()
writeHSInitFile := (tempInit,
                    tempInput,
		    tempGBOutput,
		    tempPBOutput,
		    tempHSOutput) -> (
   fil := openOut tempInit;
   fil << "(setf (getenv \"bmload\") \"" << bergmanPath << "/lap/clisp/unix\")" << endl;
   fil << "(ncpbhgroebner " 
       << "\"" << tempInput << "\" "
       << "\"" << tempGBOutput << "\" "
       << "\"" << tempPBOutput << "\" "
       << "\"" << tempHSOutput << "\")" << endl;
   fil << "(calctolimit (getmaxdeg))" << endl;
   fil << "(tdegreehseriesout (getmaxdeg))" << endl;
   fil << "(quit)" << endl << close;   
)

hsFromOutputFiles = method()
hsFromOutputFiles (NCQuotientRing,String,String) := (B,tempOutput,tempTerminal) -> (
   fil1 := openIn tempOutput;
   file1Lines := lines get fil1;
   fil2 := openIn tempTerminal;
   file2Lines := lines get fil2;
   dims := select(file1Lines | file2Lines, l -> #l > 0 and l#0 == "+");
   dims = apply(dims, d -> first select("[0-9][0-9]*",d));
   dims
)

hilbertBergman = method(Options => {DegreeLimit => 0,  -- DegreeLimit = 0 means return rational function (if possible)
                                                       -- else return as a power series 
	                            DegreeVariable => (getSymbol "T")})

-- will add this later
-- hilbertBergman NCIdeal := opts -> I -> (

hilbertBergman NCQuotientRing := opts -> B -> (
  -- Is the result already here? Check the cache and return if so.
  if not B#"BergmanRing" then 
     error << "Bergman interface can only handle coefficients over QQ or ZZ/p at the present time." << endl;
  -- prepare the call to bergman
  tempInit := temporaryFileName() | ".init";      -- init file
  tempInput := temporaryFileName() | ".bi";       -- gb input file
  tempGBOutput := temporaryFileName() | ".bgb";   -- gb output goes here
  tempHSOutput := temporaryFileName() | ".bhs";   -- hs output goes here
  tempPBOutput := temporaryFileName() | ".bpb";   -- pb 'output' goes here (?)
  tempTerminal := temporaryFileName() | ".ter";   -- terminal output goes here
  I := ideal B;
  gensI := gens I;
  writeBergmanInputFile(gensI,
                        tempInput,
			DegreeLimit=>opts#DegreeLimit);
  writeHSInitFile(tempInit,tempInput,tempGBOutput,tempPBOutput,tempHSOutput);
  stderr << "--Calling bergman for HS computation." << endl;
  runCommand("bergman -i " | tempInit | " -on-error exit --silent > " | tempTerminal);
  I.cache#gb = gbFromOutputFile(ring I,tempGBOutput);
  hsFromOutputFiles(B,tempHSOutput,tempTerminal)
)

-------------------------------------------------
--- Bergman Kernel computations -----------------
-------------------------------------------------

buildMatrixRing = method()
buildMatrixRing NCMatrix := M -> (
   rowsM := #(M.target);
   colsM := #(M.source);
   B := ring M;
   kk := coefficientRing B;
   gensB := gens B;
   weightsB := gensB / degree;
   --- make the dictionary for the variables
   varsDic := new GlobalDictionary;
   RoW := getGlobalSymbol(varsDic, "RoW");
   CoL := getGlobalSymbol(varsDic, "CoL");
   --- create the variables
   rowGens := toList (RoW_0..RoW_(rowsM-1));
   colGens := toList (CoL_0..CoL_(colsM-1));
   --- store old values of B gens
   oldVarSymbols := B.generatorSymbols;
   oldVarValues := oldVarSymbols / value;
   --- create the ring
   gensC := gensB | colGens | rowGens;
   C := kk gensC;
   --- roll back B gens
   scan(oldVarSymbols, oldVarValues, (sym,val) -> sym <- val);
   --- fill the cache
   C.cache#Dictionary = varsDic;
   C.cache#"MatrixRingOver" = B;
   C.cache#"rows" = rowsM;
   C.cache#"cols" = colsM;
   -- set weights
   setWeights(C,weightsB | (M.source) | (M.target))
)

buildMatrixRelations = method()
buildMatrixRelations NCMatrix := M -> (
   --- if done before, no need to recreate
   if M.cache#?"BergmanRelations" then return M.cache#"BergmanRelations";
   C := buildMatrixRing M;
   B := ring M;
   I := ideal B;
   rowsM := #(M.target);
   colsM := #(M.source);
   gensB := gens B;
   gensC := gens C;
   phi := ncMap(C,B,gensC_{0..(#gensB-1)});
   colVars := gensC_{(#gensB)..(#gensB+colsM-1)};
   rowVars := gensC_{(#gensB+colsM)..(#gensC-1)};
   rowVarMatr := ncMatrix {rowVars};
   colVarMatr := ncMatrix {colVars};
   bergmanRels := (flatten entries (rowVarMatr*(phi M) - colVarMatr));
   M.cache#"BergmanRelations" = bergmanRels;
   ((gens ideal B) / (ambient phi)) | bergmanRels
)

rightKernelBergman = method(Options=>{DegreeLimit=>10})
rightKernelBergman (NCMatrix) := opts -> (M) -> (
   B := ring M;
   if not B#"BergmanRing" then 
      error "Bergman interface can only handle coefficients over QQ or ZZ/p at the present time.";
   if not isHomogeneous M then
      error "Expected a homogeneous matrix.";
   maxKerDeg := max M.source + opts#DegreeLimit;
   matrRels := buildMatrixRelations M;
   C := ring first matrRels;
   kerGBGens := getMatrixGB(M, DegreeLimit => maxKerDeg);
   kerM := minimizeMatrixKerGens(C,M,gens kerGBGens, DegreeLimit=>maxKerDeg);
   kerM
)

getKernelElements = (kerGens,gensBinC,colGens) -> (
   select(kerGens, f -> isKernelElement(f,gensBinC,colGens))
)

isKernelElement = (f, gensBinC, colGens) -> (
   fsupp := support f;
   -- isSubset uses === and not ==, so can't use it (did this break recently?)
   all(fsupp, f -> any(gensBinC | colGens, g -> f == g)) and 
   any(fsupp, f -> all(gensBinC, g -> f != g))
   --isSubset(fsupp,gensBinC | colGens) and not isSubset(fsupp,gensBinC)
)

getModuleCoefficients = method()
getModuleCoefficients (List, List) := (modElts, modVars) -> (
   --- this is for the case of an ideal, where there is not a 'module' element.
   if modVars == {} then return ncMatrix {modElts};
   --- the rest is for honest module coefficients
   C := ring first modElts;
   B := C.cache#"MatrixRingOver";
   cols := C.cache#"cols";
   rows := C.cache#"rows";
   bGensList := apply(gens B | toList (cols:0) | toList (rows:0), f -> promote(f,B));
   CtoB := ncMap(B,C,bGensList);
   modVarSymbols := modVars / baseName;
   -- finally, build the matrix corresponding to the kernel
   MkerC := ncMatrix {for f in modElts list (
      -- need to get the coefficients of each element as a column vector.
      -- the entry in row i of this column vector will be the coefficient of Col_i
      -- need to be careful, however, since there may be several entries with Col_i
      -- as a leading coefficient.
      eltCoeffs := new MutableHashTable from {};
      -- put in all module variables with zeroes
      scan(modVarSymbols, c -> eltCoeffs#c = promote(0,C));
      for p in pairs f.terms do (
         modvar := first p#0#monList;
         theRest := putInRing(drop(p#0#monList,1),C,1);
         if eltCoeffs#?modvar then
            eltCoeffs#modvar = eltCoeffs#modvar + theRest*(p#1);
      );
      ncMatrix apply(modVarSymbols, c -> {eltCoeffs#c})
   )};
   --- make homogeneous
   if all(modElts, isHomogeneous) then
      assignDegrees(MkerC,modVars / degree,modElts / degree);
   CtoB MkerC
)

rightMingens = method()
rightMingens NCMatrix := M -> (
   --- returns a minimal generating set of the right column space
   --- of the input matrix 
   --- Not yet complete...
   B := ring M;
   if not B#"BergmanRing" then 
      error "Bergman interface can only handle coefficients over QQ or ZZ/p at the present time.";
   if not isHomogeneous M then
      error "Expected a homogeneous matrix.";
   minDeg := min M.source;
   minDegPos := positions(M.source, m -> m == minDeg);
   otherPos := positions(M.source, m -> m != minDeg);
   minGens := M_minDegPos;
   loopM := M;
   --- rewrite using module elements rather than matrices?  Probably faster.
   while otherPos != {} do (
      loopM = loopM_otherPos;
      facMatr := loopM // minGens;
      remainders := loopM - minGens*facMatr;
      possGens := positions(toList(0..#otherPos-1), i -> remainders_{i} != 0);
      if possGens != {} then (
         minGens = minGens | loopM_{first possGens};
         otherPos = drop(possGens, 1);
      )
      else
         otherPos = possGens;
   );
   minGens
)

minimizeMatrixKerGens = method(Options => options rightKernelBergman)
minimizeMatrixKerGens(NCPolynomialRing,NCMatrix,List) := opts -> (C,M,kerGens) -> (
   -- first select only the generators that involve just the columns and the
   -- ring variables alone.
   B := ring M;
   cols := #(M.source);
   rows := #(M.target);
   gensC := gens C;
   gensBinC := take(gensC, numgens B);
   ambientBtoC := ambient ncMap(C,B,gensBinC);
   gbIdealB := (gens ncGroebnerBasis ideal B) / ambientBtoC;
   colGens := gensC_{(numgens B)..(numgens B+cols-1)};
   colGenSymbols := (C.generatorSymbols)_{(numgens B)..(numgens B+cols-1)};
   kerGensElim := getKernelElements(kerGens,gensBinC,colGens);
   sortGens := sortUsing(kerGensElim,f -> (degree f, #(terms f)));
   kernelMatrix := getModuleCoefficients(sortGens,colGens);
   minMker := rightMingens kernelMatrix;
   minMker
)

------------------------------------------------------------------
--- End Bergman interface code
------------------------------------------------------------------

------------------------------------------------------------------
------- NCGroebnerBasis methods
------------------------------------------------------------------

generators NCGroebnerBasis := opts -> ncgb -> (pairs ncgb.generators) / last

leftNCGroebnerBasis = method()
leftNCGroebnerBasis List := genList -> (
)

rightNCGroebnerBasis = method()
rightNCGroebnerBasis List := genList -> (
)

ncGroebnerBasis = method(Options => {DegreeLimit => 100,
                                     InstallGB => false})
ncGroebnerBasis List := opts -> fList -> (
   if opts#InstallGB then (
      fList = apply(fList, f -> (coeff := leadCoefficient f; if isUnit coeff then (coeff)^(-1)*f else (leadCoefficient coeff)^(-1)*f));
      (minNCGBDeg,maxNCGBDeg,minCoeffDeg,maxCoeffDeg) := getMinMaxDegrees(fList);
      new NCGroebnerBasis from hashTable {(symbol generators) => hashTable apply(fList, f -> (leadMonomialForGB f,f)),
                                          (symbol cache) => new CacheTable from {},
                                          "MaxNCGBDegree" => maxNCGBDeg,
                                          "MinNCGBDegree" => minNCGBDeg,
                                          "MaxCoeffDegree" => maxCoeffDeg,
                                          "MinCoeffDegree" => minCoeffDeg}
   )
   else ncGroebnerBasis(ncIdeal fList,opts)
)

ncGroebnerBasis NCIdeal := opts -> I -> (
   if I.cache#?gb then return I.cache#gb;
   ncgb := if opts#InstallGB then (
              gensI := apply(gens I, f -> (coeff := leadCoefficient f; if isUnit coeff then (leadCoefficient f)^(-1)*f else promote((leadCoefficient coeff)^(-1), coefficientRing ring f)*f));
              (minNCGBDeg,maxNCGBDeg,minCoeffDeg,maxCoeffDeg) := getMinMaxDegrees(gensI);
              new NCGroebnerBasis from hashTable {(symbol generators) => hashTable apply(gensI, f -> (leadMonomialForGB f,f)),
                                                  (symbol cache) => new CacheTable from {},
                                                  "MaxNCGBDegree" => maxNCGBDeg,
                                                  "MinNCGBDegree" => minNCGBDeg,
                                                  "MaxCoeffDegree" => maxCoeffDeg,
                                                  "MinCoeffDegree" => minCoeffDeg}
   )
   else twoSidedNCGroebnerBasisBergman(I,
                                       DegreeLimit => opts#DegreeLimit);
   I.cache#gb = ncgb;
   ncgb   
)
net NCGroebnerBasis := ncgb -> (
   stack apply(pairs ncgb.generators, (lt,pol) -> (net pol) | net "; Lead Term = " | (net lt))
)

ZZ % NCGroebnerBasis := (n,ncgb) -> n
QQ % NCGroebnerBasis := (n,ncgb) -> n

basis(ZZ,NCRing) := opts -> (n,B) -> (
   ncgbGens := if class B === NCQuotientRing then pairs (ncGroebnerBasis B.ideal).generators else {};
   basisList := {ncMonomial({},B)};
   varsList := B.generatorSymbols;
   lastTerms := ncgbGens / first / first;
   for i from 1 to n do (
      basisList = flatten apply(varsList, v -> apply(basisList, b -> ncMonomial({v},B) | b));
      if ncgbGens =!= {} then
         basisList = select(basisList, b -> all(lastTerms, mon -> not findSubstring(mon,b,"CheckPrefixOnly"=>true)));
   );
   ncMatrix {apply(basisList, mon -> putInRing(mon,1))}
)

leftMultiplicationMap = method()
leftMultiplicationMap(NCRingElement,ZZ) := (f,n) -> (
   -- Input : A form f of degree m, and a degree n
   -- Output : A matrix (over coefficientRing f.ring) representing the left multiplication
   --          map from degree n to degree n+m.
   B := f.ring;
   m := degree f;
   nBasis := flatten entries basis(n,B);
   nmBasis := flatten entries basis(n+m,B);
   leftMultiplicationMap(f,nBasis,nmBasis)
)

leftMultiplicationMap(NCRingElement,List,List) := (f,fromBasis,toBasis) -> (
   -- Input : A form f of degree m, an independent set of homogeneous elements of degree n, a basis for the ring in degree n+(deg f)
   -- Output : A matrix (over coefficientRing f.ring) representing the left multiplication
   --          map on fromBasis.

   if not isHomogeneous f then error "Expected a homogeneous element.";
   sparseCoeffs(f*fromBasis, Monomials=>toBasis)

)

rightMultiplicationMap = method()
rightMultiplicationMap(NCRingElement,ZZ) := (f,n) -> (
   -- Input : A form f of degree m, and a degree n
   -- Output : A matrix (over coefficientRing f.ring) representing the left multiplication
   --          map from degree n to degree n+m.
   B := f.ring;
   m := degree f;
   nBasis := flatten entries basis(n,B);
   nmBasis := flatten entries basis(n+m,B);
   rightMultiplicationMap(f,nBasis,nmBasis)
)

rightMultiplicationMap(NCRingElement,List,List) := (f,fromBasis,toBasis) -> (
   -- Input : A form f, an independent set of homogeneous elements of degree n, a basis for the ring in degree n+(deg f)
   -- Output : A matrix (over coefficientRing f.ring) representing the left multiplication
   --          map on fromBasis

   if not isHomogeneous f then error "Expected a homogeneous element.";
   sparseCoeffs(fromBasis*f, Monomials=>toBasis)

)

centralElements = method()
centralElements(NCRing,ZZ) := (B,n) -> (
   -- This function returns a basis over R = coefficientRing B of the central
   -- elements in degree n.
   idB := ncMap(B,B,gens B);
   normalElements(idB,n)
)

normalElements = method()
normalElements(NCRingMap,ZZ) := (phi,n) -> (
   -- this function returns a basis over R = coefficientRing B of the normal
   -- elements with respect to the automorphism phi in degree n
   if source phi =!= target phi then error "Expected an automorphism.";
   B := source phi;
   ringVars := gens B;
   diffMatrix := matrix apply(ringVars, x -> {leftMultiplicationMap(phi x,n) - rightMultiplicationMap(x,n)});
   nBasis := basis(n,B);
   kerDiff := ker diffMatrix;
   R := ring diffMatrix;
   if kerDiff == 0 then sub(matrix{{}},R) else nBasis * (gens kerDiff)
)

normalElements (NCQuotientRing, ZZ, Symbol, Symbol) := (R,n,x,y) -> (
   -- Inputs: An NCQuotientRing R, a degree n, and two symbols to use for indexed variables.
   -- Outputs: (1) A list of normal monomials in degree n 
   --          (2) the components of the variety of normal elements (excluding the normal monomials) 
   --              expressed as ideals in terms of coefficients of non-normal monomial basis elements
   -- 
   -- The variety also contains information about the normalizing automorphism. This information is not displayed.
   -- The user can obtain the normalizing automorphism of a normal element via the normalAutomorphism function
   fromBasis := flatten entries basis(n,R);
   toBasis := flatten entries basis(n+1,R);
   pos := positions(fromBasis,m->isNormal(m));
   normalBasis := apply(pos, i-> fromBasis#i);
   nonNormalBasis := fromBasis-set normalBasis;
   -- print a list of normal monomials
      << "Normal monomials of degree " << n << ":" << endl;
      for i from 0 to ((length normalBasis) - 1) do (
        << normalBasis#i << endl;
      );
      if (length normalBasis)==0 then << "none" << endl;
   numGens := numgens R;
   leftMaps := apply(gens R, x->leftMultiplicationMap(x,nonNormalBasis,toBasis));
   rightMaps := apply(gens R, x->rightMultiplicationMap(x,nonNormalBasis,toBasis));
   -- make a polynomial ring with (fromDim) - (number of normal monomials)  + (numgens R)^2 variables
   -- need to hide variables from user
   xvars := apply(nonNormalBasis, i->x_i);
   yvars := table(numGens, numGens, (i,j) -> y_(i,j));
   cRing := R.CoefficientRing[(flatten yvars) | xvars,MonomialOrder=>Eliminate numGens^2];
   xvars = xvars / value;
   yvars = applyTable(yvars,value);
   leftCoeff := apply(leftMaps, L-> L*transpose matrix {xvars});
   rightCoeff := apply(rightMaps, R-> R*transpose matrix {xvars});
   idealGens := flatten apply(numGens,g-> rightCoeff#(g-1) - sum(numGens,j->(yvars#g#j)*leftCoeff#(j-1)));
   I:=ideal idealGens;
   -- the next line throws away information, including automorphism data
   << "Components of the normal variety, excluding normal monomials:" << endl;
   unique(select(apply(xvars, x-> (J:=saturate(I,ideal(x));
                                   if J!=cRing then 
                                      selectInSubring(1, gens gb J)
                                   else
                                      0)),c->c!=0))
)

--- This is the command that computes the kernel via linear
--- algebra over the base ring.  It can only handle
--- a matrix of homogeneous entries all of the same degree
rightKernel = method(Options=>{NumberOfBins => 1, Verbosity=>0})
rightKernel(NCMatrix,ZZ):= opts -> (M,deg) -> (
   -- Assume (without checking) that the entries of M are homogeneous of the same degree n
   -- This function takes a NCMatrix M and a degree deg and returns the left kernel in degree deg over the tensor algebra. 
   -- Increasing bins can provide some memory savings if the degree deg part of the ring is large. Optimal bin size seems to be in the 1000-2000 range.
   bins := opts#NumberOfBins;
   rows := # entries M;
   cols := # first M.matrix;
   MasList := flatten entries M;
   n := max apply(MasList, i->degree i);

   bas := basis(deg,M.ring);
   fromBasis := flatten entries bas;
   toBasis := flatten entries basis(deg+n,M.ring);

   fromDim := #fromBasis; --the number of rows of K is dim*cols
   toDim := #toBasis; --the number of rows in multiplication map

   -- packing variables
   if toDim % bins != 0 then error "Basis doesn't divide evenly into that many bins";
   pn := toDim//bins; -- denominator is number of bins
   pB := pack(toBasis,pn);

   -- zero vectors
   fromZeros := apply(toList(0..(fromDim-1)),i->0);
   toZeros := transpose matrix{apply(toList(0..(#(pB#0)-1)),i->0)};
   zeroMat := matrix{apply(fromZeros, i-> toZeros)};
 
   -- get left product rows (no need for separate function call)
--   U := unique select(MasList, c->c!=0); -- unique does not work on ring elements, and I am skeptical about this call on flattened entries.
--   Umat := ncMatrix {U};                 -- this is now a row vector
--   Lmat := (transpose Umat)*bas;
--   L := hashTable apply(#U, e->{U#e,(Lmat.matrix)#e}); -- if code improvement below works, delete this line.
   
   --initialize (in an effort to save space, we're going to overwrite these variables in the loops below)
   Kscalar := (coefficientRing M.ring)^(fromDim*cols);
   nextKer := 0;  
   U:= 0;
   Lmat:=0;
   for row from 0 to (rows-1) when Kscalar!=0 do (
       if opts#Verbosity > 0 then 
          << "Computing kernel of row " << row+1 << " of " << rows << endl; 
         U = ncMatrix{ (M.matrix)#row };
         Lmat = (transpose U)*bas;
       for ind from 0 to (#pB-1) when Kscalar!=0 do (
       	   if opts#Verbosity > 0 then
              << "Converting to coordinates" << endl;
	   -- the following is the most expensive step in the calculation time-wise. 
--           coeffs := matrix{ flatten apply((M.matrix)#row,i-> (
--	   	    	    	           if i==0 then
--                                             return zeroMat
--	   	    	    	           else
--					      sparseCoeffs(L#i,Monomials=>pB#ind) 
--				    --          apply(L#i,j-> (if j == 0 then return toZeros else coefficients(j,Monomials=>pB#ind)))  
--				           ))};

           coeffs:= sparseCoeffs(flatten entries Lmat, Monomials=>pB#ind);


       	   nextKer = sub(ker coeffs, coefficientRing M.ring);
	   if opts#Verbosity > 0 then
              << "Updating kernel" << endl;
	   Kscalar = intersect(Kscalar,nextKer);
	   );
   );

   if Kscalar == 0 then
      return 0
   else
      if opts#Verbosity > 0 then << "Kernel computed. Reverting to ring elements." << endl;
   ncMatrix apply(toList(0..(cols-1)), k-> {bas*submatrix(gens Kscalar,{k*fromDim..(k*fromDim+fromDim-1)},)})
)

isLeftRegular = method()
isLeftRegular (NCRingElement, ZZ) := (f,d) -> (
   A := ring f;
   if not isHomogeneous f then error "Expected a homogeneous element.";
   r := rank rightMultiplicationMap(f,d);
   s := #(flatten entries basis(d,A));
   r == s
)

isRightRegular = method()
isRightRegular (NCRingElement, ZZ) := (f,d) -> (
   A := ring f;
   if not isHomogeneous f then error "Expected a homogeneous element.";
   r := rank leftMultiplicationMap(f,d);
   s := #(flatten entries basis(d,A));
   r == s
)

NCRingElement % NCGroebnerBasis := (f,ncgb) -> (
   if (degree f <= MAXDEG and size f <= MAXSIZE) or not f.ring#"BergmanRing" then
      remainderFunction(f,ncgb)
   else
      first normalFormBergman({f},ncgb)
)

ncSubstrings = method()
ncSubstrings (NCMonomial,ZZ,ZZ) := (mon,m,n) -> (
   monLen := #(mon#monList);
   flatten apply(toList(1..(monLen)), i -> if i > n or i < m then 
                                            {}
                                         else
                                            apply(monLen-i+1, j -> (mon_{0..(j-1)},mon_{j..j+i-1},mon_{j+i..(monLen-1)})))
)

cSubstrings = method()
cSubstrings (List,ZZ,ZZ) := (exps,m,n) -> (
   if #exps == 1 then 
      apply(toList (m..(min(exps#0,n))),l -> {l})
   else
      flatten for i from 0 to min(exps#0,n) list apply(cSubstrings(drop(exps,1),max(0,m-i),max(0,n-i)), l -> {i} | l)
)

commDivides = (x,y) -> (y // x)*x == y

List ** List := (xs,ys) -> flatten for y in ys list apply(xs, x -> {x,y})

remainderFunction = method(Options => {"DontUse" => 0})
remainderFunction (NCRingElement,NCGroebnerBasis) := opts -> (f,ncgb) -> (
   if #(gens ncgb) == 0 then return f;
   if ((gens ncgb)#0).ring =!= f.ring then error "Expected GB over the same ring.";
   dontUse := opts#"DontUse";
   ncgbHash := ncgb.generators;
   maxNCGBDeg := ncgb#"MaxNCGBDegree";
   minNCGBDeg := ncgb#"MinNCGBDegree";
   maxCoeffDeg := ncgb#"MaxCoeffDegree";
   minCoeffDeg := ncgb#"MinCoeffDegree";
   newf := f;
   R := f.ring.CoefficientRing;
   hasCoeffs := not (isField R);
   pairsf := sort pairs newf.terms;
   foundSubstr := {};
   coeff := null;
   gbHit := null;
   ncSubstrs := null;
   cSubstrs := null;
   for p in pairsf do (
      ncSubstrs = ncSubstrings(p#0,minNCGBDeg,maxNCGBDeg);
      cSubstrs = if hasCoeffs then
                    apply(cSubstrings(first exponents leadMonomial promote(p#1,R),minCoeffDeg,maxCoeffDeg), s -> R_s)
                 else
                    {1_R};
      foundSubstr = select(ncSubstrs ** cSubstrs, s -> ncgbHash#?(s#0#1,s#1) and
                                                       ncgbHash#(s#0#1,s#1) != dontUse);
      coeff = p#1;
      if foundSubstr =!= {} then (
         foundSubstr = minUsing(foundSubstr, s -> size ncgbHash#(s#0#1,s#1));
         gbHit = ncgbHash#(foundSubstr#0#1,foundSubstr#1);
         break;
      );
   );
   while foundSubstr =!= {} do (
      pref := putInRing(foundSubstr#0#0,1);
      suff := putInRing(foundSubstr#0#2,1);
      newf = newf - (promote(coeff,R)//promote(foundSubstr#1,R))*pref*gbHit*suff;
      pairsf = sort pairs newf.terms;
      foundSubstr = {};
      gbHit = null;
      coeff = null;
      for p in pairsf do (
         ncSubstrs = ncSubstrings(p#0,minNCGBDeg,maxNCGBDeg);
         cSubstrs = if hasCoeffs then
                       apply(cSubstrings(first exponents leadMonomial promote(p#1,R),minCoeffDeg,maxCoeffDeg), s -> R_s)
                    else
                       {1_R};
         foundSubstr = select(ncSubstrs ** cSubstrs, s -> ncgbHash#?(s#0#1,s#1) and
                                                          ncgbHash#(s#0#1,s#1) != dontUse);
         coeff = p#1;
         if foundSubstr =!= {} then (
            foundSubstr = minUsing(foundSubstr, s -> size ncgbHash#(s#0#1,s#1));
            gbHit = ncgbHash#(foundSubstr#0#1,foundSubstr#1);
            break;
         );
      );
   );
   newf
)

---------------------------------------
----NCRingMap Commands -----------------
---------------------------------------

ncMap = method()
--- ncMap from Ring to NCRing not implemented.
ncMap (Ring,NCRing,List) := 
ncMap (NCRing,NCRing,List) := (B,C,imageList) -> (
   genCSymbols := C.generatorSymbols;
   if not all(imageList / class, r -> r === B) then error "Expected a list of entries in the target ring.";
   new NCRingMap from hashTable {(symbol functionHash) => hashTable apply(#genCSymbols, i -> (genCSymbols#i,imageList#i)),
                                 (symbol source) => C,
                                 (symbol target) => B}
)

source NCRingMap := f -> f.source
target NCRingMap := f -> f.target
matrix NCRingMap := opts -> f -> ncMatrix {(gens source f) / f}
--id _ NCRing := B -> ncMap(B,B,gens B)

NCRingMap NCRingElement := (f,x) -> (
   if x == 0 then return promote(0, target f);
   if ring x =!= source f then error "Ring element not in source of ring map.";
   C := ring x;
   sum for t in pairs x.terms list (
      monImage := promote(product apply(t#0#monList, v -> f.functionHash#v),target f);
      (t#1)*monImage
   )
)

NCRingMap NCMatrix := (f,M) -> (
   newMatr := applyTable(M.matrix, x -> f x);
   newM := ncMatrix newMatr;
   if isHomogeneous M and isHomogeneous f then
      assignDegrees(newM,M.target,M.source)
   else
      assignDegrees newM;
   newM
)

List / NCRingMap := (xs, f) -> apply(xs, x -> f x)

net NCRingMap := f -> (
   net "NCRingMap " | (net target f) | net " <--- " | (net source f)
)

ambient NCRingMap := f -> (
   C := source f;
   ambC := ambient C;
   genCSymbols := C.generatorSymbols;
   ncMap(target f, ambC, apply(genCSymbols, c -> f.functionHash#c))
)

isWellDefined NCRingMap := f -> (
   defIdeal := ideal source f;
   liftf := ambient f;
   all(gens defIdeal, x -> liftf x == 0)
)

isHomogeneous NCRingMap := f -> (
   gensB := gens source f;
   gensC := gens target f;
   all(gensB, x -> degree (f x) == degree x or f x == 0)
)

NCRingMap _ ZZ := (f,n) -> (
   B := source f;
   C := target f;
   srcBasis := flatten entries basis(n,B);
   tarBasis := flatten entries basis(n,C);
   imageList := srcBasis / f;
   if #(unique (select(imageList, g -> g != 0) / degree)) != 1 then
      error "Expected the image of degree " << n << " part of source to lie in single degree." << endl;
   sparseCoeffs(imageList,Monomials=> tarBasis)
--   matrix {apply(imageList, g -> coefficients(g,Monomials => tarBasis))}
)

NCRingMap @@ NCRingMap := (f,g) -> (
   if target g =!= source f then error "Expected composable maps.";
   ncMap(target f, source g, apply(gens source g, x -> f g x))
)

oppositeElement = method()
oppositeElement NCRingElement := f -> (
   new (ring f) from hashTable {
          (symbol ring, f.ring),
          (symbol cache, new CacheTable from {}),
          (symbol terms, hashTable apply(pairs f.terms, p -> (
               newMon := new NCMonomial from {(symbol monList) => reverse p#0#monList,
                                              (symbol ring) => ring f};
               (newMon,p#1))))}
)

oppositeRing = method()
oppositeRing NCRing := B -> (
   gensB := gens B;
   R := coefficientRing B;
   oppA := R gensB;
   if class B === NCPolynomialRing then return oppA;
   idealB := gens ideal B;
   phi := ncMap(oppA,ambient B, gens oppA);
   oppIdealB := idealB / oppositeElement / phi // ncIdeal;
   oppIdealBGB := ncGroebnerBasis(oppIdealB, InstallGB=>not B#"BergmanRing");
   oppA / oppIdealB
)

validSkewMatrix = method()
validSkewMatrix Matrix := M -> (
   rows := numgens source M;
   cols := numgens target M;
   if rows != cols then return false;
   invOffDiag := all(apply(rows, i -> all apply(toList(i..cols-1), j -> isUnit M_i_j and isUnit M_j_i and (M_j_i)^(-1) == M_i_j)));
   oneOnDiag := all(rows, i -> M_i_i == 1);
   invOffDiag and oneOnDiag
)

skewPolynomialRing = method()
skewPolynomialRing (Ring,Matrix,List) := (R,skewMatrix,varList) -> (
   if not validSkewMatrix skewMatrix then
      error "Expected a matrix M such that M_ij = M_ji^(-1).";
   if ring skewMatrix =!= R then error "Expected skewing matrix over base ring.";
   A := R varList;
   gensA := gens A;
   I := ncIdeal apply(subsets(numgens A, 2), p -> 
            (gensA_(p#0))*(gensA_(p#0)) - (skewMatrix_(p#0)_(p#1))*(gensA_(p#1))*(gensA_(p#0)));
   Igb := ncGroebnerBasis(I, InstallGB=>A#"BergmanRing");
   B := A/I;
   B
)

skewPolynomialRing (Ring,ZZ,List) := 
skewPolynomialRing (Ring,QQ,List) := 
skewPolynomialRing (Ring,RingElement,List) := (R,skewElt,varList) -> (
   if class skewElt =!= R then error "Expected ring element over base ring.";
   A := R varList;
   gensA := gens A;
   I := ncIdeal apply(subsets(numgens A, 2), p ->
            (gensA_(p#0))*(gensA_(p#1)) - skewElt*(gensA_(p#1))*(gensA_(p#0)));
   Igb := ncGroebnerBasis(I, InstallGB=>(not A#"BergmanRing"));
   B := A/I;
   B
)

oreIdeal = method()
oreIdeal (NCRing,NCRingMap,NCRingMap,NCRingElement) := 
oreIdeal (NCRing,NCRingMap,NCRingMap,Symbol) := (B,sigma,delta,X) -> (
   -- This version assumes that the derivation is zero on B
   -- Don't yet have multiple rings with the same variables names working yet.  Not sure how to
   -- get the symbol with the same name as the variable.
   X = baseName X;
   kk := coefficientRing B;
   varsList := ((gens B) / baseName) | {X};
   C := kk varsList;
   A := ambient B;
   fromBtoC := ncMap(C,B,drop(gens C, -1));
   fromAtoC := ncMap(C,A,drop(gens C, -1));
   X = value X;
   ncIdeal (apply(gens B.ideal, f -> fromAtoC promote(f,A)) |
            apply(gens B, x -> X*(fromBtoC x) - (fromBtoC sigma x)*X - (fromBtoC delta x)))
)

oreIdeal (NCRing,NCRingMap,Symbol) := 
oreIdeal (NCRing,NCRingMap,NCRingElement) := (B,sigma,X) -> (
   zeroMap := ncMap(B,B,toList ((numgens B):promote(0,B)));
   oreIdeal(B,sigma,zeroMap,X)
)

oreExtension = method()
oreExtension (NCRing,NCRingMap,NCRingMap,Symbol) := 
oreExtension (NCRing,NCRingMap,NCRingMap,NCRingElement) := (B,sigma,delta,X) -> (
   X = baseName X;
   I := oreIdeal(B,sigma,delta,X);
   C := ring I;
   C/I
)

oreExtension (NCRing,NCRingMap,Symbol) := 
oreExtension (NCRing,NCRingMap,NCRingElement) := (B,sigma,X) -> (
   X = baseName X;
   I := oreIdeal(B,sigma,X);
   C := ring I;
   C/I
)

---------------------------------------
----NCMatrix Commands -----------------
---------------------------------------
ncMatrix = method()
ncMatrix List := ncEntries -> (
   if #ncEntries == 0 then error "Expected a nonempty list.";
   if not isTable ncEntries then error "Expected a rectangular matrix.";
   rows := #ncEntries;
   cols := #(ncEntries#0);
   --- here, we need to find a common ring to promote all the entries to before checking anything else.
   ringList := (flatten ncEntries) / ring;
   B := (ringList)#(position(ringList, r -> ancestor(NCRing,class r)));
   ncEntries = applyTable(ncEntries, e -> promote(e,B));
   types := ncEntries // flatten / class // unique;
   if #types != 1 then error "Expected a table of either NCRingElements over the same ring or NCMatrices.";
   local retVal;
   if ancestor(NCRingElement,types#0) then (
      retVal = new NCMatrix from hashTable {(symbol ring, (ncEntries#0#0).ring), 
                                            (symbol matrix, ncEntries),
                                   	    (symbol cache, new CacheTable from {})};
    
   )
   else if types#0 === NCMatrix then (
      -- this block of code handles a matrix of matrices and creates a large matrix from that
      blockEntries := applyTable(ncEntries, entries);
      -- this is a hash table with the sizes of the matrices in the matrix
      sizeHash := new HashTable from flatten apply(rows, i -> apply(cols, j -> (i,j) => (#(blockEntries#i#j), #(blockEntries#i#j#0))));
      -- make sure the blocks are of the right size, and all matrices are defined over same ring.
      if not all(rows, i -> #(unique apply(select(pairs sizeHash, (e,m) -> e#0 == i), (e,m) -> m#0)) == 1) then
         error "Expected all matrices in a row to have the same number of rows.";
      if not all(cols, j -> #(unique apply(select(pairs sizeHash, (e,m) -> e#1 == j), (e,m) -> m#1)) == 1) then
         error "Expected all matrices in a column to have the same number of columns.";
      rings := unique apply(flatten ncEntries, m -> m.ring);
      if #rings != 1 then error "Expected all matrices to be defined over the same ring.";
      -- now we may perform the conversion.
      newEntries := flatten for i from 0 to rows-1 list
                            for k from 0 to (sizeHash#(i,0))#0-1 list (
                               flatten for j from 0 to cols-1 list
                                       for l from 0 to (sizeHash#(0,j))#1-1 list blockEntries#i#j#k#l
                            );
      retVal = new NCMatrix from hashTable {(symbol ring, (ncEntries#0#0).ring), 
	                                    (symbol matrix, newEntries),
                                   	    (symbol cache, new CacheTable from {})};
   );
   assignDegrees retVal
)

ring NCMatrix := M -> M.ring

lift NCMatrix := opts -> M -> ncMatrix applyTable(M.matrix, entry -> promote(entry,(M.ring.ambient)))

NCMatrix * NCMatrix := (M,N) -> (
   if M.ring =!= N.ring then error "Expected matrices over the same ring.";
   B := M.ring;
   colsM := length first M.matrix;
   rowsN := length N.matrix;
   if colsM != rowsN then error "Maps not composable.";
   rowsM := length M.matrix;
   colsN := length first N.matrix;
   -- lift entries of matrices to tensor algebra
   local prod;
   if class B === NCQuotientRing then (
      MoverTens := lift M;
      NoverTens := lift N;
      prodOverTens := MoverTens*NoverTens;
      ncgb := B.ideal.cache#gb;
      reducedMatr := prodOverTens % ncgb;
      prod = promote(reducedMatr,B);
      if isHomogeneous M and isHomogeneous N then
         assignDegrees(prod,M.target,N.source);
      prod
   )
   else
   (
      -- not sure which of the below is faster
      -- ncMatrix apply(toList (0..(rowsM-1)), i -> apply(toList (0..(colsN-1)), j -> sum(0..(colsM-1), k -> ((M.matrix)#i#k)*((N.matrix)#k#j))))
      prod = ncMatrix table(toList (0..(rowsM-1)), toList (0..(colsN-1)), (i,j) -> sum(0..(colsM-1), k -> ((M.matrix)#i#k)*((N.matrix)#k#j)));
      if isHomogeneous M and isHomogeneous N then
         assignDegrees(prod,M.target,N.source);
      prod
   )
)

NCMatrix * Matrix := (M,N) -> (
   N' := sub(N,coefficientRing M.ring);
   N'' := ncMatrix applyTable(entries N, e -> promote(e,M.ring));
   M*N''
)

Matrix * NCMatrix := (N,M) -> (
   N' := sub(N,coefficientRing M.ring);
   N'' := ncMatrix applyTable(entries N, e -> promote(e,M.ring));
   N''*M
)

NCMatrix % NCGroebnerBasis := (M,ncgb) -> (
   -- this function should be only one call to bergman
   -- the nf for a list is there already, just need to do entries, nf, then unpack.
   coeffRing := coefficientRing M.ring;
   colsM := #(first M.matrix);
   rowsM := #(M.matrix);
   entriesM := flatten M.matrix;
   maxDeg := max(entriesM / degree);
   maxSize := max(entriesM / size);
   -- this code does not yet handle zero entries correctly when sending them to the bergman interface.
   entriesMNF := if (rowsM*colsM > MAXSIZE) or
                    (maxDeg > MAXDEG or maxSize > MAXSIZE) or
                    (coeffRing === QQ and coeffRing === ZZ/(char coeffRing)) then 
   		    normalFormBergman(entriesM, ncgb)
                 else
                    apply(entriesM, f -> f % ncgb);
   ncMatrix pack(colsM,entriesMNF)
)

-- need to make this more intelligent(hah!) via repeated squaring and binary representations.
NCMatrix ^ ZZ := (M,n) -> product toList (n:M)

NCMatrix + NCMatrix := (M,N) -> (
   if M.ring =!= N.ring then error "Expected matrices over the same ring.";
   colsM := length first M.matrix;
   rowsN := length N.matrix;
   rowsM := length M.matrix;
   colsN := length first N.matrix;
   if colsM != colsN or rowsM != rowsN then error "Matrices not the same shape.";
   MpN := ncMatrix apply(toList(0..(rowsM-1)), i -> apply(toList(0..(colsM-1)), j -> M.matrix#i#j + N.matrix#i#j));
   if isHomogeneous M and isHomogeneous N and M.target == N.target and M.source == N.source then
      assignDegrees(MpN,M.target,M.source);
   MpN
)

NCMatrix - NCMatrix := (M,N) -> (
   if M.ring =!= N.ring then error "Expected matrices over the same ring.";
   colsM := length first M.matrix;
   rowsN := length N.matrix;
   rowsM := length M.matrix;
   colsN := length first N.matrix;
   if colsM != colsN or rowsM != rowsN then error "Matrices not the same shape.";
   MmN := ncMatrix apply(toList(0..(rowsM-1)), i -> apply(toList(0..(colsM-1)), j -> M.matrix#i#j - N.matrix#i#j));
   if isHomogeneous M and isHomogeneous N and M.target == N.target and M.source == N.source then
      assignDegrees(MmN,M.target,M.source);
   MmN
)

NCMatrix | NCMatrix := (M,N) -> (
   if M.ring =!= N.ring then error "Expected matrices over the same ring.";
   rowsN := length N.matrix;
   rowsM := length M.matrix;
   if rowsN != rowsM then error "Expected matrices with the same number of rows.";
   pipe := ncMatrix apply(rowsN, i -> (M.matrix)#i | (N.matrix)#i);
   if isHomogeneous M and isHomogeneous N and M.target == N.target then
      assignDegrees(pipe,M.target, M.source | N.source);
   pipe
)

NCMatrix || NCMatrix := (M,N) -> (
   if M.ring =!= N.ring then error "Expected matrices over the same ring.";
   colsN := length first N.matrix;
   colsM := length first M.matrix;
   if colsN != colsM then error "Expected matrices with the same number of columns.";
   pipe := ncMatrix (M.matrix | N.matrix);
   if isHomogeneous M and isHomogeneous N and M.source == N.source then
      assignDegrees(pipe,M.target | N.target, M.source);
   pipe
)

NCMatrix * ZZ := (M,r) -> ncMatrix apply(M.matrix, row -> apply(row, entry -> entry*sub(r,M.ring.CoefficientRing)))
ZZ * NCMatrix := (r,M) -> M*r
NCMatrix * QQ := (M,r) -> ncMatrix apply(M.matrix, row -> apply(row, entry -> entry*sub(r,M.ring.CoefficientRing)))
QQ * NCMatrix := (r,M) -> M*r
- NCMatrix := M -> (-1)*M
NCMatrix * RingElement := (M,r) -> M*(promote(r,M.ring))
RingElement * NCMatrix := (r,M) -> (promote(r,M.ring)*M)

NCMatrix * NCRingElement := (M,r) -> (
   B := M.ring;
   s := promote(r,B);
   -- lift entries of matrices to tensor algebra
   Mr := if class B === NCQuotientRing then (
      MOverTens := lift M;
      sOverTens := lift s;
      prodOverTens := MOverTens*sOverTens;
      ncgb := B.ideal.cache#gb;
      reducedMatr := prodOverTens % ncgb;
      promote(reducedMatr,B)
   )
   else 
      ncMatrix applyTable(M.matrix, m -> m*s);
   --- now set the degrees properly
   
   if isHomogeneous M and isHomogeneous r then
      assignDegrees(Mr, M.target, apply(M.source, d -> d + degree r));
   Mr
)

NCRingElement * NCMatrix := (r,M) -> (
   B := M.ring;
   s := promote(r,B);
   -- lift entries of matrices to tensor algebra
   if class B === NCQuotientRing then (
      MOverTens := lift M;
      sOverTens := lift s;
      prodOverTens := sOverTens*MOverTens;
      ncgb := B.ideal.cache#gb;
      reducedMatr := prodOverTens % ncgb;
      flagReducedMatrix(reducedMatr);
      promMatr := promote(reducedMatr,B);
      promMatr
   )
   else
      ncMatrix applyTable(M.matrix, m -> s*m)
)

entries NCMatrix := M -> M.matrix
transpose NCMatrix := M -> ncMatrix transpose M.matrix

--- flag an entire matrix as having reduced entries
--- internal routine
flagReducedMatrix = method()
flagReducedMatrix NCMatrix := M ->
   applyTable(M.matrix, entry -> entry.isReduced = true);

--- for printing out the matrices; taken from the core M2 code for
--- usual matrix printouts (though simplified)
net NCMatrix := M -> net expression M
expression NCMatrix := M -> MatrixExpression applyTable(M.matrix, expression)

assignDegrees = method()
assignDegrees NCMatrix := M -> (
   rowsM := #(M.matrix);
   colsM := #(first (M.matrix));
   sourceDeg := toList (colsM:0);
   targetDeg := toList (rowsM:0);
   entriesM := select(flatten entries M, f -> f != 0);
   -- if the zero matrix or entries not homogeneous, then just assign zero degrees.
   if entriesM == {} or any(entriesM, f -> not isHomogeneous f) then
      return assignDegrees(M,targetDeg,sourceDeg);
   colDegs := apply(transpose M.matrix, col -> unique apply(select(col, f -> f != 0), f -> degree f));
   if not all(colDegs, coldeg -> #coldeg == 1) then
      return assignDegrees(M,targetDeg,sourceDeg);
   sourceDeg = apply(colDegs, coldeg -> if coldeg == {} then 0 else first coldeg);
   -- assign the degrees
   assignDegrees(M,targetDeg,sourceDeg);
   -- set the isHomogeneous flag
   setIsHomogeneous M;
   -- for matrices that are not homogeneous with these degrees, the user may use assignDegrees
   -- below.  An attempt to find a set of degrees for which the map is homogeneous requires
   -- integer programming.  I may implement this in the future.
   M
)

assignDegrees (NCMatrix, List, List) := (M,targetDeg,sourceDeg) -> (
   -- this function is for manual assignment of degrees
   M#(symbol source) = sourceDeg;
   M#(symbol target) = targetDeg;
   -- set the isHomogeneous flag.
   setIsHomogeneous M;
   M
)

setIsHomogeneous = method()
setIsHomogeneous NCMatrix := M -> (
   targetDeg := M.target;
   sourceDeg := M.source;
   retVal := all(#(M.matrix), i -> all(#((M.matrix)#i), j -> (M.matrix)#i#j == 0 or sourceDeg#j - degree ((M.matrix)#i#j) == targetDeg#i));
   M#(symbol isHomogeneous) = retVal;
   retVal      
)

isHomogeneous NCMatrix := M -> M.?isHomogeneous and M.isHomogeneous

NCMatrix _ List := (M,ns) -> (
    M' := ncMatrix (transpose (transpose (M.matrix))_ns);
    assignDegrees(M',M.target, (M.source)_ns);
    M'
)

NCMatrix ^ List := (M,ns) -> (
    M' := ncMatrix ((M.matrix)_ns);
    assignDegrees(M',(M.target)_ns, M.source);
    M'
)

NCMatrix // NCMatrix := (N,M) -> (
   -- The function factors a map through another.  However, if no such lift is possible,
   -- the function finds the 'closest' to a lift that it can by reducing the columns of N
   -- modulo a GB for the image of M.  The answer satisfies M - N * (M // N) is equal to the
   -- columns of N reduced modulo the image of M (similar to the // command for ordinary Matrices)
   if not (isHomogeneous M and isHomogeneous N) then
      error "Expected homogeneous maps.";
   if M.target != N.target then
      error "Expected maps with the same target.";
   -- handle trivial cases now:
   
   -------------------------------
   gbDegree := max N.source;   -- is this high enough of a degree to factor?
   matrixRelsM := buildMatrixRelations M;
   CM := ring first matrixRelsM;
   matrixRelsN := buildMatrixRelations N;
   CN := ring first matrixRelsN;
   matrixGBM := getMatrixGB(M, DegreeLimit => gbDegree, ClearDenominators => true);
   B := ring M;
   colsN := #(N.source);
   rowsN := #(N.target);
   colsM := #(M.source);
   rowsM := #(M.target);
   phi := ncMap(CM,CN,take(gens CM, numgens B) | toList(colsN:promote(0,CM)) | take(gens CM, -rowsM));
   colVarsCM := (gens CM)_{(numgens B)..(numgens B+colsM-1)};
   reducedN := apply(N.cache#"BergmanRelations" / phi, f -> f % matrixGBM);
   factorMap := getModuleCoefficients(reducedN,colVarsCM);
   assignDegrees(factorMap, M.source, N.source);
   factorMap
)

getMatrixGB = method(Options => {DegreeLimit => 10, ClearDenominators => false})
getMatrixGB NCMatrix := opts -> M -> (
   if M.cache#?"matrixGB" and M.cache#"gbDegree" >= opts#DegreeLimit then return M.cache#"matrixGB";
   
   matrRels := buildMatrixRelations M;
   C := ring first matrRels;
   B := ring M;
   ambBtoC := ncMap (C,ambient B,take(gens C,numgens B));
   mGB := twoSidedNCGroebnerBasisBergman(matrRels | ((gens ideal B) / ambBtoC),
                                         "NumModuleVars" => numgens C - numgens B,
                                         DegreeLimit => opts#DegreeLimit,
                                         ClearDenominators=>opts#ClearDenominators,
                                         CacheBergmanGB=>false);
   M.cache#"matrixGB" = mGB;
   M.cache#"gbDegree" = opts#DegreeLimit;

   mGB
)

NCMatrix == NCMatrix := (M,N) -> (
    if isHomogeneous M and isHomogeneous N then
       (M.source == N.source) and (M.target == N.target) and (M.matrix) == (N.matrix)
    else
       (M.matrix) == (N.matrix)
)
NCMatrix == ZZ := (M,n) -> (
   if n != 0 then error "Expected comparison to zero.";
   all(flatten entries M, f -> f == 0)
)
ZZ == NCMatrix := (n,M) -> M == n

-------------------------------------------------------------
------- end package code ------------------------------------

-------------------- timing code ---------------------------
wallTime = Command (() -> value get "!date +%s.%N")  --- %N doesn't work on Mac
wallTiming = f -> (
    a := wallTime(); 
    r := f(); 
    b := wallTime();  
    << "wall time : " << b-a << " seconds" << endl;
    r);
------------------------------------------------------------

--- include the documentation
load "NCAlgebra/NCAlgebraDoc.m2"

end

--- bug fix/performance improvements
------------------------------------
--- Make homogeneous maps interface more streamlined.
---   May require implementation of modules to do properly
--- Finish right mingens
--- Finish left kernels and mingens etc (opposite ring now done)
--- Make sure that trivial ideals are handled correctly
--- Make sure that ring constructions respect weights, if present
--- isFiniteDimensional?
--- 'basis' for f.d. algebras?
--- Generating set for algebras not over a field
--- Proper handling of rings generated in several positive degrees
---    This goes for things such as basis, etc, as well.
--- fix coefficients to return a pair again.
--- 3d sklyanin generator (following Artin-Schelter)

--- other things to add or work on in due time
-----------------------------------
--- Dare I say it, Diamond Lemma?
--- Make Quotients of Quotients work.
--- NCRingMap kernels (to a certain degree)  -- Not sure I can do this with
---   Bergman, can't use block orders in bergman.
--- anick          -- resolution
--- ncpbhgroebner  -- gb, hilbert series
--- NCModules (?) (including module gb (via simple), hilbert series, modulebettinumbers)
--- Work on reduction code a bit?
--- Testing!
--- Documentation!

-- skylanin example from Ellen / Artin-Schelter generic Sklyanin example
restart
needsPackage "NCAlgebra"
A = QQ{x,y,z}
a = random(QQ)
b = random(QQ)
c = random(QQ)
a = 1
b = 1
c = -1
I = ncIdeal {a*x*y+b*y*x+c*z^2,
             a*y*z+b*z*y+c*x^2,
             a*z*x+b*x*z+c*y^2}
Igb = ncGroebnerBasis(I,DegreeLimit=>5)
B = A/I
C = first flatten entries centralElements(B,3)
(b*(c^3-a^3))/(c*(c^3-b^3))
(a*(b^3-c^3))/(c*(c^3-b^3))
(c*(a^3-c^3))/(c*(c^3-b^3))

--- andy bug 6/24/2013
restart
needsPackage "NCAlgebra"
R=toField(QQ[q]/ideal{q^2+q+1})
A=R{x,y,z}
I=ncIdeal{z*z+q^2*x*y-q*y*x,q*y*z+q^2*x*x-z*y,q*y*y+z*x-q^2*x*z,x^2*z-q*y*x*y,q^2*x*y*x-x^2*y-y^2*z-q*y*x^2}
ncgb=ncGroebnerBasis(I,InstallGB=>true)

----
restart
uninstallPackage "NCAlgebra"
installPackage "NCAlgebra"
needsPackage "NCAlgebra"
viewHelp "NCAlgebra"