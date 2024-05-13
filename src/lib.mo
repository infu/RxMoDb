import O "mo:rxmo";
import Vector "mo:vector";
import Debug "mo:base/Debug";
import List "mo:base/List";

module {
    //let {Observable; Subject; null_func; of; pipe2; pipe3; pipe4; first; map; concatAll; mergeMap; distinct; reduce; takeUntil} = O;
    let {Subject; null_func } = O;

    public type RXMDB<V> = {
        vec: Vector.Vector<?V>;
        var reuse_queue : List.List<Nat>;
    };

  
    public func init<V>() : RXMDB<V> {
        return {
            vec = Vector.new<?V>();
            var reuse_queue = List.nil<Nat>();
        };
    };

    public type ObsInit<V> = {
        insert: O.Obs<(?Nat, V)>;
        var before_insert: O.Obs<(?Nat, V)>;
        var index_insert: O.Obs<(Nat, V)>;
        var index_update: O.Obs<(Nat, V, V)>;
        var index_delete: O.Obs<(Nat, V)>;
        var after_insert: O.Obs<(Nat, V)>;
        var after_update: O.Obs<(Nat, V, V)>;
    };

    public func init_obs<V>() : ObsInit<V> {
        let insert = Subject<(?Nat, V)>();
        return {
            insert;
            var before_insert = insert;
            var index_insert = Subject<(Nat, V)>();
            var index_update = Subject<(Nat, V, V)>();
            var index_delete = Subject<(Nat, V)>();
            var after_insert = Subject<(Nat, V)>();
            var after_update = Subject<(Nat, V, V)>();
        };
    };


    public class Use<V>(db: RXMDB<V>, obs: ObsInit<V>) {

        var _unsubscribeBI = obs.before_insert.subscribe({
            next = func ((inc_idx:?Nat, v:V)) : () {
                switch(inc_idx) {
                    case (?idx) {
                        let ?pv = Vector.get(db.vec, idx) else Debug.trap("IE1 internal error");
                        Vector.put(db.vec, idx, ?v);
                        obs.index_update.next((idx, pv, v));
                        obs.after_update.next((idx, pv, v));

                    };
                    case (null) {
                        let (head, tail) = List.pop(db.reuse_queue);
                        let idx:Nat = switch(head) { // Reuse empty Vector slots
                          case(?reuse) {
                            Vector.put(db.vec, reuse, ?v);
                            db.reuse_queue := tail;
                            reuse;
                          };
                          case (null) {
                            Vector.add(db.vec, ?v);
                            Vector.size(db.vec) - 1;
                          };
                        };
                        
                        obs.index_insert.next((idx, v));
                        obs.after_insert.next((idx, v));
                    };
                };
            };
            complete =  null_func
        });
      

        public func deleteIdx( idx: Nat ) : () {
            deleteIdxF<V>(db, obs, idx);
        };

        public func getIdx( idx: Nat) : ?V {
            return Vector.get(db.vec, idx);
        };
        
        /// Insert or ( Update if you have a Primary Key ) 
        public func insert( v: V ) : () {
            obs.insert.next((null, v));
        };

        // public func update ( idx: Nat, f:(V) -> V ) : () {
        //     let ?v = Vector.get(db.vec, idx) else return;
        //     obs.insert.next((?idx, f(v)));
        // };

        /// Do not use if you have a Primary Key, the idx will be ignored
        public func setIdx( idx: Nat, v: V ) : () {
            obs.insert.next((?idx, v));
        };
     
    };


    public func deleteIdxF<V>(db: RXMDB<V>, obs: ObsInit<V>, idx: Nat ) : () {
        let ?v = Vector.get(db.vec, idx) else return;
        Vector.put(db.vec, idx, null);
        db.reuse_queue := List.push(idx, db.reuse_queue);
        obs.index_delete.next((idx, v));
    };
}