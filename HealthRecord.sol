// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HealthcareRecords {

    address public admin;
    uint256 private recordCounter;

    constructor() {
        admin = msg.sender;
        recordCounter = 0;
    }

    struct MedicalRecord {
        uint256 id;
        string record;
        address addedBy;
        uint256 timestamp;
        string recordType; // "diagnostic", "prescription", "treatment", "emergency", etc.
    }

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

    struct Doctor {
        string name;
        string specialization;
        string licenseNumber;
        bool isVerified;
        uint256 registrationDate;
    }

    struct Institution {
        string name;
        string institutionType; // "hospital", "clinic", "laboratory", etc.
        address admin;
        bool isVerified;
        uint256 registrationDate;
    }

    mapping(address => Patient) private patients;
    mapping(address => Doctor) private doctors;
    mapping(address => Institution) private institutions;
    mapping(address => bool) public isPatientRegistered;
    mapping(address => bool) public isDoctorRegistered;
    mapping(address => bool) public isInstitutionRegistered;

    // Events pour traçabilité
    event PatientRegistered(address indexed patient, string name, uint256 timestamp);
    event DoctorRegistered(address indexed doctor, string name, uint256 timestamp);
    event InstitutionRegistered(address indexed institution, string name, uint256 timestamp);
    event MedicalRecordAdded(address indexed patient, uint256 recordId, address addedBy, uint256 timestamp);
    event DoctorAuthorized(address indexed patient, address indexed doctor, uint256 timestamp);
    event InstitutionAuthorized(address indexed patient, address indexed institution, uint256 timestamp);
    event EmergencyAccess(address indexed patient, address indexed accessor, uint256 timestamp);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Seul l'administrateur peut effectuer cette action.");
        _;
    }

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

    modifier onlyVerifiedDoctor() {
        require(isDoctorRegistered[msg.sender] && doctors[msg.sender].isVerified, 
                "Docteur non verifie.");
        _;
    }

    modifier onlyVerifiedInstitution() {
        require(isInstitutionRegistered[msg.sender] && institutions[msg.sender].isVerified, 
                "Institution non verifiee.");
        _;
    }

    modifier patientExists(address _patient) {
        require(isPatientRegistered[_patient], "Patient non enregistre.");
        _;
    }

    modifier patientActive(address _patient) {
        require(patients[_patient].isActive, "Compte patient desactive.");
        _;
    }

    // === FONCTIONS D'ENREGISTREMENT ===

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

    // === FONCTIONS DE GESTION DES DOSSIERS MÉDICAUX ===

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

    function addAllergy(address _patient, string memory _allergy) 
        public onlyAuthorized(_patient) patientExists(_patient) patientActive(_patient) {
        patients[_patient].allergies.push(_allergy);
    }

    function getMedicalHistory(address _patient) 
        public view onlyAuthorized(_patient) patientExists(_patient) 
        returns (MedicalRecord[] memory) {
        return patients[_patient].medicalHistory;
    }

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

    function getRecordsByType(address _patient, string memory _recordType) 
        public view onlyAuthorized(_patient) patientExists(_patient) 
        returns (MedicalRecord[] memory) {
        
        MedicalRecord[] memory allRecords = patients[_patient].medicalHistory;
        uint256 count = 0;
        
        // Compter les enregistrements du type demandé
        for (uint256 i = 0; i < allRecords.length; i++) {
            if (keccak256(bytes(allRecords[i].recordType)) == keccak256(bytes(_recordType))) {
                count++;
            }
        }
        
        // Créer un tableau avec la bonne taille
        MedicalRecord[] memory filteredRecords = new MedicalRecord[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allRecords.length; i++) {
            if (keccak256(bytes(allRecords[i].recordType)) == keccak256(bytes(_recordType))) {
                filteredRecords[index] = allRecords[i];
                index++;
            }
        }
        
        return filteredRecords;
    }

    // === FONCTIONS D'AUTORISATION ===

    function authorizeDoctor(address _patient, address _doctor) 
        public onlyAuthorized(_patient) patientExists(_patient) patientActive(_patient) {
        require(isDoctorRegistered[_doctor], "Docteur non enregistre.");
        require(!isAuthorizedDoctor(_patient, _doctor), "Docteur deja autorise.");
        
        patients[_patient].authorizedDoctors.push(_doctor);
        
        emit DoctorAuthorized(_patient, _doctor, block.timestamp);
    }

    function authorizeInstitution(address _patient, address _institution) 
        public onlyAuthorized(_patient) patientExists(_patient) patientActive(_patient) {
        require(isInstitutionRegistered[_institution], "Institution non enregistree.");
        require(!isAuthorizedInstitution(_patient, _institution), "Institution deja autorisee.");
        
        patients[_patient].authorizedInstitutions.push(_institution);
        
        emit InstitutionAuthorized(_patient, _institution, block.timestamp);
    }

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

    // === FONCTIONS D'URGENCE ===

    function emergencyAccess(address _patient) 
        public view onlyVerifiedDoctor patientExists(_patient) 
        returns (
            string memory name,
            string memory bloodType,
            string[] memory allergies,
            string memory emergencyContact
        ) {
        Patient storage p = patients[_patient];
        
        // En cas d'urgence, permettre l'accès aux informations critiques
        return (p.name, p.bloodType, p.allergies, p.emergencyContact);
    }

    // === FONCTIONS ADMINISTRATIVES ===

    function deactivatePatient(address _patient) public onlyAdmin patientExists(_patient) {
        patients[_patient].isActive = false;
    }

    function reactivatePatient(address _patient) public onlyAdmin patientExists(_patient) {
        patients[_patient].isActive = true;
    }

    function updatePatientEmergencyContact(address _patient, string memory _newContact) 
        public onlyAuthorized(_patient) patientExists(_patient) {
        patients[_patient].emergencyContact = _newContact;
    }

    function transferAdmin(address _newAdmin) public onlyAdmin {
        require(_newAdmin != address(0), "Adresse invalide.");
        admin = _newAdmin;
    }

    // === FONCTIONS DE VÉRIFICATION ===

    function isAuthorizedDoctor(address _patient, address _doctor) internal view returns (bool) {
        address[] memory doctorsList = patients[_patient].authorizedDoctors;
        for (uint256 i = 0; i < doctorsList.length; i++) {
            if (doctorsList[i] == _doctor) {
                return true;
            }
        }
        return false;
    }

    function isAuthorizedInstitution(address _patient, address _institution) internal view returns (bool) {
        address[] memory institutionsList = patients[_patient].authorizedInstitutions;
        for (uint256 i = 0; i < institutionsList.length; i++) {
            if (institutionsList[i] == _institution) {
                return true;
            }
        }
        return false;
    }

    // === FONCTIONS DE CONSULTATION PUBLIQUE ===

    function getDoctorInfo(address _doctor) public view returns (
        string memory name,
        string memory specialization,
        bool isVerified
    ) {
        require(isDoctorRegistered[_doctor], "Docteur non enregistre.");
        Doctor storage d = doctors[_doctor];
        return (d.name, d.specialization, d.isVerified);
    }

    function getInstitutionInfo(address _institution) public view returns (
        string memory name,
        string memory institutionType,
        bool isVerified
    ) {
        require(isInstitutionRegistered[_institution], "Institution non enregistree.");
        Institution storage inst = institutions[_institution];
        return (inst.name, inst.institutionType, inst.isVerified);
    }

    function getTotalRecords() public view onlyAdmin returns (uint256) {
        return recordCounter;
    }

    function getAuthorizedDoctors(address _patient) 
        public view onlyAuthorized(_patient) patientExists(_patient) 
        returns (address[] memory) {
        return patients[_patient].authorizedDoctors;
    }

    function getAuthorizedInstitutions(address _patient) 
        public view onlyAuthorized(_patient) patientExists(_patient) 
        returns (address[] memory) {
        return patients[_patient].authorizedInstitutions;
    }
}

/*
=== NOUVELLES FONCTIONNALITÉS AJOUTÉES ===

1. STRUCTURES AMÉLIORÉES :
   - MedicalRecord : ID unique, timestamp, type d'enregistrement, auteur
   - Doctor : Informations détaillées avec spécialisation et licence
   - Institution : Support pour hôpitaux, cliniques, laboratoires
   - Patient : Contact d'urgence, groupe sanguin, allergies

2. GESTION DES RÔLES :
   - Enregistrement et vérification des médecins
   - Enregistrement et gestion des institutions médicales
   - Système d'autorisation granulaire

3. FONCTIONNALITÉS MÉDICALES :
   - Gestion des allergies
   - Types d'enregistrements médicaux
   - Filtrage des dossiers par type
   - Accès d'urgence aux informations critiques

4. SÉCURITÉ ET AUDIT :
   - Events pour traçabilité complète
   - Modifiers de sécurité avancés
   - Activation/désactivation des comptes
   - Révocation d'autorisations

5. ADMINISTRATION :
   - Transfert d'administration
   - Statistiques système
   - Gestion d'état des patients

6. OPTIMISATIONS :
   - Compteur d'enregistrements unique
   - Vérifications d'existence
   - Gestion des erreurs améliorée
*/