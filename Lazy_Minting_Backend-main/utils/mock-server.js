const { ethers } = require("hardhat")

const createVoucher = async (tokenId, uri, minPrice = 0, LazyNft) => {
    try {
        // console.log("Generating Mock Voucher...")

        const SIGNING_DOMAIN = "LazyNFT-Voucher"
        const SIGNATURE_VERSION = "1"
        const chainId = await LazyNft.getChainId()
        const accounts = await ethers.getSigners()
        const signer = accounts[0]

        const domain = {
            name: SIGNING_DOMAIN,
            version: SIGNATURE_VERSION,
            verifyingContract: LazyNft.address,
            chainId,
        }

        const voucher = { tokenId, uri, minPrice }

        const types = {
            NFTVoucher: [
                { name: "tokenId", type: "uint256" },
                { name: "minPrice", type: "uint256" },
                { name: "uri", type: "string" },
            ],
        }

        console.log("The address used for signing the voucher: ", signer.address)

        const signature = await signer._signTypedData(domain, types, voucher)

        console.log(
            `tokenId: ${tokenId}, uri: ${uri}, minPrice: ${minPrice}, signature: ${signature}`
        )

        return {
            ...voucher,
            signature,
        }
    } catch (error) {
        console.log("Error ::", error)
    }
}

module.exports = { createVoucher }
