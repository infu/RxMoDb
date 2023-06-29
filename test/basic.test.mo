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
import Hero "./hero";

let hero_store = Hero.init();
let hero = Hero.use(hero_store);


test("Insert", func() {

    hero.db.insert({
        id=123;
        updatedAt= 1;
        score= 3;
        name= "A";
        level= 1;
        skills= ["Fireball","Blizzard","Thunder"];
        deleted= false
    });

    hero.db.insert({
        id=2323;
        updatedAt= 2;
        score= 2;
        name= "J";
        level= 55;
        skills= ["Blizzard"];
        deleted= false
    });
 
    hero.db.insert({
        id=567565;
        updatedAt= 3;
        score= 1;
        name= "Z";
        level= 10;
        skills= ["Thunder"];
        deleted= false
    });

    let ?rec = hero.pk.get(123) else Debug.trap("Not found");
    assert(rec.id == 123);
   
});

test("Find by score", func() {
    let res = hero.score.find(0, ^0, #fwd, 1);
    assert(res[0].name == "Z");
});

test("Update", func() {
   
    hero.db.insert({
        id=123;
        updatedAt= 1;
        score= 3;
        name= "B";
        level= 1;
        skills= ["Fireball","Blizzard","Thunder"];
        deleted= false
    });

    let ?rec = hero.pk.get(123) else Debug.trap("Not found");
    assert(rec.name == "B");
   
});

func resultsToNames(results: [(Nat64,Nat)]) : Text {
    var t = "";
    for ( (idxkey, idx) in results.vals()) {
        let ?v = hero.db.get(idx) else Debug.trap("IE100 Internal error");
        t := t # v.name;
    };
    return t;
};

test("Use Indexes", func() {

    // let res = BTree.scanLimit<Nat64, Nat>(hero_store.updatedAt, Nat64.compare, 0, ^0, #bwd, 10);
    let res = hero.updatedAt.findIdx(0, ^0, #bwd, 10);
    assert(debug_show(res) == "[(12_884_901_890, 2), (8_589_934_593, 1), (4_294_967_296, 0)]");

    
    let res2 = hero.updatedAt.findIdx(0, ^0, #fwd, 10);
    assert(debug_show(res2) == "[(4_294_967_296, 0), (8_589_934_593, 1), (12_884_901_890, 2)]");

    
    let res3 = hero.score.findIdx(0, ^0, #fwd, 10);
    assert(resultsToNames(res3) == "ZJB");

    
    let res4 = hero.score.findIdx(0, ^0, #bwd, 10);
    assert(resultsToNames(res4) == "BJZ");

});

test("Delete (soft)", func() {
   
    hero.db.insert({
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

    let ?rec = hero.pk.get(123) else Debug.trap("Not found");
    assert(rec.name == "B");
   
});

test("Deleted records shouldn't be inside the score index", func() {
    let res4 = hero.score.findIdx(0, ^0, #bwd, 10);
    assert(resultsToNames(res4) == "JZ");
});


test("Check if indexes get refreshed on update", func() {

    hero.db.insert({
        id=123;
        updatedAt= 1;
        score= 0; // changing score
        name= "B";
        level= 1;
        skills= ["Fireball","Blizzard","Thunder"];
        deleted= false
    });

    let res3 = hero.score.findIdx(0, ^0, #fwd, 10);
    assert(resultsToNames(res3) == "BZJ");
   
});

// test("Regenerate indexes", func() { 
//     hero_idx_score_unsubscribe();
//     ignore PluginIDXBTree.Subscribe<Nat64, Hero>({
//         db=hero_db;
//         obs=hero_obs;
//         store=idx_score;
//         compare=Nat64.compare;
//         key=hero_idx_score;
//         regenerate=#yes;
//         });

//     let res = BTree.scanLimit<Nat64, Nat>(idx_score, Nat64.compare, 0, ^0, #fwd, 10);
//     assert(resultsToNames(res.results) == "BZJ");

// });


func vecToNames(vec: Vector.Vector<?Hero.Doc>) : Text {
    let results = Vector.toArray(vec);
    var t = "";
    label lo for ( va in results.vals()) {
        let ?v = va else {
            t := t # "-";
            continue lo;
        };
        t := t # v.name;
    };
    return t;
};

test("Check if insertation works again", func() {

    hero.db.insert({
        id=98765;
        updatedAt= 34343;
        score= 3;
        name= "E";
        level= 1;
        skills= ["Fireball","Blizzard","Thunder"];
        deleted= false
    });

    let res2 = hero.score.findIdx(0, ^0, #fwd, 10);
    assert(resultsToNames(res2) == "BZJE");

});

test("Delete (hard) and reuse Vector slots", func() {
   
    hero.db.delete(0);
    hero.db.delete(1);

    let res = hero.score.findIdx(0, ^0, #fwd, 10);
    
    assert(resultsToNames(res) == "ZE");

    assert(vecToNames(hero_store.db.vec) == "--ZE");

    hero.db.insert({
        id=4444;
        updatedAt= 34343;
        score= 3;
        name= "K";
        level= 1;
        skills= ["Fireball","Blizzard","Thunder"];
        deleted= false
    });

    assert(vecToNames(hero_store.db.vec) == "-KZE");

    hero.db.insert({
        id=4444232;
        updatedAt= 34343;
        score= 3;
        name= "M";
        level= 1;
        skills= ["Fireball","Blizzard","Thunder"];
        deleted= false
    });

    assert(vecToNames(hero_store.db.vec) == "MKZE");

    hero.db.insert({
        id=656565;
        updatedAt= 34343;
        score= 3;
        name= "N";
        level= 1;
        skills= ["Fireball","Blizzard","Thunder"];
        deleted= false
    });

    assert(vecToNames(hero_store.db.vec) == "MKZEN");


    let res2 = hero.score.findIdx(0, ^0, #fwd, 10);
    assert(resultsToNames(res2) == "ZMKEN");

});