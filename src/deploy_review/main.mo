// import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Principal "mo:base/Principal";

import Array, Error, Buffer, Debug, Blob, Nat, Option, Principal from base library
import DeployRequest "./deploy_request";
import SHA256 "mo:sha256/SHA256";
import IC "./ic";
import IC, DeployRequest module from files

// create an actor class and assign self to it
actor class cycle_manager(m : Nat, list : [DeployRequest.Admin]) = self {
	// assign the type Admin, Canister, DeployRequestID, DeployRequest, DeployRequestType using DeployRequest module
	public type Admin = DeployRequest.Admin;
	public type Canister = DeployRequest.Canister;
	public type DeployRequest = DeployRequest.DeployRequest;
	public type DeployRequestID = DeployRequest.DeployRequestID;
	public type DeployRequestType = DeployRequest.DeployRequestType;
	
	// create deploy_requests var to hold a stateful buffer class with 0 initCapacity encapsulating a mutable array (item type DeployRequest);return a buffer
	var deploy_requests : Buffer.Buffer<DeployRequest> = Buffer.Buffer<DeployRequest>(0);
	// create ownedCanisters var initialized with an empty list;return a list(item type Canister)
	var ownedCanisters : [Canister] = [];
	// create canisters var initialized with an empty list;return a list(item type Canister)
  	var CanisterPermissions : HashMap.HashMap<Canister, Bool> = HashMap.HashMap<Canister, Bool>(0, func(x: Canister,y: Canister) {x==y}, Principal.hash);
  	var adminList : [Admin] = list;
  	var M : Nat = m;
  	var N : Nat = adminList.size();
	public func greet(name: Text) : async Text {
		// return a Text
		return "Hello, " # name # "!";
	};
	
	// create a function deploy_request to start a deploy request process
	public shared (msg) func deploy_request() : async DeployRequest {
		// check if caller is one of the admins
	    assert(admin_check(msg.caller));

		// only the canister that (permission = false) can add permission
		if (deploy_request_type == #addPermission) {
		assert(CanisterPermissions.get(Option.unwrap(canister_id)) == ?false);
		// only the canister that (permission = true) can remove permission
		if (deploy_request_type == #removePermission) {
    	  assert(canisterPermissions.get(Option.unwrap(canister_id)) == ?true);
    	};
    	var wasm_code_hash : [Nat8] = [];
    	if (deploy_request_type == #installCode) {
    	  assert(Option.isSome(wasm_code));
    	  wasm_code_hash := SHA256.sha256(Blob.toArray(Option.unwrap(wasm_code)));
    	};
    	if (deploy_request_type == #upgradeCode) {
    	  assert(Option.isSome(wasm_code));
    	  wasm_code_hash := SHA256.sha256(Blob.toArray(Option.unwrap(wasm_code)));
    	};

	    // if deploy_request_type is not createCanister, canister_id is needed
	    if (deploy_request_type != #createCanister) {
	      assert(Option.isSome(canister_id));
	    };
	    
	    switch (canister_id) {
	      case (?id) assert(canister_check(id));
	      case (null) {};
	    };

	    let deploy_request : DeployRequest = {
	      deploy_request_id = deploy_requests.size();
	      wasm_code;
		  wasm_code_hash;
	      deploy_request_type;
	      deploy_requester = msg.caller;
	      canister_id;
	      reviewer = [];
		  rejecters = []
	      review_passed = false;
	    };

	    Debug.print(debug_show(msg.caller, "REQUESTED", deploy_request.deploy_request_type, "Deploy Request ID", deploy_request.deploy_request_id));
	    Debug.print(debug_show());

	    // create deploy request using deploy_request.add() method
	    deploy_request.add(deploy_request);
	    // return deploy_request
	    deploy_request
	};
	func is_canister_ops_need_no_permission(r: DeployRequest) : Bool {
    Option.isSome(r.canister_id) and canisterPermissions.get(Option.unwrap(r.canister_id)) == ?false
      and r.deploy_request_type != #addPermission and r.deploy_request != #removePermission and r.deploy_request != #createCanister
  	};
	// create a function review for deploy request review; with deploy request id as param
	public shared (msg) func review(deploy_request_id: DeployRequestID) : async DeployRequest {
		// caller should be one of the admins
	    assert(admin_check(msg.caller));

	    assert(id + 1 <= deploy_requests.size());

	    var deploy_request = deploy_requests.get(id);

	    assert(not deploy_request.finished);

	    assert(Option.isNull(Array.find(deploy_request.reviewers, func(a: Admin) : Bool { a == msg.caller})));

	    deploy_request := DeployRequest.add_reviewer(deploy_request, msg.caller);

	    // if the number of reviewers meet the threashhold, do the operation
	    if (deploy_request.reviewers.size() == M) { 
	      let ic : IC.Self = actor("aaaaa-aa");

	      switch (deploy_request.deploy_request_type) {
			case (#addPermission) {
			ownedCanisterPermissions.put(Option.unwrap(deploy_request.canister_id), true);
			};
			case (#removePermission) {
			ownedCanisterPermissions.put(Option.unwrap(deploy_request.canister_id), false);
			};
	        case (#createCanister) {
	          let settings : IC.canister_settings = 
	          {
	            freezing_threshold = null;
	            controllers = ?[Principal.fromActor(self)];
	            memory_allocation = null;
	            compute_allocation = null;
				Cycles.add(1_000_000_000_000);
	          };

	          let result = await ic.create_canister({settings = ?settings});

	          ownedCanisters := Array.append(ownedCanisters, [result.canister_id]);
			  ownedCanisterPermissions.put(result.canister_id, true);
	          deploy_request := deploy_request_type.update_canister_id(deploy_request, result.canister_id);
	        };

	      deploy_request := DeployRequest.finish_proposer(deploy_request);
	    }; 

	    Debug.print(debug_show(msg.caller, "APPROVED", deploy_request.deploy_request_type, "Deploy Request ID", deploy_request.deploy_request_id, "Executed", deploy_request.finished));
	    Debug.print(debug_show());

	    deploy_requests.put(deploy_request_id, deploy_request);
	    deploy_requests.get(deploy_request_id)
	};
	public shared (msg) func reject(deploy_request_id: DeployRequestID) : async DeployRequest {
		// caller should be one of the owners
		assert(admin_check(msg.caller));
		assert(deploy_request_id + 1 <= deploy_requests.size());
		var deploy_request = deploy_requests.get(deploy_request_id);
		assert(not deploy_request.finished);
		assert(Option.isNull(Array.find(deploy_request.rejecters, func(a: Owner) : Bool { a == msg.caller})));
		deploy_request := DeployRequest.add_refuser(deploy_request, msg.caller);
		if (proposal.rejecters.size() + M > N or is_canister_ops_need_no_permission(deploy_request)) {
      		proposal := DeployRequest.pass_review(deploy_request);
    	};
		Debug.print(debug_show(msg.caller, "REJECTED", deploy_request.deploy_request_type, "Deploy Request ID", deploy_request.deploy_request_id, "Executed", deploy_request.review_passed));
		Debug.print(debug_show());
		deploy_requests.put(deploy_request_id, deploy_request);
		deploy_requests.get(deploy_request_id)
  	};
	// create a funciton get_deploy_request (param deploy_request_id) to get i-th element of the buffer as an option with deploy_requests.getOpt() method
	public query func get_deploy_request(deploy_request_id: DeployRequestID) : async ?DeployRequest {
		deploy_requests.getOpt(deploy_request_id);
	};
	// create a function admin_check to check if the user is part of Admins
	func admin_check(admin: Admin) : Bool {
		Option.isSome(Array.find(adminList, func (a: Admin) : Bool { Principal.equal(a, Admin) }))
	};
	// create a function canister_check to check if the canister is owned by the user
	func canister_check(canister: Canister) : Bool {
		Option.isSome(Array.find(ownedCanisters, func (a: Canister) : Bool { Principal.equal(a, canister) }))
	};
	// create a function get_admin_list to get of list of Admins
	public query func get_admin_list() : async [Admin] {
		adminList
	};
	// create a function get_owned_canisters_list to get of list of owned casniters
	public query func get_owned_canisters_list() : async [Canister] {
		ownedCanisters
	};
}