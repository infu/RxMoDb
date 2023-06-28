import R "./lib";
import O "mo:rxmo";
import BTree "mo:stableheapbtreemap/BTree";

module {
    public type Compare<K> = (K, K) -> { #less; #equal; #greater };

    public func Init<K>(btorder: ?Nat) : BTree.BTree<K,Nat> = BTree.init<K, Nat>(btorder);

    public func Connect<K, V>(obs: R.ObsInit<V>, pkstore: BTree.BTree<K, Nat>, compare: Compare<K>, to_key: (V) -> K) : () {

        // check if document pk->idx mapping already exists
        obs.before_insert := O.pipe2(
        obs.insert,
        O.map<(?Nat, V),(?Nat, V)>(func((inc_idx: ?Nat, v: V)) : ((?Nat, V)) {
            let ?idx = BTree.get(pkstore, compare, to_key(v)) else return (null, v);
            (?idx, v);
        }));

        // insert new pk->idx mapping
        ignore obs.after_insert.subscribe({
            next = func((idx: Nat, v: V)) : () {
                ignore BTree.insert(pkstore, compare, to_key(v), idx);
            };
            complete = O.null_func;
        });
    }


}