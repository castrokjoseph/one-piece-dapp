// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract OnePieceMint is VRFConsumerBaseV2, ERC721, Ownable, ERC721URIStorage {
	string[] internal characterTokenURIs = [
		"https://scarlet-live-iguana-759.mypinata.cloud/ipfs/QmNp4sHf4ccqPpqMBUCSG1CpFwFR4D6kgHesxc1mLs75am",
		"https://scarlet-live-iguana-759.mypinata.cloud/ipfs/QmPHaFt55PeidgCuXe2kaeRYmLaBUPE1Y7Kg4tDyzapZHy",
		"https://scarlet-live-iguana-759.mypinata.cloud/ipfs/QmP9pC9JuUpKcnjUk8GBXEWVTGvK3FTjXL91Q3MJ2rhA16",
		"https://scarlet-live-iguana-759.mypinata.cloud/ipfs/QmSnNXo5hxrFnpbyBeb7jY7jhkm5eyknaCXtr8muk31AHK",
		"https://scarlet-live-iguana-759.mypinata.cloud/ipfs/QmarkkgDuBUcnqksatPzU8uNS4o6LTbEtuK43P7Jyth9NH"
	];

	uint256 private s_tokenCounter; // Used to keep track of the number of NFTs being minted
	VRFCoordinatorV2Interface private i_vrfCoordinator; // Used to store VRF coordinator link
	uint256 private i_subscriptionId; // Used to store subscription ID from VRF chainlink
	bytes32 private i_keyHash; // Used to store key hash from VRF chainlink
	uint32 private i_callbackGasLimit; // Used to specify the gas limit
	
	mapping(uint256 => address) private requestIdToSender; // allows the contract to keep track of which address made a request
	mapping(address => uint256) private userCharacter; // enables the contract to associate each user with their selected character
	mapping(address => bool) public hasMinted; // prevents users from minting multiple NFTs with the same address
	mapping(address => uint256) public s_addressToCharacter; // allows users to query which character they received based on their address

	event NftRequested(uint256 requestId, address requester);
	event CharacterTraitDetermined(uint256 characterId);
	event NftMinted(uint256 characterId, address minter);

	constructor(
		address vrfCoordinatorV2Address,
		uint256 subId,
		bytes32 keyHash,
		uint32 callbackGasLimit
	) VRFConsumerBaseV2(vrfCoordinatorV2Address) ERC721("OnePiece NFT", "OPN"){
	
		i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2Address);
		i_subscriptionId = subId;
		i_keyHash = keyHash;
		i_callbackGasLimit = callbackGasLimit;
	}

	// Function to mint NFT according to the character id
	function mintNFT(address recipient, uint256 characterId) internal {
		// Ensure the address has not been minted before
		require(!hasMinted[recipient], "You have already minted your house NFT");
	
		// Get the next available token ID
		uint256 tokenId = s_tokenCounter;
	
		// Mint the NFT and assign it to the recipient
		_safeMint(recipient, tokenId);
	
		// Set the token URI for the minted NFT based on the character ID
		_setTokenURI(tokenId, characterTokenURIs[characterId]);
	
		// Map the recipient's address to the character ID they received
		s_addressToCharacter[recipient] = characterId;
	
		// Increment the token counter for the next minting
		s_tokenCounter += 1;
	
		// Mark the recipient's address as having minted an NFT
		hasMinted[recipient] = true;
	
		// Emit an event to log the minting of the NFT
		emit NftMinted(characterId, recipient);
	}

	// Function to request NFT for specific answers
	function requestNFT(uint256[5] memory answers) public {
		// Determine the character based on the provided answers and store it for the user
		userCharacter[msg.sender] = determineCharacter(answers);
	
		// Request random words from the VRF coordinator to determine the character traits
		uint256 requestId = i_vrfCoordinator.requestRandomWords(
			i_keyHash, 
			uint64(i_subscriptionId),
			3,
			i_callbackGasLimit,
			1
		);
	
		// Map the request ID to the sender's address for later reference
		requestIdToSender[requestId] = msg.sender;
	
		// Emit an event to log the request for the NFT
		emit NftRequested(requestId, msg.sender);
	}

	function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
		// Get the address of the NFT owner associated with the request ID
		address nftOwner = requestIdToSender[requestId];
	
		// Get the character ID determined based on the user's traits
		uint256 traitBasedCharacterId = userCharacter[nftOwner];
	
		// Retrieve the first random word from the provided array
		uint256 randomValue = randomWords[0];
	
		// Calculate the random character ID based on the random value
		uint256 randomCharacterId = (randomValue % 5);
	
		// Calculate the final character ID by combining the trait-based and random character IDs
		uint256 finalCharacterId = (traitBasedCharacterId + randomCharacterId) % 5;
	
		// Mint the NFT for the owner with the final character ID
		mintNFT(nftOwner, finalCharacterId);
	}

	function determineCharacter(uint256[5] memory answers) private returns (uint256) {
		// Initialize characterId variable to store the calculated character ID
		uint256 characterId = 0;
	
		// Loop through each answer provided in the answers array
		for (uint256 i = 0; i < 5; i++) {
			// Add each answer to the characterId variable
			characterId += answers[i];
		}
	
		// Calculate the final character ID by taking the remainder when divided by 5 and adding 1
		characterId = (characterId % 5) + 1;
	
		// Emit an event to log the determination of the character traits
		emit CharacterTraitDetermined(characterId);
	
		// Return the final character ID
		return characterId;
	}

	// Override the transfer functionality of ERC721 to make it soulbound
	// This function is called before every token transfer to enforce soulbinding
	function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual override {
		// Call the parent contract's implementation of _beforeTokenTransfer
		super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
	
		// Ensure that tokens are only transferred to or from the zero address
		require(from == address(0) || to == address(0), "Err! This is not allowed");
	}
	
	// Override the tokenURI function to ensure compatibility with ERC721URIStorage
	function tokenURI(uint256 tokenId)
		public
		view
		override(ERC721, ERC721URIStorage)
		returns (string memory)
	{
		// Call the parent contract's implementation of tokenURI
		return super.tokenURI(tokenId);
	}
	
	// Override the supportsInterface function to ensure compatibility with ERC721URIStorage
	function supportsInterface(bytes4 interfaceId)
		public
		view
		override(ERC721, ERC721URIStorage)
		returns (bool)
	{
		// Call the parent contract's implementation of supportsInterface
		return super.supportsInterface(interfaceId);
	}
	
	// Override the _burn function to ensure compatibility with ERC721URIStorage
	function _burn(uint256 tokenId)
		internal
		override(ERC721, ERC721URIStorage)
	{
		// Call the parent contract's implementation of _burn
		super._burn(tokenId);
	}
}
