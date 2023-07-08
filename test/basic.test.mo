import Debug "mo:base/Debug";
import RXMDB "../src/";
import PluginPKBTree "../src/primarykey";
import PluginIDXBTree "../src/index"; 
import {test} "mo:test";
import Hero "./hero";
import {toNames; vecToNames} "./utils";

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


test("Use Indexes", func() {

    let res = hero.updatedAt.findIdx(0, ^0, #bwd, 10);
    assert(debug_show(res) == "[(12_884_901_890, 2), (8_589_934_593, 1), (4_294_967_296, 0)]");

    
    let res2 = hero.updatedAt.findIdx(0, ^0, #fwd, 10);
    assert(debug_show(res2) == "[(4_294_967_296, 0), (8_589_934_593, 1), (12_884_901_890, 2)]");

    
    assert(toNames(hero.score.find(0, ^0, #fwd, 10)) == "ZJB");

    
    assert(toNames(hero.score.find(0, ^0, #bwd, 10)) == "BJZ");

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
    assert(toNames(hero.score.find(0, ^0, #bwd, 10)) == "JZ");
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

    assert(toNames(hero.score.find(0, ^0, #fwd, 10)) == "BZJ");
   
});




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

    assert(toNames(hero.score.find(0, ^0, #fwd, 10)) == "BZJE");

});


test("Iter #fwd", func() {
    var t:Text = "";

    for ( (k,v) in hero.pk.findIter(0, ^0, #fwd) ) {
        t := t # debug_show(v)
    };

    assert(t == "0132");
});

test("Iter #bwd", func() {
    var t:Text = "";

    for ( (k,v) in hero.pk.findIter(0, ^0, #bwd) ) {
        t := t # debug_show(v)
    };

    assert(t == "2310");
});


test("Delete (hard) and reuse Vector slots", func() {
   
    hero.db.deleteIdx(0);
    hero.db.deleteIdx(1);

    
    assert(toNames(hero.score.find(0, ^0, #fwd, 10)) == "ZE");

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


    assert(toNames(hero.score.find(0, ^0, #fwd, 10)) == "ZMKEN");

});

test("Delete by PK", func() {
    hero.pk.delete(656565);

    assert(toNames(hero.score.find(0, ^0, #fwd, 10)) == "ZMKE");
});