import R "./lib";
import O "mo:rxmo";
import BTree "mo:stableheapbtreemap/BTree";
import Array "mo:base/Array";
import Vector "mo:vector";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";

module {
    public type Compare<K> = (K, K) -> { #less; #equal; #greater };

    public type Init<K> = BTree.BTree<K,Nat>;

    public func init<K>(btorder: ?Nat) : BTree.BTree<K,Nat> = BTree.init<K, Nat>(btorder);

    public type Config<K,V> = {
        obs: R.ObsInit<V>;
        db: R.RXMDB<V>;
        store: BTree.BTree<K, Nat>;
        compare: Compare<K>;
        key: (V) -> K;
        regenerate:{#no; #yes};
    };
    
    let IterBatch = 200;

    public class Use<K, V>({obs; db; store; compare; key} : Config<K,V>) {
        
        public func getIdx(pk : K) : ?Nat {
            BTree.get(store, compare, pk);
        };
        
        public func get(pk: K) : ?V {
            let ?idx = BTree.get(store, compare, pk) else return null;
            let ?v = Vector.get<?V>(db.vec, idx) else Debug.trap("E101 Internal Error");
            ?v;
        };

        public func delete(pk: K) : () {
            let ?idx = BTree.get(store, compare, pk) else return;
            R.deleteIdxF<V>(db, obs, idx);
        };

        public func findIdx(start: K, end: K, dir: BTree.Direction, limit: Nat) : [(K, Nat)] {
            BTree.scanLimit<K, Nat>(store, compare, start, end, dir, limit).results;
        };
        
        public func findIter(start: K, end: K, dir: BTree.Direction) : Iter.Iter<(K, Nat)> { 

            var res = BTree.scanLimit<K, Nat>(store, compare, start, end, dir, IterBatch);
            var idx:Nat = 0;
            var size = Array.size(res.results);
               
            { 
                next = func() : ?(K, Nat) {
                    idx += 1;
                    
                    if (idx > size) {
                        if (size < IterBatch) return null;
                        switch(res.nextKey) {
                            case (null) return null;
                            case (?nextKey) {
                                res := BTree.scanLimit<K, Nat>(store, compare, nextKey, end, dir, IterBatch);
                                idx := 1;
                                size := Array.size(res.results);
                            };
                        };
                    };
                    ?res.results[idx - 1];
                }
            };
        };

        public func find(start: K, end: K, dir: BTree.Direction, limit: Nat) : [V] {
            Array.map<(K, Nat),V>(BTree.scanLimit<K, Nat>(store, compare, start, end, dir, limit).results,
            func((k, v)) {
                let ?x = Vector.get<?V>(db.vec, v) else Debug.trap("E101 Internal Error");
                x;
            });
        };
    };

    public func Subscribe<K, V>({obs; db; store; compare; key; regenerate} : Config<K,V>) : () {

        let clear = func() : () {
                // wipes the whole btree
                store.root := #leaf({
                    data = {
                    kvs = Array.tabulateVar<?(K, Nat)>(store.order - 1, func(i) { null });
                    var count = 0;
                    };
                });
                store.size := 0;
            };
            
        let insert = func((idx: Nat, v: V)) : () {
                ignore BTree.insert(store, compare, key(v), idx);
            };

        let delete = func((idx: Nat, v: V)) : () {
                ignore BTree.delete(store, compare, key(v));
            };

        // check if document pk->idx mapping already exists
        obs.before_insert := O.pipe2(
        obs.before_insert,
        O.map<(?Nat, V),(?Nat, V)>(func((inc_idx: ?Nat, v: V)) : ((?Nat, V)) {
            let ?idx = BTree.get(store, compare, key(v)) else return (null, v);
            (?idx, v);
        }));

        // insert new pk->idx mapping
        ignore obs.index_insert.subscribe({
            next = insert;
            complete = O.null_func;
        });

        ignore obs.index_delete.subscribe({
            next = delete;
            complete = O.null_func;
        });

        // can't change primary key, so no need to handle updates

        switch(regenerate) {
            case (#no) ();
            case (#yes) {
                clear();
                Vector.iterateItems<?V>(db.vec, func(idx, v) {
                    let ?x = v else return;
                    insert((idx, x));
                });
            };
        };
    }


}