const networkConfig = {
    5: {
        name: "goerli",
        interval: "30", // 30 seconds
    },

    31337: {
        name: "hardhat",
        interval: "30", // 30 seconds
    },
}

const developmentChains = ["hardhat", "localhost"]

module.exports = {
    networkConfig,
    developmentChains,
}
