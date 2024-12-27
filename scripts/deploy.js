const hre = require("hardhat");
const fs = require('fs');

async function main() {
  // Get the contract factory
  const XAIAgentDRC20 = await hre.ethers.getContractFactory("XAIAgentDRC20");
  
  console.log("Deploying XAIAgentDRC20...");
  
  // Deploy the contract
  const token = await XAIAgentDRC20.deploy();
  await token.deployed();
  
  console.log("XAIAgentDRC20 deployed to:", token.address);
  
  // Save the contract address
  const deploymentInfo = {
    address: token.address,
    network: hre.network.name,
    timestamp: new Date().toISOString()
  };
  
  fs.writeFileSync(
    'deployment-info.json',
    JSON.stringify(deploymentInfo, null, 2)
  );
  
  // Clear private key from environment
  if (process.env.PRIVATE_KEY) {
    console.log("Clearing private key from environment...");
    process.env.PRIVATE_KEY = "";
    
    // Overwrite the .env file if it exists, removing the private key
    if (fs.existsSync('.env')) {
      const envContent = fs.readFileSync('.env', 'utf8');
      const newEnvContent = envContent.replace(/PRIVATE_KEY=.*\n/, 'PRIVATE_KEY=\n');
      fs.writeFileSync('.env', newEnvContent);
    }
  }
  
  console.log("Deployment complete. Private key has been cleared from environment.");
  console.log("IMPORTANT: Make sure you have saved the contract address and any necessary backup information!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
