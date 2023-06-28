import O "mo:rxmo";
import Vector "mo:vector";
import Debug "mo:base/Debug";

module {
    let {Observable; Subject; null_func; of; pipe2; pipe3; pipe4; first; map; concatAll; mergeMap; distinct; reduce; takeUntil} = O;

    public type RXMDB<V> = {
        vec: Vector.Vector<?V>;
    };

  
    public func init<V>() : RXMDB<V> {
        return {
            vec = Vector.new<?V>()
        };
    };

    public type ObsInit<V> = {
        insert: O.Observable<(?Nat, V)>;
        var before_insert: O.Observable<(?Nat, V)>;
        var after_insert: O.Observable<(Nat, V)>;
        var after_update: O.Observable<(Nat, V, V)>;

    };

    public func init_obs<V>() : ObsInit<V> {
        let insert = Subject<(?Nat, V)>();
        return {
            insert;
            var before_insert = insert;
            var after_insert = Subject<(Nat, V)>();
            var after_update = Subject<(Nat, V, V)>();
 
        };
    };


    public class Use<V>(db: RXMDB<V>, obs: ObsInit<V>) {

        var unsubscribeBI = obs.before_insert.subscribe({
            next = func ((inc_idx:?Nat, v:V)) : () {
                switch(inc_idx) {
                    case (?idx) {
                        let ?pv = Vector.get(db.vec, idx) else Debug.trap("IE1 internal error");
                        Vector.put(db.vec, idx, ?v);
                        obs.after_update.next((idx, pv, v));
                    };
                    case (null) {
                        Vector.add(db.vec, ?v);
                        let idx:Nat = Vector.size(db.vec) - 1;
                        obs.after_insert.next((idx, v));
                    };
                };
               
            };
            complete =  null_func
        });
      

        public func insert( v: V ) : () {
            obs.insert.next((null, v));
        };

     
    };
}