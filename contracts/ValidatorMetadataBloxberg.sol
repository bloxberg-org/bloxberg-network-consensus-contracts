pragma solidity >=0.4.22 <0.6.0;

import "./libs/SafeMath.sol";
import "./interfaces/BaseOwnedSet.sol";
import "./RelaySet.sol";


contract ValidatorMetadata is BaseOwnedSet {

    struct ConsortiumMember {        
        address sender;
        string firstName;
        string lastName;
        string contactEmail;
        string researchInstitute;
        string researchField;
        string instituteAddress;
    }

    mapping (address => ConsortiumMember) consortiumMembers;

    event CreatedMetadata (
        address memberAddress
    );

    function createMetadata(
        string _firstName,
        string _lastName,
        string _contactEmail,
        string _researchInstitute,
        string _researchField,
        string _instituteAddress
    )
        public
        //isValidator(msg.sender)
    {
        
        ConsortiumMember storage tempMember = consortiumMembers[msg.sender];
        tempMember.firstName = _firstName;
        tempMember.lastName = _lastName;
        tempMember.contactEmail = _contactEmail;
        tempMember.researchInstitute = _researchInstitute;
        tempMember.researchField = _researchField;
        tempMember.instituteAddress = _instituteAddress;
        tempMember.sender = tx.origin;
        
        emit CreatedMetadata(msg.sender);
    }

    function validatorsMetadata(address memberAddress) public view returns (
        string memory,
        string memory,
        string memory,
        string memory,
        string memory,
        string memory,
        address sender
    ) {
        return (
            consortiumMembers[memberAddress].firstName,
            consortiumMembers[memberAddress].lastName,
            consortiumMembers[memberAddress].contactEmail,
            consortiumMembers[memberAddress].researchInstitute,
            consortiumMembers[memberAddress].researchField,
            consortiumMembers[memberAddress].instituteAddress,
            consortiumMembers[memberAddress].sender
        );
    }
}
