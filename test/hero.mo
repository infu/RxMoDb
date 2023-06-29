import Blob "mo:base/Blob";
import BTree "mo:stableheapbtreemap/BTree";
import Nat64 "mo:base/Nat64";
import Int32 "mo:base/Int32";
import Nat32 "mo:base/Nat32";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Prim "mo:⛔";
import Vector "mo:vector";
import RXMDB "../src/";
import O "mo:rxmo";
import PK "../src/primarykey";
import IDX "../src/index"; 

module {

// Document Type
public type Doc = {
    id: Nat64;
    updatedAt: Nat32;
    score: Nat32;
    name: Text;
    level: Nat32;
    skills: [Text];
    deleted: Bool;
};

public type UpdateAtKey = Nat64;
public type ScoreKey = Nat64;
public type PKKey = Nat64;

public type Init = { // All stable
    db : RXMDB.RXMDB<Doc>;
    pk : PK.Init<Nat64>;
    updatedAt : IDX.Init<UpdateAtKey>;
    score : IDX.Init<Nat64>;
};

public func init() : Init {
    return {
    db = RXMDB.init<Doc>();
    pk = PK.init<PKKey>(?32);
    updatedAt = IDX.init<UpdateAtKey>(?32);
    score = IDX.init<ScoreKey>(?32);
    };
};

public func updatedAt_key(idx:Nat, h : Doc) : ?UpdateAtKey = ?((Nat64.fromNat(Nat32.toNat(h.updatedAt)) << 32) | Nat64.fromNat(idx));

public func score_key(idx:Nat, h : Doc) : ?ScoreKey {
        if (h.deleted) return null;
        ?((Nat64.fromNat(Nat32.toNat(h.score)) << 32) | Nat64.fromNat(idx));
};

public func pk_key(h : Doc) : PKKey = h.id;

public type Use = {
    db : RXMDB.Use<Doc>;
    pk : PK.Use<PKKey, Doc>;
    updatedAt : IDX.Use<UpdateAtKey, Doc>;
    score : IDX.Use<ScoreKey, Doc>;
};

public func use(init : Init) : Use {
    let obs = RXMDB.init_obs<Doc>(); // Observables for attachments

    // PK
    let pk_config : PK.Config<PKKey, Doc> = {
        db=init.db;
        obs;
        store=init.pk;
        compare=Nat64.compare;
        key=pk_key;
        regenerate=#no;
        };
    PK.Subscribe<PKKey, Doc>(pk_config); 

    // Index - updatedAt
    let updatedAt_config : IDX.Config<UpdateAtKey, Doc> = {
        db=init.db;
        obs;
        store=init.updatedAt;
        compare=Nat64.compare;
        key=updatedAt_key;
        regenerate=#no;
        };
    IDX.Subscribe(updatedAt_config);

    // Index - score
    let score_conig = {
        db=init.db;
        obs;
        store=init.score;
        compare=Nat64.compare;
        key=score_key;
        regenerate=#no;
        };
    IDX.Subscribe(score_conig); 

    return {
        db = RXMDB.Use<Doc>(init.db, obs);
        pk = PK.Use(pk_config);
        updatedAt = IDX.Use(updatedAt_config);
        score = IDX.Use(score_conig);
    }

}


}