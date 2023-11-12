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
    public type Unsubscribe = () -> ();

    public type Keep = {
        #all;
        #bottom : Nat;
        #top : Nat;
    };

    public type Config<K,V> ={
        db: R.RXMDB<V>; 
        obs: R.ObsInit<V>; 
        store: BTree.BTree<K, Nat>; 
        compare: Compare<K>; 
        key: (Nat, V) -> ?K; 
        regenerate:{#no; #yes};
        keep: Keep;
    };
    
    let IterBatch = 200;

    public class Use<K, V>({db; obs; store; compare; key; regenerate; keep}: Config<K, V>) {
        
        public func findIdx(start: K, end: K, dir: BTree.Direction, limit: Nat) : [(K, Nat)] {
            BTree.scanLimit<K, Nat>(store, compare, start, end, dir, limit).results;
        };
        
        public func get(a: K) : ?V {
            let ?idx = BTree.get<K, Nat>(store, compare, a) else return null;
            let ?x = Vector.get<?V>(db.vec, idx) else Debug.trap("E101 Internal Error");
            ?x
        };

        public func find(start: K, end: K, dir: BTree.Direction, limit: Nat) : [V] {
            Array.map<(K, Nat),V>(BTree.scanLimit<K, Nat>(store, compare, start, end, dir, limit).results,
            func((k, v)) {
                let ?x = Vector.get<?V>(db.vec, v) else Debug.trap("E101 Internal Error");
                x;
            });
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

    };

    
    public func Subscribe<K, V>({db; obs; store; compare; key; regenerate; keep}: Config<K, V>) : () {

        let clear = func () {
            store.root := #leaf({
                data = {
                kvs = Array.tabulateVar<?(K, Nat)>(store.order - 1, func(i) { null });
                var count = 0;
                };
            });
            store.size := 0;
        };

        let insertInternal = func(idx:Nat, k:K) {
            switch(keep) {
                case (#all) ();
                case (#top(len)) {
                    if (BTree.size(store) >= len) {
                        let ?(z,_) = BTree.min(store) else Debug.trap("E231 Internal Error");
                        if (compare(z, k) != #greater) {
                            ignore BTree.delete(store, compare, z); // Delete the lowest
                        } else return ();
                    }
                };
                case (#bottom(len)) {
                    if (BTree.size(store) >= len) {
                        let ?(z,_) = BTree.max(store) else Debug.trap("E231 Internal Error");
                        if (compare(z, k) != #less) {
                            ignore BTree.delete(store, compare, z); // Delete the highest
                        } else return ();
                    }
                };
            };
            ignore BTree.insert(store, compare, k, idx);
        };

        let insert = func((idx: Nat, v: V)) : () {
                let ?k = key(idx, v) else return ();
                insertInternal(idx, k);
            };
            
        let update = func((idx: Nat, pv:V, v: V)) : () {
                let pv_key = key(idx, pv);
                let v_key = key(idx, v);
                switch(pv_key, v_key) {
                    case (null, null) return ();
                    case (?pv_key, ?v_key) {
                         if (compare(pv_key, v_key) != #equal) {
                        ignore BTree.delete(store, compare, pv_key);
                        insertInternal(idx, v_key);
                        }
                    };
                    case (?pv_key, null) {
                        ignore BTree.delete(store, compare, pv_key);
                    };
                    case (null, ?v_key) {
                        insertInternal(idx, v_key);
                    };
                }  
            };

         let delete = func((idx: Nat, pv:V)) : () {
                let pv_key = key(idx, pv);
                
                switch(pv_key) {
                    case (null) return ();
                    case (?pv_key) {
                        ignore BTree.delete(store, compare, pv_key);
                    };
                };
            };

        let insert_unsubscribe = obs.index_insert.subscribe({
            next = insert;
            complete = O.null_func;
        });

        let update_unsubscribe = obs.index_update.subscribe({
            next = update;
            complete = O.null_func;
        });

        let delete_unsubscribe = obs.index_delete.subscribe({
            next = delete;
            complete = O.null_func;
        });

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

  

    };


}