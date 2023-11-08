import Buffer "mo:base/Buffer";

actor {
    let name : Text = "MOKTO-DAO";
    private var manifesto : Text = "DEMO for MotokoBootcamp";
    let goals = Buffer.Buffer<Text>(10);

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
};
