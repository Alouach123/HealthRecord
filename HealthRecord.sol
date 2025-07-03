// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HealthcareRecords
 * @dev A comprehensive healthcare records management system on blockchain
 * @notice This contract manages patient medical records, doctor authorizations, and institutional access
 * @author Abdennour Alouach, Idris Elgarrab
 */
contract HealthcareRecords {

    /// @notice The administrator address with full system privileges
    address public admin;
    
    /// @notice Counter for unique medical record IDs
    uint256 private recordCounter;

    /**
     * @dev Contract constructor
     * @notice Sets the deployer as the initial administrator
     */
    constructor() {
        admin = msg.sender;
        recordCounter = 0;
    }

    /**
     * @dev Structure representing a medical record entry
     * @param id Unique identifier for the record
     * @param record The medical record content/description
     * @param addedBy Address of the entity that added this record
     * @param timestamp When the record was created
     * @param recordType Type of record (diagnostic, prescription, treatment, emergency, etc.)
     */
    struct MedicalRecord {
        uint256 id;
        string record;
        address addedBy;
        uint256 timestamp;
        string recordType;
    }

    /**
     * @dev Structure representing a patient's complete profile
     * @param name Patient's full name
     * @param birthYear Year of birth for age calculation
     * @param emergencyContact Emergency contact information
     * @param bloodType Patient's blood type
     * @param allergies Array of known allergies
     * @param medicalHistory Complete medical history records
     * @param authorizedDoctors List of authorized doctors
     * @param authorizedInstitutions List of authorized medical institutions
     * @param isActive Whether the patient account is active
     * @param registrationDate When the patient was registered
     */
    struct Patient {
        string name;
        uint256 birthYear;
        string emergencyContact;
        string bloodType;
        string[] allergies;
        MedicalRecord[] medicalHistory;
        address[] authorizedDoctors;
        address[] authorizedInstitutions;
        bool isActive;
        uint256 registrationDate;
    }

    /**
     * @dev Structure representing a doctor's profile
     * @param name Doctor's full name
     * @param specialization Medical specialization
     * @param licenseNumber Professional license number
     * @param isVerified Whether the doctor is verified by admin
     * @param registrationDate When the doctor was registered
     */
    struct Doctor {
        string name;
        string specialization;
        string licenseNumber;
        bool isVerified;
        uint256 registrationDate;
    }

    /**
     * @dev Structure representing a medical institution
     * @param name Institution name
     * @param institutionType Type of institution (hospital, clinic, laboratory, etc.)
     * @param admin Administrator address for the institution
     * @param isVerified Whether the institution is verified
     * @param registrationDate When the institution was registered
     */
    struct Institution {
        string name;
        string institutionType;
        address admin;
        bool isVerified;
        uint256 registrationDate;
    }

    // State mappings for efficient data retrieval
    /// @dev Mapping from patient address to their complete profile
    mapping(address => Patient) private patients;
    
    /// @dev Mapping from doctor address to their profile
    mapping(address => Doctor) private doctors;
    
    /// @dev Mapping from institution address to their profile
    mapping(address => Institution) private institutions;
    
    /// @dev Quick lookup for patient registration status
    mapping(address => bool) public isPatientRegistered;
    
    /// @dev Quick lookup for doctor registration status
    mapping(address => bool) public isDoctorRegistered;
    
    /// @dev Quick lookup for institution registration status
    mapping(address => bool) public isInstitutionRegistered;

    // Events for blockchain traceability and logging
    /**
     * @dev Emitted when a new patient is registered
     * @param patient Address of the registered patient
     * @param name Name of the patient
     * @param timestamp Registration timestamp
     */
    event PatientRegistered(address indexed patient, string name, uint256 timestamp);
    
    /**
     * @dev Emitted when a new doctor is registered
     * @param doctor Address of the registered doctor
     * @param name Name of the doctor
     * @param timestamp Registration timestamp
     */
    event DoctorRegistered(address indexed doctor, string name, uint256 timestamp);
    
    /**
     * @dev Emitted when a new institution is registered
     * @param institution Address of the registered institution
     * @param name Name of the institution
     * @param timestamp Registration timestamp
     */
    event InstitutionRegistered(address indexed institution, string name, uint256 timestamp);
    
    /**
     * @dev Emitted when a medical record is added
     * @param patient Patient address
     * @param recordId Unique record identifier
     * @param addedBy Address that added the record
     * @param timestamp When the record was added
     */
    event MedicalRecordAdded(address indexed patient, uint256 recordId, address addedBy, uint256 timestamp);
    
    /**
     * @dev Emitted when a doctor is authorized for a patient
     * @param patient Patient address
     * @param doctor Authorized doctor address
     * @param timestamp Authorization timestamp
     */
    event DoctorAuthorized(address indexed patient, address indexed doctor, uint256 timestamp);
    
    /**
     * @dev Emitted when an institution is authorized for a patient
     * @param patient Patient address
     * @param institution Authorized institution address
     * @param timestamp Authorization timestamp
     */
    event InstitutionAuthorized(address indexed patient, address indexed institution, uint256 timestamp);
    
    /**
     * @dev Emitted when emergency access is granted
     * @param patient Patient address
     * @param accessor Address accessing emergency information
     * @param timestamp Access timestamp
     */
    event EmergencyAccess(address indexed patient, address indexed accessor, uint256 timestamp);

    // Access control modifiers
    /**
     * @dev Restricts function access to the contract administrator only
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Seul l'administrateur peut effectuer cette action.");
        _;
    }

    /**
     * @dev Restricts access to authorized entities for a specific patient
     * @param _patient The patient address to check authorization for
     * @notice Allows access to: patient themselves, admin, authorized doctors, authorized institutions
     */
    modifier onlyAuthorized(address _patient) {
        require(
            msg.sender == _patient || 
            msg.sender == admin || 
            isAuthorizedDoctor(_patient, msg.sender) ||
            isAuthorizedInstitution(_patient, msg.sender),
            "Acces refuse."
        );
        _;
    }

    /**
     * @dev Restricts access to verified doctors only
     */
    modifier onlyVerifiedDoctor() {
        require(isDoctorRegistered[msg.sender] && doctors[msg.sender].isVerified, 
                "Docteur non verifie.");
        _;
    }

    /**
     * @dev Restricts access to verified institutions only
     */
    modifier onlyVerifiedInstitution() {
        require(isInstitutionRegistered[msg.sender] && institutions[msg.sender].isVerified, 
                "Institution non verifiee.");
        _;
    }

    /**
     * @dev Ensures the patient exists in the system
     * @param _patient Patient address to verify
     */
    modifier patientExists(address _patient) {
        require(isPatientRegistered[_patient], "Patient non enregistre.");
        _;
    }

    /**
     * @dev Ensures the patient account is active
     * @param _patient Patient address to check
     */
    modifier patientActive(address _patient) {
        require(patients[_patient].isActive, "Compte patient desactive.");
        _;
    }

    // === REGISTRATION FUNCTIONS ===

    /**
     * @dev Registers a new patient in the system
     * @param _patient Patient's blockchain address
     * @param _name Patient's full name
     * @param _birthYear Patient's birth year (must be between 1900-2024)
     * @param _emergencyContact Emergency contact information
     * @param _bloodType Patient's blood type
     * @notice Only admin can register patients
     * @notice Emits PatientRegistered event
     */
    function registerPatient(
        address _patient, 
        string memory _name, 
        uint256 _birthYear,
        string memory _emergencyContact,
        string memory _bloodType
    ) public onlyAdmin {
        require(!isPatientRegistered[_patient], "Patient deja enregistre.");
        require(_birthYear > 1900 && _birthYear <= 2024, "Annee de naissance invalide.");

        Patient storage p = patients[_patient];
        p.name = _name;
        p.birthYear = _birthYear;
        p.emergencyContact = _emergencyContact;
        p.bloodType = _bloodType;
        p.isActive = true;
        p.registrationDate = block.timestamp;

        isPatientRegistered[_patient] = true;

        emit PatientRegistered(_patient, _name, block.timestamp);
    }

    /**
     * @dev Registers a new doctor in the system
     * @param _doctor Doctor's blockchain address
     * @param _name Doctor's full name
     * @param _specialization Medical specialization
     * @param _licenseNumber Professional license number
     * @notice Only admin can register doctors
     * @notice Doctor is automatically verified upon registration
     * @notice Emits DoctorRegistered event
     */
    function registerDoctor(
        address _doctor,
        string memory _name,
        string memory _specialization,
        string memory _licenseNumber
    ) public onlyAdmin {
        require(!isDoctorRegistered[_doctor], "Docteur deja enregistre.");

        doctors[_doctor] = Doctor({
            name: _name,
            specialization: _specialization,
            licenseNumber: _licenseNumber,
            isVerified: true,
            registrationDate: block.timestamp
        });

        isDoctorRegistered[_doctor] = true;

        emit DoctorRegistered(_doctor, _name, block.timestamp);
    }

    /**
     * @dev Registers a new medical institution in the system
     * @param _institution Institution's blockchain address
     * @param _name Institution name
     * @param _institutionType Type of institution (hospital, clinic, laboratory, etc.)
     * @param _institutionAdmin Administrator address for the institution
     * @notice Only admin can register institutions
     * @notice Institution is automatically verified upon registration
     * @notice Emits InstitutionRegistered event
     */
    function registerInstitution(
        address _institution,
        string memory _name,
        string memory _institutionType,
        address _institutionAdmin
    ) public onlyAdmin {
        require(!isInstitutionRegistered[_institution], "Institution deja enregistree.");

        institutions[_institution] = Institution({
            name: _name,
            institutionType: _institutionType,
            admin: _institutionAdmin,
            isVerified: true,
            registrationDate: block.timestamp
        });

        isInstitutionRegistered[_institution] = true;

        emit InstitutionRegistered(_institution, _name, block.timestamp);
    }

    // === MEDICAL RECORDS MANAGEMENT FUNCTIONS ===

    /**
     * @dev Adds a new medical record to a patient's history
     * @param _patient Patient address
     * @param _record Medical record content/description
     * @param _recordType Type of record (diagnostic, prescription, treatment, emergency, etc.)
     * @notice Only authorized entities can add records
     * @notice Patient must exist and be active
     * @notice Emits MedicalRecordAdded event
     */
    function addMedicalRecord(
        address _patient, 
        string memory _record,
        string memory _recordType
    ) public onlyAuthorized(_patient) patientExists(_patient) patientActive(_patient) {
        recordCounter++;
        
        MedicalRecord memory newRecord = MedicalRecord({
            id: recordCounter,
            record: _record,
            addedBy: msg.sender,
            timestamp: block.timestamp,
            recordType: _recordType
        });

        patients[_patient].medicalHistory.push(newRecord);

        emit MedicalRecordAdded(_patient, recordCounter, msg.sender, block.timestamp);
    }

    /**
     * @dev Adds a new allergy to a patient's profile
     * @param _patient Patient address
     * @param _allergy Allergy description
     * @notice Only authorized entities can add allergies
     * @notice Patient must exist and be active
     */
    function addAllergy(address _patient, string memory _allergy) 
        public onlyAuthorized(_patient) patientExists(_patient) patientActive(_patient) {
        patients[_patient].allergies.push(_allergy);
    }

    /**
     * @dev Retrieves complete medical history for a patient
     * @param _patient Patient address
     * @return Array of all medical records for the patient
     * @notice Only authorized entities can access medical history
     * @notice Patient must exist
     */
    function getMedicalHistory(address _patient) 
        public view onlyAuthorized(_patient) patientExists(_patient) 
        returns (MedicalRecord[] memory) {
        return patients[_patient].medicalHistory;
    }

    /**
     * @dev Retrieves basic patient information
     * @param _patient Patient address
     * @return name Patient's name
     * @return birthYear Patient's birth year
     * @return emergencyContact Emergency contact info
     * @return bloodType Patient's blood type
     * @return allergies Array of patient's allergies
     * @return isActive Whether the patient account is active
     * @notice Only authorized entities can access patient info
     * @notice Patient must exist
     */
    function getPatientInfo(address _patient) 
        public view onlyAuthorized(_patient) patientExists(_patient) 
        returns (
            string memory name,
            uint256 birthYear,
            string memory emergencyContact,
            string memory bloodType,
            string[] memory allergies,
            bool isActive
        ) {
        Patient storage p = patients[_patient];
        return (p.name, p.birthYear, p.emergencyContact, p.bloodType, p.allergies, p.isActive);
    }

    /**
     * @dev Retrieves medical records filtered by type
     * @param _patient Patient address
     * @param _recordType Type of records to retrieve
     * @return Array of medical records matching the specified type
     * @notice Only authorized entities can access records
     * @notice Patient must exist
     * @notice Uses string comparison with keccak256 for efficiency
     */
    function getRecordsByType(address _patient, string memory _recordType) 
        public view onlyAuthorized(_patient) patientExists(_patient) 
        returns (MedicalRecord[] memory) {
        
        MedicalRecord[] memory allRecords = patients[_patient].medicalHistory;
        uint256 count = 0;
        
        // Count records of requested type
        for (uint256 i = 0; i < allRecords.length; i++) {
            if (keccak256(bytes(allRecords[i].recordType)) == keccak256(bytes(_recordType))) {
                count++;
            }
        }
        
        // Create array with correct size
        MedicalRecord[] memory filteredRecords = new MedicalRecord[](count);
        uint256 index = 0;
        
        // Populate filtered array
        for (uint256 i = 0; i < allRecords.length; i++) {
            if (keccak256(bytes(allRecords[i].recordType)) == keccak256(bytes(_recordType))) {
                filteredRecords[index] = allRecords[i];
                index++;
            }
        }
        
        return filteredRecords;
    }

    // === AUTHORIZATION MANAGEMENT FUNCTIONS ===

    /**
     * @dev Authorizes a doctor to access a patient's records
     * @param _patient Patient address
     * @param _doctor Doctor address to authorize
     * @notice Only authorized entities can grant access
     * @notice Patient must exist, be active, and doctor must be registered
     * @notice Prevents duplicate authorizations
     * @notice Emits DoctorAuthorized event
     */
    function authorizeDoctor(address _patient, address _doctor) 
        public onlyAuthorized(_patient) patientExists(_patient) patientActive(_patient) {
        require(isDoctorRegistered[_doctor], "Docteur non enregistre.");
        require(!isAuthorizedDoctor(_patient, _doctor), "Docteur deja autorise.");
        
        patients[_patient].authorizedDoctors.push(_doctor);
        
        emit DoctorAuthorized(_patient, _doctor, block.timestamp);
    }

    /**
     * @dev Authorizes an institution to access a patient's records
     * @param _patient Patient address
     * @param _institution Institution address to authorize
     * @notice Only authorized entities can grant access
     * @notice Patient must exist, be active, and institution must be registered
     * @notice Prevents duplicate authorizations
     * @notice Emits InstitutionAuthorized event
     */
    function authorizeInstitution(address _patient, address _institution) 
        public onlyAuthorized(_patient) patientExists(_patient) patientActive(_patient) {
        require(isInstitutionRegistered[_institution], "Institution non enregistree.");
        require(!isAuthorizedInstitution(_patient, _institution), "Institution deja autorisee.");
        
        patients[_patient].authorizedInstitutions.push(_institution);
        
        emit InstitutionAuthorized(_patient, _institution, block.timestamp);
    }

    /**
     * @dev Revokes doctor authorization for a patient
     * @param _patient Patient address
     * @param _doctor Doctor address to revoke
     * @notice Only authorized entities can revoke access
     * @notice Patient must exist
     * @notice Uses efficient array removal (swap with last element and pop)
     */
    function revokeDoctor(address _patient, address _doctor) 
        public onlyAuthorized(_patient) patientExists(_patient) {
        address[] storage authorizedDoctors = patients[_patient].authorizedDoctors;
        
        for (uint256 i = 0; i < authorizedDoctors.length; i++) {
            if (authorizedDoctors[i] == _doctor) {
                authorizedDoctors[i] = authorizedDoctors[authorizedDoctors.length - 1];
                authorizedDoctors.pop();
                break;
            }
        }
    }

    /**
     * @dev Revokes institution authorization for a patient
     * @param _patient Patient address
     * @param _institution Institution address to revoke
     * @notice Only authorized entities can revoke access
     * @notice Patient must exist
     * @notice Uses efficient array removal (swap with last element and pop)
     */
    function revokeInstitution(address _patient, address _institution) 
        public onlyAuthorized(_patient) patientExists(_patient) {
        address[] storage authorizedInstitutions = patients[_patient].authorizedInstitutions;
        
        for (uint256 i = 0; i < authorizedInstitutions.length; i++) {
            if (authorizedInstitutions[i] == _institution) {
                authorizedInstitutions[i] = authorizedInstitutions[authorizedInstitutions.length - 1];
                authorizedInstitutions.pop();
                break;
            }
        }
    }

    // === EMERGENCY ACCESS FUNCTIONS ===

    /**
     * @dev Provides emergency access to critical patient information
     * @param _patient Patient address
     * @return name Patient's name
     * @return bloodType Patient's blood type
     * @return allergies Patient's allergies
     * @return emergencyContact Emergency contact information
     * @notice Only verified doctors can access emergency information
     * @notice Patient must exist
     * @notice Bypasses normal authorization requirements for emergencies
     * @notice Should emit EmergencyAccess event in production (currently view function)
     */
    function emergencyAccess(address _patient) 
        public view onlyVerifiedDoctor patientExists(_patient) 
        returns (
            string memory name,
            string memory bloodType,
            string[] memory allergies,
            string memory emergencyContact
        ) {
        Patient storage p = patients[_patient];
        
        // In emergency cases, allow access to critical information
        return (p.name, p.bloodType, p.allergies, p.emergencyContact);
    }

    // === ADMINISTRATIVE FUNCTIONS ===

    /**
     * @dev Deactivates a patient account
     * @param _patient Patient address to deactivate
     * @notice Only admin can deactivate accounts
     * @notice Patient must exist
     * @notice Deactivated patients cannot have new records added
     */
    function deactivatePatient(address _patient) public onlyAdmin patientExists(_patient) {
        patients[_patient].isActive = false;
    }

    /**
     * @dev Reactivates a patient account
     * @param _patient Patient address to reactivate
     * @notice Only admin can reactivate accounts
     * @notice Patient must exist
     */
    function reactivatePatient(address _patient) public onlyAdmin patientExists(_patient) {
        patients[_patient].isActive = true;
    }

    /**
     * @dev Updates patient's emergency contact information
     * @param _patient Patient address
     * @param _newContact New emergency contact information
     * @notice Only authorized entities can update emergency contact
     * @notice Patient must exist
     */
    function updatePatientEmergencyContact(address _patient, string memory _newContact) 
        public onlyAuthorized(_patient) patientExists(_patient) {
        patients[_patient].emergencyContact = _newContact;
    }

    /**
     * @dev Transfers admin privileges to a new address
     * @param _newAdmin New administrator address
     * @notice Only current admin can transfer privileges
     * @notice New admin address cannot be zero address
     */
    function transferAdmin(address _newAdmin) public onlyAdmin {
        require(_newAdmin != address(0), "Adresse invalide.");
        admin = _newAdmin;
    }

    // === INTERNAL VERIFICATION FUNCTIONS ===

    /**
     * @dev Checks if a doctor is authorized for a specific patient
     * @param _patient Patient address
     * @param _doctor Doctor address to check
     * @return bool True if doctor is authorized, false otherwise
     * @notice Internal function for authorization verification
     */
    function isAuthorizedDoctor(address _patient, address _doctor) internal view returns (bool) {
        address[] memory doctorsList = patients[_patient].authorizedDoctors;
        for (uint256 i = 0; i < doctorsList.length; i++) {
            if (doctorsList[i] == _doctor) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Checks if an institution is authorized for a specific patient
     * @param _patient Patient address
     * @param _institution Institution address to check
     * @return bool True if institution is authorized, false otherwise
     * @notice Internal function for authorization verification
     */
    function isAuthorizedInstitution(address _patient, address _institution) internal view returns (bool) {
        address[] memory institutionsList = patients[_patient].authorizedInstitutions;
        for (uint256 i = 0; i < institutionsList.length; i++) {
            if (institutionsList[i] == _institution) {
                return true;
            }
        }
        return false;
    }

    // === PUBLIC INFORMATION FUNCTIONS ===

    /**
     * @dev Retrieves public doctor information
     * @param _doctor Doctor address
     * @return name Doctor's name
     * @return specialization Doctor's specialization
     * @return isVerified Whether the doctor is verified
     * @notice Doctor must be registered
     * @notice Public function for transparency
     */
    function getDoctorInfo(address _doctor) public view returns (
        string memory name,
        string memory specialization,
        bool isVerified
    ) {
        require(isDoctorRegistered[_doctor], "Docteur non enregistre.");
        Doctor storage d = doctors[_doctor];
        return (d.name, d.specialization, d.isVerified);
    }

    /**
     * @dev Retrieves public institution information
     * @param _institution Institution address
     * @return name Institution's name
     * @return institutionType Type of institution
     * @return isVerified Whether the institution is verified
     * @notice Institution must be registered
     * @notice Public function for transparency
     */
    function getInstitutionInfo(address _institution) public view returns (
        string memory name,
        string memory institutionType,
        bool isVerified
    ) {
        require(isInstitutionRegistered[_institution], "Institution non enregistree.");
        Institution storage inst = institutions[_institution];
        return (inst.name, inst.institutionType, inst.isVerified);
    }

    /**
     * @dev Returns the total number of medical records in the system
     * @return uint256 Total count of medical records
     * @notice Only admin can access this information
     * @notice Useful for system statistics and monitoring
     */
    function getTotalRecords() public view onlyAdmin returns (uint256) {
        return recordCounter;
    }

    /**
     * @dev Retrieves list of authorized doctors for a patient
     * @param _patient Patient address
     * @return Array of authorized doctor addresses
     * @notice Only authorized entities can access this information
     * @notice Patient must exist
     */
    function getAuthorizedDoctors(address _patient) 
        public view onlyAuthorized(_patient) patientExists(_patient) 
        returns (address[] memory) {
        return patients[_patient].authorizedDoctors;
    }

    /**
     * @dev Retrieves list of authorized institutions for a patient
     * @param _patient Patient address
     * @return Array of authorized institution addresses
     * @notice Only authorized entities can access this information
     * @notice Patient must exist
     */
    function getAuthorizedInstitutions(address _patient) 
        public view onlyAuthorized(_patient) patientExists(_patient) 
        returns (address[] memory) {
        return patients[_patient].authorizedInstitutions;
    }
}
