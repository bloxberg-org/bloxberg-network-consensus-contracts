pragma solidity ^0.4.24;

import "./libs/SafeMath.sol";
import "./interfaces/IBallotsStorage.sol";
import "./interfaces/IProxyStorage.sol";
import "./interfaces/IKeysManager.sol";
import "./interfaces/IValidatorMetadata.sol";
import "./eternal-storage/EternalStorage.sol";
import "./abstracts/EnumThresholdTypes.sol";


contract ValidatorMetadata is EternalStorage, EnumThresholdTypes, IValidatorMetadata {
    using SafeMath for uint256;

    bytes32 internal constant INIT_METADATA_DISABLED = keccak256("initMetadataDisabled");
    bytes32 internal constant OWNER = keccak256("owner");
    bytes32 internal constant PROXY_STORAGE = keccak256("proxyStorage");

    bytes32 internal constant CONFIRMATIONS = "confirmations";
    bytes32 internal constant CONTACT_EMAIL = "contactEmail";
    bytes32 internal constant CREATED_DATE = "createdDate";
    bytes32 internal constant EXPIRATION_DATE = "expirationDate";
    bytes32 internal constant FIRST_NAME = "firstName";
    bytes32 internal constant FULL_ADDRESS = "fullAddress";
    bytes32 internal constant IS_COMPANY = "isCompany";
    bytes32 internal constant LAST_NAME = "lastName";
    bytes32 internal constant LICENSE_ID = "licenseId";
    bytes32 internal constant MIN_THRESHOLD = "minThreshold";
    bytes32 internal constant STATE = "state";
    bytes32 internal constant UPDATED_DATE = "updatedDate";
    bytes32 internal constant VOTERS = "voters";
    bytes32 internal constant ZIP_CODE = "zipcode";

    event MetadataCleared(address indexed miningKey);
    event MetadataCreated(address indexed miningKey);
    event MetadataMoved(address indexed oldMiningKey, address indexed newMiningKey);
    event ChangeRequestInitiated(address indexed miningKey);
    event CancelledRequest(address indexed miningKey);
    event Confirmed(address indexed miningKey, address votingSender, address votingSenderMiningKey);
    event FinalizedChange(address indexed miningKey);

    modifier onlyValidVotingKey(address _votingKey) {
        require(_getKeysManager().isVotingActive(_votingKey));
        _;
    }

    modifier onlyFirstTime(address _votingKey) {
        address miningKey = _getKeysManager().getMiningKeyByVoting(_votingKey);
        require(_getCreatedDate(false, miningKey) == 0);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == addressStorage[OWNER]);
        _;
    }

    modifier onlyKeysManager() {
        require(msg.sender == address(_getKeysManager()));
        _;
    }

    function clearMetadata(address _miningKey)
        external
        onlyKeysManager
    {
        if (_ifPendingExist(_miningKey)) {
            _deleteMetadata(true, _miningKey);
        }
        _deleteMetadata(false, _miningKey);
        emit MetadataCleared(_miningKey);
    }

    function moveMetadata(address _oldMiningKey, address _newMiningKey)
        external
        onlyKeysManager
    {
        if (_ifPendingExist(_oldMiningKey)) {
            _moveMetadata(true, _oldMiningKey, _newMiningKey);
        }
        _moveMetadata(false, _oldMiningKey, _newMiningKey);
        emit MetadataMoved(_oldMiningKey, _newMiningKey);
    }

    function proxyStorage() public view returns (address) {
        return addressStorage[PROXY_STORAGE];
    }

    function getValidatorName(address _miningKey) public view returns (
        bytes32 firstName,
        bytes32 lastName
    ) {
        firstName = _getFirstName(false, _miningKey);
        lastName = _getLastName(false, _miningKey);
    }

    function validators(address _miningKey) public view returns (
        bytes32 firstName,
        bytes32 lastName,
        bytes32 licenseId,
        string fullAddress,
        bytes32 state,
        bytes32 zipcode,
        uint256 expirationDate,
        uint256 createdDate,
        uint256 updatedDate,
        uint256 minThreshold,
        bytes32 contactEmail,
        bool isCompany
    ) {
        return _validators(false, _miningKey);
    }

    function pendingChanges(address _miningKey) public view returns (
        bytes32 firstName,
        bytes32 lastName,
        bytes32 licenseId,
        string fullAddress,
        bytes32 state,
        bytes32 zipcode,
        uint256 expirationDate,
        uint256 createdDate,
        uint256 updatedDate,
        uint256 minThreshold,
        bytes32 contactEmail,
        bool isCompany
    ) {
        return _validators(true, _miningKey);
    }

    function confirmations(address _miningKey) public view returns (
        uint256 count,
        address[] voters
    ) {
        voters = _getConfirmationsVoters(_miningKey);
        count = voters.length;
    }

    function initMetadataDisabled() public view returns(bool) {
        return boolStorage[INIT_METADATA_DISABLED];
    }

    function initMetadata( // used for migration from v1.0 contracts
        bytes32 _firstName,
        bytes32 _lastName,
        bytes32 _licenseId,
        string _fullAddress,
        bytes32 _state,
        bytes32 _zipcode,
        uint256 _expirationDate,
        uint256 _createdDate,
        uint256 _updatedDate,
        uint256 _minThreshold,
        address _miningKey
    ) public onlyOwner {
        require(_getKeysManager().isMiningActive(_miningKey));
        require(_getCreatedDate(false, _miningKey) == 0);
        require(_createdDate != 0);
        require(!initMetadataDisabled());
        _setMetadata(
            false,
            _miningKey,
            _firstName,
            _lastName,
            _licenseId,
            _fullAddress,
            _state,
            _zipcode,
            _expirationDate,
            _createdDate,
            _updatedDate,
            _minThreshold
        );
    }

    function initMetadataDisable() public onlyOwner {
        boolStorage[INIT_METADATA_DISABLED] = true;
    }

    function createMetadata(
        bytes32 _firstName,
        bytes32 _lastName,
        bytes32 _licenseId,
        string _fullAddress,
        bytes32 _state,
        bytes32 _zipcode,
        uint256 _expirationDate,
        bytes32 _contactEmail,
        bool _isCompany
    )
        public
        onlyValidVotingKey(msg.sender)
        onlyFirstTime(msg.sender)
    {
        address miningKey = _getKeysManager().getMiningKeyByVoting(msg.sender);
        _setMetadata(
            false,
            miningKey,
            _firstName,
            _lastName,
            _licenseId,
            _fullAddress,
            _state,
            _zipcode,
            _expirationDate,
            getTime(),
            0,
            getMinThreshold()
        );
        _setContactEmail(false, miningKey, _contactEmail);
        _setIsCompany(false, miningKey, _isCompany);
        emit MetadataCreated(miningKey);
    }

    function changeRequest(
        bytes32 _firstName,
        bytes32 _lastName,
        bytes32 _licenseId,
        string _fullAddress,
        bytes32 _state,
        bytes32 _zipcode,
        uint256 _expirationDate,
        bytes32 _contactEmail,
        bool _isCompany
    )
        public
        onlyValidVotingKey(msg.sender)
    {
        address miningKey = _getKeysManager().getMiningKeyByVoting(msg.sender);
        _setMetadata(
            true,
            miningKey,
            _firstName,
            _lastName,
            _licenseId,
            _fullAddress,
            _state,
            _zipcode,
            _expirationDate,
            _getCreatedDate(false, miningKey),
            getTime(),
            _getMinThreshold(false, miningKey)
        );
        _setContactEmail(true, miningKey, _contactEmail);
        _setIsCompany(true, miningKey, _isCompany);
        emit ChangeRequestInitiated(miningKey);
    }

    function cancelPendingChange() public onlyValidVotingKey(msg.sender) returns(bool) {
        address miningKey = _getKeysManager().getMiningKeyByVoting(msg.sender);
        _deleteMetadata(true, miningKey);
        emit CancelledRequest(miningKey);
        return true;
    }

    function isValidatorAlreadyVoted(address _miningKey, address _voterMiningKey)
        public
        view
        returns(bool)
    {
        IKeysManager keysManager = _getKeysManager();
        address historyVoterMiningKey = _voterMiningKey;
        uint256 maxDeep = keysManager.maxOldMiningKeysDeepCheck();

        for (uint256 i = 0; i < maxDeep; i++) {
            if (_isValidatorAlreadyVoted(_miningKey, historyVoterMiningKey)) {
                return true;
            }
            address oldMiningKey = keysManager.getMiningKeyHistory(historyVoterMiningKey);
            if (oldMiningKey == address(0)) {
                break;
            }
            historyVoterMiningKey = oldMiningKey;
        }

        return false;
    }

    function confirmPendingChange(address _miningKey)
        public
        onlyValidVotingKey(msg.sender)
    {
        address voterMiningKey = _getKeysManager().getMiningKeyByVoting(msg.sender);
        require(voterMiningKey != _miningKey);
        require(!isValidatorAlreadyVoted(_miningKey, voterMiningKey));

        uint256 confirmationsLimit = _getBallotsStorage().metadataChangeConfirmationsLimit();
        require(_getConfirmationsVoters(_miningKey).length < confirmationsLimit);

        _confirmationsVoterAdd(_miningKey, voterMiningKey);
        emit Confirmed(_miningKey, msg.sender, voterMiningKey);
    }

    function finalize(address _miningKey) public onlyValidVotingKey(msg.sender) {
        require(_ifPendingExist(_miningKey));
        uint256 count = _getConfirmationsVoters(_miningKey).length;
        uint256 minThreshold = _getMinThreshold(true, _miningKey);
        require(count >= minThreshold);
        _setFirstName(false, _miningKey, _getFirstName(true, _miningKey));
        _setLastName(false, _miningKey, _getLastName(true, _miningKey));
        _setLicenseId(false, _miningKey, _getLicenseId(true, _miningKey));
        _setState(false, _miningKey, _getState(true, _miningKey));
        _setFullAddress(false, _miningKey, _getFullAddress(true, _miningKey));
        _setZipcode(false, _miningKey, _getZipcode(true, _miningKey));
        _setExpirationDate(false, _miningKey, _getExpirationDate(true, _miningKey));
        _setCreatedDate(false, _miningKey, _getCreatedDate(true, _miningKey));
        _setUpdatedDate(false, _miningKey, _getUpdatedDate(true, _miningKey));
        _setMinThreshold(false, _miningKey, minThreshold);
        _setContactEmail(false, _miningKey, _getContactEmail(true, _miningKey));
        _setIsCompany(false, _miningKey, _getIsCompany(true, _miningKey));
        _deleteMetadata(true, _miningKey);
        emit FinalizedChange(_miningKey);
    }

    function getTime() public view returns(uint256) {
        return now;
    }

    function getMinThreshold() public view returns(uint256) {
        return _getBallotsStorage().getBallotThreshold(uint256(ThresholdTypes.MetadataChange));
    }

    function _storeName(bool _pending) private pure returns(string) {
        return _pending ? "pendingChanges" : "validators";
    }

    function _getBallotsStorage() private view returns(IBallotsStorage) {
        return IBallotsStorage(IProxyStorage(proxyStorage()).getBallotsStorage());
    }

    function _getContactEmail(bool _pending, address _miningKey)
        private
        view
        returns(bytes32)
    {
        return bytes32Storage[keccak256(abi.encode(
            _storeName(_pending), _miningKey, CONTACT_EMAIL
        ))];
    }

    function _getFirstName(bool _pending, address _miningKey)
        private
        view
        returns(bytes32)
    {
        return bytes32Storage[keccak256(abi.encode(
            _storeName(_pending), _miningKey, FIRST_NAME
        ))];
    }

    function _getIsCompany(bool _pending, address _miningKey)
        private
        view
        returns(bool)
    {
        return boolStorage[keccak256(abi.encode(
            _storeName(_pending), _miningKey, IS_COMPANY
        ))];
    }

    function _getLastName(bool _pending, address _miningKey)
        private
        view
        returns(bytes32)
    {
        return bytes32Storage[keccak256(abi.encode(
            _storeName(_pending), _miningKey, LAST_NAME
        ))];
    }

    function _getLicenseId(bool _pending, address _miningKey)
        private
        view
        returns(bytes32)
    {
        return bytes32Storage[keccak256(abi.encode(
            _storeName(_pending), _miningKey, LICENSE_ID
        ))];
    }

    function _getFullAddress(bool _pending, address _miningKey)
        private
        view
        returns(string)
    {
        return stringStorage[keccak256(abi.encode(
            _storeName(_pending), _miningKey, FULL_ADDRESS
        ))];
    }

    function _getState(bool _pending, address _miningKey)
        private
        view
        returns(bytes32)
    {
        return bytes32Storage[keccak256(abi.encode(
            _storeName(_pending), _miningKey, STATE
        ))];
    }

    function _getZipcode(bool _pending, address _miningKey)
        private
        view
        returns(bytes32)
    {
        return bytes32Storage[keccak256(abi.encode(
            _storeName(_pending), _miningKey, ZIP_CODE
        ))];
    }

    function _getExpirationDate(bool _pending, address _miningKey)
        private
        view
        returns(uint256)
    {
        return uintStorage[keccak256(abi.encode(
            _storeName(_pending), _miningKey, EXPIRATION_DATE
        ))];
    }

    function _getCreatedDate(bool _pending, address _miningKey)
        private
        view
        returns(uint256)
    {
        return uintStorage[keccak256(abi.encode(
            _storeName(_pending), _miningKey, CREATED_DATE
        ))];
    }

    function _getUpdatedDate(bool _pending, address _miningKey)
        private
        view
        returns(uint256)
    {
        return uintStorage[keccak256(abi.encode(
            _storeName(_pending), _miningKey, UPDATED_DATE
        ))];
    }

    function _getMinThreshold(bool _pending, address _miningKey)
        private
        view
        returns(uint256)
    {
        return uintStorage[keccak256(abi.encode(
            _storeName(_pending), _miningKey, MIN_THRESHOLD
        ))];
    }

    function _getConfirmationsVoters(address _miningKey)
        private
        view
        returns(address[] voters)
    {
        voters = addressArrayStorage[keccak256(abi.encode(
            CONFIRMATIONS, _miningKey, VOTERS
        ))];
    }

    function _getKeysManager() private view returns(IKeysManager) {
        return IKeysManager(IProxyStorage(proxyStorage()).getKeysManager());
    }

    function _ifPendingExist(address _miningKey) private view returns(bool) {
        return _getCreatedDate(true, _miningKey) > 0;
    }

    function _isValidatorAlreadyVoted(address _miningKey, address _voterMiningKey)
        private
        view
        returns(bool)
    {
        uint256 count;
        address[] memory voters;
        (count, voters) = confirmations(_miningKey);
        for (uint256 i = 0; i < count; i++) {
            if (voters[i] == _voterMiningKey) {
                return true;
            }
        }
        return false;
    }

    function _deleteMetadata(bool _pending, address _miningKey) private {
        string memory _store = _storeName(_pending);
        delete bytes32Storage[keccak256(abi.encode(_store, _miningKey, FIRST_NAME))];
        delete bytes32Storage[keccak256(abi.encode(_store, _miningKey, LAST_NAME))];
        delete bytes32Storage[keccak256(abi.encode(_store, _miningKey, LICENSE_ID))];
        delete bytes32Storage[keccak256(abi.encode(_store, _miningKey, STATE))];
        delete stringStorage[keccak256(abi.encode(_store, _miningKey, FULL_ADDRESS))];
        delete bytes32Storage[keccak256(abi.encode(_store, _miningKey, ZIP_CODE))];
        delete uintStorage[keccak256(abi.encode(_store, _miningKey, EXPIRATION_DATE))];
        delete uintStorage[keccak256(abi.encode(_store, _miningKey, CREATED_DATE))];
        delete uintStorage[keccak256(abi.encode(_store, _miningKey, UPDATED_DATE))];
        delete uintStorage[keccak256(abi.encode(_store, _miningKey, MIN_THRESHOLD))];
        delete bytes32Storage[keccak256(abi.encode(_store, _miningKey, CONTACT_EMAIL))];
        delete boolStorage[keccak256(abi.encode(_store, _miningKey, IS_COMPANY))];
        if (_pending) {
            _confirmationsVotersClear(_miningKey);
        }
    }

    function _moveMetadata(bool _pending, address _oldMiningKey, address _newMiningKey) private {
        _setMetadata(
            _pending,
            _newMiningKey,
            _getFirstName(_pending, _oldMiningKey),
            _getLastName(_pending, _oldMiningKey),
            _getLicenseId(_pending, _oldMiningKey),
            _getFullAddress(_pending, _oldMiningKey),
            _getState(_pending, _oldMiningKey),
            _getZipcode(_pending, _oldMiningKey),
            _getExpirationDate(_pending, _oldMiningKey),
            _getCreatedDate(_pending, _oldMiningKey),
            _getUpdatedDate(_pending, _oldMiningKey),
            _getMinThreshold(_pending, _oldMiningKey)
        );
        _setContactEmail(_pending, _newMiningKey, _getContactEmail(_pending, _oldMiningKey));
        _setIsCompany(_pending, _newMiningKey, _getIsCompany(_pending, _oldMiningKey));

        if (_pending) {
            _confirmationsVotersCopy(_oldMiningKey, _newMiningKey);
        }

        _deleteMetadata(_pending, _oldMiningKey);
    }

    function _setContactEmail(bool _pending, address _miningKey, bytes32 _contactEmail) private {
        bytes32Storage[keccak256(abi.encode(
            _storeName(_pending),
            _miningKey,
            CONTACT_EMAIL
        ))] = _contactEmail;
    }

    function _setFirstName(bool _pending, address _miningKey, bytes32 _firstName) private {
        bytes32Storage[keccak256(abi.encode(
            _storeName(_pending),
            _miningKey,
            FIRST_NAME
        ))] = _firstName;
    }

    function _setIsCompany(bool _pending, address _miningKey, bool _isCompany) private {
        boolStorage[keccak256(abi.encode(
            _storeName(_pending),
            _miningKey,
            IS_COMPANY
        ))] = _isCompany;
    }

    function _setLastName(bool _pending, address _miningKey, bytes32 _lastName) private {
        bytes32Storage[keccak256(abi.encode(
            _storeName(_pending),
            _miningKey,
            LAST_NAME
        ))] = _lastName;
    }

    function _setLicenseId(bool _pending, address _miningKey, bytes32 _licenseId) private {
        bytes32Storage[keccak256(abi.encode(
            _storeName(_pending),
            _miningKey,
            LICENSE_ID
        ))] = _licenseId;
    }

    function _setState(bool _pending, address _miningKey, bytes32 _state) private {
        bytes32Storage[keccak256(abi.encode(
            _storeName(_pending),
            _miningKey,
            STATE
        ))] = _state;
    }

    function _setFullAddress(
        bool _pending,
        address _miningKey,
        string _fullAddress
    ) private {
        require(bytes(_fullAddress).length <= 200);
        stringStorage[keccak256(abi.encode(
            _storeName(_pending),
            _miningKey,
            FULL_ADDRESS
        ))] = _fullAddress;
    }

    function _setZipcode(bool _pending, address _miningKey, bytes32 _zipcode) private {
        bytes32Storage[keccak256(abi.encode(
            _storeName(_pending),
            _miningKey,
            ZIP_CODE
        ))] = _zipcode;
    }

    function _setExpirationDate(
        bool _pending,
        address _miningKey,
        uint256 _expirationDate
    ) private {
        uintStorage[keccak256(abi.encode(
            _storeName(_pending),
            _miningKey,
            EXPIRATION_DATE
        ))] = _expirationDate;
    }

    function _setCreatedDate(
        bool _pending,
        address _miningKey,
        uint256 _createdDate
    ) private {
        uintStorage[keccak256(abi.encode(
            _storeName(_pending),
            _miningKey,
            CREATED_DATE
        ))] = _createdDate;
    }

    function _setUpdatedDate(
        bool _pending,
        address _miningKey,
        uint256 _updatedDate
    ) private {
        uintStorage[keccak256(abi.encode(
            _storeName(_pending),
            _miningKey,
            UPDATED_DATE
        ))] = _updatedDate;
    }

    function _setMetadata(
        bool _pending,
        address _miningKey,
        bytes32 _firstName,
        bytes32 _lastName,
        bytes32 _licenseId,
        string _fullAddress,
        bytes32 _state,
        bytes32 _zipcode,
        uint256 _expirationDate,
        uint256 _createdDate,
        uint256 _updatedDate,
        uint256 _minThreshold
    ) private {
        _setFirstName(_pending, _miningKey, _firstName);
        _setLastName(_pending, _miningKey, _lastName);
        _setLicenseId(_pending, _miningKey, _licenseId);
        _setState(_pending, _miningKey, _state);
        _setFullAddress(_pending, _miningKey, _fullAddress);
        _setZipcode(_pending, _miningKey, _zipcode);
        _setExpirationDate(_pending, _miningKey, _expirationDate);
        _setCreatedDate(_pending, _miningKey, _createdDate);
        _setUpdatedDate(_pending, _miningKey, _updatedDate);
        _setMinThreshold(_pending, _miningKey, _minThreshold);
        if (_pending) {
            _confirmationsVotersClear(_miningKey);
        }
    }

    function _setMinThreshold(
        bool _pending,
        address _miningKey,
        uint256 _minThreshold
    ) private {
        uintStorage[keccak256(abi.encode(
            _storeName(_pending),
            _miningKey,
            MIN_THRESHOLD
        ))] = _minThreshold;
    }

    function _confirmationsVoterAdd(address _miningKey, address _voterMiningKey) private {
        addressArrayStorage[keccak256(abi.encode(
            CONFIRMATIONS, _miningKey, VOTERS
        ))].push(_voterMiningKey);
    }

    function _confirmationsVotersClear(address _miningKey) private {
        delete addressArrayStorage[keccak256(abi.encode(
            CONFIRMATIONS, _miningKey, VOTERS
        ))];
    }

    function _confirmationsVotersCopy(address _oldMiningKey, address _newMiningKey) private {
        address[] memory voters = _getConfirmationsVoters(_oldMiningKey);
        for (uint256 i = 0; i < voters.length; i++) {
            _confirmationsVoterAdd(_newMiningKey, voters[i]);
        }
    }

    function _validators(bool _pending, address _miningKey) private view returns (
        bytes32 firstName,
        bytes32 lastName,
        bytes32 licenseId,
        string fullAddress,
        bytes32 state,
        bytes32 zipcode,
        uint256 expirationDate,
        uint256 createdDate,
        uint256 updatedDate,
        uint256 minThreshold,
        bytes32 contactEmail,
        bool isCompany
    ) {
        firstName = _getFirstName(_pending, _miningKey);
        lastName = _getLastName(_pending, _miningKey);
        licenseId = _getLicenseId(_pending, _miningKey);
        fullAddress = _getFullAddress(_pending, _miningKey);
        state = _getState(_pending, _miningKey);
        zipcode = _getZipcode(_pending, _miningKey);
        expirationDate = _getExpirationDate(_pending, _miningKey);
        createdDate = _getCreatedDate(_pending, _miningKey);
        updatedDate = _getUpdatedDate(_pending, _miningKey);
        minThreshold = _getMinThreshold(_pending, _miningKey);
        contactEmail = _getContactEmail(_pending, _miningKey);
        isCompany = _getIsCompany(_pending, _miningKey);
    }

}
