const { expect } = require('chai');
const erc20 = require('@studydefi/money-legos/erc20');

describe('NFT Marketplace Contract', () => {
    let marketplace, owner, addr1, daiContract;

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
        await marketplace.createSellOffer(
            owner.address,
            '0xd07dc4262bcdbf85190c01c996b4c06a461d2430',
            65678,
            10,
            2,
            15000
        );

        const sellerAddress = await marketplace.checkSeller(65678);
        console.log(sellerAddress);
        expect(sellerAddress).to.be.equal(owner.address);
    });

    it('should revert if someone tries to override a existing sell offer', async () => {
        await expect(
            marketplace.createSellOffer(
                addr1.address,
                '0xd07dc4262bcdbf85190c01c996b4c06a461d2430',
                65678,
                10,
                2,
                15000
            )
        ).to.be.revertedWith('A sell offer with this ID already exists');
    });

    it('should revert if someone that is not the seller tries to delete the sell offer', async () => {
        await expect(
            marketplace.connect(addr1).deleteSellOffer(65678)
        ).to.be.revertedWith('Only the sell offer creator can delete it');
    });

    it('should be able to delete a sellOffer', async () => {
        await marketplace.deleteSellOffer(65678);

        const sellerAddress = await marketplace.checkSeller(65678);
        console.log(sellerAddress);
        expect(sellerAddress).to.be.equal(
            '0x0000000000000000000000000000000000000000'
        );
    });
});
