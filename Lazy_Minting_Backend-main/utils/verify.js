const { run } = require("hardhat")

const verify = async (contractAddress, constructorArgs) => {
    console.log("Verifying Contract...")

    try {
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: constructorArgs,
        })
    } catch (error) {
        if (error.message.toLowerCase().includes("already verified")) {
            console.log("Contract Verified Already")
        } else {
            console.log("Error verifying contract :: ", error)
        }
    } finally {
        console.log("------------------------------")
    }
}

module.exports = { verify }
