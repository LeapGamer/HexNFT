// contracts/HexNFT.sol
// SPDX-License-Identifier: MIT
//pragma solidity 0.6.6;
pragma solidity ^0.8.0;

import "https://raw.githubusercontent.com/smartcontractkit/chainlink/master/evm-contracts/src/v0.6/VRFConsumerBase.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/master/contracts/token/ERC721/ERC721.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/master/contracts/utils/Counters.sol";

contract HexNFT is ERC721 {
    // to set the owner of the contract
    address private owner;

    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);

     // for chainlink VRF oracle
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;

     // to store the original caller of mint
    address internal minter;

    // for ERC721 token standard
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // for storing the random token data attached to each token
    mapping (uint256 => uint256) private _tokenData;

    // modifier to check if caller is owner
    modifier isOwner() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public isOwner {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Return owner address 
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }

    // log an event that includes the address, the index, and the random value returned by the VRF oracle
    event MintItem(address indexed _from, uint256 indexed _tokenId, uint256 _value, bytes32 indexed _id);

    /**
     * Constructor inherits VRFConsumerBase
     * 
     * Network: Kovan
     * Chainlink VRF Coordinator address: 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9
     * LINK token address:                0xa36085F69e2889c224210F603D836748e7dC0088
     * Key Hash: 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4
     */
     /**
     * @dev Set contract deployer as owner
     */
     
    constructor() 
        VRFConsumerBase(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
            0xa36085F69e2889c224210F603D836748e7dC0088  // LINK Token
        ) public ERC721("Hex", "ITEM") 
    {
        // set the owner of this contract as the deployer
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);

        // set the fee for the VRF oracle
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }

    /**
     * Withdraw LINK from this contract
     * only owner can call this function
    */
    function withdrawLink() external isOwner {
        require(LINK.transfer(msg.sender, LINK.balanceOf(address(this))), "Unable to transfer");
    }

    /*
     * Requests randomness from a user-provided seed and uses it to mint an NFT
     * Since the random number to seed the VRF oracle with is based on the difficulty
     * a miner could still decide not to send a block with a negative outcome for them, but that would incur large costs
     * see the chainlink VRF docs for more details
     */
    function mintItem() public returns (bytes32 requestId) {
        // require that we get verified randomness from the oracle
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - fill contract with faucet");

        // store the senders address to award the new token to them once we have the random value
        minter = msg.sender;
        return requestRandomness(keyHash, fee, uint(block.difficulty));
    }

     /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
        uint256 newItem = awardItem(minter, randomness);
        emit MintItem(minter, newItem, randomness, requestId);
    }

    /**
     * @dev Base URI for computing {tokenURI}. Empty by default, can be overriden
     * in by defining it in this child contract. The token ID is appended to the URI.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return "https://theta.casino/hex_item.php?tokenId=";
    }

    /** 
     * Returns the random token data for the matching NFT
     */
    function tokenData(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "MyNFT: URI query for nonexistent token");
        return _tokenData[tokenId];
    }
}