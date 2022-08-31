import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("MetaCoin", function () {
  async function deployAndInitFixture() {
    const [owner, otherAccount] = await ethers.getSigners();

    const MetaCoin = await ethers.getContractFactory("MetaCoin");
    const metaCoin = await MetaCoin.deploy();

    return { metaCoin };
  }

  it("Ownable Test", async function () {
    const { metaCoin } = await loadFixture(deployAndInitFixture);

    const [owner, other1] = await ethers.getSigners();

    await metaCoin.connect(owner).mint(owner.address, 1_000_000);
    await expect(
      metaCoin.connect(other1).mint(other1.address, 1_000_000)
    ).revertedWith("NO");
  });
});
