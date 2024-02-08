// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error MadWizard__AlreadyInitialized();
error MadWizard__RangeOutOfBounds();
error MadWizard__TransferFailed();
error MadWizard__MaxSupplyReached();

enum YieldMode {
    AUTOMATIC,
    VOID,
    CLAIMABLE
}

enum GasMode {
    VOID,
    CLAIMABLE 
}

interface IBlast{
    // configure
    function configureContract(address contractAddress, YieldMode _yield, GasMode gasMode, address governor) external;
    function configure(YieldMode _yield, GasMode gasMode, address governor) external;

    // base configuration options
    function configureClaimableYield() external;
    function configureClaimableYieldOnBehalf(address contractAddress) external;
    function configureAutomaticYield() external;
    function configureAutomaticYieldOnBehalf(address contractAddress) external;
    function configureVoidYield() external;
    function configureVoidYieldOnBehalf(address contractAddress) external;
    function configureClaimableGas() external;
    function configureClaimableGasOnBehalf(address contractAddress) external;
    function configureVoidGas() external;
    function configureVoidGasOnBehalf(address contractAddress) external;
    function configureGovernor(address _governor) external;
    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external;

    // claim yield
    function claimYield(address contractAddress, address recipientOfYield, uint256 amount) external returns (uint256);
    function claimAllYield(address contractAddress, address recipientOfYield) external returns (uint256);

    // claim gas
    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256);
    function claimGasAtMinClaimRate(address contractAddress, address recipientOfGas, uint256 minClaimRateBips) external returns (uint256);
    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint256);
    function claimGas(address contractAddress, address recipientOfGas, uint256 gasToClaim, uint256 gasSecondsToConsume) external returns (uint256);

    // read functions
    function readClaimableYield(address contractAddress) external view returns (uint256);
    function readYieldConfiguration(address contractAddress) external view returns (uint8);
    function readGasParams(address contractAddress) external view returns (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode);
}

interface IERC20Rebasing {
  // changes the yield mode of the caller and update the balance
  // to reflect the configuration
  function configure(YieldMode) external returns (uint256);
  // "claimable" yield mode accounts can call this this claim their yield
  // to another address
  function claim(address recipient, uint256 amount) external returns (uint256);
  // read the claimable amount for an account
  function getClaimableAmount(address account) external view returns (uint256);
}

contract MadWizard is ERC721URIStorage, Ownable {
    // Types
    enum Destiny {
        GREEN,
        PURPLE,
        RED
    }


    // NFT Variables
    uint256 private s_tokenCounter;
    uint256 internal constant MAX_CHANCE_VALUE = 100;
    uint256 private immutable i_maxSupply;
    string[] internal s_genTokenUris;
    bool private s_initialized;
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    IERC20Rebasing public constant USDB = IERC20Rebasing(0x4200000000000000000000000000000000000022);
    IERC20Rebasing public constant WETH = IERC20Rebasing(0x4200000000000000000000000000000000000023);

    

    event NftMinted(address indexed minter, uint256 indexed tokenId);

    constructor(
        string[3] memory genTokenUris,
        uint256 maxSupply
    ) ERC721 ("MadWizzards", "MWIZ") {
        _initializeContract(genTokenUris);
        s_tokenCounter = 0;
        i_maxSupply = maxSupply;
        USDB.configure(YieldMode.CLAIMABLE);
        WETH.configure(YieldMode.CLAIMABLE);
        BLAST.configureClaimableYield(); 
        BLAST.configureClaimableGas(); 
		BLAST.configureGovernor(msg.sender);
    }

    function requestNft() public payable {
        if (s_tokenCounter >= i_maxSupply) {
            revert MadWizard__MaxSupplyReached();
        }
        address wizardMinter = msg.sender;
        uint256 updatedItemID = s_tokenCounter;
        s_tokenCounter = s_tokenCounter + 1;
        uint256 randomWords = setNumber();
        uint256 moddedRng = randomWords % MAX_CHANCE_VALUE;
        Destiny genDestiny = getDestinyFromModdedRng(moddedRng);
        _safeMint(wizardMinter, updatedItemID);
        _setTokenURI(updatedItemID, s_genTokenUris[uint256(genDestiny)]);
        emit NftMinted(wizardMinter, s_tokenCounter);
        
    }

    function setNumber() internal view returns (uint) {
        uint randNo = 0;
        randNo= uint (keccak256(abi.encodePacked (msg.sender, block.timestamp, randNo)));
        return randNo;
    }

    function getChanceArray() public pure returns (uint256[3] memory) {
        return [60, 90, MAX_CHANCE_VALUE];
    }

    function _initializeContract(string[3] memory genTokenUris) private {
        if (s_initialized) {
            revert MadWizard__AlreadyInitialized();
        }
        s_genTokenUris = genTokenUris;
        s_initialized = true;
    }

    function getDestinyFromModdedRng(uint256 moddedRng) public pure returns (Destiny) {
        uint256 cumulativeSum = 0;
        uint256[3] memory chanceArray = getChanceArray();
        for (uint256 i = 0; i < chanceArray.length; i++) {
            if (moddedRng >= cumulativeSum && moddedRng < chanceArray[i]) {
                return Destiny(i);
            }
            cumulativeSum = chanceArray[i];
        }
        revert MadWizard__RangeOutOfBounds();
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert MadWizard__TransferFailed();
        }
    }

    // Blast FUNCTIONs

    function claimMyContractsGas() external onlyOwner{
        BLAST.claimAllGas(address(this), msg.sender);
    }
    function claimMyContractsYield(address recipient, uint256 amount) external onlyOwner{
	    //This function is public meaning anyone can claim the yield
		BLAST.claimYield(address(this), recipient, amount);
    }
	function claimMyContractsAllYield(address recipient) external onlyOwner{
	    //This function is public meaning anyone can claim the yield
	    BLAST.claimAllYield(address(this), recipient);
    }

    function getgenTokenUris(uint256 index) public view returns (string memory) {
        return s_genTokenUris[index];
    }

    function getInitialized() public view returns (bool) {
        return s_initialized;
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }
}