const hre = require("hardhat");
const fs = require('fs');

async function main() {
  // Get the contract factory
  const XAIAgentDRC20 = await hre.ethers.getContractFactory("XAIAgentDRC20Upgradeable");
  
  console.log("Deploying XAIAgentDRC20Upgradeable...");
  
  // Deploy proxy without parameters since we've removed investment and distribution logic
  const xaaProxy = await hre.upgrades.deployProxy(
    XAIAgentDRC20,
    [],
    {
      kind: "uups",
      initializer: "initialize"
    }
  );

  await xaaProxy.waitForDeployment();
  proxyAddress = await xaaProxy.getAddress();
  console.log("XAIAgentDRC20Upgradeable deployed to:", proxyAddress);

  // Get implementation address
  const implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(proxyAddress);
  console.log("Implementation contract address:", implementationAddress);

  // Save deployment information
  const deploymentInfo = {
    proxy: xaaProxy.address,
    implementation: implementationAddress,
    network: hre.network.name,
    timestamp: new Date().toISOString(),
    parameters: {}
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
