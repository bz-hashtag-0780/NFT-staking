import NonFungibleToken from "./NonFungibleToken.cdc"
import MetadataViews from "./MetadataViews.cdc"
import Flovatar from "./Flovatar.cdc"

pub contract FlovatarNFTStaking {

    pub event Stake(id: UInt64, to: Address?)
    pub event Unstake(id: UInt64, from: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    access(self) var stakers: [Address]

    pub resource interface NFTStakingCollectionPublic {
        pub fun getIDs(): [UInt64]
        pub fun getTimedStaked(id: UInt64): UFix64?
        pub fun getAllTimedStaked(): {UInt64: UFix64}
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        // pub fun borrowFlovatar(id: UInt64): &Flovatar.NFT{Flovatar.Public, MetadataViews.Resolver}? {
        //     post {
        //         (result == nil) || (result?.id == id):
        //             "Cannot borrow Flovatar reference: The ID of the returned reference is incorrect"
        //     }
        // }
    }

    pub resource Collection: NFTStakingCollectionPublic {

        pub var stakedNFTs: @{UInt64: Flovatar.NFT}
        access(self) var timedStaked: {UInt64: UFix64}

        init() {
            self.stakedNFTs <- {}
            self.timedStaked = {}
        }

        pub fun getIDs(): [UInt64] {
            return self.stakedNFTs.keys
        }

        pub fun getTimedStaked(id: UInt64): UFix64? {
            return self.timedStaked[id]
        }

        pub fun getAllTimedStaked(): {UInt64: UFix64} {
            return self.timedStaked
        }

        pub fun stake(nft: @Flovatar.NFT) {
            let id: UInt64 = nft.id

            let oldToken <- self.stakedNFTs[id] <- nft

            destroy oldToken

            // add new staker to the list
            FlovatarNFTStaking.addStaker(address: self.owner?.address!)

            // add timer
            self.timedStaked[id] = getCurrentBlock().timestamp

            emit Stake(id: id, to: self.owner?.address)
        }

        pub fun unstake(id: UInt64): @Flovatar.NFT {
            let token <- self.stakedNFTs.remove(key: id) ?? panic("missing NFT")

            // remove timer
            self.timedStaked.remove(key: id)

            emit Unstake(id: token.id, from: self.owner?.address)

            return <-token
        } 

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.stakedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // pub fun borrowFlovatar(id: UInt64): &Flovatar.NFT{Flovatar.Public, MetadataViews.Resolver}? {
        //     if self.stakedNFTs[id] != nil {
        //         let ref = (&self.stakedNFTs[id] as &Flovatar.NFT?)!
        //         return ref as &Flovatar.NFT{Flovatar.Public, MetadataViews.Resolver}
        //     } else {
        //         return nil
        //     }
        // }

        destroy() {
            destroy self.stakedNFTs
        }

    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    access(contract) fun addStaker(address: Address) {
        if(!FlovatarNFTStaking.stakers.contains(address)) {
            FlovatarNFTStaking.stakers.append(address)
        }
    }

    init() {
        self.stakers = []
        
        self.CollectionStoragePath = /storage/FlovatarNFTStakingCollection
        self.CollectionPublicPath = /public/FlovatarNFTStakingCollection
    }

}