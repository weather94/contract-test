import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { UniWrapper, INonfungiblePositionManager } from "../typechain";

describe("UniWraaper", function () {
  // let uniWrapper: UniWrapper;
  // let npm: INonfungiblePositionManager;

  async function deployAndInitFixture() {
    const UNISWAP_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
    const UNISWAP_NPM = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
    const UNISWAP_ROUTER = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

    const UniWrapper = await ethers.getContractFactory("UniWrapper");
    const uniWrapper = await UniWrapper.deploy(
      UNISWAP_FACTORY,
      UNISWAP_NPM,
      UNISWAP_ROUTER
    );

    const npm = await ethers.getContractAt(
      "INonfungiblePositionManager",
      UNISWAP_NPM
    );

    return { uniWrapper, npm };
  }

  // beforeEach("Load Fixture", async () => {
  //   console.log("Load Fixture");
  //   const { uniWrapper: _uniWrapper, npm: _npm } = await loadFixture(
  //     deployAndInitFixture
  //   );
  //   uniWrapper = _uniWrapper;
  //   npm = _npm;
  // });

  describe("Deployment", async function () {
    it("Ownable Check", async function () {
      const { uniWrapper, npm } = await loadFixture(deployAndInitFixture);
      const [owner] = await ethers.getSigners();

      expect(await uniWrapper.owner()).to.equal(owner.address);
    });
  });

  describe("RegisterPosition", async function () {
    describe("Validations", async function () {
      let uniWrapper: UniWrapper;
      let npm: INonfungiblePositionManager;

      it("NFT Register", async function () {
        const { uniWrapper: _uniWrapper, npm: _npm } = await loadFixture(
          deployAndInitFixture
        );
        uniWrapper = _uniWrapper;
        npm = _npm;
        const [owner] = await ethers.getSigners();

        expect(await npm.balanceOf(uniWrapper.address)).eq(0);

        const nft0 = await npm.tokenOfOwnerByIndex(owner.address, 0);
        await npm.approve(uniWrapper.address, nft0);
        await uniWrapper.registerPosition(nft0);

        expect(await npm.balanceOf(uniWrapper.address)).eq(1);
        const position = await uniWrapper.positionInfos(nft0);
        expect(position.enabled).eq(true);
      });

      it("Validations Check1", async function () {
        const [owner] = await ethers.getSigners();
        expect(await uniWrapper.owner()).to.equal(owner.address);
      });
      it("Validations Check2", async function () {
        const [owner] = await ethers.getSigners();
        expect(await uniWrapper.owner()).to.equal(owner.address);
      });
      it("Validations Check3", async function () {
        const [owner] = await ethers.getSigners();
        expect(await uniWrapper.owner()).to.equal(owner.address);
      });
    });
    describe("Events", async function () {
      it("Emit Event", async function () {
        const { uniWrapper, npm } = await loadFixture(deployAndInitFixture);
        const [owner] = await ethers.getSigners();

        expect(await npm.balanceOf(uniWrapper.address)).eq(0);
        const nft0 = await npm.tokenOfOwnerByIndex(owner.address, 0);
        await npm.approve(uniWrapper.address, nft0);

        await expect(uniWrapper.registerPosition(nft0))
          .to.emit(uniWrapper, "RegisterPosition")
          .withArgs(nft0);
      });
    });
  });
});
