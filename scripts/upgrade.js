const { ethers, upgrades } = require("hardhat");

async function main() {
    const contract = await ethers.getContractFactory("XAIAgentDRC20Upgradeable");

    await upgrades.upgradeProxy(
        process.env.DBC_TOKEN_ADDRESS,
        contract,
        { kind: "uups" }
    );
    console.log("contract upgraded");
}

main();