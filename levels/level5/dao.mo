import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import TrieMap "mo:base/TrieMap";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";

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

    //level4
    var nextProposalId : Nat = 0;
    var proposals : TrieMap.TrieMap<Nat, Proposal> = TrieMap.TrieMap(Nat.equal, Hash.hash);
    type createProposalOk = { #ProposalCreated };
    type createProposalErr = { #NotDAOMember; #NotEnoughTokens };
    type createProposalResult = {
        #ok : createProposalOk;
        #err : createProposalErr;
    };
    type voteErr = { #AlreadyVoted; #ProposalNotFound; #ProposalEnded };
    type voteOk = { #ProposalAccepted; #ProposalRefused; #ProposalOpen };
    type voteResult = { #ok : voteOk; #err : voteErr };

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

    //level4
    type Status = { #Open; #Rejected; #Accepted };
    type Proposal = {
        id : Nat;
        status : Status;
        manifest : Text;
        votes : Int;
        voters : List.List<Principal>;
    };

    public shared ({ caller }) func createProposal(manifest : Text) : async Result<createProposalOk, createProposalErr> {
        switch (members.get(caller)) {
            case (null) {
                return #err(#NotDAOMember);
            };
            case (?member) {
                let account : Account.Account = {
                    owner = caller;
                    subaccount = null;
                };

                // check for enough tokens
                let balance = ledger.get(account);

                switch (balance) {
                    case (null) {
                        return #err(#NotEnoughTokens);
                    };
                    case (?balance) {
                        if (balance > 1) {
                            nextProposalId += 1;
                            var proposal : Proposal = {
                                id = nextProposalId;
                                status = #Open;
                                manifest = manifest;
                                votes = 0;
                                voters = List.nil<Principal>();
                            };
                            proposals.put(nextProposalId, proposal);
                            ledger.put(account, balance - 1);
                            return #ok(#ProposalCreated);

                        } else {
                            return #err(#NotEnoughTokens);
                        };
                    };
                };
            };
        };
    };

    // Task 4: Implement the getProposal query function
    public shared query func getProposal(id : Nat) : async ?Proposal {
        proposals.get(id);
    };

    // get_all_proposals
    public shared query func get_all_proposals() : async [(Nat, Proposal)] {
        let result : [(Nat, Proposal)] = Iter.toArray<(Nat, Proposal)>(proposals.entries());
        result;
    };

    public shared ({ caller }) func vote(id : Nat, vote : Bool) : async Result<voteResult, voteErr> {

        switch (members.get(caller)) {
            case (null) { return #err(#ProposalEnded) };
            case (?member) {
                let account : Account.Account = {
                    owner = caller;
                    subaccount = null;
                };

                // check if proposal exists
                var proposal = await getProposal(id);

                switch (proposal) {
                    case (null) {
                        return #err(#ProposalNotFound);
                    };
                    case (?proposal) {
                        // check if caller has already voted
                        let hasVoted : ?Principal = List.find<Principal>(proposal.voters, func x = Principal.toText(x) == Principal.toText(caller));
                        switch (hasVoted) {
                            case (null) {
                                // check if proposal is still open
                                switch (proposal.status) {
                                    case (#Open) {
                                        // add caller to voters
                                        let voters = List.push(caller, proposal.voters);

                                        // with their voting power being equivalent to the number of tokens they possess
                                        var balanceOfVoter = ledger.get(account);
                                        switch (balanceOfVoter) {
                                            case (null) {
                                                return #err(#ProposalEnded);
                                            };
                                            case (?balanceOfVoter) {
                                                // update votes
                                                var votes = proposal.votes;
                                                if (vote) {
                                                    votes += balanceOfVoter;
                                                } else {
                                                    votes -= balanceOfVoter;
                                                };

                                                var status = proposal.status;

                                                if (votes >= 100) {
                                                    // update proposal
                                                    status := #Accepted;
                                                    let updatedProposal : Proposal = {
                                                        proposal with votes;
                                                        voters;
                                                        status;
                                                    };
                                                    proposals.put(id, updatedProposal);

                                                    return #ok(#ok(#ProposalAccepted));
                                                } else if (votes <= -100) {
                                                    status := #Rejected;
                                                    let updatedProposal : Proposal = {
                                                        proposal with votes;
                                                        voters;
                                                        status;
                                                    };
                                                    proposals.put(id, updatedProposal);
                                                    return #ok(#ok(#ProposalRefused));
                                                } else {
                                                    let updatedProposal : Proposal = {
                                                        proposal with votes;
                                                        voters;
                                                        status;
                                                    };
                                                    proposals.put(id, updatedProposal);
                                                    return #ok(#ok(#ProposalOpen));
                                                };
                                            };
                                        };
                                    };
                                    case (#Rejected) {
                                        return #err(#ProposalEnded);
                                    };
                                    case (#Accepted) {
                                        return #err(#ProposalEnded);
                                    };
                                };
                            };
                            case (?hasVoted) {
                                return #err(#AlreadyVoted);
                            };
                        };
                    };
                };
            };
        };
    };
};
