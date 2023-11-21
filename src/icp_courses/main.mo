import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import List "mo:base/List";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Bool "mo:base/Bool";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Error "mo:base/Error";
import Types "./types";
import Account "./account";

shared actor class NFT(icp_token_canister: Text, custodian: Principal, init : Types.NonFungibleToken) = Self {
  stable var transactionId: Types.TransactionId = 0;
  private var nfts = List.nil<Types.Nft>();
  private var usedIds = List.nil<Nat64>();
  stable var custodians = List.make<Principal>(custodian);
  stable var _logo : Types.LogoResult = init.logo;
  stable var _name : Text = init.name;
  stable var _symbol : Text = init.symbol;
  stable var _price : Nat64 = 0;

  // https://forum.dfinity.org/t/is-there-any-address-0-equivalent-at-dfinity-motoko/5445/3
  let null_address : Principal = Principal.fromText("aaaaa-aa");

  public query func getPrice() : async Nat64 {
    return _price;
  };

  public query func balanceOf(user: Principal, token_id: Types.TokenId) : async Nat64 {
    let item = List.find(nfts, func(token: Types.Nft) : Bool { token.id == token_id });
    switch (item) {
      case (null) {
        return 0;
      };
      case (?token) {
        return Nat64.fromNat(
          List.size(
            List.filter(token.holders, func(holder: Principal) : Bool { holder == user })
          )
        );
      };
    };
  };

  public query func ownerOf(token_id: Types.TokenId) : async Types.OwnerResult {
    let item = List.find(nfts, func(token: Types.Nft) : Bool { token.id == token_id });
    switch (item) {
      case (null) {
        return #Err(#InvalidTokenId);
      };
      case (?token) {
        return #Ok(token.holders);
      };
    };
  };

  public shared({ caller }) func safeTransferFrom(from: Principal, to: Principal, token_id: Types.TokenId) : async Types.TxReceipt {  
    if (to == null_address) {
      return #Err(#ZeroAddress);
    } else {
      return _transferFrom(from, to, token_id, caller);
    };
  };

  public shared({ caller }) func transferFrom(from: Principal, to: Principal, token_id: Types.TokenId) : async Types.TxReceipt {
    return _transferFrom(from, to, token_id, caller);
  };

  func _transferFrom(from: Principal, to: Principal, token_id: Types.TokenId, caller: Principal) : Types.TxReceipt {
    let item = List.find(nfts, func(token: Types.Nft) : Bool { token.id == token_id });
    switch (item) {
      case null {
        return #Err(#InvalidTokenId);
      };
      case (?token) {
        let fromHolder = List.find(token.holders, func(holder: Principal) : Bool {from == holder});
        switch (fromHolder) {
          case null {
            return #Err(#Other);
          };
          case (?holder) {
            if(Principal.notEqual(from, caller) and not List.some(custodians, func (custodian : Principal) : Bool { custodian == caller })) {
              return #Err(#Unauthorized);
            };
            nfts := List.map(nfts, func (item : Types.Nft) : Types.Nft {
              if (item.id == token.id) {
                var flag : Bool = false;
                let update : Types.Nft = {
                  holders = List.map(item.holders, func (holder : Principal) : Principal {
                    if(Principal.equal(holder, from) and not flag) {
                      flag := true;
                      return to;
                    } else {
                      return holder;
                    };
                  });
                  id = item.id;
                  metadata = token.metadata;
                };
                return update;
              } else {
                return item;
              };
            });
            transactionId += 1;
            return #Ok(transactionId);
            };
          };
        };
      };
    };


  public query func supportedInterfaces() : async [Types.InterfaceId] {
    return [#TransferNotification, #Burn, #Mint];
  };

  public query func logo() : async Types.LogoResult {
    return _logo;
  };

  public query func name() : async Text {
    return _name;
  };

  public query func symbol() : async Text {
    return _symbol;
  };

  public query func totalSupply() : async Nat64 {
    return Nat64.fromNat(
      List.size(nfts)
    );
  };

  public query func getMetadata(token_id: Types.TokenId) : async Types.MetadataResult {
    let item = List.find(nfts, func(token: Types.Nft) : Bool { token.id == token_id });
    switch (item) {
      case null {
        return #Err(#InvalidTokenId);
      };
      case (?token) {
        return #Ok(token.metadata);
      }
    };
  };

  public func getMetadataForUser(user: Principal) : async Types.ExtendedMetadataResult {
    let item = List.find(nfts, func(token: Types.Nft) : Bool { 
      /* token.owner == user */
      let holder = List.find(token.holders, func(holder: Principal) : Bool {user == holder});
      switch (holder) {
        case null {
          return false;
        };
        case (?owner) {
          return true;
        };
      };
    });
    switch (item) {
      case null {
        return #Err(#Other);
      };
      case (?token) {
        return #Ok({
          metadata_desc = token.metadata;
          token_id = token.id;
        });
      }
    };
  };

  public query func getTokenIdsForUser(user: Principal) : async [Types.TokenId] {
    let items = List.filter(nfts, func(token: Types.Nft) : Bool { 
      /* token.owner == user */
      let holder = List.find(token.holders, func(holder: Principal) : Bool {user == holder});
      switch (holder) {
        case null {
          return false;
        };
        case (?owner) {
          return true;
        };
      };
    });
    let tokenIds = List.map(items, func (item : Types.Nft) : Types.TokenId { item.id });
    return List.toArray(tokenIds);
  };

  public shared({ caller }) func mint(metadata: Types.MetadataDesc) : async Types.MintReceipt {
    if (not List.some(custodians, func (custodian : Principal) : Bool { custodian == caller })) {
      return #Err(#Unauthorized);
    };

    let newId = Nat64.fromNat(List.size(nfts));
    let nft : Types.Nft = {
      holders = List.nil<Principal>();
      id = newId;
      metadata = metadata;
    };

    nfts := List.push(nft, nfts);

    transactionId += 1;

    return #Ok({
      token_id = newId;
      id = transactionId;
    });
  };

  public shared({caller}) func setPrice(price: Nat64) : async Types.TxReceipt {
    if (not List.some(custodians, func (custodian : Principal) : Bool { custodian == caller })) {
      return #Err(#Unauthorized);
    };
    if (price <= 10000) {return #Err(#Other)};
    _price := price;
    transactionId += 1;
    return #Ok(transactionId);
  };

  public shared({caller}) func withdrawPayments() : async Types.TxReceipt {
    if (not List.some(custodians, func (custodian : Principal) : Bool { custodian == caller })) {
      return #Err(#Unauthorized);
    };
    let tokenAdapter : Types.ExtTokenActor = actor(icp_token_canister);
    let accArg : Types.Account = {owner = Principal.fromActor(Self); subaccount = ?Blob.toArray(Account.defaultSubaccount());};
    let accountArg : Types.BinaryAccountBalanceArgs = {
      account = await tokenAdapter.account_identifier(accArg);//Blob.toArray(Principal.toBlob(Principal.fromActor(Self)));
    };
    let amount = await tokenAdapter.account_balance(accountArg);
    if (amount.e8s > 10000) {
      let feeArg : Types.Tokens = {
        e8s = 10000;
      };
      let amountArg : Types.Tokens = {
        e8s = amount.e8s - feeArg.e8s;
      };
      let timeArg : Types.TimeStamp = {
        timestamp_nanos = Nat64.fromIntWrap(Time.now());
      };
      let accArg : Types.Account = {owner = caller; subaccount = ?Blob.toArray(Account.defaultSubaccount());};
      let args : Types.TransferArgs = {
        to = await tokenAdapter.account_identifier(accArg);//Blob.toArray(Principal.toBlob(caller));
        fee = feeArg;
        memo = 0;
        from_subaccount = null;
        created_at_time = ?timeArg;
        amount = amountArg;
      };
      switch (await tokenAdapter.transfer(args)) {
        case (#Ok(_)) {
          transactionId += 1;
          return #Ok(transactionId);
        };
        case (#Err(code)) {
          return #Err(#IcpTransfer);
        };
      };
    } else {
      return #Err(#Other);
    };
  };

  public shared({caller}) func buy(token_id: Types.TokenId, transfer_id: Nat64) : async Types.TxReceipt {
    let item = List.find(nfts, func(token: Types.Nft) : Bool { token.id == token_id });
    switch (item) {
      case null {
        return #Err(#InvalidTokenId);
      };
      case (?token) {
        let tokenAdapter : Types.ExtTokenActor = actor(icp_token_canister);

        var accArg : Types.Account = {owner = Principal.fromActor(Self); subaccount = ?Blob.toArray(Account.defaultSubaccount());};
        let toArg : [Nat8] = await tokenAdapter.account_identifier(accArg);
        accArg := {owner = caller; subaccount = ?Blob.toArray(Account.defaultSubaccount());};
        let fromArg : [Nat8] = await tokenAdapter.account_identifier(accArg);
        let blockResponse = await tokenAdapter.query_blocks({start = transfer_id; length = 1;});
        let blocksList = List.fromArray(blockResponse.blocks);

        // Return error if it is empty blocks, operation.
        if (List.isNil(blocksList)) {
          return #Err(#IcpTransfer);
        } else {
          let blockOp = List.get(blocksList, 0);
          let block = switch (blockOp) {
            case null return #Err(#IcpTransfer);
            case (?myBlock) {
              switch (myBlock.transaction.operation) {
                case (?#Transfer(info)) {
                  if(info.to == toArg and info.from == fromArg and info.amount.e8s >= _price) {
                    let txnId = List.find(usedIds, func(id: Nat64) : Bool { id == transfer_id} );
                    switch (txnId) {
                      case (?foundedId) return #Err(#IcpTransfer);
                      case null {
                        usedIds := List.push(transfer_id, usedIds);
                        nfts := List.map(nfts, func (item : Types.Nft) : Types.Nft {
                          if (item.id == token.id) {
                            let update : Types.Nft = {
                              holders = List.push(caller, item.holders);
                              id = item.id;
                              metadata = token.metadata;
                            };
                            return update;
                          } else {
                            return item;
                          };
                        });
                        transactionId += 1;
                        return #Ok(transactionId);
                      };
                    };
                  } else {
                    return #Err(#IcpTransfer);
                  };
                };
                case (null or ?#Approve(_) or ?#Burn(_) or ?#Mint(_)) return #Err(#IcpTransfer);
              };
            };
          };
        };  
      };
    };
  };
}
