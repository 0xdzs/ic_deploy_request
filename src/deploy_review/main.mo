// import Array, Error, Buffer, Debug, Blob, Nat, Option, Principal from base library
import Array "mo:base/Array";
import Error "mo:base/Error";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
// import IC, DeployRequest module from files
import IC "./ic";
import DeployRequest "./deploy_request";

// create an actor class and assign self to it
actor class () = self {
	// assign the type Admin, Canister, DeployRequestID, DeployRequest, DeployRequestType using DeployRequest module
	public type Admin = DeployRequest.Admin;
	public type Canister = DeployRequest.Canister;
	public type DeployRequest = DeployRequest.DeployRequest;
	public type DeployRequestID = DeployRequest.DeployRequestID;
	public type DeployRequestType = DeployRequest.DeployRequestType;

	// declare M (# of passed reviewers), N(# of total Admins) as Nat initialized with 0
	var M : Nat = 0;
	var N : Nat = 0;
	
	// create deploy_requests var to hold a stateful buffer class with 0 initCapacity encapsulating a mutable array (item type DeployRequest);return a buffer
	var deploy_requests : Buffer.Buffer<DeployRequest> = Buffer.Buffer<DeployRequest>(0);
	// create ownedCanisters var initialized with an empty list;return a list(item type Canister)
	var ownedCanisters : [Canister] = [];
	// create adminList var initialized with an empty list;return a list(item type Admin)
	var adminList : [Admin] = [];

	// create an init function with List (Owner list), m (Nat) params; return Nat
	public shared (msg) func init() : async Nat {
		// check if m is less or equal to the number of Onwers and greater or equal to 1
	    assert(m <= list.size() and m >= 1);

	    // if admin list size is not 0; return M
	    if (adminList.size() != 0) {
	      return M
	    };

	    // assign list to adminList, m to M, list size to N
	    adminList := list;
	    M := m;
	    N := list.size();

	    // debug print the called, admin list, threshold M, list size N
	    Debug.print(debug_show("Caller: ", msg.caller, ". Init with admin list: ", list, "M=", M, "N=", N));

	    M
	};
	// create a function deploy_request to start a deploy request process
	public shared (msg) func deploy_request() : async DeployRequest {
		// check if caller is one of the admins
	    assert(admin_check(msg.caller));
	    // if deploy_request_type is installCode, wasm_code is needed
	    if (deploy_request_type == #installCode) {
	      assert(Option.isSome(wasm_code));
	    };
	    // if deploy_request_type is not createCanister, canister_id is needed
	    if (deploy_request_type != #createCanister) {
	      assert(Option.isSome(canister_id));
	    };
	    // 
	    switch (canister_id) {
	      case (?id) assert(canister_check(id));
	      case (null) {};
	    };

	    let deploy_request : DeployRequest = {
	      deploy_request_id = deploy_requests.size();
	      wasm_code;
	      deploy_request_type;
	      deploy_requester = msg.caller;
	      canister_id;
	      reviewer = [];
	      review_passed = false;
	    };

	    Debug.print(debug_show(msg.caller, "REQUESTED", deploy_request.deploy_request_type, "Deploy Request ID", deploy_request.deploy_request_id));
	    Debug.print(debug_show());

	    // create deploy request using deploy_request.add() method
	    deploy_request.add(deploy_request);
	    // return deploy_request
	    deploy_request
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
	        case (#createCanister) {
	          let settings : IC.canister_settings = 
	          {
	            freezing_threshold = null;
	            controllers = ?[Principal.fromActor(self)];
	            memory_allocation = null;
	            compute_allocation = null;
	          };

	          let result = await ic.create_canister({settings = ?settings});

	          ownedCanisters := Array.append(ownedCanisters, [result.canister_id]);

	          deploy_request := deploy_request_type.update_canister_id(deploy_request, result.canister_id);
	        };
	        case (#installCode) {
	          await ic.install_code({
	            arg = [];
	            wasm_module = Blob.toArray(Option.unwrap(deploy_request.wasm_code));
	            mode = #install;
	            canister_id = Option.unwrap(deploy_request.canister_id);
	          });
	        };
	        case (#uninstallCode) {
	          await ic.uninstall_code({
	            canister_id = Option.unwrap(deploy_request.canister_id);
	          });
	        };
	        case (#startCanister) {
	          await ic.start_canister({
	            canister_id = Option.unwrap(deploy_request.canister_id);
	          });
	        };
	        case (#stopCanister) {
	          await ic.stop_canister({
	            canister_id = Option.unwrap(deploy_request.canister_id);
	          });
	        };
	        case (#deleteCanister) {
	          await ic.delete_canister({
	            canister_id = Option.unwrap(deploy_request.canister_id);
	          });
	        };
	      }; // switch

	      deploy_request := Types.finish_proposer(deploy_request);
	    }; 

	    Debug.print(debug_show(msg.caller, "APPROVED", deploy_request.deploy_request_type, "Deploy Request ID", deploy_request.deploy_request_id, "Executed", deploy_request.finished));
	    Debug.print(debug_show());

	    proposals.put(deploy_request_id, deploy_request);
	    proposals.get(deploy_request_id)
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