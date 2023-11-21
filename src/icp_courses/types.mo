import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import List "mo:base/List";
import Array "mo:base/Array";

module {
  public type NonFungibleToken = {
    logo: LogoResult;
    name: Text;
    symbol: Text;
    // maxLimit : Nat16;
  };

  public type ApiError = {
    #Unauthorized;
    #InvalidTokenId;
    #ZeroAddress;
    #Other;
    #IcpTransfer;
  };

  public type Result<S, E> = {
    #Ok : S;
    #Err : E;
  };

  public type OwnerResult = Result<List.List<Principal>, ApiError>;
  public type TxReceipt = Result<Nat, ApiError>;
  
  public type TransactionId = Nat;
  public type TokenId = Nat64;

  public type InterfaceId = {
    #Approval;
    #TransactionHistory;
    #Mint;
    #Burn;
    #TransferNotification;
  };

  public type LogoResult = {
    logo_type: Text;
    data: Text;
  };

  public type Nft = {
    holders: List.List<Principal>;
    id: TokenId;
    metadata: MetadataDesc;
  };

  public type ExtendedMetadataResult = Result<{
    metadata_desc: MetadataDesc;
    token_id: TokenId;
  }, ApiError>;

  public type MetadataResult = Result<MetadataDesc, ApiError>;

  public type MetadataDesc = [MetadataPart];

  public type MetadataPart = {
    purpose: MetadataPurpose;
    key_val_data: [MetadataKeyVal];
    data: Blob;
  };

  public type MetadataPurpose = {
    #Preview;
    #Rendered;
  };
  
  public type MetadataKeyVal = {
    key: Text;
    val: MetadataVal;
  };

  public type MetadataVal = {
    #TextContent : Text;
    #BlobContent : Blob;
    #NatContent : Nat;
    #Nat8Content: Nat8;
    #Nat16Content: Nat16;
    #Nat32Content: Nat32;
    #Nat64Content: Nat64;
  };

  public type MintReceipt = Result<MintReceiptPart, ApiError>;

  public type MintReceiptPart = {
    token_id: TokenId;
    id: Nat;
  };

  // ICP token canister interface
  public type Account = { owner : Principal; subaccount : ?[Nat8] };
  public type GetBlocksArgs = { start : Nat64; length : Nat64 };
  public type TimeStamp = { timestamp_nanos : Nat64 };
  public type Tokens = { e8s : Nat64 };
  public type Result_5 = { #Ok : Nat64; #Err : TransferError_1 };
  public type Result_3 = { #Ok : BlockRange; #Err : GetBlocksError };
  public type BlockRange = { blocks : [CandidBlock] };
  public type TransferError_1 = {
    #TxTooOld : { allowed_window_nanos : Nat64 };
    #BadFee : { expected_fee : Tokens };
    #TxDuplicate : { duplicate_of : Nat64 };
    #TxCreatedInFuture;
    #InsufficientFunds : { balance : Tokens };
  };
  public type GetBlocksError = {
    #BadFirstBlockIndex : {
      requested_index : Nat64;
      first_valid_index : Nat64;
    };
    #Other : { error_message : Text; error_code : Nat64 };
  };

  public type TransferArgs = {
    to : [Nat8];
    fee : Tokens;
    memo : Nat64;
    // from_subaccount : ?[Nat8];
    // created_at_time : ?TimeStamp;
    amount : Tokens;
  };
  public type QueryBlocksResponse = {
    // certificate : ?[Nat8];
    blocks : [CandidBlock];
    chain_length : Nat64;
    first_block_index : Nat64;
    archived_blocks : [ArchivedBlocksRange];
  };
  public type CandidBlock = {
    transaction : CandidTransaction;
    timestamp : TimeStamp;
    parent_hash : ?[Nat8];
  };
  public type ArchivedBlocksRange = {
    callback : shared query GetBlocksArgs -> async Result_3;
    start : Nat64;
    length : Nat64;
  };
  public type CandidTransaction = {
    memo : Nat64;
    icrc1_memo : ?[Nat8];
    operation : ?CandidOperation;
    created_at_time : TimeStamp;
  };
  public type CandidOperation = {
    #Approve : {
      fee : Tokens;
      from : [Nat8];
      allowance_e8s : Int;
      allowance : Tokens;
      expected_allowance : ?Tokens;
      expires_at : ?TimeStamp;
      spender : [Nat8];
    };
    #Burn : { from : [Nat8]; amount : Tokens; spender : ?[Nat8] };
    #Mint : { to : [Nat8]; amount : Tokens };
    #Transfer : {
      to : [Nat8];
      fee : Tokens;
      from : [Nat8];
      amount : Tokens;
      spender : ?[Nat8];
    };
  };

  public type BinaryAccountBalanceArgs = { account : [Nat8] };

  public type ExtTokenActor = actor {
    transfer : shared TransferArgs -> async Result_5;
    account_balance : shared query BinaryAccountBalanceArgs -> async Tokens;
    account_identifier : shared query Account -> async [Nat8];
    query_blocks : shared query GetBlocksArgs -> async QueryBlocksResponse;
  };
};
