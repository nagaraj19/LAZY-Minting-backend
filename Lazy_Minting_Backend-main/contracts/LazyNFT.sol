/**
 * @notice THE WORKFLOW => Two contract NFTMarketplace and LazyNFT
 *
 * NFTMarketplace =>
 *  1. all the "minted NFTs" (not vouchers, vouchers will be stored on backend) will be listed on this contract
 *  2. keep track of "minted NFT" being bought, sold, listed, delisted in the marketplace
 *
 * LazyNFT =>
 *  1. This is a common token for the platform/NftMarketplace
 *  2. All the Creators can create "vouchers" for this token from frontend which will be stored on backend and can be redeemed for actual NFTs
 *
 * theGraph =>
 *  1. Listen for events like NftMinted, NftBought, NftListedForSale, NftDeListedForSale
 *  2. Use the data emitted by these events(like newOwner in case of emit OwnerChanged(address newOwner) ) to keep track of active listed NFTs for sale to be shown on NftMarketplace
 *
 *                                      @notice////////////////////// THE WORKFLOW //////////////////////
 *
 * CREATOR ---> frontend ---> createVoucher(<required args>) --> Backend
 *                                                                   |
 *  _________________________________________________________________|
 * |
 * |--> get current tokenId(LazyNft) ---> LazyNFT.current() ---> generateVoucher(<required args>) ---> store returned Voucher in MongoDb --> LazyNFT.increment() --> increase tokenId for next voucher/ potential NFT
 *                                                                                                                             |
 *  ___________________________________________________________________________________________________________________________|                                                                                          |
 * |
 * |--> frontend ---> add the voucher for sale ---> User buys voucher (buyVoucher(<required args>))
 *                                                                  |
 *  ________________________________________________________________|
 * |
 * |--> smartContract(LazyNft) ---> redeem(<required args>) ---> NFT is created!
 *                                                                  | <optional, only if user wants to resale the NFT>
 *  ________________________________________________________________|
 * |
 * |--> frontend ---> listNftFrontend(<required args>) ---> listNft(NftMarketplace) ---> emit NftListed(<required args>) ---> theGraph listens for the event and NFT data emitted with this event and add to active
 *                                                                                                                                                                      |
 *  ____________________________________________________________________________________________________________________________________________________________________|
 * |
 * |--> frontend ---> query theGraph for active listed Nfts ---> display the active listed Nfts ---> USER_2 ---> buyNftFrontend(<required args>)
 *                                                                                                                          |
 *  ________________________________________________________________________________________________________________________|
 * |
 * |--> smartContract(NftMarketplace) ---> transferNft(<required args>) ---> update +amount to USER balance in NftMarketplace treasury mapping ---> emit NftBoughtAndDelisted(<required args>) ---> theGraph listens for the event and NFT data emitted with this event and remove from active
 *                                                                                                                                                                                                                       |
 *  _____________________________________________________________________________________________________________________________________________________________________________________________________________________|
 * |
 * |--> frontend ---> query theGraph for active listed Nfts ---> display the active listed Nfts
 */

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

////////////////////// ERRORS //////////////////////

error LazyNFT__UnauthorizedCreator();
error LazyNFT__InsufficientFundsSent();

