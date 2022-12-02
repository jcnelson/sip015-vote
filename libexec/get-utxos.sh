#!/bin/bash

###########################################################################################
#
# This is a script for getting the UTXOs for "yes" and "no" votes for SIP-015
#
###########################################################################################

usage() {
   echo >&1 "Usage: $0 /path/to/bitcoin.conf"
   exit 1
}

if ! command -v "jq" >/dev/null 2>&1; then
   echo >&1 "Missing 'jq' program"
   exit 1
fi

if [ "$1" = "help" ] || [ -z "$1" ]; then
   usage
fi

BITCOIN_CONF="$1"

YES_ADDR="11111111111111X6zHB1ZC2FmtnqJ"
NO_ADDR="1111111111111117CrbcZgemVNFx8"

set -oue pipefail

bitcoin_cli() {
   # Run bitcoin-cli with default settings
   #
   # $@: bitcoin-cli args
   # stdin: none
   # stdout: bitcoin-cli command output
   # stderr: bitcoin-cli error message
   # return: 0 on success, nonzero on error
   bitcoin-cli -conf="$BITCOIN_CONF" "$@"
}

get_utxos() {
   # Get the UTXOs for an address
   #
   # $1: Bitcoin address
   # stdin: none
   # stdout: JSON-encoded unspents from the address
   # stderr: bitcoin-cli error message
   # return: 0 on success, nonzero on error
   local address="$1"
   bitcoin_cli listunspent 0 1000000 "[\"$address\"]"
}

get_transactions() {
   # Get transactions for a given list of UTXOs
   #
   # (no args)
   # stdin: newline-separated txids
   # stdout: a JSON list of decoded Bitcoin transactions
   # stderr: bitcoin-cli error message
   # return: 0 on success, non-zero on error
   local txid
   local next_txid

   echo '['

   read -r txid || true
   if [ -z "$txid" ]; then
      echo ']'
      return 0
   fi

   while true; do
      read -r next_txid || true
      bitcoin_cli getrawtransaction "$txid" 1
      if [ -z "$next_txid" ]; then
         break
      fi
      txid="$next_txid"
      echo ','
   done
   echo ']'
   return 0
}

get_vote_address_transactions() {
   # Get the transactions for a vote address
   #
   # $1: the vote address
   # stdin: none
   # stdout: a JSON list of decoded Bitcoin transactions
   # stderr: bitcoin-cli error message
   # return: 0 on success, non-zero on error
   local address="$1"
   get_utxos "$address" | jq -r ".[].txid" | get_transactions
}

main() {
   # Get "yes" and "no" votes
   #
   # stdin: none
   # stdout: a JSON object with two keys, "yes" and "no", which map to lists of decoded Bitcoin transactions
   # stderr: bitcoin-cli error message
   # return: 0 on success, non-zero on error
   echo '{'
   echo '"yes":'
   get_vote_address_transactions "$YES_ADDR"
   echo ','
   echo '"no":'
   get_vote_address_transactions "$NO_ADDR"
   echo '}'
}

main | jq .

