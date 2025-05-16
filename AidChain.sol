// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Humanitarian Aid Supply Chain Smart Contract System
 * @dev A set of contracts managing decentralized identity, aid tokens, and delivery verification
 *
 * DEPLOYMENT SEQUENCE:
 * 1. Deploy DIDRegistry first and note its address
 * 2. Deploy AidToken with the DIDRegistry address and relief agency address
 * 3. Deploy AidTokenHandler with the AidToken contract address
 */

/**
 * @title DIDRegistry
 * @dev Manages decentralized identity roles for aid distribution participants
 * @notice Stores and validates identity information for transporters, ground relief teams, and aid recipients
 */
contract DIDRegistry {
    // Relief agency address for access control
    address public reliefAgency;
    
    // Role types in the system
    enum Role {
        None,
        Transporter,
        GroundRelief,
        Recipient
    }
    
    // Structure for storing identity information
    struct DIDInfo {
        string did;       // Unique identifier (e.g., "transporter-0xABC123")
        Role role;        // Associated role
        string location;  // Geographic location (e.g., "Fiji", "Port Moresby")
    }
    
    // Address to DID information mapping (forward lookup)
    mapping(address => DIDInfo) public dids;
    
    // DID string to address mapping (reverse lookup)
    mapping(string => address) public didToAddress;
    
    // Role-specific address registries
    address[] public transporterAddresses;
    address[] public groundReliefAddresses;
    address[] public recipientAddresses;
    
    // Events
    event RoleRegistered(address indexed user, Role role, string location);
    
    /**
     * @dev Sets the relief agency address during deployment
     * @param _reliefAgency Address of the relief agency with administrative privileges
     */
    constructor(address _reliefAgency) {
        require(_reliefAgency != address(0), "Invalid relief agency address");
        reliefAgency = _reliefAgency;
    }
    
    // Access control modifier
    modifier onlyReliefAgency() {
        require(msg.sender == reliefAgency, "Only relief agency can call this function");
        _;
    }
    
    /**
     * @dev Internal function to register a user with a specific role
     * @param user Address to register
     * @param roleString Role prefix for DID generation
     * @param _role Role enumeration value
     * @param _location Geographic location
     */
    function internalRegisterDID(
        address user,
        string memory roleString,
        Role _role,
        string memory _location
    ) internal {
        require(user != address(0), "Invalid address");
        require(bytes(dids[user].did).length == 0, "Address already registered");
        
        string memory autoDID = string(abi.encodePacked(roleString, toAsciiString(user)));
        require(didToAddress[autoDID] == address(0), "DID already in use");
        
        dids[user] = DIDInfo(autoDID, _role, _location);
        didToAddress[autoDID] = user;
        
        if (_role == Role.Transporter) {
            transporterAddresses.push(user);
        } else if (_role == Role.GroundRelief) {
            groundReliefAddresses.push(user);
        } else if (_role == Role.Recipient) {
            recipientAddresses.push(user);
        }
        
        emit RoleRegistered(user, _role, _location);
    }
    
    /**
     * @dev Register a new transporter
     * @param user Address to register
     * @param location Geographic location
     */
    function registerTransporterDID(address user, string memory location) public onlyReliefAgency {
        internalRegisterDID(user, "transporter-", Role.Transporter, location);
    }
    
    /**
     * @dev Register a new ground relief team
     * @param user Address to register
     * @param location Geographic location
     */
    function registerGroundReliefDID(address user, string memory location) public onlyReliefAgency {
        internalRegisterDID(user, "groundrelief-", Role.GroundRelief, location);
    }
    
    /**
     * @dev Register a new aid recipient
     * @param user Address to register
     * @param location Geographic location
     */
    function registerRecipientDID(address user, string memory location) public onlyReliefAgency {
        internalRegisterDID(user, "recipient-", Role.Recipient, location);
    }
    
    /**
     * @dev Get the role assigned to a specific address
     * @param user Address to check
     * @return Role enumeration value
     */
    function getRole(address user) public view returns (Role) {
        return dids[user].role;
    }
    
    /**
     * @dev Get the location assigned to a specific address
     * @param user Address to check
     * @return Location string
     */
    function getLocation(address user) public view returns (string memory) {
        return dids[user].location;
    }
    
    /**
     * @dev Validate that a DID has the expected role prefix
     * @param user Address to validate
     * @param expectedPrefix Expected prefix string
     * @return True if the prefix matches
     */
    function validateDIDPrefix(address user, string memory expectedPrefix) public view returns (bool) {
        string memory userDID = dids[user].did;
        bytes memory didBytes = bytes(userDID);
        bytes memory prefixBytes = bytes(expectedPrefix);
        
        if (didBytes.length < prefixBytes.length) return false;
        
        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (didBytes[i] != prefixBytes[i]) return false;
        }
        
        return true;
    }
    
    /**
     * @dev Get all registered transporter addresses
     * @return Array of transporter addresses
     */
    function getAllTransporters() external view returns (address[] memory) {
        return transporterAddresses;
    }
    
    /**
     * @dev Get all registered ground relief addresses
     * @return Array of ground relief addresses
     */
    function getAllGroundRelief() external view returns (address[] memory) {
        return groundReliefAddresses;
    }
    
    /**
     * @dev Get all registered recipient addresses
     * @return Array of recipient addresses
     */
    function getAllRecipients() external view returns (address[] memory) {
        return recipientAddresses;
    }
    
    /**
     * @dev Transfer relief agency role to a new address
     * @param newReliefAgency New relief agency address
     */
    function transferReliefAgency(address newReliefAgency) public onlyReliefAgency {
        require(newReliefAgency != address(0), "Invalid new relief agency address");
        reliefAgency = newReliefAgency;
    }
    
    /**
     * @dev Convert an address to its ASCII string representation
     * @param x Address to convert
     * @return String representation of the address
     */
    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        
        return string(s);
    }
    
    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}

