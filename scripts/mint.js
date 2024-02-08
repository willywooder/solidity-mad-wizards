const { ethers, network, getNamedAccounts, deployments} = require("hardhat")
const { moveBlocks } = require("../utils/move-blocks")

let MadWizard, MadWizardAddress, MadWizardInstance

async function mintAndList() {
    const { deployer } = await getNamedAccounts()
    const signer = await ethers.getSigner(deployer)
    MadWizard = await deployments.get("MadWizard")
    MadWizardAddress = MadWizard.address
    MadWizardInstance = await ethers.getContractAt(
        "MadWizard",
        MadWizardAddress,
        signer,
    )
    console.log("Minting NFT...")
    const mintTx = await MadWizardInstance.requestNft()
    const mintTxReceipt = await mintTx.wait(1)
    console.log(
        `Minted tokenId ${mintTxReceipt.logs[0].args.tokenId.toString()} from contract: ${
            MadWizardAddress
        }`
    )
    const UriTx = await MadWizardInstance.tokenURI(mintTxReceipt.logs[0].args.tokenId.toString())
    console.log(UriTx)
    if (network.config.chainId == 31337) {
        // Moralis has a hard time if you move more than 1 block!
        await moveBlocks(2, (sleepAmount = 1000))
    }
}

mintAndList()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
