import Debug "mo:base/Debug";
import RXMDB "../src/";
import PluginPKBTree "../src/primarykey";
import PluginIDXBTree "../src/index"; 
import {test} "mo:test";
import Hero "./hero";
import {toNames; vecToNames; toIds; toScores} "./utils";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";

let hero_store = Hero.init();
let hero = Hero.use(hero_store);


test("Insert", func() {

    var i:Nat = 0;
    while(i < 20) {
        hero.db.insert({
                id=Nat64.fromNat(i);
                updatedAt= 1;
                score= Nat32.fromNat(i);
                name= "A";
                level= 1;
                skills= ["Fireball","Blizzard","Thunder"];
                deleted= false
            });
        i+=1;
    };
    i := 0;
    while(i < 20) {
        hero.db.insert({
                id=Nat64.fromNat(i)+ 100;
                updatedAt= 1;
                score= Nat32.fromNat(i);
                name= "A";
                level= 1;
                skills= ["Fireball","Blizzard","Thunder"];
                deleted= false
            });
        i+=1;
    };

});

test("Top scores", func() {
    assert(toScores(hero.score.find(0, ^0, #bwd, 100)) == "-19-19-18-18-17-17-16-16-15-15");
});

test("Bottom scores", func() {
    assert(toScores(hero.scoreBottom.find(0, ^0, #fwd, 100)) == "-0-0-1-1-2-2-3-3-4-4");
});
