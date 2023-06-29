import R "./lib";
import O "mo:rxmo";
import BTree "mo:stableheapbtreemap/BTree";
import Array "mo:base/Array";
import Vector "mo:vector";
import Debug "mo:base/Debug";

module {
    public type Compare<K> = (K, K) -> { #less; #equal; #greater }; 

    public type Init<K> = BTree.BTree<K,Nat>;
    public func init<K>(btorder: ?Nat) : BTree.BTree<K,Nat> = BTree.init<K, Nat>(btorder);
    public type Unsubscribe = () -> ();

    public type Config<K,V> ={
        db: R.RXMDB<V>; 
        obs: R.ObsInit<V>; 
        store: BTree.BTree<K, Nat>; 
        compare: Compare<K>; 
        key: (Nat, V) -> ?K; 
        regenerate:{#no; #yes}
        };


    public class Use<K, V>({db; obs; store; compare; key; regenerate}: Config<K, V>) {
        
        public func findIdx(start: K, end: K, dir: BTree.Direction, limit: Nat) : [(K, Nat)] {
                 BTree.scanLimit<K, Nat>(store, compare, start, end, dir, limit).results;
        };
        
        public func find(start: K, end: K, dir: BTree.Direction, limit: Nat) : [V] {
                Array.map<(K, Nat),V>(BTree.scanLimit<K, Nat>(store, compare, start, end, dir, limit).results,
                func((k, v)) {
                    let ?x = Vector.get<?V>(db.vec, v) else Debug.trap("E101 Internal Error");
                    x;
                });
        };
    };

    
    public func Subscribe<K, V>({db; obs; store; compare; key; regenerate}: Config<K, V>) : () {

        let clear = func () {
            store.root := #leaf({
                data = {
                kvs = Array.tabulateVar<?(K, Nat)>(store.order - 1, func(i) { null });
                var count = 0;
                };
            });
            store.size := 0;
        };

        let insert = func((idx: Nat, v: V)) : () {
                let ?k = key(idx, v) else return ();
                ignore BTree.insert(store, compare, k, idx);
            };
            
        let update = func((idx: Nat, pv:V, v: V)) : () {
                let pv_key = key(idx, pv);
                let v_key = key(idx, v);
                switch(pv_key, v_key) {
                    case (null, null) return ();
                    case (?pv_key, ?v_key) {
                         if (compare(pv_key, v_key) != #equal) {
                        ignore BTree.delete(store, compare, pv_key);
                        ignore BTree.insert(store, compare, v_key, idx);
                        }
                    };
                    case (?pv_key, null) {
                        ignore BTree.delete(store, compare, pv_key);
                    };
                    case (null, ?v_key) {
                        ignore BTree.insert(store, compare, v_key, idx);
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