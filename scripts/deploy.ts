import { ethers } from "hardhat";

const UNISWAP_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const UNISWAP_NPM = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
const UNISWAP_ROUTER = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

async function main() {
  const MetaCoin = await ethers.getContractFactory("MetaCoin");
  const metaCoin = await MetaCoin.deploy();

  await metaCoin.deployed();

  console.log("MetaCoin deployed to:", metaCoin.address);

  const UniWrapper = await ethers.getContractFactory("UniWrapper");
  const uniWrapper = await UniWrapper.deploy(
    UNISWAP_FACTORY,
    UNISWAP_NPM,
    UNISWAP_ROUTER
  );

  console.log("UniWrapper deployed to:", uniWrapper.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
