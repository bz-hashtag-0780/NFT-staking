import FlovatarNFTStaking from "./FlovatarNFTStaking.cdc"
import FlovatarNFTStakingRewards from "./FlovatarNFTStakingRewards.cdc"

pub contract FlovatarRaids {

    pub event ContractInitialized()
    pub event PlayerOptIn(player: Address, nftID: UInt64)

    access(self) var raidRecords: {UInt64: {UInt32: RaidRecord}}
    access(self) var playerOptIns: {Address: UInt64}
    access(self) var playerLockStartDates: {UInt64: UFix64}

    pub struct RaidRecord {
        pub let id: UInt32
        pub let attacker: UInt64
        pub let defender: UInt64
        pub let winner: UInt64

        init(id: UInt32, attacker: UInt64, defender: UInt64, winner: UInt64) {
            self.id = id
            self.attacker = attacker
            self.defender = defender
            self.winner = winner
        }
    }

    pub resource Player {
        pub fun optIn(nftID: UInt64) {
            
            // check if player has the nft in the staking collection
            let playerAddress = self.owner!.address
            let collectionRef = getAccount(playerAddress).getCapability(FlovatarNFTStaking.CollectionPublicPath)
                                                            .borrow<&FlovatarNFTStaking.Collection{FlovatarNFTStaking.NFTStakingCollectionPublic}>()

            if(collectionRef != nil) {
                let IDs = collectionRef!.getIDs()
                assert(IDs.contains(nftID), message: "This address does not hold the NFT")
            }
            
            // check if player has valid rewards
            if(FlovatarNFTStakingRewards.hasRewardItemOne(nftID: nftID) || FlovatarNFTStakingRewards.hasRewardItemTwo(nftID: nftID)) {
                FlovatarRaids.playerOptIns[playerAddress] = nftID

                emit PlayerOptIn(player: playerAddress, nftID: nftID)
            }
        }

        pub fun createNewGameMaster(): @GameMaster {
            return <-create GameMaster()
        }
    }

    pub resource GameMaster {
        pub fun randomRaid(attacker: UInt64) {

            // start lock timer
            FlovatarRaids.playerLockStartDates[attacker] = getCurrentBlock().timestamp
        }

        pub fun targetedRaid(attacker: UInt64, defender: UInt64) {
            if(attacker != defender) {
                if(FlovatarRaids.playerOptIns.values.contains(defender)) {

                    // start lock timer
                    FlovatarRaids.playerLockStartDates[attacker] = getCurrentBlock().timestamp
                }
            }

            
        }

    }

    pub fun createNewPlayer(): @Player {
        return <-create Player()
    }

    init() {
        self.raidRecords = {}
        self.playerOptIns = {}
        self.playerLockStartDates = {}

        emit ContractInitialized()
    }
}