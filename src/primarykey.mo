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

    public type Config<K,V> = {
        obs: R.ObsInit<V>;
        db: R.RXMDB<V>;
        store: BTree.BTree<K, Nat>;
        compare: Compare<K>;
        key: (V) -> K
    };
    
    public class Use<K, V>({obs; db; store; compare; key} : Config<K,V>) {
        
        public func getIdx(pk : K) : ?Nat {
               BTree.get(store, compare, pk);
        };
        
        public func get(pk: K) : ?V {
               let ?idx = BTree.get(store, compare, pk) else return null;
               let ?v = Vector.get<?V>(db.vec, idx) else Debug.trap("E101 Internal Error");
               ?v;
        };
    };

    public func Subscribe<K, V>({obs; db; store; compare; key} : Config<K,V>) : () {

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

        // can't change primary key, so no need to handle update

    }


}