const { network, ethers } = require("hardhat")
const { verify } = require("../utils/verify")
const { developmentChains } = require("../helper-hardhat-config")

module.exports = async ({ getNamedAccounts, deployments }) => {
    // const { deployer } = await getNamedAccounts()
    const accounts = await ethers.getSigners()
    const deployer = accounts[0]

    const { deploy, log } = deployments

    log("--------------------------------")

    const args = ["Test Lazy NFT Studio", "TLFS", deployer.address]

    const LazyNFT = await deploy("LazyNFT", {
        from: deployer.address,
        args: args,
        log: true,
        waitConfirmations: network.config.waitConfirmations || 1,
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(LazyNFT.address, args)
    }

    log("--------------------------------")
}

module.exports.tags = ["LazyNFT", "all"]