contract LazyNFT is ERC721URIStorage, EIP712, AccessControl {
    using Counters for Counters.Counter;

    ////////////////////// TYPE DECLARATIONS //////////////////////

    /// @notice Voucher represents an un-minted NFT, a signed voucher can be redeemed for a minted NFT using redeem function
    struct NFTVoucher {
        /// @notice id of NFT, if the NFT corresponding to this tokenId is already minted then redeem function will revert
        uint256 tokenId;
        /// @notice price in wei required to mint the NFT using redeem function, redeem function reverts if not enough wei is sent
        uint256 minPrice;
        /// @notice uri points to meta-data of the NFT
        string uri;
        ///@notice for a voucher to be valid, it must be signed by someone with MINTER_ROLE
        bytes signature;
    }

    ////////////////////// STATE VARIABLES //////////////////////
    bytes32 private constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    string private constant SIGNING_DOMAIN = "LazyNFT-Voucher";
    string private constant SIGNATURE_VERSION = "1";
    mapping(address => uint256) private pendingWithdrawls;
    Counters.Counter private _tokenIdCounter;

    ////////////////////// EVENTS //////////////////////
    event NftMinted(address indexed redeemer, uint256 indexed tokenId, string tokenURI);

    ////////////////////// CONSTRUCTOR //////////////////////
    /**
     *
     * @param nftCollectionName represents the name of the NFT Collection
     * @param nftCollectionSymbol represents the symbol of the NFTs belonging to a NFT Collection
     * @param creator represents the entity that has created the vouchers to be redeemed for NFTs
     */
    constructor(
        string memory nftCollectionName,
        string memory nftCollectionSymbol,
        address payable creator
    ) ERC721(nftCollectionName, nftCollectionSymbol) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        _grantRole(CREATOR_ROLE, creator);
    }

    ////////////////////// FUNCTIONS //////////////////////
    function redeem(
        address redeemer,
        NFTVoucher calldata voucher
    ) public payable returns (uint256) {
        // makes sure signature is valid and get hte address of the signer
        address signer = _verify(voucher);
        console.log("The signer recovered from the signature", signer);

        // make sure that the signer is authorized to mint NFTs
        if (!hasRole(CREATOR_ROLE, signer)) {
            revert LazyNFT__UnauthorizedCreator();
        }

        // make sures that redeemer is paying enough
        if (msg.value < voucher.minPrice) {
            revert LazyNFT__InsufficientFundsSent();
        }

        // first minting the NFT to the creator, to establish provenance on-chain
        _safeMint(signer, voucher.tokenId);

        _setTokenURI(voucher.tokenId, voucher.uri);

        // transferring token to the redeemer
        _transfer(signer, redeemer, voucher.tokenId);

        // record payment to signer's withdrawl balance
        pendingWithdrawls[signer] += msg.value;

        // emitting event for NFT being minted
        emit NftMinted(msg.sender, voucher.tokenId, voucher.uri);

        return voucher.tokenId;
    }

    // /// @notice transfers all the pending withdrawls of the caller to the caller. Reverts if caller does not have CREATOR_ROLE
    // function withdraw() external {
    //     if (!hasRole(CREATOR_ROLE, msg.sender)) {
    //         revert LazyNFT__UnauthorizedCreator();
    //     }

    //     address payable receiver = payable(msg.sender);

    //     uint256 amount = pendingWithdrawls[receiver];
    //     // updating balances before transfer to prevent re-entrancy attacks
    //     pendingWithdrawls[receiver] = 0;
    //     receiver.transfer(amount);
    // }

    // /// @notice returns the amount of ETH (or equivalent crypto coin) available to withdraw
    // function availableToWithdraw() public view returns (uint256) {
    //     return pendingWithdrawls[msg.sender];
    // }

    /**
     *@notice returns hash of the given NFTVoucher according to EIP-712
     *@param voucher NFTVoucher to hash
     */
    function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256("NFTVoucher(uint256 tokenId,uint256 minPrice,string uri)"),
                        voucher.tokenId,
                        voucher.minPrice,
                        keccak256(bytes(voucher.uri))
                    )
                )
            );
    }

    function getChainId() external view returns (uint256) {
        return block.chainid;
    }

    /**
     * @notice verifies the signature of the given NFTVoucher and returns address of the signer
     * @notice reverts if signature is invalid. It does not verify that singer has CREATOR_ROLE
     * @param voucher describes an unminted NFT
     */
    function _verify(NFTVoucher calldata voucher) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl, ERC721) returns (bool) {
        return
            ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }

    // open to more functionality...
}
