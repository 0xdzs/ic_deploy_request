// deploy_request.mo define types and deploy request related functions
// import Array, Blob, Principal from base library
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Hash "mo:base/Hash";
import Principal "mo:base/Principal";

// create a module to group definitions (including types) and create a name space for them
module {
	// define the type of Admin, Canister as Principal
	public type Admin = Principal;
	public type Canister = Principal;
	public type Hash = Hash.Hash;
	// define the type of DeployRequestID as Nat
	public type DeployRequestID = Nat;
	// create DeployRequest type with relevant deploy request info
	public type DeployRequest = {
		deploy_request_id: DeployRequestID;
		deploy_requester: Admin;
		wasm_code:  ?Blob; 
		wasm_code_hash:  [Nat8]; 
		deploy_request_type: DeployRequestType;
		canister_id:  ?Canister; 
		reviewers: [Admin];
		rejecters: [Admin];
		review_passed: Bool;
	};
	// define DeployRequestType with install/uninstall/create/start/stop/delete canisters 
	// using enumerated types to define basic enumerations, for which no payloads are required
	public type DeployRequestType = {
		#addPermission;
		#removePermissi
		#installCode;
		#upgradeCode;
		#uninstallCode;
		#createCanister;
		#startCanister;
		#stopCanister;
		#deleteCanister;
		#addMember;
	};

	public type CanisterStatus = { #stopped; #stopping; #running };
	// create a function pass_review to end the review process
	public func pass_review(r: DeployRequest) : DeployRequest {
		{
			deploy_request_id = r.deploy_request_id;
			deploy_requester = r.deploy_requester;
			wasm_code = r.wasm_code;
			wasm_code_hash = r.wasm_code_hash;
			deploy_request_type = r.deploy_request_type;
			canister_id = r.canister_id;
			reviewers = r.reviewers;
			rejecters = r.rejecters;
			review_passed = true;
  		}
	};
	// create a function add_reviewer to add a reviewer to the deploy request
	public func add_reviewer(r: DeployRequest, reviewer: Admin) : DeployRequest {
		{
			deploy_request_id = r.deploy_request_id;
			deploy_requester = r.deploy_requester;
			wasm_code = r.wasm_code;
			deploy_request_type = r.deploy_request_type;
			canister_id = r.canister_id;
			reviewers = Array.append(r.reviewers, [reviewer]);
			rejecters = r.rejecters;
			review_passed = r.review_passed;
  		}
	};
	public func add_rejecter(r : DeployRequest, rejecter: Admin) : DeployRequest {
		{
			deploy_request_id = r.deploy_request_id;
			deploy_requester = r.deploy_requester;
			wasm_code = r.wasm_code;
			wasm_code_hash = r.wasm_code_hash;
			deploy_request_type = r.deploy_request_type;
			canister_id = r.canister_id;
			reviewers = r.reviewers;
			rejecters = Array.append(r.rejecters, [rejecter]);
			review_passed = r.review_passed;
  		}
	};
	// create a function update_canister_id to update canister id to the proposal
	public func update_canister_id(r: DeployRequest, c_id: Canister) : DeployRequest {
		{
			deploy_request_id = r.deploy_request_id;
			deploy_requester = r.deploy_requester;
			wasm_code = r.wasm_code;
			wasm_code_hash = r.wasm_code_hash;
			deploy_request_type = r.deploy_request_type;
			canister_id = ?c_id;
			reviewers = r.reviewers;
			rejecters = r.rejecters;
			review_passed = true;
  		}
	};

}