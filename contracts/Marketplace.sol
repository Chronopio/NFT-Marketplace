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
    struct sellOffer {
        address seller;
        address tokenAddress;
        uint256 amountOfTokens;
        uint256 deadline;
        uint256 packPrice;
    }
    mapping(uint256 => sellOffer) sellOffers;

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

    function createSellOffer(
        address _seller,
        address _tokenAddress,
        uint256 _tokenID,
        uint256 _tokenAmount,
        uint256 _deadlineInHours,
        uint256 _price
    ) external {
        require(
            sellOffers[_tokenID].seller == address(0),
            "A sell offer with this ID already exists"
        );
        sellOffer storage newOffer = sellOffers[_tokenID];
        newOffer.seller = _seller;
        newOffer.tokenAddress = _tokenAddress;
        newOffer.amountOfTokens = _tokenAmount;
        newOffer.deadline = block.timestamp + _deadlineInHours * 1 hours;
        newOffer.packPrice = _price;
    }

    function deleteSellOffer(uint256 _tokenID) external {
        require(
            sellOffers[_tokenID].seller == msg.sender,
            "Only the sell offer creator can delete it"
        );
        delete sellOffers[_tokenID];
    }

    function checkSeller(uint256 _tokenID) external view returns (address) {
        return sellOffers[_tokenID].seller;
    }
}
