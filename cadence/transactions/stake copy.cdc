import FlovatarNFTStaking from "../contracts/FlovatarNFTStaking.cdc"
import Flovatar from "../contracts/Flovatar.cdc"

pub fun hasStakingCollection(_ address: Address): Bool {
        return getAccount(address).capabilities.get<&FlovatarNFTStaking.Collection{FlovatarNFTStaking.NFTStakingCollectionPublic}>(FlovatarNFTStaking.CollectionPublicPath)!.check()
    }

transaction(nftID: UInt64) {

    let stakingCollectionRef: &FlovatarNFTStaking.Collection
    let nftCollectionRef: &Flovatar.Collection

    prepare(signer: AuthAccount) {

        // create staking collection
        if !hasStakingCollection(signer.address) {
            if signer.borrow<&FlovatarNFTStaking.Collection>(from: FlovatarNFTStaking.CollectionStoragePath) == nil {
                signer.save(<-FlovatarNFTStaking.createEmptyCollection(), to: FlovatarNFTStaking.CollectionStoragePath)
            }

            signer.capabilities.unpublish(FlovatarNFTStaking.CollectionPublicPath)

            let issuedCap = signer.capabilities.storage.issue(<&FlovatarNFTStaking.Collection>(FlovatarNFTStaking.CollectionStoragePath))

            signer.capabilities.publish(issuedCap, at: FlovatarNFTStaking.CollectionPublicPath)
        }

        self.stakingCollectionRef = signer.borrow<&FlovatarNFTStaking.Collection>(from: FlovatarNFTStaking.CollectionStoragePath)??panic("Couldn't borrow staking collection")

        self.nftCollectionRef = signer.borrow<&Flovatar.Collection>(from: Flovatar.CollectionStoragePath)??panic("Couldn't borrow staking collection")

    }

    execute {

        let nft <-self.nftCollectionRef.withdraw(withdrawID: nftID) as! @Flovatar.NFT

        self.stakingCollectionRef.stake(nft: <-nft)

    }
}