/**
 * @title AidToken
 * @dev Manages aid tokens based on donor contributions
 * @notice Collects donations, issues tokens, and assigns stakeholders
 */
contract AidToken {
    // Reference to the DIDRegistry contract
    DIDRegistry public didRegistry;
    
    // Relief agency address
    address public reliefAgency;
    
    // Donation thresholds and counters
    uint256 public donationThreshold = 0.32 ether;  // ~$500 USD
    uint256 public minDonation = 0.013 ether;       // ~$20 USD
    uint256 public tokenIdCounter;
    uint256 public currentTokenBalance;
    uint256 public constant MAX_TOKENS_PER_TRANSACTION = 5;
    
    // Structure for storing aid token data
    struct AidTokenData {
        address[] donors;         // List of contributing donors
        uint256 donationAmount;   // Total donated amount
        address transferTeam;     // Transport team address
        address groundRelief;     // Local relief team address
        address recipient;        // Final recipient address
        bool isIssued;            // Whether the token has been issued
        bool isAssigned;          // Whether recipients have been assigned
        string location;          // Geographic location
    }
    
    // Token ID to token data mapping
    mapping(uint256 => AidTokenData) public aidTokens;
    
    // Donor address to unallocated balance mapping
    mapping(address => uint256) public donorBalances;
    
    // Events
    event Donation(address indexed donor, uint256 amount, uint256 tokenId);
    event AidTokenIssued(uint256 tokenId, address[] donors);
    event AidTokenAssigned(uint256 indexed tokenId, address transferTeam, address groundRelief, address recipient);
    
    /**
     * @dev Sets the relief agency and DIDRegistry addresses during deployment
     * @param _reliefAgency Relief agency address
     * @param _didRegistry DIDRegistry contract address
     */
    constructor(address _reliefAgency, address _didRegistry) {
        reliefAgency = _reliefAgency;
        didRegistry = DIDRegistry(_didRegistry);
    }
    
    // Access control modifier
    modifier onlyReliefAgency() {
        require(msg.sender == reliefAgency, "Only relief agency can call this function");
        _;
    }
    
    /**
     * @dev Receive and process donations
     * @notice Accepts donations and creates aid tokens when threshold is met
     */
    function donate() external payable {
        require(msg.value >= minDonation, "Donation must be at least $20");
        
        donorBalances[msg.sender] += msg.value;
        uint256 remaining = msg.value;
        uint256 tokenCount = 0;
        
        while (remaining > 0 && tokenCount < MAX_TOKENS_PER_TRANSACTION) {
            tokenCount++;
            
            uint256 spaceLeft = donationThreshold - currentTokenBalance;
            
            if (remaining >= spaceLeft) {
                // Complete current token
                aidTokens[tokenIdCounter].donors.push(msg.sender);
                aidTokens[tokenIdCounter].donationAmount += spaceLeft;
                currentTokenBalance += spaceLeft;
                remaining -= spaceLeft;
                
                emit Donation(msg.sender, spaceLeft, tokenIdCounter);
                
                issueAidToken(tokenIdCounter);
                tokenIdCounter++;
                currentTokenBalance = 0;
            } else {
                // Partial token funding
                aidTokens[tokenIdCounter].donors.push(msg.sender);
                aidTokens[tokenIdCounter].donationAmount += remaining;
                currentTokenBalance += remaining;
                
                emit Donation(msg.sender, remaining, tokenIdCounter);
                remaining = 0;
            }
        }
    }
    
    /**
     * @dev Issue an aid token when donation threshold is met
     * @param tokenId Token ID to issue
     */
    function issueAidToken(uint256 tokenId) internal {
        require(aidTokens[tokenId].donationAmount >= donationThreshold, "Donation threshold not met");
        
        aidTokens[tokenId].isIssued = true;
        emit AidTokenIssued(tokenId, aidTokens[tokenId].donors);
    }
    
    /**
     * @dev Assign stakeholders to an issued aid token
     * @param tokenId Token ID to assign
     * @param transferAddress Transport team address
     * @param groundAddress Ground relief team address
     * @param recipientAddress Aid recipient address
     * @param location Geographic location
     */
    function assignAidRecipients(
        uint256 tokenId,
        address transferAddress,
        address groundAddress,
        address recipientAddress,
        string memory location
    ) external onlyReliefAgency {
        require(tokenId < tokenIdCounter, "Token ID does not exist");
        require(aidTokens[tokenId].isIssued, "Token not yet issued");
        require(!aidTokens[tokenId].isAssigned, "This token already has assigned recipients");
        
        // Role verification
        require(didRegistry.getRole(transferAddress) == DIDRegistry.Role.Transporter, "Invalid transporter");
        require(didRegistry.getRole(groundAddress) == DIDRegistry.Role.GroundRelief, "Invalid ground relief");
        require(didRegistry.getRole(recipientAddress) == DIDRegistry.Role.Recipient, "Invalid recipient");
        
        // DID prefix validation
        require(didRegistry.validateDIDPrefix(transferAddress, "transporter-"), "Transfer address DID prefix mismatch");
        require(didRegistry.validateDIDPrefix(groundAddress, "groundrelief-"), "Ground relief DID prefix mismatch");
        require(didRegistry.validateDIDPrefix(recipientAddress, "recipient-"), "Recipient DID prefix mismatch");
        
        // Location validation
        require(
            keccak256(bytes(didRegistry.getLocation(transferAddress))) == keccak256(bytes(location)),
            "Transfer team location mismatch"
        );
        require(
            keccak256(bytes(didRegistry.getLocation(groundAddress))) == keccak256(bytes(location)),
            "Ground Relief location mismatch"
        );
        require(
            keccak256(bytes(didRegistry.getLocation(recipientAddress))) == keccak256(bytes(location)),
            "Recipient location mismatch"
        );
        
        // Assign stakeholders
        aidTokens[tokenId].transferTeam = transferAddress;
        aidTokens[tokenId].groundRelief = groundAddress;
        aidTokens[tokenId].recipient = recipientAddress;
        aidTokens[tokenId].isAssigned = true;
        aidTokens[tokenId].location = location;
        
        emit AidTokenAssigned(tokenId, transferAddress, groundAddress, recipientAddress);
    }
    
    /**
     * @dev Get the transport team address for a token
     * @param tokenId Token ID to query
     * @return Transport team address
     */
    function getTransferTeam(uint256 tokenId) public view returns (address) {
        return aidTokens[tokenId].transferTeam;
    }
    
    /**
     * @dev Get the ground relief team address for a token
     * @param tokenId Token ID to query
     * @return Ground relief team address
     */
    function getGroundRelief(uint256 tokenId) public view returns (address) {
        return aidTokens[tokenId].groundRelief;
    }
    
    /**
     * @dev Get the recipient address for a token
     * @param tokenId Token ID to query
     * @return Recipient address
     */
    function getRecipient(uint256 tokenId) public view returns (address) {
        return aidTokens[tokenId].recipient;
    }
    
    /**
     * @dev Check if a token has been issued
     * @param tokenId Token ID to query
     * @return True if the token has been issued
     */
    function isTokenIssued(uint256 tokenId) public view returns (bool) {
        return aidTokens[tokenId].isIssued;
    }
}

