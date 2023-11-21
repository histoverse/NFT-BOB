#!/bin/sh

dfx canister uninstall-code icp_courses
dfx canister stop icp_courses
dfx canister delete icp_courses

dfx deploy icp_courses --argument "(\"bkyz2-fmaaa-aaaaa-qaaaq-cai\", principal \"32yk2-hflnj-4yibm-x5js4-cy3gz-cttjz-3vrqn-y7owk-p2dkg-cfkfi-yqe\", record { logo = record {logo_type = \"image/png\"; data = \"$(base64 -i ./logo.png)\";}; name = \"Immortal Collection\"; symbol = \"IMRT\";})"
dfx canister call icp_courses setPrice "(40000)"
dfx canister call icp_courses mint "(vec {record {purpose = variant{Rendered}; data = blob\"history course\"; key_val_data = vec {record { key = \"description\"; val = variant{TextContent=\"The NFT metadata can hold arbitrary metadata\"}; }; record { key = \"tag\"; val = variant{TextContent=\"learn\"}; }; record { key = \"contentType\"; val = variant{TextContent=\"text/plain\"}; }; record { key = \"locationType\"; val = variant{Nat8Content=4:nat8} };}}})"
dfx canister call icp_ledger_canister icrc1_transfer "(record {to = record {owner = principal \"$(dfx canister id icp_courses)\";}; amount = 40000;})"
dfx canister call icp_courses buy "(principal \"$(dfx identity get-principal)\", 0, 1)"
