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
import PluginPKBTree "../src/primarykey";
import PluginIDXBTree "../src/index"; 
import {test} "mo:test";


// Document Type
type Hero = {
    id: Nat64;
    updatedAt: Nat32;
    score: Nat32;
    name: Text;
    level: Nat32;
    skills: [Text];
    deleted: Bool;
};

// Setup RXMDB
let hero_db = RXMDB.init<Hero>();
let hero_obs = RXMDB.init_obs<Hero>(); // Observables for attachments

// Plugin adding PK functionality
let hero_id = func (h : Hero) : Nat64 = h.id;
let hero_pk = PluginPKBTree.Init<Nat64>(?32);
PluginPKBTree.Connect<Nat64, Hero>(hero_obs, hero_pk, Nat64.compare, hero_id); 

// Plugin adding Index functionality
let hero_idx_updatedAt = func (idx:Nat, h : Hero) : ?Nat64 = ?((Nat64.fromNat(Nat32.toNat(h.updatedAt)) << 32) | Nat64.fromNat(idx));
let idx_updatedAt = PluginIDXBTree.Init<Nat64>(?32);
PluginIDXBTree.Connect<Nat64, Hero>(hero_obs, idx_updatedAt, Nat64.compare, hero_idx_updatedAt); 

// Plugin adding Index functionality
let hero_idx_score = func (idx:Nat, h : Hero) : ?Nat64 {
    if (h.deleted) return null;
    ?((Nat64.fromNat(Nat32.toNat(h.score)) << 32) | Nat64.fromNat(idx));
};
let idx_score = PluginIDXBTree.Init<Nat64>(?32);
PluginIDXBTree.Connect<Nat64, Hero>(hero_obs, idx_score, Nat64.compare, hero_idx_score); 

// Make RXMDB usable (!Always after plugins)
let hero = RXMDB.Use<Hero>(hero_db, hero_obs);


test("Insert", func() {


    hero.insert({
        id=123;
        updatedAt= 1;
        score= 3;
        name= "A";
        level= 1;
        skills= ["Fireball","Blizzard","Thunder"];
        deleted= false
    });

    hero.insert({
        id=2323;
        updatedAt= 2;
        score= 2;
        name= "J";
        level= 55;
        skills= ["Blizzard"];
        deleted= false
    });
 
    hero.insert({
        id=567565;
        updatedAt= 3;
        score= 1;
        name= "Z";
        level= 10;
        skills= ["Thunder"];
        deleted= false
    });

    let ?idx = BTree.get(hero_pk, Nat64.compare, 123:Nat64) else Debug.trap("ID not found");
    assert(idx == 0);

    let ?rec = Vector.get(hero_db.vec, idx) else Debug.trap("Record not found");
    assert(rec.id == 123);
   

});

test("Update", func() {
   
    hero.insert({
        id=123;
        updatedAt= 1;
        score= 3;
        name= "B";
        level= 1;
        skills= ["Fireball","Blizzard","Thunder"];
        deleted= false
    });


    let ?idx = BTree.get(hero_pk, Nat64.compare, 123:Nat64) else Debug.trap("ID not found");
    assert(idx == 0);

    let ?rec = Vector.get(hero_db.vec, idx) else Debug.trap("Record not found");
    assert(rec.name == "B");
   
});

func resultsToNames(results: [(Nat64,Nat)]) : Text {
    var t = "";
    for ( (idxkey, idx) in results.vals()) {
        let ?v = Vector.get(hero_db.vec, idx) else Debug.trap("IE100 Internal error");
        t := t # v.name;
    };
    return t;
};

test("Use Indexes", func() {

    let res = BTree.scanLimit<Nat64, Nat>(idx_updatedAt, Nat64.compare, 0, ^0, #bwd, 10);
    assert(debug_show(res.results) == "[(12_884_901_890, 2), (8_589_934_593, 1), (4_294_967_296, 0)]");

    let res2 = BTree.scanLimit<Nat64, Nat>(idx_updatedAt, Nat64.compare, 0, ^0, #fwd, 10);
    assert(debug_show(res2.results) == "[(4_294_967_296, 0), (8_589_934_593, 1), (12_884_901_890, 2)]");

    let res3 = BTree.scanLimit<Nat64, Nat>(idx_score, Nat64.compare, 0, ^0, #fwd, 10);
    assert(resultsToNames(res3.results) == "ZJB");

    let res4 = BTree.scanLimit<Nat64, Nat>(idx_score, Nat64.compare, 0, ^0, #bwd, 10);
    assert(resultsToNames(res4.results) == "BJZ");

});

test("Delete", func() {
   
    hero.insert({
        id=123;
        updatedAt= 1;
        score= 3;
        name= "B";
        level= 1;
        skills= ["Fireball","Blizzard","Thunder"];
        deleted= true
    });

});

test("You should still be able to find a deleted record by pk", func() {

    let ?idx = BTree.get(hero_pk, Nat64.compare, 123:Nat64) else Debug.trap("ID not found");
    assert(idx == 0);

    let ?rec = Vector.get(hero_db.vec, idx) else Debug.trap("Record not found");
    assert(rec.name == "B");
   
});

test("Deleted records shouldn't be inside the score index", func() {
    let res4 = BTree.scanLimit<Nat64, Nat>(idx_score, Nat64.compare, 0, ^0, #bwd, 10);
    assert(resultsToNames(res4.results) == "JZ");
});


test("Check if indexes get refreshed on update", func() {
    
    hero.insert({
        id=123;
        updatedAt= 1;
        score= 0; // changing score
        name= "B";
        level= 1;
        skills= ["Fireball","Blizzard","Thunder"];
        deleted= false
    });

    let res3 = BTree.scanLimit<Nat64, Nat>(idx_score, Nat64.compare, 0, ^0, #fwd, 10);
    assert(resultsToNames(res3.results) == "BZJ");
   
});