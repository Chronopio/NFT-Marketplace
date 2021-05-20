//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title A NFT Marketplace
/// @author Joaquin Yañez
/// @notice You can sell of buy ERC1155 tokens safely and with low fees

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Marketplace is Initializable, OwnableUpgradeable {
    address private constant daiContractAddress =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant linkContractAddress =
        0x514910771AF9Ca656af840dff83E8264EcF986CA;
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

    /// @notice Event to be emitted on sell
    /// @param _from The seller address
    /// @param _tokenID The ID of the token that has been sold
    /// @param _price Price for whole set of tokens
    /// @param _deadline The deadline to accept and buy the offer
    /// @param _amount Amount of tokens in the pack
    event Sell(
        address indexed _from,
        uint256 indexed _tokenID,
        uint256 indexed _price,
        uint256 _deadline,
        uint256 _amount
    );
    /// @notice Event to be emitted on offer cancel
    /// @param _tokenID The ID of the token that has been sold
    /// @param _when Timestamp when the offer was cancelled
    event Cancel(uint256 indexed _tokenID, uint256 indexed _when);
    /// @notice Event to be emitted on buy
    /// @param _from The buyer address
    /// @param _tokenID The ID of the token that has been sold
    /// @param _paymentTokenIndex Index of the token used in the payment, 0 for ETH, 1 for DAI, 2 for LINK
    /// @param _paymentToken Name of the token used in the payment
    event Buy(
        address indexed _from,
        uint256 indexed _tokenID,
        uint256 indexed _paymentTokenIndex,
        string _paymentToken
    );
    /// @param _message Standard message to advice that the offer has been cancelled
    event Expired(string _message);

    /// @dev Function to replace the constructor, to make the contract upgradeable
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

    /// @notice This function can not be called by someone different than the owner
    /// @param _feeRecipient The new fee recipient address
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
    }

    /// @notice This function can not be called by someone different than the owner
    /// @param _feeAmount The new fee amount (in basis points)
    function setFeeAmount(uint256 _feeAmount) external onlyOwner {
        feeAmount = _feeAmount;
    }

    /// @notice Function that returns the DAI price
    /// @dev This function is intended to be internal but it is public for testing purposes
    /// @return The amount of USD you get for each DAI, with 8 decimals
    function getDaiPrice() public view returns (int256) {
        (, int256 price, , , ) = daiPriceFeed.latestRoundData();
        return price;
    }

    /// @notice Function that returns the ETH price
    /// @dev This function is intended to be internal but it is public for testing purposes
    /// @return The amount of USD you get for each ETH, with 8 decimals
    function getEthPrice() public view returns (int256) {
        (, int256 price, , , ) = ethPriceFeed.latestRoundData();
        return price;
    }

    /// @notice Function that returns the LINK price
    /// @dev This function is intended to be internal but it is public for testing purposes
    /// @return The amount of USD you get for each LINK, with 8 decimals
    function getLinkPrice() public view returns (int256) {
        (, int256 price, , , ) = linkPriceFeed.latestRoundData();
        return price;
    }

    /// @notice Creates a sell offer
    /// @param _tokenAddress The address of the token that is going to be sold
    /// @param _tokenID ID of the token that is going to be sold
    /// @param _tokenAmount The amount of token in the pack
    /// @param _deadlineInHours Deadline in hours
    /// @param _price Price for the whole set
    function createSellOffer(
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
        require(IERC1155(_tokenAddress).balanceOf(msg.sender, _tokenID) > 0);
        sellOffer storage newOffer = sellOffers[_tokenID];
        newOffer.seller = msg.sender;
        newOffer.tokenAddress = _tokenAddress;
        newOffer.amountOfTokens = _tokenAmount;
        newOffer.deadline = block.timestamp + (_deadlineInHours * 1 hours);
        newOffer.packPrice = _price;

        emit Sell(msg.sender, _tokenID, _price, _deadlineInHours, _tokenAmount);
    }

    /// @notice Deletes a sell offer, only can be called by the offer creator
    /// @param _tokenID ID of the token being sold
    function deleteSellOffer(uint256 _tokenID) external {
        require(
            sellOffers[_tokenID].seller == msg.sender,
            "Only the sell offer creator can delete it"
        );
        delete sellOffers[_tokenID];

        emit Cancel(_tokenID, block.timestamp);
    }

    /// @notice Check the seller of a specific offer
    /// @dev This function is mainly intended for testing purposes
    /// @param _tokenID ID of the token being sold
    /// @return The seller of the respective token ID
    function checkSeller(uint256 _tokenID) external view returns (address) {
        return sellOffers[_tokenID].seller;
    }

    /// @notice Returns the price of the set in a specific token
    /// @dev The pack price is multiplied by 1000, to handle the lack of floating point support in solidity
    /// @param _tokenID a parameter just like in doxygen (must be followed by parameter name)
    /// @param _paymentToken a parameter just like in doxygen (must be followed by parameter name)
    /// @return price of the set in a specific token
    function getOfferPrice(uint256 _tokenID, uint256 _paymentToken)
        external
        view
        returns (uint256 price)
    {
        require(
            _paymentToken >= 0 && _paymentToken <= 2,
            "You can only choose between ETH, DAI and LINK"
        );

        if (_paymentToken == 0) {
            uint256 ethPrice = uint256(getEthPrice());
            price = (sellOffers[_tokenID].packPrice * 1000) / ethPrice;
        } else if (_paymentToken == 1) {
            uint256 daiPrice = uint256(getDaiPrice());
            price = (sellOffers[_tokenID].packPrice * 1000) / daiPrice;
        } else {
            uint256 linkPrice = uint256(getLinkPrice());
            price = (sellOffers[_tokenID].packPrice * 1000) / linkPrice;
        }
    }

    /// @notice Accepts an offer, the user is able to pay with ETH, DAI, LINK. If the user pays with ETH the function takes the exact amount and returns the rest
    /// @param _tokenID The ID of the token tha is being buyed
    /// @param _paymentToken Index of the token used in the payment, 0 for ETH, 1 for DAI, 2 for LINK
    function buyOffer(uint256 _tokenID, uint256 _paymentToken)
        external
        payable
    {
        require(
            _paymentToken >= 0 && _paymentToken <= 2,
            "You can only choose between ETH, DAI and LINK"
        );
        if (block.timestamp > sellOffers[_tokenID].deadline) {
            delete sellOffers[_tokenID];
            emit Cancel(_tokenID, sellOffers[_tokenID].deadline);
            emit Expired("The offer has expired, please try with another one");
        } else {
            uint256 price = this.getOfferPrice(_tokenID, _paymentToken);
            if (_paymentToken == 0) {
                // The price is multiplied by 1e15 to convert the value to wei. Remember it was previously multiplied by 1e3
                require(
                    msg.value >= price * 1e15,
                    "You are sending less money than needed"
                );
                if (msg.value > price * 1e15) {
                    payable(msg.sender).transfer(msg.value - (price * 1e15));
                }

                uint256 amountToFeeRecipient =
                    address(this).balance / feeAmount;
                payable(feeRecipient).transfer(amountToFeeRecipient);
                payable(sellOffers[_tokenID].seller).transfer(
                    address(this).balance
                );

                emit Buy(msg.sender, _tokenID, 0, "ETH");
            } else if (_paymentToken == 1) {
                // The price must be divided by 1000 on each use case to get the correct amount, because the price was previously multiplied by 1000
                require(
                    IERC20(daiContractAddress).balanceOf(msg.sender) >=
                        price / 1000,
                    "Not enough balance to pay the token"
                );
                require(
                    IERC20(daiContractAddress).allowance(
                        msg.sender,
                        address(this)
                    ) >= price / 1000,
                    "You must approve the contract to send the tokens"
                );
                uint256 feeToSend = (price / 1000) / feeAmount;
                uint256 amountToSend = (price / 1000) - feeToSend;

                IERC20(daiContractAddress).transferFrom(
                    msg.sender,
                    feeRecipient,
                    feeToSend
                );

                IERC20(daiContractAddress).transferFrom(
                    msg.sender,
                    sellOffers[_tokenID].seller,
                    amountToSend
                );

                emit Buy(msg.sender, _tokenID, 1, "DAI");
            } else {
                // The price must be divided by 1000 on each use case to get the correct amount, because the price was previously multiplied by 1000
                require(
                    IERC20(linkContractAddress).balanceOf(msg.sender) >=
                        price / 1000,
                    "Not enough balance to pay the token"
                );
                require(
                    IERC20(linkContractAddress).allowance(
                        msg.sender,
                        address(this)
                    ) >= price / 1000,
                    "You must approve the contract to send the tokens"
                );
                uint256 feeToSend = (price / 1000) / feeAmount;
                uint256 amountToSend = (price / 1000) - feeToSend;

                if (feeToSend == 0) {
                    feeToSend = 1;
                }

                IERC20(linkContractAddress).transferFrom(
                    msg.sender,
                    feeRecipient,
                    feeToSend
                );

                IERC20(linkContractAddress).transferFrom(
                    msg.sender,
                    sellOffers[_tokenID].seller,
                    amountToSend
                );

                emit Buy(msg.sender, _tokenID, 2, "LINK");
            }

            IERC1155(sellOffers[_tokenID].tokenAddress).safeTransferFrom(
                sellOffers[_tokenID].seller,
                msg.sender,
                65678,
                sellOffers[_tokenID].amountOfTokens,
                ""
            );
            delete sellOffers[_tokenID];
        }
    }
}
