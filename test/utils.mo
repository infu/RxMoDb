import Vector "mo:vector";
import Hero "./hero";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";

module {

    public func vecToNames(vec: Vector.Vector<?Hero.Doc>) : Text {
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

    public func toNames(results: [Hero.Doc]) : Text {
        var t = "";
        for ( v in results.vals()) {
            t := t # v.name;
        };
        return t;
    };

    public func toIds(results: [Hero.Doc]) : Text {
        var t = "";
        for ( v in results.vals()) {
            t := t # "-" # Nat64.toText(v.id);
        };
        return t;
    };

    public func toScores(results: [Hero.Doc]) : Text {
        var t = "";
        for ( v in results.vals()) {
            t := t # "-" # Nat32.toText(v.score);
        };
        return t;
    };
}