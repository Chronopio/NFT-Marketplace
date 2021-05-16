//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Marketplace is Initializable, OwnableUpgradeable {
    address private feeRecipient;
    uint256 private feeAmount;
    AggregatorV3Interface internal daiPriceFeed;
    AggregatorV3Interface internal ethPriceFeed;
    AggregatorV3Interface internal linkPriceFeed;

    function initialize() public initializer {
        OwnableUpgradeable.__Ownable_init();
        feeRecipient = 0xD215De1fc9E2514Cf274df3F2378597C7Be06Aca;
        feeAmount = 100; // Basis points
        daiPriceFeed = AggregatorV3Interface(
            0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9
        );
        ethPriceFeed = AggregatorV3Interface(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
        linkPriceFeed = AggregatorV3Interface(
            0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c
        );
    }

    function getDaiPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = daiPriceFeed.latestRoundData();
        return price;
    }

    function getEthPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = ethPriceFeed.latestRoundData();
        return price;
    }

    function getLinkPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = linkPriceFeed.latestRoundData();
        return price;
    }
}
