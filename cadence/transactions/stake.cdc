import BasicBeastsNFTStaking from "../contracts/BasicBeastsNFTStaking.cdc"
import BasicBeasts from "../contracts/BasicBeasts.cdc"

pub fun hasStakingCollection(_ address: Address): Bool {
        return getAccount(address).capabilities.get<&BasicBeastsNFTStaking.Collection{BasicBeastsNFTStaking.NFTStakingCollectionPublic}>(BasicBeastsNFTStaking.CollectionPublicPath) == nil
    }

transaction(nftID: UInt64) {

    let stakingCollectionRef: &BasicBeastsNFTStaking.Collection
    let nftCollectionRef: &BasicBeasts.Collection

    prepare(signer: AuthAccount) {

        // create staking collection
        if !hasStakingCollection(signer.address) {
            if signer.borrow<&BasicBeastsNFTStaking.Collection>(from: BasicBeastsNFTStaking.CollectionStoragePath) == nil {
                signer.save(<-BasicBeastsNFTStaking.createEmptyCollection(), to: BasicBeastsNFTStaking.CollectionStoragePath)
            }

            signer.capabilities.unpublish(BasicBeastsNFTStaking.CollectionPublicPath)

            signer.capabilities.publish(signer.capabilities.storage.issue<&BasicBeastsNFTStaking.Collection>(BasicBeastsNFTStaking.CollectionStoragePath), at: BasicBeastsNFTStaking.CollectionPublicPath)
        }

        self.stakingCollectionRef = signer.borrow<&BasicBeastsNFTStaking.Collection>(from: BasicBeastsNFTStaking.CollectionStoragePath)??panic("Couldn't borrow staking collection")

        self.nftCollectionRef = signer.borrow<&BasicBeasts.Collection>(from: BasicBeasts.CollectionStoragePath)??panic("Couldn't borrow staking collection")

    }

    execute {

        let nft <-self.nftCollectionRef.withdraw(withdrawID: nftID) as! @BasicBeasts.NFT

        self.stakingCollectionRef.stake(nft: <-nft)

    }
}