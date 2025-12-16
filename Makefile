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

# Create test coverage report and save to .txt file
coverageReport :; forge coverage --report debug > coverage.txt

# Generate Gas Snapshot
snapshot :; forge snapshot

# Generate table showing gas cost for each function
gasReport :; forge test --gas-report

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network eth MAINNET,$(ARGS)),--network eth MAINNET)
	NETWORK_ARGS := --rpc-url $(ETH_MAINNET_RPC_URL) --account defaultKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network eth sepolia,$(ARGS)),--network eth sepolia)
	NETWORK_ARGS := --rpc-url $(ETH_SEPOLIA_RPC_URL) --account defaultKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network arb MAINNET,$(ARGS)),--network arb MAINNET)
	NETWORK_ARGS := --rpc-url $(ARB_MAINNET_RPC_URL) --account defaultKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

ifeq ($(findstring --network arb sepolia,$(ARGS)),--network arb sepolia)
	NETWORK_ARGS := --rpc-url $(ARB_SEPOLIA_RPC_URL) --account defaultKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

# during anvil deployment grantMintAndBurnRole for vault contract is failing, not sure why but acts like it is being called from someone who is not the owner even though it is within the same broadcast. Need to investigate further
deploy:
	@read -p "Deploy Vault contract also? (y/n): " RESPONSE; \
	DEPLOY_FLAG=$$([ "$$RESPONSE" = "y" ] && echo "true" || echo "false"); \
	forge script script/DeployRBT.s.sol:DeployRBT --sig "run(bool)" $$DEPLOY_FLAG $(NETWORK_ARGS)