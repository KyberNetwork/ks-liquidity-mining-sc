# ks-liquidity-mining-sc
Repo for Liquidity Mining contracts

# setup
run `yarn` for installing dependencies

add .env file with the following line:
ETH_NODE_URL=your eth node url

# compile
run `forge build`

# test
run `forge test -vvv` for all tests
run `forge test --mp path/to/specific/test` for a specific test file

*modify the vebosity param if needed:
-vv -> show console log only
-vvv -> show traces for failed tests only
-vvvv -> show traces for all tests

# coverage
run `forge coverage` to show coverage
run `forge coverage --report lcov` to output LCOV file

# deploy
add PRIVATE_KEY=your private key in .env file
run `forge script script/ELMV2/Deploy.s.sol:Deploy --rpc-url <network> --broadcast --optimize --verify`

*incase deploy succeed but not verify, you can try to verify it again by running
run `cast abi-encode "constructor(address,address)" "<nft address>" "<helper address>"`

run `forge verify-contract \
    <LMv2 contract address> \
    contracts/KSElasticLMV2.sol:KSElasticLMV2 \
    <your etherscan key> \
    --chain-id <chain id> \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args <result from cast here> \
    --compiler-version v0.8.9+commit.e5eed63a`

# add farm
run `forge script script/AddFarm.s.sol:AddFarm --rpc-url <network> --broadcast`