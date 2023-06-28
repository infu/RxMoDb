import R "./lib";
import O "mo:rxmo";
import BTree "mo:stableheapbtreemap/BTree";

module {
    public type Compare<K> = (K, K) -> { #less; #equal; #greater }; 

    public func Init<K>(btorder: ?Nat) : BTree.BTree<K,Nat> = BTree.init<K, Nat>(btorder);

    public func Connect<K, V>(obs: R.ObsInit<V>, store: BTree.BTree<K, Nat>, compare: Compare<K>, enc_key: (Nat, V) -> ?K) : () {

        ignore obs.after_insert.subscribe({
            next = func((idx: Nat, v: V)) : () {
                let ?key = enc_key(idx, v) else return ();
                ignore BTree.insert(store, compare, key, idx);
            };
            complete = O.null_func;
        });

        ignore obs.after_update.subscribe({
            next = func((idx: Nat, pv:V, v: V)) : () {
                let pv_key = enc_key(idx, pv);
                let v_key = enc_key(idx, v);
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
            complete = O.null_func;
        });
    }


}