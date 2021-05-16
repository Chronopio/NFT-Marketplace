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
    });
});
