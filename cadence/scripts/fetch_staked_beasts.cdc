import FlovatarNFTStaking from "../contracts/FlovatarNFTStaking.cdc"

pub fun main(acct: Address): [AnyStruct] {
    var stakingCollection: [AnyStruct] = []

    let collectionRef = getAccount(acct).capabilities.get<&BasicBeastsNFTStaking.Collection{BasicBeastsNFTStaking.NFTStakingCollectionPublic}>(BasicBeastsNFTStaking.CollectionPublicPath)
    

    if(collectionRef != nil) {
        let beastIDs = collectionRef!.getIDs()

        for id in beastIDs {
            let borrowedBeast = collectionRef!.borrowBeast(id: id)!
            stakingCollection.append(borrowedBeast)
        }
    }
    return stakingCollection
}