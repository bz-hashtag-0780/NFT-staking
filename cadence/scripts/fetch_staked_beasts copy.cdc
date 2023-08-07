import FlovatarNFTStaking from "../contracts/FlovatarNFTStaking.cdc"

pub fun main(acct: Address): [AnyStruct] {
    var stakingCollection: [AnyStruct] = []

    let cap: Capability<&FlovatarNFTStaking.Collection{FlovatarNFTStaking.NFTStakingCollectionPublic}>? = getAccount(acct).capabilities.get<&FlovatarNFTStaking.Collection{FlovatarNFTStaking.NFTStakingCollectionPublic}>(FlovatarNFTStaking.CollectionPublicPath)
    var collectionRef:&FlovatarNFTStaking.Collection{FlovatarNFTStaking.NFTStakingCollectionPublic}?  = nil
    if(cap != nil) {
        collectionRef = cap!.borrow()
    }
    if(collectionRef != nil) {
        let beastIDs = collectionRef!.getIDs()

        for id in beastIDs {
            let borrowedBeast = collectionRef!.borrowBeast(id: id)!
            stakingCollection.append(borrowedBeast)
        }
    }
    return stakingCollection
}