deploy-dbc-testnet:
	source .env && npx hardhat run scripts/deploy_upgradeable.js --network dbcTestnet

verify-dbc-testnet:
	source .env && npx hardhat verify --network dbcTestnet $DBC_TOKEN_ADDRESS

upgrade-dbc-testnet:
	source .env && npx hardhat run scripts/upgrade.js --network dbcTestnet


deploy-dbc-mainnet:
	source .env && npx hardhat run scripts/deploy_upgradeable.js --network dbcMainnet

verify-dbc-mainnet:
	source .env && npx hardhat verify --network dbcMainnet $DBC_TOKEN_ADDRESS

upgrade-dbc-testnet:
	source .env && npx hardhat run scripts/upgrade.js --network dbcMainnet