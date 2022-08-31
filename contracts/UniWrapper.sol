//SPDX-License-Identifier: Unlicense
// eslint-disable-next-line
pragma solidity ^0.8.4;
// pragma abicoder v2;

import "hardhat/console.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./token/ERC20Mint.sol";

import {FixedPointMathLib} from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";

contract UniWrapper is Ownable, IERC721Receiver {
    using FixedPointMathLib for uint256;

    struct PositionInfo {
        address asset0;
        address asset1;
        uint24 fee;
        uint256 reward0;
        uint256 reward1;
        ERC20Mint lfCoin;
        bool enabled;
    }

    event RegisterPosition(uint256 tokenId);
    event UnregisterPosition(uint256 tokenId);

    IUniswapV3Factory public immutable factory;
    INonfungiblePositionManager public immutable npm;
    ISwapRouter public immutable swapRouter;
    mapping(uint256 => PositionInfo) public positionInfos;

    constructor(
        address _factory,
        address _npm,
        address _router
    ) {
        factory = IUniswapV3Factory(_factory);
        npm = INonfungiblePositionManager(_npm);
        swapRouter = ISwapRouter(_router);
    }

    function registerPosition(uint256 tokenId) public onlyOwner {
        npm.safeTransferFrom(_msgSender(), address(this), tokenId);
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = npm.positions(tokenId);
        string memory tokenName = "LF";
        ERC20Mint lfCoin = new ERC20Mint(tokenName, tokenName);

        positionInfos[tokenId] = PositionInfo(
            token0,
            token1,
            fee,
            0,
            0,
            lfCoin,
            true
        );
        uint256 shares = convertToShares(tokenId, liquidity);
        lfCoin.mint(_msgSender(), shares);
        console.log("Transferring from %s, %s tokens", msg.sender, tokenId);
        emit RegisterPosition(tokenId);
    }

    function unregisterPosition(uint256 tokenId) public onlyOwner {
        npm.safeTransferFrom(address(this), _msgSender(), tokenId);
        delete positionInfos[tokenId];
    }

    function deposit(
        uint256 tokenId,
        uint256 amountAdd0,
        uint256 amountAdd1
    ) public {
        PositionInfo memory pInfo = positionInfos[tokenId];
        uint256 beforeLiquidity = totalAssets(tokenId);
        ERC20(pInfo.asset0).transferFrom(
            _msgSender(),
            address(this),
            amountAdd0
        );
        ERC20(pInfo.asset1).transferFrom(
            _msgSender(),
            address(this),
            amountAdd1
        );

        ERC20(pInfo.asset0).approve(address(npm), amountAdd0);
        ERC20(pInfo.asset1).approve(address(npm), amountAdd1);

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: amountAdd0,
                    amount1Desired: amountAdd1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (uint128 liquidity, uint256 amount0, uint256 amount1) = npm
            .increaseLiquidity(params);

        if (amountAdd0 > amount0) {
            ERC20(pInfo.asset0).transfer(_msgSender(), amountAdd0 - amount0);
        }
        if (amountAdd1 > amount1) {
            ERC20(pInfo.asset1).transfer(_msgSender(), amountAdd1 - amount1);
        }
        uint256 shares = convertToShares(tokenId, liquidity, beforeLiquidity);
        pInfo.lfCoin.mint(_msgSender(), shares);
    }

    function withdraw(uint256 tokenId, uint256 amount)
        public
        returns (uint256 returnAmount0, uint256 returnAmount1)
    {
        PositionInfo memory pInfo = positionInfos[tokenId];
        uint128 withdrawLiquidity = convertToAssets(tokenId, amount);
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: withdrawLiquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (uint256 amount0, uint256 amount1) = npm.decreaseLiquidity(params);

        INonfungiblePositionManager.CollectParams
            memory collectParams = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: _msgSender(),
                amount0Max: uint128(amount0),
                amount1Max: uint128(amount1)
            });
        (returnAmount0, returnAmount1) = npm.collect(collectParams);
        pInfo.lfCoin.burnFrom(_msgSender(), amount);
    }

    function collect(uint256 positionId) public returns (uint256, uint256) {
        PositionInfo storage pInfo = positionInfos[positionId];

        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: positionId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });
        (uint256 collectedAmount0, uint256 collectedAmount1) = npm.collect(
            params
        );
        pInfo.reward0 += collectedAmount0;
        pInfo.reward1 += collectedAmount1;
        return (pInfo.reward0, pInfo.reward1);
    }

    function reinvest(
        uint256 positionId,
        uint256 swapAmount,
        bool zeroToOne
    ) public returns (uint256) {
        // (, , address token0, address token1, uint24 fee, , , , , , , ) = npm
        //     .positions(positionId);
        PositionInfo storage pInfo = positionInfos[positionId];

        (uint256 collectedAmount0, uint256 collectedAmount1) = npm.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: positionId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        uint256 asset0Amount = collectedAmount0 + pInfo.reward0;
        uint256 asset1Amount = collectedAmount1 + pInfo.reward1;
        require(
            zeroToOne ? asset0Amount > swapAmount : asset1Amount > swapAmount,
            "I"
        );
        if (zeroToOne) {
            asset0Amount -= swapAmount;
        } else {
            asset1Amount -= swapAmount;
        }

        address tokenIn = zeroToOne ? pInfo.asset0 : pInfo.asset1;
        address tokenOut = zeroToOne ? pInfo.asset1 : pInfo.asset0;

        IERC20(tokenIn).approve(address(swapRouter), swapAmount);
        uint256 amountOut = swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: pInfo.fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: swapAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        if (zeroToOne) {
            asset1Amount += amountOut;
        } else {
            asset0Amount += amountOut;
        }
        uint256 _positionId = positionId;

        uint256 beforeLiquidity = totalAssets(_positionId);
        IERC20(pInfo.asset0).approve(address(npm), asset0Amount);
        IERC20(pInfo.asset1).approve(address(npm), asset1Amount);
        (uint128 liquidity, uint256 amount0, uint256 amount1) = npm
            .increaseLiquidity(
                INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: _positionId,
                    amount0Desired: asset0Amount,
                    amount1Desired: asset1Amount,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );
        pInfo.reward0 = asset0Amount - amount0;
        pInfo.reward1 = asset1Amount - amount1;
        uint256 shares = convertToShares(
            _positionId,
            liquidity,
            beforeLiquidity
        );
        uint256 reward = (shares * 500) / 10000;
        pInfo.lfCoin.mint(_msgSender(), reward);
        return reward;
    }

    function totalAssets(uint256 tokenId) public view returns (uint128) {
        (, , , , , , , uint128 liquidity, , , , ) = npm.positions(tokenId);
        return liquidity;
    }

    function convertToShares(
        uint256 tokenId,
        uint256 assets,
        uint256 _totalAssets
    ) public view virtual returns (uint256) {
        uint256 _totalShare = positionInfos[tokenId].lfCoin.totalSupply();
        return
            _totalShare == 0
                ? assets
                : assets.mulDivDown(_totalShare, _totalAssets);
    }

    function convertToShares(uint256 tokenId, uint256 assets)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 _totalShare = positionInfos[tokenId].lfCoin.totalSupply();
        uint256 _totalAssets = totalAssets(tokenId);
        return
            _totalShare == 0
                ? assets
                : assets.mulDivDown(_totalShare, _totalAssets);
    }

    function convertToAssets(uint256 tokenId, uint256 shares)
        public
        view
        virtual
        returns (uint128)
    {
        uint256 _totalShare = positionInfos[tokenId].lfCoin.totalSupply();
        uint128 _totalAssets = totalAssets(tokenId);
        return
            uint128(
                _totalShare == 0
                    ? shares
                    : shares.mulDivDown(_totalAssets, _totalShare)
            );
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
