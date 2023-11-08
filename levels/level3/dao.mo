import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";

actor {
    let name : Text = "MOKTO-DAO";
    type Member = {
        name : Text;
        age : Nat;
    };
    type Result<Ok, Err> = { #ok : Ok; #err : Err };
    private var manifesto : Text = "MOKTO-DAO for MotokoBootcamp";
    let goals = Buffer.Buffer<Text>(10);
    var members = HashMap.HashMap<Principal, Member>(1, Principal.equal, Principal.hash);

    public shared query func getName() : async Text {
        return name;
    };

    public shared query func getManifesto() : async Text {
        return manifesto;
    };

    public shared func setManifesto(newManifesto : Text) : async () {
        manifesto := newManifesto;
    };

    public shared func addGoal(goal : Text) : async () {
        goals.add(goal);
    };

    public shared query func getGoals() : async [Text] {
        return Buffer.toArray(goals);
    };

    //level2
    //Add a Member
    public shared ({ caller }) func addMember(member : Member) : async Result<(), Text> {
        switch (members.get(caller)) {
            case (null) {
                members.put(caller, member);
                return #ok();
            };
            case (?member) {
                return #err("Caller is a member in MOKTO-DAO!");
            };
        };
    };

    //Get a Memeber
    public shared query func getMember(principal : Principal) : async Result<Member, Text> {
        let member = members.get(principal);
        switch (member) {
            case (null) {
                return #err("Member is not found!");
            };
            case (?member) {
                return #ok(member);
            };
        };
    };

    // Update a member
    public shared ({ caller }) func updateMember(member : Member) : async Result<(), Text> {
        switch (members.get(caller)) {
            case (null) {
                return #err("Caller is not a member in MOKTO-DAO!");
            };
            case (?member) {
                members.put(caller, member);
                return #ok();
            };
        };
    };
    //Get All Members
    public shared query func getAllMembers() : async [Member] {
        let iter : Iter.Iter<Member> = members.vals();
        Iter.toArray<Member>(iter);
    };

    //Get Memeber size
    public shared query func numberOfMembers() : async Nat {
        members.size();
    };
};
