const pinataSDK = require("@pinata/sdk")
const fs = require("fs")
const path = require("path")
require("dotenv").config()

const pinataApiKey = process.env.PINATA_API_KEY || ""
const pinataApiSecret = process.env.PINATA_API_SECRET || ""
const pinata = new pinataSDK(pinataApiKey, pinataApiSecret)

async function storeImages(imagesFilePath) {
    const fullImagesPath = path.resolve(imagesFilePath)

    // Filter the files in case the are a file that in not a .png
    const files = fs.readdirSync(fullImagesPath).filter((file) => file.includes(".gif"))

    let responses = []
    console.log("Uploading to IPFS")

    for (const fileIndex in files) {
        const readableStreamForFile = fs.createReadStream(`${fullImagesPath}/${files[fileIndex]}`)
        const options = {
            pinataMetadata: {
                name: files[fileIndex],
            },
        }
        try {
            await pinata
                .pinFileToIPFS(readableStreamForFile, options)
                .then((result) => {
                    responses.push(result)
                })
                .catch((err) => {
                    console.log(err)
                })
        } catch (error) {
            console.log(error)
        }
    }
    return { responses, files }
}

async function storeTokenUriMetadata(metadata) {
    const options = {
        pinataMetadata: {
            name: metadata.name,
        },
    }
    try {
        const response = await pinata.pinJSONToIPFS(metadata, options)
        return response
    } catch (error) {
        console.log(error)
    }
    return null
}

async function storeTokenUriMetadataPath(metadataLocation) {
    fs.readdir(metadataLocation, (err, files) => {
        files.forEach(file => {
            if (path.extname(file) === '.json') { // Check if the file is a JSON file
                const filePath = path.join(metadataLocation, file);
                fs.readFile(filePath, 'utf8', async (err, data) => {
                    if (err) {
                        console.error("Error reading file:", filePath, err);
                        return;
                    }
                    try {
                        const jsonContent = JSON.parse(data);
                        console.log(`Uploading ${jsonContent.name}...`)
                        const metadataUploadResponse = await storeTokenUriMetadata(jsonContent)
                        console.log(jsonContent)
                        tokenUris.push(`ipfs://${metadataUploadResponse.IpfsHash}`)
                    } catch (parseErr) {
                        console.error("Error parsing JSON from file:", filePath, parseErr);
                    }
                });
            }
        });
    });
}


module.exports = { storeImages, storeTokenUriMetadata, storeTokenUriMetadataPath }