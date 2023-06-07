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
run `forge script script/Deploy.s.sol:Deploy --rpc-url goerli --broadcast --optimize --verify`