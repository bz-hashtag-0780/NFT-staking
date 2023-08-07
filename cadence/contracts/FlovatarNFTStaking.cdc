import NonFungibleToken from "./NonFungibleToken.cdc"
import MetadataViews from "./MetadataViews.cdc"
import Flovatar from "./Flovatar.cdc"

pub contract FlovatarNFTStaking {

    pub event ContractInitialized()
    pub event Stake(id: UInt64, to: Address?)
    pub event Unstake(id: UInt64, from: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    access(self) var stakers: [Address]
    access(self) var stakingStartDates: {UInt64: UFix64}
    access(self) var adjustedStakingDates: {UInt64: UFix64}

    pub resource interface NFTStakingCollectionPublic {
        pub fun getIDs(): [UInt64]
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

        init() {
            self.stakedNFTs <- {}
        }

        pub fun getIDs(): [UInt64] {
            return self.stakedNFTs.keys
        }

        pub fun stake(nft: @Flovatar.NFT) {
            let id: UInt64 = nft.id

            let oldToken <- self.stakedNFTs[id] <- nft

            destroy oldToken

            // add new staker to the list
            FlovatarNFTStaking.addStaker(address: self.owner?.address!)

            // add timer
            FlovatarNFTStaking.stakingStartDates[id] = getCurrentBlock().timestamp
            FlovatarNFTStaking.adjustedStakingDates[id] = getCurrentBlock().timestamp

            emit Stake(id: id, to: self.owner?.address)
        }

        pub fun unstake(id: UInt64): @Flovatar.NFT {
            let token <- self.stakedNFTs.remove(key: id) ?? panic("missing NFT")

            // remove timer
            FlovatarNFTStaking.stakingStartDates[id] = nil
            FlovatarNFTStaking.stakingStartDates.remove(key: id)
            FlovatarNFTStaking.adjustedStakingDates[id] = nil
            FlovatarNFTStaking.adjustedStakingDates.remove(key: id)

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

    access(account) fun updateAdjustedStakingDate(id: UInt64, rewardPerSecond: UFix64) {
        if(self.adjustedStakingDates[id] != nil) {
            self.adjustedStakingDates[id] = self.adjustedStakingDates[id]! + rewardPerSecond
        }
    }

    pub fun getStakingStartDate(id: UInt64): UFix64? {
        return self.stakingStartDates[id]
    }

    pub fun getAllStakingStartDates(): {UInt64: UFix64} {
        return self.stakingStartDates
    }

    pub fun getAdjustedStakingDate(id: UInt64): UFix64? {
        return self.adjustedStakingDates[id]
    }

    pub fun getAllAdjustedStakingDates(): {UInt64: UFix64} {
        return self.adjustedStakingDates
    }

    pub fun getStakers(): [Address] {
        return self.stakers
    }

    init() {
        self.stakers = []
        self.stakingStartDates = {}
        self.adjustedStakingDates = {}
        
        self.CollectionStoragePath = /storage/FlovatarNFTStakingCollection
        self.CollectionPublicPath = /public/FlovatarNFTStakingCollection

        emit ContractInitialized()
    }

}