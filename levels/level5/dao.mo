import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import TrieMap "mo:base/TrieMap";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Text "mo:base/Text";

import Account "../level3/account";
import Http "http";
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

    //Level5
    let logo : Text = "<?xml version='1.0' encoding='UTF-8' standalone='no'?> <svg id='Layer_1' data-name='Layer 1' viewBox='0 0 2000 2000' version='1.1' sodipodi:docname='icAcademy-B1.svg' inkscape:export-filename='icAcademy-B1.svg' inkscape:export-xdpi='36.779999' inkscape:export-ydpi='36.779999' inkscape:version='1.3 (0e150ed, 2023-07-21)' xmlns:inkscape='http://www.inkscape.org/namespaces/inkscape' xmlns:sodipodi='http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd' xmlns='http://www.w3.org/2000/svg' xmlns:svg='http://www.w3.org/2000/svg'> <sodipodi:namedview id='namedview14' pagecolor='#ffffff' bordercolor='#000000' borderopacity='0.25' inkscape:showpageshadow='2' inkscape:pageopacity='0.0' inkscape:pagecheckerboard='0' inkscape:deskcolor='#d1d1d1' inkscape:zoom='0.3495' inkscape:cx='1000' inkscape:cy='998.56938' inkscape:window-width='1392' inkscape:window-height='1207' inkscape:window-x='0' inkscape:window-y='25' inkscape:window-maximized='0' inkscape:current-layer='Layer_1' /> <defs id='defs1'><style id='style1'>.cls-1{fill:#145e86;}</style></defs> <path class='cls-1' d='M616.16,1203.71v-82.48c0-5.94,3.22-9.15,9-9.15s9,3.21,9,9.15v82.48c0,5.68-3.22,8.9-9,8.9S616.16,1209.39,616.16,1203.71Z' id='path1' /> <path class='cls-1' d='M657.71,1174.27v-23.49c0-23.37,16.44-38.83,41.18-38.83,13.85,0,27.2,5.94,33.38,16.94,1.73,3.09,1.36,9.15-4.2,11.25-5.07,1.86-8.78-.12-10.64-2.22-5.56-7.05-12.48-10-18.54-10-13.85,0-23.13,9.52-23.13,23.87v21.52c0,14.09,9.28,23.49,23.25,23.49,7.79,0,14.59-4,19-10.39,2.35-2.84,5.94-4.2,10.51-2.35,5.57,2.35,6.31,7.3,5.07,9.77-5.81,12.74-19.53,18.92-34.62,18.92C674.15,1212.73,657.71,1197.4,657.71,1174.27Z' id='path2' /><path class='cls-1' d='M861.61,1212.11c-5.56,1.49-9.52-.61-11.13-6.18l-4.69-14.34H805.72l-4.57,14.34c-1.74,5.57-5.57,7.67-11.13,6.18s-7.67-5.56-5.82-11.25l25.73-77.78c2.1-6.68,7.29-10.51,15-10.51h1.85c7.67,0,12.86,3.83,15,10.51l25.73,77.78C869.16,1206.55,867.05,1210.51,861.61,1212.11ZM840.84,1176l-15.09-46.38-15,46.38Z' id='path3' /> <path class='cls-1' d='M884.12,1182.44v-12c0-18.18,13.1-30.3,32.64-30.3,10.39,0,20.9,3.47,25.47,12.86a7.05,7.05,0,0,1-4.32,9.65c-4.58,1.36-7.55.12-9.28-1.48-3.58-4.33-7.42-6.06-11.87-6.06-9.15,0-15.33,6.3-15.33,15.83v11.12c0,9.4,6.18,15.59,15.46,15.59a15.58,15.58,0,0,0,12.36-6.06c1.61-1.61,4.33-3.09,8.78-1.61a7.22,7.22,0,0,1,5.07,9.15c-3.09,9.52-15.09,13.6-26.21,13.6C897.22,1212.73,884.12,1200.61,884.12,1182.44Z' id='path4' /> <path class='cls-1' d='M1023,1164.5v39.21c0,5.68-2.72,8.9-7.79,8.9s-8-3.22-8.41-8.78v-.74c-5.07,6.06-13,9.64-22.75,9.64-13.48,0-22.51-7.91-22.51-20v-4.08c0-11.25,9.15-18.67,23-18.67h21.15v-4.21c0-7.42-5.32-12.36-13.11-12.36-4.82,0-9.15,1.73-13.11,6.06a7.38,7.38,0,0,1-7.91,1.73c-6.06-1.86-7.42-6.68-5.57-9.77,4.33-7.55,15.34-11.26,26.59-11.26C1010.74,1140.14,1023,1149.79,1023,1164.5Zm-17.31,20.78v-3.46H988.48c-5.69,0-9.65,3-9.65,7.54v1.36c0,5.07,4.21,8.29,10.52,8.29C999,1199,1005.67,1193.56,1005.67,1185.28Z' id='path5' /> <path class='cls-1' d='M1109,1121v82.73c0,5.68-2.72,8.9-7.79,8.9s-8-3.22-8.28-8.78v-1.24c-4.83,6.43-12.37,10.14-21.64,10.14-16.7,0-27.7-11.62-27.7-29.06V1169.2c0-17.43,11-29.06,27.7-29.06,8.53,0,15.58,3.1,20.4,8.66V1121c0-5.69,3.09-8.9,8.66-8.9S1109,1115.29,1109,1121Zm-17.31,60.84v-10.76c0-9.52-6.18-16-15.46-16s-15.33,6.43-15.33,16v10.76c0,9.52,6.06,15.83,15.33,15.83S1091.73,1191.34,1091.73,1181.82Z' id='path6' /> <path class='cls-1' d='M1194,1170.19v4.46c0,4.57-2.6,7.17-7.17,7.17h-39.45v1.23c0,9.9,6.06,16.45,15.09,16.45a18.65,18.65,0,0,0,14.22-6.68,7.54,7.54,0,0,1,7.91-1.85c6.06,1.85,7.42,6.8,5.57,9.89-4.45,7.67-15.71,11.87-27.7,11.87-19.42,0-32.4-12-32.4-30v-12.49c0-18,12.74-30,31.9-30S1194,1152.14,1194,1170.19Zm-17.31-.37c0-9.89-5.94-16.44-14.72-16.44s-14.59,6.55-14.59,16.44v.13h29.31Z' id='path7' /> <path class='cls-1' d='M1319.62,1166.11v37.6c0,5.68-3,8.9-8.65,8.9s-8.66-3.22-8.66-8.9v-34.88c0-8.28-5.32-13.72-13.23-13.72s-13.23,5.44-13.23,13.72v34.88c0,5.68-3,8.9-8.66,8.9s-8.65-3.22-8.65-8.9v-34.88c0-8.28-5.32-13.72-13.24-13.72s-13.23,5.44-13.23,13.72v34.88c0,5.68-3,8.9-8.65,8.9s-8.66-3.22-8.66-8.9v-54.54c0-5.69,2.85-8.9,8-8.9s7.91,3.09,8.16,8.65c4.45-5.56,11.38-8.78,19.66-8.78,9.4,0,16.82,4,21.15,10.76,4.82-6.8,12.73-10.76,22.63-10.76C1309.61,1140.14,1319.62,1150.53,1319.62,1166.11Z' id='path8' /> <path class='cls-1' d='M1398.39,1152l-23.25,64.3c-4.7,13.11-14.59,21.64-28.19,21.64-4.33,0-6.93-2.6-6.93-7.17,0-4.21,2.1-6.56,5.94-6.56a12,12,0,0,0,11.37-8l2.35-6.43L1338,1152c-2-5.44-.24-9.53,5.07-11.13s9.28.37,11,5.69l14.71,43,13.48-42.66c1.61-5.57,5.57-7.79,10.88-6.06S1400.24,1146.7,1398.39,1152Z' id='path9' /> <path class='cls-1' d='M825.75,1082a7.35,7.35,0,0,1-2.64-14.22L1197.92,924a7.36,7.36,0,1,1,5.27,13.74L828.38,1081.54A7.16,7.16,0,0,1,825.75,1082Z' id='path10' /><path class='cls-1' d='M1174.62,979.85a7.36,7.36,0,0,1-6-11.53l23.81-34.53c-17.49-5.59-37.81-12.08-39.4-12.53a7.31,7.31,0,0,1-5.23-9,7.4,7.4,0,0,1,9-5.27c1.65.43,35.2,11.17,49.55,15.76a7.35,7.35,0,0,1,3.81,11.18l-29.44,42.69A7.33,7.33,0,0,1,1174.62,979.85Z' id='path11' /><path class='cls-1' d='M895.62,1055.23a7.34,7.34,0,0,1-3.92-1.13,155.94,155.94,0,0,1-73.31-132.65c0-86.37,70.27-156.64,156.64-156.64s156.64,70.27,156.64,156.64a156.87,156.87,0,0,1-5.94,42.86,7.35,7.35,0,0,1-4.44,4.86l-223,85.57A7.25,7.25,0,0,1,895.62,1055.23ZM975,779.52c-78.26,0-141.93,63.67-141.93,141.93a141.27,141.27,0,0,0,63.37,118.22l216.06-82.9a142.32,142.32,0,0,0,4.43-35.32C1117,843.19,1053.29,779.52,975,779.52ZM1118.66,962.3h0Z' id='path12' /><path class='cls-1' d='M941.54,1035.05a7.37,7.37,0,0,1-7.36-7.36V943.06a53.88,53.88,0,0,1,107.75,0v49.21a7.36,7.36,0,1,1-14.71,0V943.06a39.17,39.17,0,0,0-78.33,0v84.63A7.36,7.36,0,0,1,941.54,1035.05Z' id='path13' /><path class='cls-1' d='M988.05,886.13A34.14,34.14,0,1,1,1022.19,852,34.17,34.17,0,0,1,988.05,886.13Zm0-53.55A19.42,19.42,0,1,0,1007.47,852,19.45,19.45,0,0,0,988.05,832.58Z' id='path14' /></svg>";

    type DAOInfo = {
        name : Text;
        manifesto : Text;
        goals : [Text];
        logo : Text;
    };
    public shared query func getStats() : async DAOInfo {
        let info : DAOInfo = {
            name = tknName;
            manifesto = manifesto;
            goals = Buffer.toArray(goals);
            logo = logo;
        };
        return info;
    };

    func _getWebpage() : Text {
        var webpage = "<style>" #
        "body { text-align: center; font-family: Arial, sans-serif; background-color: #f0f8ff; color: #333; }" #
        "h1 { font-size: 3em; margin-bottom: 10px; }" #
        "hr { margin-top: 20px; margin-bottom: 20px; }" #
        "em { font-style: italic; display: block; margin-bottom: 20px; }" #
        "ul { list-style-type: none; padding: 0; }" #
        "li { margin: 10px 0; }" #
        "li:before { content: '👉 '; }" #
        "svg { max-width: 150px; height: auto; display: block; margin: 20px auto; }" #
        "h2 { text-decoration: underline; }" #
        "</style>";

        webpage := webpage # "<div><h1>" # tknName # "</h1></div>";
        webpage := webpage # "<em>" # manifesto # "</em>";
        webpage := webpage # "<div>" # logo # "</div>";
        webpage := webpage # "<hr>";
        webpage := webpage # "<h2>Our goals:</h2>";
        webpage := webpage # "<ul>";
        for (goal in goals.vals()) {
            webpage := webpage # "<li>" # goal # "</li>";
        };
        webpage := webpage # "</ul>";
        return webpage;
    };
    public query func http_request(request : Http.Request) : async Http.Response {
        let response = {
            body = Text.encodeUtf8("Hello world");
            headers = [("Content-Type", "text/html; charset=UTF-8")];
            status_code = 200 : Nat16;
            streaming_strategy = null;
        };
        return (response);
    };
};
