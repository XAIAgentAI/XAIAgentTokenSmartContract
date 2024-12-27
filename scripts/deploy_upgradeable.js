const hre = require("hardhat");
const fs = require('fs');

async function main() {
  // Get the contract factory
  const XAIAgentDRC20 = await hre.ethers.getContractFactory("XAIAgentDRC20Upgradeable");
  
  console.log("Deploying XAIAgentDRC20Upgradeable...");
  
  // Get deployment parameters from environment
  const initialTokenPrice = process.env.INITIAL_TOKEN_PRICE;
  const dbcTokenAddress = process.env.DBC_TOKEN_ADDRESS;
  const xaaPoolAddress = process.env.XAA_POOL_ADDRESS;
  const ecosystemAddress = process.env.ECOSYSTEM_ADDRESS;
  const creatorAddress = process.env.CREATOR_ADDRESS;

  // Validate parameters
  if (!initialTokenPrice || !dbcTokenAddress || !xaaPoolAddress || !ecosystemAddress || !creatorAddress) {
    throw new Error("Missing required environment variables");
  }

  console.log("Deployment parameters:");
  console.log(`- Initial Token Price: ${initialTokenPrice}`);
  console.log(`- DBC Token Address: ${dbcTokenAddress}`);
  console.log(`- XAA Pool Address: ${xaaPoolAddress}`);
  console.log(`- Ecosystem Address: ${ecosystemAddress}`);
  console.log(`- Creator Address: ${creatorAddress}`);

  // Deploy proxy
  const xaaProxy = await hre.upgrades.deployProxy(
    XAIAgentDRC20,
    [
      initialTokenPrice,
      dbcTokenAddress,
      xaaPoolAddress,
      ecosystemAddress,
      creatorAddress
    ],
    {
      kind: "uups",
      initializer: "initialize"
    }
  );

  await xaaProxy.deployed();
  console.log("XAIAgentDRC20Upgradeable deployed to:", xaaProxy.address);

  // Get implementation address
  const implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(xaaProxy.address);
  console.log("Implementation contract address:", implementationAddress);

  // Save deployment information
  const deploymentInfo = {
    proxy: xaaProxy.address,
    implementation: implementationAddress,
    network: hre.network.name,
    timestamp: new Date().toISOString(),
    parameters: {
      initialTokenPrice,
      dbcTokenAddress,
      xaaPoolAddress,
      ecosystemAddress,
      creatorAddress
    }
  };

  fs.writeFileSync(
    'deployment-info.json',
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("Deployment complete! Information saved to deployment-info.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
