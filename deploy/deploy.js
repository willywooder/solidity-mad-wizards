const { network } = require("hardhat")
const { developmentChains, VERIFICATION_BLOCK_CONFIRMATIONS } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")
const { storeImages, storeTokenUriMetadata } = require("../utils/uploadToPinata")

const MAX_SUPPLY = 999
const imagesLocation = "./images"
const metadataTemplate = {
    name: "",
    description: "",
    image: "",
    attributes: [
        {
            trait_type: "health",
            value: "",
        }
    ]
}

module.exports = async ({ getNamedAccounts, deployments }) => {
    
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const waitBlockConfirmations = developmentChains.includes(network.name)
        ? 1
        : VERIFICATION_BLOCK_CONFIRMATIONS

    log("----------------------------------------------------")
    let tokenUris
    if (process.env.UPLOAD_TO_PINATA == "true") {
        tokenUris = await handleTokenUris()
    }
    await storeTokenUriMetadata(metadataTemplate)
    const args = [tokenUris, MAX_SUPPLY]
    const MadWizard = await deploy("MadWizard", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: waitBlockConfirmations,
    })

    // Verify the deployment
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(MadWizard.address, args)
    }
    log("----------------------------------------------------")

    async function handleTokenUris() {
    // Check out https://github.com/PatrickAlphaC/nft-mix for a pythonic version of uploading
    // to the raw IPFS-daemon from https://docs.ipfs.io/how-to/command-line-quick-start/
    // You could also look at pinata https://www.pinata.cloud/
    tokenUris = []
    const { responses: imageUploadResponses, files } = await storeImages(imagesLocation)
    for (imageUploadResponseIndex in imageUploadResponses) {
        let tokenUriMetadata = { ...metadataTemplate }
        tokenUriMetadata.name = files[imageUploadResponseIndex].replace(".gif", "")
        tokenUriMetadata.description = `Wizard the Mad!`
        tokenUriMetadata.image = `ipfs://${imageUploadResponses[imageUploadResponseIndex].IpfsHash}`

        let rareness
        let rarity
        if (tokenUriMetadata.name == "MadGreenWizard"){
            rarity = "common"
        } else if (tokenUriMetadata.name == "MadPurpleWizard") {
            rarity = "epic"
        } else if (tokenUriMetadata.name == "MadRedWizard") {
            rarity = "legendary"
        }
        tokenUriMetadata.attributes[0].value = rarity
        console.log(`Uploading ${tokenUriMetadata.name}...`)
        const metadataUploadResponse = await storeTokenUriMetadata(tokenUriMetadata)
        tokenUris.push(`ipfs://${metadataUploadResponse.IpfsHash}`)
    }
    console.log("Token URIs uploaded! They are:")
    console.log(tokenUris)
    return tokenUris
    }

}

module.exports.tags = ["MadWizard", "UsingPictures"]
