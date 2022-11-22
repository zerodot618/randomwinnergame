const { ethers } = require("hardhat");
require("dotenv").config({ path: ".env" });
const { FEE, VRF_COORDINATOR, LINK_TOKEN, KEY_HASH } = require("../constants");

async function main() {
  /**
   * 在ethers.js中，ContractFactory是一个用于部署新智能合约的抽象。
   * 所以这里的 randomWinnerGame 是我们的Verify合约实例的一个工厂。
   */
  const randomWinnerGame = await ethers.getContractFactory("RandomWinnerGame");
  // 部署合约
  const deployedRandomWinnerGame = await randomWinnerGame.deploy(
    VRF_COORDINATOR,
    LINK_TOKEN,
    KEY_HASH,
    FEE
  );
  // 等待合约部署完成
  await deployedRandomWinnerGame.deployed();
  // 打印合约地址
  console.log("RandomWinnerGame Contract Address:", deployedRandomWinnerGame.address);

  console.log("Sleeping.....");
  // 等待etherscan留意合约已被部署
  await sleep(30000);

  // 部署中验证合约
  await hre.run("verify:verify", {
    address: deployedRandomWinnerGame.address,
    constructorArguments: [VRF_COORDINATOR, LINK_TOKEN, KEY_HASH, FEE],
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });