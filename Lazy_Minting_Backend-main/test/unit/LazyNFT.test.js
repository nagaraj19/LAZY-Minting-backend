const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")
const { createVoucher } = require("../../utils/mock-server")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("LazyNFT Unit Tests", () => {
          let LazyNft, deployer, player, voucher

          beforeEach(async () => {
              const accounts = await ethers.getSigners()
              deployer = accounts[0]
              player = accounts[1]

              await deployments.fixture(["all"])

              LazyNft = await ethers.getContract("LazyNFT")

              voucher = await createVoucher(
                  1,
                  "www.google.com",
                  ethers.utils.parseEther("1"),
                  LazyNft
              )
          })

          describe("LazyNFT Constructor is set correctly", () => {
              it("sets the name to Test Lazy NFT Studio", async () => {
                  const name = await LazyNft.name()
                  assert.equal(name, "Test Lazy NFT Studio")
              })

              it("sets the symbol to TLFS", async () => {
                  const symbol = await LazyNft.symbol()
                  assert.equal(symbol, "TLFS")
              })

              it("sets the creatorRole to deployer", async () => {
                  const creatorRole = ethers.utils.keccak256(
                      ethers.utils.toUtf8Bytes("CREATOR_ROLE")
                  )

                  expect(await LazyNft.hasRole(creatorRole, deployer.address)).to.be.true
              })
          })

          describe("LazyNFT redeem", () => {
              it("mints an NFT for a valid voucher", async () => {
                  const LazyNftPlayer = LazyNft.connect(player)
                  const redeemTransaction = await LazyNftPlayer.redeem(player.address, voucher, {
                      value: ethers.utils.parseEther("1"),
                  })
                  await redeemTransaction.wait(1)

                  const playerLazyNftBalance = await LazyNftPlayer.balanceOf(player.address)

                  assert(playerLazyNftBalance.toString(), "1")
              })

              it("reverts if the voucher is tampered with", async () => {
                  const tamperedVoucher = {
                      ...voucher,
                      tokenId: 2,
                      minPrice: 0,
                      uri: "www.youtube.com",
                  }
                  await expect(LazyNft.redeem(player.address, tamperedVoucher)).to.be.revertedWith(
                      "LazyNFT__UnauthorizedCreator"
                  )
              })
          })
      })
