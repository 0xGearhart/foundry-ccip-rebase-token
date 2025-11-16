-include .env

.PHONY: all test clean deploy fund help install snapshot coverageReport format anvil

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/foundry-devops@0.4.0 && forge install foundry-rs/forge-std@v1.11.0 && forge install openzeppelin/openzeppelin-contracts@v5.5.0 && forge install smartcontractkit/chainlink-local@v0.2.7-beta && npm install @chainlink/contracts-ccip@1.6.3

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

# Create Test Coverage Report And Save To .txt File
coverageReport :; forge coverage --report debug > coverage.txt

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account defaultKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

# deployDSC:
# 	@forge script script/DeployDSC.s.sol:DeployDSC $(NETWORK_ARGS)

# mintDynamicNft:
# 	@forge script script/Interactions.s.sol:MintDynamicNft $(NETWORK_ARGS)

# flipDynamicNft:
# 	@forge script script/Interactions.s.sol:FlipDynamicNft $(NETWORK_ARGS)
