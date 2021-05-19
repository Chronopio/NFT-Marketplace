const { expect } = require('chai');
const erc20 = require('@studydefi/money-legos/erc20');
require('@openzeppelin/test-helpers/configure')({
    singletons: {
        defaultSender: '0xD215De1fc9E2514Cf274df3F2378597C7Be06Aca'
    }
});
const time = require('@openzeppelin/test-helpers/src/time');

describe('NFT Marketplace Contract', () => {
    let marketplace,
        owner,
        addr1,
        tokenOwner,
        daiOwner,
        daiContract,
        testTokenContract;

    before(async () => {
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

        daiContract = new ethers.Contract(
            erc20.dai.address,
            erc20.dai.abi,
            owner
        );

        const Marketplace = await ethers.getContractFactory('Marketplace');
        marketplace = await upgrades.deployProxy(Marketplace);
        await marketplace.deployed();

        const IERC1155 = await hre.artifacts.readArtifact('IERC1155');
        const IERC20 = await hre.artifacts.readArtifact('IERC20');

        testTokenContract = new ethers.Contract(
            '0xd07dc4262bcdbf85190c01c996b4c06a461d2430',
            IERC1155.abi,
            owner
        );
        linkContract = new ethers.Contract(
            '0x514910771af9ca656af840dff83e8264ecf986ca',
            IERC20.abi,
            owner
        );

        await hre.network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: ['0x5a098be98f6715782ee73dc9c5b9574bd4c130c9']
        });
        tokenOwner = await ethers.provider.getSigner(
            '0x5a098be98f6715782ee73dc9c5b9574bd4c130c9'
        );

        await hre.network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: ['0xbc79855178842fdba0c353494895deef509e26bb']
        });
        daiOwner = await ethers.provider.getSigner(
            '0xbc79855178842fdba0c353494895deef509e26bb'
        );

        await hre.network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: ['0xdad22a85ef8310ef582b70e4051e543f3153e11f']
        });
        linkOwner = await ethers.provider.getSigner(
            '0xdad22a85ef8310ef582b70e4051e543f3153e11f'
        );

        daiContract
            .balanceOf('0xbc79855178842fdba0c353494895deef509e26bb')
            .then((balance) => console.log('Dai balance', balance.toString()));

        testTokenContract
            .balanceOf('0x5a098be98f6715782ee73dc9c5b9574bd4c130c9', 65678)
            .then((balance) =>
                console.log('IERC1155 token balance:', balance.toString())
            );

        linkContract
            .balanceOf('0xdad22a85ef8310ef582b70e4051e543f3153e11f')
            .then((balance) => console.log('Link balance', balance.toString()));

        const linkOwnerEthBalance = await ethers.provider.getBalance(
            '0xdad22a85ef8310ef582b70e4051e543f3153e11f'
        );
        console.log(linkOwnerEthBalance.toString());
    });

    it('should revert is user tries to change fee recipient', async () => {
        await expect(
            marketplace.connect(addr1).setFeeRecipient(addr1.address)
        ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('should revert is user tries to change fee amount', async () => {
        await expect(
            marketplace.connect(addr1).setFeeAmount(10000)
        ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('should get the price in USD of DAI, ETH and LINK', async () => {
        const daiPrice = await marketplace.getDaiPrice();
        const ethPrice = await marketplace.getEthPrice();
        const linkPrice = await marketplace.getLinkPrice();

        console.log(`DAI price: ${daiPrice}`);
        console.log(`ETH price: ${ethPrice}`);
        console.log(`LINK price: ${linkPrice}`);

        expect(daiPrice.gt(0)).to.be.true;
        expect(ethPrice.gt(0)).to.be.true;
        expect(linkPrice.gt(0)).to.be.true;
    });

    it('should be able to create a sellOffer', async () => {
        await marketplace
            .connect(tokenOwner)
            .createSellOffer(
                '0xd07dc4262bcdbf85190c01c996b4c06a461d2430',
                65678,
                10,
                2,
                200e8
            );

        await testTokenContract
            .connect(tokenOwner)
            .setApprovalForAll(marketplace.address, true);

        const sellerAddress = await marketplace.checkSeller(65678);
        console.log(sellerAddress);
        expect(sellerAddress).to.be.equal(tokenOwner._address);
    });

    it('should approve the contract to expend tokens', async () => {
        const isApproved = await testTokenContract.isApprovedForAll(
            tokenOwner._address,
            marketplace.address
        );

        console.log(isApproved);
        expect(isApproved).to.be.true;
    });

    it('should revert if someone tries to override a existing sell offer', async () => {
        await expect(
            marketplace
                .connect(addr1)
                .createSellOffer(
                    '0xd07dc4262bcdbf85190c01c996b4c06a461d2430',
                    65678,
                    10,
                    2,
                    200e8
                )
        ).to.be.revertedWith('A sell offer with this ID already exists');
    });

    it('should revert if someone that is not the seller tries to delete the sell offer', async () => {
        await expect(
            marketplace.connect(addr1).deleteSellOffer(65678)
        ).to.be.revertedWith('Only the sell offer creator can delete it');
    });

    it('should return correct offer price', async () => {
        const daiPriceFromContract = await marketplace.getOfferPrice(65678, 2);
        console.log(
            `Price multiplied by 1000 is ${daiPriceFromContract.toString()}`
        );
    });

    it('should be able to buy a set of tokens with ETH, and sent additional money to the user', async () => {
        const initialSellerBalance = await testTokenContract.balanceOf(
            tokenOwner._address,
            65678
        );
        const initialBuyerBalance = await testTokenContract.balanceOf(
            owner.address,
            65678
        );

        await marketplace.buyOffer(65678, 0, {
            value: ethers.utils.parseEther('1')
        });

        const finalSellerBalance = await testTokenContract.balanceOf(
            tokenOwner._address,
            65678
        );
        const finalBuyerBalance = await testTokenContract.balanceOf(
            owner.address,
            65678
        );

        console.log(`Initial buyer balance: ${initialBuyerBalance}`);
        console.log(`Initial seller balance: ${initialSellerBalance}`);
        console.log(`Final buyer balance ${finalBuyerBalance}`);
        console.log(`Final seller balance ${finalSellerBalance}`);

        expect(finalSellerBalance).to.be.equal(initialSellerBalance - 10);
        expect(finalBuyerBalance).to.be.equal(initialBuyerBalance + 10);
    });

    it('should be able to buy tokens with DAI', async () => {
        await marketplace
            .connect(tokenOwner)
            .createSellOffer(
                '0xd07dc4262bcdbf85190c01c996b4c06a461d2430',
                65678,
                5,
                2,
                200e8
            );

        await testTokenContract
            .connect(tokenOwner)
            .setApprovalForAll(marketplace.address, true);

        const initialSellerBalance = await testTokenContract.balanceOf(
            tokenOwner._address,
            65678
        );
        const initialBuyerBalance = await testTokenContract.balanceOf(
            daiOwner._address,
            65678
        );

        daiContract.connect(daiOwner).approve(marketplace.address, 1000);

        await marketplace.connect(daiOwner).buyOffer(65678, 1);

        const finalSellerBalance = await testTokenContract.balanceOf(
            tokenOwner._address,
            65678
        );
        const finalBuyerBalance = await testTokenContract.balanceOf(
            daiOwner._address,
            65678
        );

        console.log(`Initial buyer balance: ${initialBuyerBalance}`);
        console.log(`Initial seller balance: ${initialSellerBalance}`);
        console.log(`Final buyer balance ${finalBuyerBalance}`);
        console.log(`Final seller balance ${finalSellerBalance}`);

        expect(finalSellerBalance).to.be.equal(initialSellerBalance - 5);
        expect(finalBuyerBalance).to.be.equal(initialBuyerBalance + 5);
    });

    it('should be able to buy tokens with LINK', async () => {
        await marketplace
            .connect(tokenOwner)
            .createSellOffer(
                '0xd07dc4262bcdbf85190c01c996b4c06a461d2430',
                65678,
                5,
                2,
                200e8
            );

        await testTokenContract
            .connect(tokenOwner)
            .setApprovalForAll(marketplace.address, true);

        const initialSellerBalance = await testTokenContract.balanceOf(
            tokenOwner._address,
            65678
        );
        const initialBuyerBalance = await testTokenContract.balanceOf(
            linkOwner._address,
            65678
        );

        linkContract.connect(linkOwner).approve(marketplace.address, 1000);

        await marketplace.connect(linkOwner).buyOffer(65678, 2);

        const finalSellerBalance = await testTokenContract.balanceOf(
            tokenOwner._address,
            65678
        );
        const finalBuyerBalance = await testTokenContract.balanceOf(
            linkOwner._address,
            65678
        );

        console.log(`Initial buyer balance: ${initialBuyerBalance}`);
        console.log(`Initial seller balance: ${initialSellerBalance}`);
        console.log(`Final buyer balance ${finalBuyerBalance}`);
        console.log(`Final seller balance ${finalSellerBalance}`);

        expect(finalSellerBalance).to.be.equal(initialSellerBalance - 5);
        expect(finalBuyerBalance).to.be.equal(initialBuyerBalance + 5);
    });

    it('should expire the offer if deadline passes', async () => {
        await marketplace
            .connect(tokenOwner)
            .createSellOffer(
                '0xd07dc4262bcdbf85190c01c996b4c06a461d2430',
                65678,
                5,
                2,
                200e8
            );

        await testTokenContract
            .connect(tokenOwner)
            .setApprovalForAll(marketplace.address, true);

        await time.increase(time.duration.hours(20));
        await marketplace.connect(daiOwner).buyOffer(65678, 1);

        const sellerAddress = await marketplace.checkSeller(65678);

        expect(sellerAddress).to.be.equal(
            '0x0000000000000000000000000000000000000000'
        );
    });

    it('should be able to delete a sellOffer', async () => {
        await marketplace
            .connect(tokenOwner)
            .createSellOffer(
                '0xd07dc4262bcdbf85190c01c996b4c06a461d2430',
                65678,
                5,
                2,
                200e8
            );

        await testTokenContract
            .connect(tokenOwner)
            .setApprovalForAll(marketplace.address, true);

        await marketplace.connect(tokenOwner).deleteSellOffer(65678);

        const sellerAddress = await marketplace.checkSeller(65678);
        console.log(sellerAddress);
        expect(sellerAddress).to.be.equal(
            '0x0000000000000000000000000000000000000000'
        );
    });
});
