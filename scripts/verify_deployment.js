const { ethers } = require('hardhat');

async function main() {
  const proxyAddress = '0x37387e0DCd0C58B451D21B608aC5a25A2b060D75';
  const XAIAgent = await ethers.getContractFactory('XAIAgentDRC20Upgradeable');
  const token = await XAIAgent.attach(proxyAddress);

  console.log('Verifying XAIAgent token deployment...');
  
  const name = await token.name();
  console.log('Token Name:', name);
  
  const symbol = await token.symbol();
  console.log('Token Symbol:', symbol);
  
  const totalSupply = await token.totalSupply();
  console.log('Total Supply:', ethers.utils.formatEther(totalSupply), 'tokens');
  
  const version = await token.version();
  console.log('Contract Version:', version.toString());
  
  const isLockActive = await token.isLockActive();
  console.log('Lock Status:', isLockActive ? 'Active' : 'Inactive');

  console.log('\nVerification complete!');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
