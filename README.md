# sip015-vote

Tabulation software for SIP-015

## Setup

You will need:

* A locally-running bitcoin node, which tracks UTXOs for `1111111111111117CrbcZgemVNFx8` and `11111111111111X6zHB1ZC2FmtnqJ`

   * You can do this with the `bitcoin-cli importaddress` subcommand.

* A locally-running Stacks node

* A version of `stacks-inspect` in your `$PATH` built from the `feat/get-reward-set` branch.  You can build this as follows:

   * `git clone https://github.com/stacks-network/stacks-blockchain && cd ./stacks-blockchain && git checkout feat/get-reward-set && cargo build --release && export PATH="$(realpath /target/release/):$PATH"`

* Copies of the following node.js packages installed globally (in your `$NODE_PATH`):

   * `c32check`

   * `bitcoinjs-lib`

   * `@stacks/common`

   * `@stacks/transactions`

   * You can get these with `sudo npm install -g c32check bitcoinjs-lib @stacks/common @stacks/transactions`

## How To Run

1. Run `./run.sh /path/to/your/bitcoin.conf /path/to/your/stacks/node/chainstate/root`
2. Grab coffee and do errands for an hour or two
3. Read the results in `./data/votes-final.json`


