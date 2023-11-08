import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import TrieMap "mo:base/TrieMap";

import Account "../level3/account";
actor {
    let tknName : Text = "MOKTO-DAO";
    type Member = {
        name : Text;
        age : Nat;
    };
    type Result<Ok, Err> = { #ok : Ok; #err : Err };
    private var manifesto : Text = "MOKTO-DAO for MotokoBootcamp";
    let goals = Buffer.Buffer<Text>(10);
    var members = HashMap.HashMap<Principal, Member>(1, Principal.equal, Principal.hash);
    //level3
    let ledger = TrieMap.TrieMap<Account.Account, Nat>(Account.accountsEqual, Account.accountsHash);

    public shared query func getName() : async Text {
        return tknName;
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

    //level3
    //Token name
    public shared query func name() : async Text {
        return "MOTToken";
    };

    //Get the symbol
    public shared query func symbol() : async Text {
        return "MOT";
    };

    //Mint function
    public shared ({ caller }) func mint(to : Principal, amount : Nat) : async Result<(), Text> {
        let account : Account.Account = { owner = to; subaccount = null };
        ledger.put(account, amount);
        return #ok();
    };

    // Transfer function
    public shared ({ caller }) func transfer(from : Account.Account, to : Account.Account, amount : Nat) : async Result<(), Text> {
        let fromBalance = ledger.get(from);
        switch (fromBalance) {
            case (null) {
                return #err("Sender account not found!");
            };
            case (?fromBalance) {
                if (fromBalance < amount) {
                    return #err("Sender has not enough tokens!");
                } else {
                    let toBalance = ledger.get(to);
                    switch (toBalance) {
                        case (null) {
                            ledger.put(to, amount);
                        };
                        case (?toBalance) {
                            ledger.put(to, toBalance + amount);
                        };
                    };
                    ledger.put(from, fromBalance - amount);
                    return #ok();
                };
            };
        };
    };

    public shared query func balanceOf(account : Account.Account) : async Nat {
        let balance = ledger.get(account);
        switch (balance) {
            case (null) {
                return 0;
            };
            case (?balance) {
                return balance;
            };
        };
    };
    
    public shared query func totalSupply() : async Nat {
        var total : Nat = 0;
        for (balance in ledger.vals()) {
            total += balance;
        };
        return total;
    };
};
