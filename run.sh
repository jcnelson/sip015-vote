#!/bin/bash

DATA="./data"
LIBEXEC="./libexec"
START_RC=33
END_RC=47

VOTE_RC_1=46
VOTE_RC_2=47

PROGNAME="$0"

set -oue pipefail

error_exit() {
   echo >&2 "$@" 
   exit 1
}

usage() {
   error_exit "Usage: $PROGNAME /path/to/bitcoin.conf /path/to/chainstate/root"
}

debug() {
   echo >&2 "$@"
}

check_deps() {
   # Check that all dependencies are in place
   # 
   # stdin: none,
   # stdout: none
   # stderr: none
   # return: 0 on success; exit on error
   local cmd=""
   for cmd in jq stacks-inspect grep; do
      if ! command -v "$cmd" >/dev/null; then 
         error_exit "Missing command $cmd"
      fi
   done

   # stacks-inspect must support `dump-txs`
   if [ -z "$(stacks-inspect dump-txs 2>&1 | grep 'dump-txs')" ]; then
      error_exit "stacks-inspect does not appear to support dump-txs"
   fi

   return 0;
}

get_tx_dumps() {
   # Get all transactions for each reward cycle
   #
   # $1: chainstate root
   # stdin: none
   # stdout: none
   # stderr: lots of diagnostics
   # return: 0 on success, non-zero on error

   local rc
   local cycle_path
   local chainstate_root="$1"
   if ! [ -d "$chainstate_root" ]; then
      usage
   fi

   for rc in $(seq $START_RC $END_RC); do
      cycle_path="$DATA/cycle-$rc.json"
      if [ -f "$cycle_path" ]; then
         continue;
      fi

      debug "Fetching reward cycle data for reward cycle $rc"
      RUST_BACKTRACE=full BLOCKSTACK_DEBUG=1 stacks-inspect dump-txs "$chainstate_root" "$rc" >"$cycle_path"
   done

   return 0
}

find_stackers() {
   # Find all stacker records in our dumps.  Applies only to cycles up to 46.
   #
   # stdin: none
   # stdout: none
   # stderr: lots of diagnostics
   # return: 0 on success, non-zero on error
   "$LIBEXEC/addrtool" find-stackers "$VOTE_RC_1" "$DATA"/cycle-*.json > "$DATA/potential-stackers-$VOTE_RC_1.json"
   "$LIBEXEC/addrtool" find-stackers "$VOTE_RC_2" "$DATA"/cycle-*.json > "$DATA/potential-stackers-$VOTE_RC_2.json"
   return 0
}

combine_stackers() {
   # Combine all stacker records in the voting reward cycles.  Only consider those
   # who are stacking in both cycles.
   #
   # stdin: none
   # stdout: none
   # stderr: lots of diagnostics
   # return: 0 on success, non-zero on error
   "$LIBEXEC/addrtool" combine-stackers "$DATA"/potential-stackers-*.json > "$DATA/all-stackers.json"
   return 0
}

get_btc_votes() {
   # Get the BTC votes
   #
   # $1: path to bitcoin config to use
   # stdin: none
   # stdout: none
   # stderr: lots of diagnostics
   # return: 0 on success, non-zero on error
   local btc_conf="$1"
   "$LIBEXEC/get-utxos.sh" "$btc_conf" > "$DATA/stacker-btc-votes.json"
   return 0
}

get_solo_stacker_votes() {
   # Get the solo stacker votes
   #
   # stdin: none
   # stdout: none
   # stderr: lots of diagnostics
   # return: 0 on success, non-zero on error
   "$LIBEXEC/addrtool" solo-stacker-votes "$DATA/all-stackers.json" "$DATA/stacker-btc-votes.json" > "$DATA/solo-votes.json"
   return 0
}

get_pool_stacker_votes() {
   # Get the pooled stacker votes
   #
   # stdin: none
   # stdout: none
   # stderr: lots of diagnostics
   # return: 0 on success, non-zero on error
   "$LIBEXEC/addrtool" pool-stacker-votes "$DATA/all-stackers.json" "$DATA/cycle-$VOTE_RC_1.json" "$DATA/cycle-$VOTE_RC_2.json" > "$DATA/pool-votes.json"
   return 0
}

tabulate_votes() {
   # Combine votes for solo and pool stackers
   # stdin: none
   # stdout: none
   # stderr: lots of diagnostics
   # return: 0 on success, non-zero on error
   "$LIBEXEC/addrtool" tabulate "$DATA/solo-votes.json" "$DATA/pool-votes.json" > "$DATA/votes-final.json"
   return 0
}

main() {
   if [ "$#" -ne 2 ]; then
      usage
   fi
   local bitcoin_conf="$1"
   local chainstate_root="$2"
   mkdir -p "$DATA"
   if [ -z "$bitcoin_conf" ]; then
      usage
   fi
   if [ -z "$chainstate_root" ]; then
      usage
   fi

   if ! [ -f "$bitcoin_conf" ]; then 
      error_exit "Not a file we can access: $bitcoin_conf"
   fi
   if ! [ -d "$chainstate_root" ]; then
      error_exit "Not a directory we can access: $chainstate_root"
   fi

   check_deps
   get_tx_dumps "$chainstate_root"
   find_stackers
   combine_stackers
   get_btc_votes "$bitcoin_conf"
   get_solo_stacker_votes
   get_pool_stacker_votes
   tabulate_votes
   
   echo "Final tabulation in $DATA/votes-final.json"
}

main "$@"