/**
 * @title AidTokenHandler
 * @dev Manages the verification and status updates for aid tokens
 * @notice Tracks the progress of aid delivery through various stages
 */
contract AidTokenHandler {
    // Reference to the AidToken contract
    AidToken public aidTokenContract;
    
    // Aid delivery status enumeration
    enum AidStatus {
        Issued,
        InTransit,
        Delivered,
        Claimed
    }
    
    // Token ID to status mapping
    mapping(uint256 => AidStatus) public aidStatus;
    
    // Events
    event AidTransferred(uint256 tokenId, address actor, AidStatus newStatus);
    event TokenStatusInitialized(uint256 indexed tokenId);
    
    /**
     * @dev Sets the AidToken contract address during deployment
     * @param _aidTokenAddress AidToken contract address
     */
    constructor(address _aidTokenAddress) {
        aidTokenContract = AidToken(_aidTokenAddress);
    }
    
    /**
     * @dev Get the status string for a token
     * @param tokenId Token ID to query
     * @return Human-readable status string
     */
    function getAidStatusString(uint256 tokenId) public view returns (string memory) {
        AidStatus status = aidStatus[tokenId];
        
        if (status == AidStatus.Issued) return "Issued";
        if (status == AidStatus.InTransit) return "InTransit";
        if (status == AidStatus.Delivered) return "Delivered";
        if (status == AidStatus.Claimed) return "Claimed";
        
        return "Unknown";
    }
    
    /**
     * @dev Initialize a token's status to Issued
     * @param tokenId Token ID to initialize
     */
    function initializeTokenStatus(uint256 tokenId) public {
        require(aidTokenContract.isTokenIssued(tokenId), "Token has not been issued yet");
        require(aidStatus[tokenId] == AidStatus(0), "Token status already initialized");
        
        aidStatus[tokenId] = AidStatus.Issued;
        
        emit AidTransferred(tokenId, msg.sender, AidStatus.Issued);
        emit TokenStatusInitialized(tokenId);
    }
    
    /**
     * @dev Get the status of multiple tokens in a batch
     * @param tokenIds Array of token IDs to query
     * @return Array of status strings
     */
    function getTokenStatusBatch(uint256[] calldata tokenIds) external view returns (string[] memory) {
        string[] memory statuses = new string[](tokenIds.length);
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            statuses[i] = getAidStatusString(tokenIds[i]);
        }
        
        return statuses;
    }
    
    /**
     * @dev Transport team updates token status to InTransit
     * @param tokenId Token ID to update
     */
    function authenticateTransferTeam(uint256 tokenId) public {
        require(aidTokenContract.isTokenIssued(tokenId), "Token has not been issued yet");
        
        address transferassigned = aidTokenContract.getTransferTeam(tokenId);
        require(msg.sender == transferassigned, "Only transfer team can mark InTransit");
        require(aidStatus[tokenId] == AidStatus.Issued, "Aid must be in 'Issued' status, or you have already claimed");
        
        aidStatus[tokenId] = AidStatus.InTransit;
        emit AidTransferred(tokenId, msg.sender, AidStatus.InTransit);
    }
    
    /**
     * @dev Ground relief team updates token status to Delivered
     * @param tokenId Token ID to update
     */
    function authenticateGroundRelief(uint256 tokenId) public {
        require(aidTokenContract.isTokenIssued(tokenId), "Token has not been issued yet");
        
        address groundassigned = aidTokenContract.getGroundRelief(tokenId);
        require(msg.sender == groundassigned, "Only ground relief team can mark Delivered");
        require(aidStatus[tokenId] == AidStatus.InTransit, "Aid must be in 'InTransit' status, or you have already claimed");
        
        aidStatus[tokenId] = AidStatus.Delivered;
        emit AidTransferred(tokenId, msg.sender, AidStatus.Delivered);
    }
    
    /**
     * @dev Recipient updates token status to Claimed
     * @param tokenId Token ID to update
     */
    function claimAid(uint256 tokenId) public {
        require(aidTokenContract.isTokenIssued(tokenId), "Token has not been issued yet");
        require(aidStatus[tokenId] != AidStatus.Claimed, "Already claimed");
        
        address repassigned = aidTokenContract.getRecipient(tokenId);
        require(msg.sender == repassigned, "Only recipient can claim aid");
        require(aidStatus[tokenId] == AidStatus.Delivered, "Aid must be in 'Delivered' status");
        
        aidStatus[tokenId] = AidStatus.Claimed;
        emit AidTransferred(tokenId, msg.sender, AidStatus.Claimed);
    }
}